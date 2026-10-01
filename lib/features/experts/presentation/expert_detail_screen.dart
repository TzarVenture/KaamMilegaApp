import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/payments/razorpay_checkout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/expert_offering.dart';
import '../models/expert_profile.dart';
import '../repositories/expert_repository.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../../app/theme/app_colors.dart';

class ExpertDetailScreen extends ConsumerStatefulWidget {
  final ExpertItem expert;

  const ExpertDetailScreen({super.key, required this.expert});

  @override
  ConsumerState<ExpertDetailScreen> createState() => _ExpertDetailScreenState();
}

class _ExpertDetailScreenState extends ConsumerState<ExpertDetailScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
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
      _selectedDate = day;
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

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFEF4444) : null,
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
    if (method == 'wallet') {
      await _bookWithWallet();
    } else if (method == 'online') {
      await _bookWithRazorpay();
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
      // Real reason instead of the old fake "booking placed" message
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  /// Bottom sheet: pay from wallet (if enough balance) or pay online
  Future<String?> _choosePaymentMethod() async {
    final price = widget.expert.price;
    // Make sure balances are fresh before showing them
    await ref.read(walletProvider.notifier).loadWallet();
    if (!mounted) return null;
    final summary = ref.read(walletProvider).summary;
    final walletLive =
        summary != null && !ref.read(walletProvider).isComingSoon;
    final mainBalance = summary?.mainBalance ?? 0;
    final canUseWallet = walletLive && mainBalance >= price;

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetDragHandle(),
              Text(
                'Pay ₹${price.toStringAsFixed(0)} for this session',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The fee is held safely in escrow until the session is completed.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: canUseWallet,
                leading: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Pay from KaamMilega Wallet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  !walletLive
                      ? 'Wallet is not available right now'
                      : canUseWallet
                      ? 'Balance: ₹${mainBalance.toStringAsFixed(0)}'
                      : 'Balance ₹${mainBalance.toStringAsFixed(0)} is not enough. Add money in Wallet.',
                ),
                onTap: canUseWallet ? () => Navigator.pop(ctx, 'wallet') : null,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.moduleExperts,
                ),
                title: const Text(
                  'Pay online',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('UPI, card or net banking via Razorpay'),
                onTap: () => Navigator.pop(ctx, 'online'),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: closeScreen
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w700),
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
    final slots = hours.isEmpty
        ? const <TimeOfDay>[]
        : WeeklyHours.slots(
            hours,
            _selectedDate,
            _sessionMinutes,
            earliest: _earliest,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mentor Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profile Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.moduleExpertsLight,
                  foregroundImage: expert.expertImage.isNotEmpty
                      ? NetworkImage(expert.expertImage)
                      : null,
                  onForegroundImageError: expert.expertImage.isNotEmpty
                      ? (_, _) {}
                      : null,
                  child: Text(
                    expert.expertName.isNotEmpty
                        ? expert.expertName[0].toUpperCase()
                        : 'E',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.moduleExperts,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        expert.expertName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  expert.expertHeadline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expert.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.moduleExpertsLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        expert.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.moduleExperts,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Session Details Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mentorship Offering',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  expert.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expert.description.isNotEmpty ? expert.description : 'Comprehensive 1-on-1 coaching session tailored to help you accelerate your career path.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaItem(
                      Icons.schedule_rounded,
                      'Duration',
                      '${expert.duration} Mins',
                    ),
                    _buildMetaItem(
                      Icons.videocam_outlined,
                      'Mode',
                      'Online 1:1',
                    ),
                    _buildMetaItem(
                      Icons.payments_outlined,
                      'Fee',
                      expert.price > 0 ? '₹${expert.price.toInt()}' : 'Free',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Schedule Picker
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Session Date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.moduleExperts,
                    ),
                    title: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Tap to choose a different day'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      bool bookable(DateTime day) =>
                          hours.isEmpty ||
                          WeeklyHours.slots(
                            hours,
                            day,
                            _sessionMinutes,
                            earliest: _earliest,
                          ).isNotEmpty;
                      final firstDate = DateTime.now();
                      final lastDate = firstDate.add(const Duration(days: 60));
                      var initial = _selectedDate;
                      if (initial.isBefore(DateUtils.dateOnly(firstDate)) ||
                          !bookable(initial)) {
                        final first = hours.isEmpty
                            ? firstDate
                            : WeeklyHours.firstBookableDay(
                                hours,
                                _sessionMinutes,
                                earliest: _earliest,
                              );
                        if (first == null) {
                          _showMessage(
                            'This expert has no free times in the next '
                            '60 days.',
                            isError: true,
                          );
                          return;
                        }
                        initial = first;
                      }
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        selectableDayPredicate: bookable,
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _snapTimeToDay(hours);
                      }
                    },
                  ),
                  if (hoursAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (hours.isNotEmpty)
                    _SlotPicker(
                      slots: slots,
                      selected: _selectedTime,
                      onSelected: (t) => setState(() => _selectedTime = t),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        hoursAsync.hasError
                            ? 'Could not load this expert\'s hours. Pick a time; '
                                  'the expert will confirm it.'
                            : 'This expert has not set fixed hours. Pick a '
                                  'time; the expert will confirm it.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.moduleExperts,
                      ),
                      title: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Tap to choose a time'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'What would you like to focus on? (e.g. Resume audit, interview prep)',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 4. Book Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _handleBookSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moduleExperts,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      expert.price > 0
                          ? 'Confirm & Pay ₹${expert.price.toInt()}'
                          : 'Book Free Session',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Start times inside the Expert's hours for the chosen day.
class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<TimeOfDay> slots;
  final TimeOfDay selected;
  final ValueChanged<TimeOfDay> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No free times on this day. Please choose another day.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Available times',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
                onSelected: (_) => onSelected(t),
              ),
          ],
        ),
      ],
    );
  }
}
