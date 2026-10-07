import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/expert_offering.dart';
import '../models/expert_profile.dart';
import '../models/expert_review.dart';
import '../repositories/expert_repository.dart';
import 'widgets/expert_reviews_section.dart';
import 'widgets/mentorship_checkout_sheet.dart';

const Color _star = Color(0xFFF59E0B);

/// A mentorship session: what it is, who gives it, picking a day and a
/// start time inside the mentor's hours, then booking (free request,
/// wallet or Razorpay). Everything shown comes from the backend; parts it
/// does not send (languages, takeaways, headline, bio) are hidden.
class ExpertDetailScreen extends ConsumerStatefulWidget {
  final ExpertItem expert;

  const ExpertDetailScreen({super.key, required this.expert});

  /// Days shown in the date grid, starting today.
  static const int dayCount = 7;

  @override
  ConsumerState<ExpertDetailScreen> createState() => _ExpertDetailScreenState();
}

class _ExpertDetailScreenState extends ConsumerState<ExpertDetailScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _notesController = TextEditingController();
  bool _isBooking = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Session date + time combined (local time; sent to the server as UTC)
  DateTime get _scheduledAt => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  /// Bookings must start at least 30 minutes from now.
  DateTime get _earliest => DateTime.now().add(const Duration(minutes: 30));

  int get _sessionMinutes => widget.expert.duration;

  /// The Expert's published hours (empty = none set, or not loaded).
  List<WeeklyHours> get _hours =>
      ref
          .read(expertAvailabilityProvider(widget.expert.expertId))
          .asData
          ?.value ??
      const <WeeklyHours>[];

  /// Whether [day] can be booked: it has a free slot inside the mentor's
  /// hours, or (no hours set) it has not ended yet.
  bool _bookable(List<WeeklyHours> hours, DateTime day) {
    if (hours.isEmpty) {
      final end = DateTime(day.year, day.month, day.day, 23, 59);
      return !end.isBefore(_earliest);
    }
    return WeeklyHours.slots(
      hours,
      day,
      _sessionMinutes,
      earliest: _earliest,
    ).isNotEmpty;
  }

  /// Moves the chosen day and time onto the Expert's hours when they are
  /// outside them (first free slot from now).
  void _snapToHours(List<WeeklyHours> hours) {
    if (hours.isEmpty) return;
    final fits = hours.any((h) => h.fits(_scheduledAt, _sessionMinutes));
    if (fits && !_scheduledAt.isBefore(_earliest)) return;
    final day = WeeklyHours.firstBookableDay(
      hours,
      _sessionMinutes,
      earliest: _earliest,
    );
    if (day == null) return;
    final slots = WeeklyHours.slots(
      hours,
      day,
      _sessionMinutes,
      earliest: _earliest,
    );
    setState(() {
      _selectedDate = DateUtils.dateOnly(day);
      _selectedTime = slots.first;
    });
  }

  /// After a new day is picked, keep the time if it is free that day,
  /// else take the day's first free slot.
  void _snapTimeToDay(List<WeeklyHours> hours) {
    if (hours.isEmpty) return;
    final slots = WeeklyHours.slots(
      hours,
      _selectedDate,
      _sessionMinutes,
      earliest: _earliest,
    );
    if (slots.isEmpty || slots.contains(_selectedTime)) return;
    setState(() => _selectedTime = slots.first);
  }

  void _selectDay(DateTime day, List<WeeklyHours> hours) {
    setState(() => _selectedDate = DateUtils.dateOnly(day));
    _snapTimeToDay(hours);
  }

  /// Calendar for days after the 7-day grid (up to 60 days ahead).
  Future<void> _pickLaterDate(List<WeeklyHours> hours) async {
    final firstDate = DateUtils.dateOnly(DateTime.now());
    final lastDate = firstDate.add(const Duration(days: 60));
    var initial = _selectedDate;
    if (initial.isBefore(firstDate) || !_bookable(hours, initial)) {
      final first = hours.isEmpty
          ? firstDate
          : WeeklyHours.firstBookableDay(
              hours,
              _sessionMinutes,
              earliest: _earliest,
            );
      if (first == null) {
        _showMessage(
          'This expert has no free times in the next 60 days.',
          isError: true,
        );
        return;
      }
      initial = DateUtils.dateOnly(first);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (d) => _bookable(hours, d),
    );
    if (picked != null && mounted) _selectDay(picked, hours);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleBookSession() async {
    if (_isBooking) return;
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      _showMessage('Please log in to book an expert session');
      return;
    }
    if (_scheduledAt.isBefore(
      DateTime.now().add(const Duration(minutes: 30)),
    )) {
      _showMessage(
        'Please choose a time at least 30 minutes from now.',
        isError: true,
      );
      return;
    }
    final hours = _hours;
    if (hours.isNotEmpty &&
        !hours.any((h) => h.fits(_scheduledAt, _sessionMinutes))) {
      _showMessage(
        'Please pick one of the times this expert is available.',
        isError: true,
      );
      return;
    }

    // Free session: simple request, no payment
    if (widget.expert.price <= 0) {
      await _bookFree();
      return;
    }

    // Paid session: let the user choose how to pay
    final method = await _choosePaymentMethod();
    if (!mounted) return;
    switch (method) {
      case SessionPayMethod.wallet:
        await _bookWithWallet();
      case SessionPayMethod.online:
        await _bookWithRazorpay();
      case null:
        break;
    }
  }

  Future<void> _bookFree() async {
    setState(() => _isBooking = true);
    try {
      await ref
          .read(expertRepositoryProvider)
          .bookSession(
            mentorshipId: widget.expert.id,
            scheduledAt: _scheduledAt,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      await _showSuccess(
        'Session Requested!',
        'Your session request with ${widget.expert.expertName} has been sent '
            'to the mentor. You will be notified once it is confirmed.',
      );
    } on AppException catch (e) {
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  /// "Confirm & Checkout" sheet: session summary, wallet (with the live
  /// balance and Top Up) or Razorpay, escrow note.
  Future<SessionPayMethod?> _choosePaymentMethod() async {
    // Fresh balance before showing it (the sheet also reloads after Top Up).
    final load = ref.read(walletProvider.notifier).loadWallet();
    if (!mounted) return null;
    final picked = showMentorshipCheckout(
      context,
      expert: widget.expert,
      scheduledAt: _scheduledAt,
    );
    await load;
    return picked;
  }

  Future<void> _bookWithWallet() async {
    setState(() => _isBooking = true);
    try {
      await ref
          .read(expertRepositoryProvider)
          .bookWithWallet(
            mentorshipId: widget.expert.id,
            scheduledAt: _scheduledAt,
            notes: _notesController.text.trim(),
          );
      // Server deducted the fee: refresh balances shown elsewhere
      await ref.read(walletProvider.notifier).loadWallet();
      if (!mounted) return;
      await _showSuccess(
        'Session Confirmed!',
        '₹${widget.expert.price.toStringAsFixed(0)} was paid from your wallet '
            'and is held in escrow until your session with '
            '${widget.expert.expertName} is completed.',
      );
    } on AppException catch (e) {
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _bookWithRazorpay() async {
    setState(() => _isBooking = true);
    try {
      final repo = ref.read(expertRepositoryProvider);
      // 1. Server creates a pending booking + Razorpay order (real price)
      final order = await repo.createBookingOrder(
        mentorshipId: widget.expert.id,
        scheduledAt: _scheduledAt,
        notes: _notesController.text.trim(),
      );

      // 2. Razorpay checkout
      final user = ref.read(authProvider).user;
      final payment = await RazorpayCheckout.pay(
        keyId: order.keyId,
        orderId: order.orderId,
        amountPaise: order.amountPaise,
        description: '${widget.expert.title} with ${widget.expert.expertName}',
        email: user?.email,
        contact: user?.mobile,
      );
      if (!mounted) return;
      if (payment.cancelled) {
        _showMessage('Payment cancelled. No money was charged.');
        return;
      }
      if (!payment.success) {
        _showMessage(payment.errorMessage ?? 'Payment failed.', isError: true);
        return;
      }

      // 3. Server verifies the payment and confirms the booking
      try {
        await repo.verifyBookingPayment(
          bookingId: order.bookingId,
          orderId: payment.orderId,
          paymentId: payment.paymentId,
          signature: payment.signature,
        );
      } on AppException catch (e) {
        if (!mounted) return;
        await _showSuccess(
          'Payment received, confirming',
          'Your payment was received but the booking could not be confirmed '
              'yet (${e.message}). Please do not pay again. Payment ID: '
              '${payment.paymentId}. Contact support with this ID if the '
              'session is not confirmed.',
          closeScreen: false,
        );
        return;
      }
      ref.read(walletProvider.notifier).loadWallet();
      if (!mounted) return;
      await _showSuccess(
        'Session Confirmed!',
        'Payment verified. Your session with ${widget.expert.expertName} is '
            'confirmed.',
      );
    } on AppException catch (e) {
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _showSuccess(
    String title,
    String message, {
    bool closeScreen = true,
  }) async {
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              closeScreen ? Icons.check_circle_rounded : Icons.info_rounded,
              color: closeScreen ? AppColors.success : _star,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (closeScreen && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final expert = widget.expert;
    final hoursAsync = ref.watch(expertAvailabilityProvider(expert.expertId));
    final hours = hoursAsync.asData?.value ?? const <WeeklyHours>[];
    ref.listen(expertAvailabilityProvider(expert.expertId), (_, next) {
      final loaded = next.asData?.value;
      if (loaded != null) _snapToHours(loaded);
    });
    // Same request the reviews section uses (shared, not fetched twice).
    final reviews = expert.expertId.trim().isEmpty
        ? null
        : ref.watch(expertReviewsProvider(expert.expertId)).asData?.value;

    final today = DateUtils.dateOnly(DateTime.now());
    final days = [
      for (var i = 0; i < ExpertDetailScreen.dayCount; i++)
        today.add(Duration(days: i)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mentorship Session',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: _BookBar(
        price: expert.price,
        busy: _isBooking,
        onBook: _handleBookSession,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _HeaderCard(expert: expert, reviews: reviews),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeeRow(price: expert.price),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                _Label(
                  icon: Icons.calendar_month_outlined,
                  text: 'SELECT DATE',
                  trailing: TextButton(
                    onPressed: hoursAsync.isLoading
                        ? null
                        : () => _pickLaterDate(hours),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('More dates'),
                  ),
                ),
                const SizedBox(height: 8),
                if (hoursAsync.isLoading)
                  const ShimmerBox(
                    width: double.infinity,
                    height: 128,
                    borderRadius: 12,
                  )
                else
                  _DayGrid(
                    days: days,
                    selected: _selectedDate,
                    isBookable: (d) => _bookable(hours, d),
                    onSelected: (d) => _selectDay(d, hours),
                  ),
                const SizedBox(height: 18),
                const _Label(
                  icon: Icons.schedule_rounded,
                  text: "EXPERT'S AVAILABLE TIME",
                ),
                const SizedBox(height: 10),
                if (hoursAsync.isLoading)
                  const ShimmerBox(
                    width: double.infinity,
                    height: 52,
                    borderRadius: 12,
                  )
                else if (hours.isNotEmpty)
                  _TimeWithHours(
                    windows: [
                      for (final h in hours)
                        if (h.dayOfWeek == _selectedDate.weekday % 7) h,
                    ],
                    slots: WeeklyHours.slots(
                      hours,
                      _selectedDate,
                      _sessionMinutes,
                      earliest: _earliest,
                    ),
                    selected: _selectedTime,
                    onSelected: (t) => setState(() => _selectedTime = t),
                  )
                else
                  _TimeWithoutHours(
                    failed: hoursAsync.hasError,
                    time: _selectedTime,
                    onTap: _pickTime,
                  ),
                const SizedBox(height: 18),
                const _Label(
                  icon: Icons.edit_note_rounded,
                  text: 'TOPICS TO DISCUSS',
                  optional: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Share your goals, challenges, or questions for this '
                        'session...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.blue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (expert.description.trim().isNotEmpty ||
              expert.takeaways.isNotEmpty) ...[
            const SizedBox(height: 14),
            _AboutCard(expert: expert),
          ],
          const SizedBox(height: 14),
          _MentorCard(expert: expert, reviews: reviews),
          const SizedBox(height: 14),
          ExpertReviewsSection(
            expertId: expert.expertId,
            expertName: expert.expertName,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = 18});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Small caps section label with an icon, optional "(OPTIONAL)" and an
/// action on the right.
class _Label extends StatelessWidget {
  const _Label({
    required this.icon,
    required this.text,
    this.optional = false,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final bool optional;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              children: [
                if (optional)
                  const TextSpan(
                    text: '  (OPTIONAL)',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Rating text from the reviews endpoint when there are reviews, else the
/// mentorship's own rating, else "New" (never an invented score).
String _ratingText(ExpertItem expert, ExpertReviews? reviews) {
  final total = reviews?.totalReviews ?? 0;
  if (reviews != null && total > 0) {
    final avg = reviews.averageRating.toStringAsFixed(1);
    return '$avg ($total ${total == 1 ? 'review' : 'reviews'})';
  }
  if (expert.rating > 0) {
    final avg = expert.rating.toStringAsFixed(1);
    return expert.reviews > 0
        ? '$avg (${expert.reviews} ${expert.reviews == 1 ? 'review' : 'reviews'})'
        : avg;
  }
  return 'New';
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.expert, required this.reviews});

  final ExpertItem expert;
  final ExpertReviews? reviews;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (expert.category.trim().isNotEmpty)
                _Chip(
                  text: expert.category.toUpperCase(),
                  background: AppColors.primaryLight,
                  border: AppColors.primaryLightBorder,
                  color: AppColors.brandNavy,
                ),
              _Chip(
                icon: Icons.star_rounded,
                text: _ratingText(expert, reviews),
                background: AppColors.topMatchCardBg,
                border: AppColors.topMatchBorder,
                color: AppColors.accentText,
                iconColor: _star,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            expert.title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _InfoItem(
                icon: Icons.schedule_rounded,
                iconColor: AppColors.brandNavy,
                label: 'DURATION',
                value: '${expert.duration} Mins',
              ),
              // Every booking is for one mentee (backend Booking.user_id).
              const _InfoItem(
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.success,
                label: 'SESSION FORMAT',
                value: '1-on-1',
              ),
              if (expert.languages.isNotEmpty)
                _InfoItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: AppColors.accent,
                  label: 'LANGUAGES',
                  value: expert.languages.join(' / '),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.background,
    required this.border,
    required this.color,
    this.icon,
    this.iconColor,
  });

  final String text;
  final Color background;
  final Color border;
  final Color color;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.price});

  final double price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SESSION FEE',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: price > 0 ? _rupees(price) : 'Free',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '  / 1-on-1 session',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _rupees(double price) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(price.round())}';

/// Seven days from today, four per row. Days without a free slot are
/// greyed out with "Off". A later day chosen from the calendar is added
/// as the last cell so the choice stays visible.
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.days,
    required this.selected,
    required this.isBookable,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime selected;
  final bool Function(DateTime) isBookable;
  final ValueChanged<DateTime> onSelected;

  static const int perRow = 4;
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final cells = [
      ...days,
      if (!days.any((d) => DateUtils.isSameDay(d, selected))) selected,
    ];
    final today = days.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final d in cells)
              SizedBox(
                width: width,
                child: _DayCell(
                  top: DateUtils.isSameDay(d, today)
                      ? 'TODAY'
                      : days.contains(d)
                      ? DateFormat('EEE').format(d).toUpperCase()
                      : DateFormat('d MMM').format(d).toUpperCase(),
                  day: days.contains(d)
                      ? '${d.day}'
                      : DateFormat('EEE').format(d),
                  semantics: DateFormat('EEEE, d MMMM').format(d),
                  selected: DateUtils.isSameDay(d, selected),
                  enabled: isBookable(d),
                  onTap: () => onSelected(d),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.top,
    required this.day,
    required this.semantics,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String top;
  final String day;
  final String semantics;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.white
        : enabled
        ? AppColors.textPrimary
        : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? semantics : '$semantics, not available',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.brandNavy
            : enabled
            ? AppColors.white
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.brandNavy : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  top,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary.withValues(
                            alpha: enabled ? 1 : 0.6,
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (!enabled)
                  const Text(
                    'Off',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mentor's window(s) for the chosen day and the start times in them.
class _TimeWithHours extends StatelessWidget {
  const _TimeWithHours({
    required this.windows,
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<WeeklyHours> windows;
  final List<TimeOfDay> slots;
  final TimeOfDay selected;
  final ValueChanged<TimeOfDay> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const _Notice(
        icon: Icons.event_busy_outlined,
        text:
            'The mentor is unavailable on this day. Please pick another day '
            'above.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in windows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brandNavy, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.brandNavy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Session Window: ${w.start.format(context)} – '
                      '${w.end.format(context)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Available times',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in slots)
              ChoiceChip(
                label: Text(t.format(context)),
                selected: t == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(t),
                selectedColor: AppColors.brandNavy,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: t == selected ? AppColors.brandNavy : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t == selected
                      ? AppColors.white
                      : AppColors.textPrimary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Configured directly by the mentor for this day.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// The mentor has no fixed hours (or they could not be loaded): pick any
/// time, the mentor confirms it.
class _TimeWithoutHours extends StatelessWidget {
  const _TimeWithoutHours({
    required this.failed,
    required this.time,
    required this.onTap,
  });

  final bool failed;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Notice(
          icon: Icons.info_outline_rounded,
          text: failed
              ? "Could not load this expert's hours. Pick a time; the expert "
                    'will confirm it.'
              : 'This expert has not set fixed hours. Pick a time; the '
                    'expert will confirm it.',
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brandNavy, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppColors.brandNavy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      time.format(context),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.expert});

  final ExpertItem expert;

  @override
  Widget build(BuildContext context) {
    final description = expert.description.trim();
    return _Card(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: AppColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'About this Mentorship Session',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (expert.takeaways.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Key Takeaways from this session:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in expert.takeaways)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dark card about the mentor: photo or initial, name, headline and bio
/// (each only when the backend has it) and a link to the full profile.
class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.expert, required this.reviews});

  final ExpertItem expert;
  final ExpertReviews? reviews;

  /// "Top Rated Mentor" only from real reviews: 4.5+ average over 5+.
  bool get _topRated {
    final r = reviews;
    return r != null && r.totalReviews >= 5 && r.averageRating >= 4.5;
  }

  @override
  Widget build(BuildContext context) {
    final name = expert.expertName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';
    final hasPhoto = expert.expertImage.isNotEmpty;
    final canOpen = expert.expertId.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.black, AppColors.brandNavy, AppColors.blue],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 20,
                color: AppColors.accentBright,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meet Your Mentor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.2),
                  ),
                ),
                alignment: Alignment.center,
                child: hasPhoto
                    ? Image.network(
                        expert.expertImage,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _Initial(initial),
                      )
                    : _Initial(initial),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Mentor',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (expert.expertHeadline.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        expert.expertHeadline.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLightBorder.withValues(
                            alpha: 0.95,
                          ),
                        ),
                      ),
                    ],
                    if (_topRated) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: AppColors.topMatchGold,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Top Rated Mentor',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.topMatchGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (expert.expertBio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              expert.expertBio.trim(),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (canOpen) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/members/${expert.expertId}'),
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: const Text('View Full Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, 42),
                side: BorderSide(
                  color: AppColors.white.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.white,
      ),
    );
  }
}

/// Fixed bottom bar: fee and Book Session, escrow line for paid sessions.
class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.price,
    required this.busy,
    required this.onBook,
  });

  final double price;
  final bool busy;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final paid = price > 0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (paid) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _rupees(price),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'per session',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: busy ? null : onBook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandNavy,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.brandNavy.withValues(
                          alpha: 0.6,
                        ),
                        minimumSize: const Size.fromHeight(50),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    paid ? 'Book Session' : 'Book Free Session',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              if (paid) ...[
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 13,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Protected by KaamMilega Escrow Guarantee',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
