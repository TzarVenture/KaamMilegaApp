import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/booking.dart';
import '../repositories/expert_repository.dart';

/// Which bookings the chips show.
enum SessionFilter {
  all('All Sessions'),
  upcoming('Upcoming / Confirmed'),
  completed('Completed'),
  cancelled('Cancelled');

  const SessionFilter(this.label);
  final String label;

  bool matches(BookingItem b) => switch (this) {
    SessionFilter.all => true,
    SessionFilter.upcoming => b.status == 'confirmed' || b.status == 'pending',
    SessionFilter.completed => b.status == 'completed',
    SessionFilter.cancelled => b.status == 'cancelled',
  };
}

/// "My Booked Sessions": the user's mentorship bookings
/// (GET /mentorships/bookings/my), as on the website.
class MySessionsScreen extends ConsumerStatefulWidget {
  const MySessionsScreen({super.key});

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen> {
  SessionFilter _filter = SessionFilter.all;

  /// Opens the rating sheet; on success reloads the list so the stars shown
  /// are the ones saved by the server.
  Future<void> _rateSession(BookingItem booking) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RateSessionSheet(booking: booking),
    );
    if (submitted != true || !mounted) return;
    ref.invalidate(myBookingsProvider);
    // The Expert's public rating and reviews now include this one.
    ref.invalidate(expertReviewsProvider(booking.expertId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks! Your review was submitted.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(myBookingsProvider);
      await ref.read(myBookingsProvider.future);
    } catch (_) {
      // Shown on the page with a Retry button.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Booked Sessions',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: bookingsAsync.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: bookingsAsync.when(
          data: (bookings) {
            if (bookings.isEmpty) {
              return NetworkStateView(
                isEmpty: true,
                emptyTitle: 'No sessions booked yet',
                emptyMessage:
                    'Book a 1-on-1 session with an expert and it will '
                    'appear here.',
                emptyAction: ElevatedButton(
                  onPressed: () => context.push('/experts'),
                  child: const Text('Browse Experts'),
                ),
                child: const SizedBox.shrink(),
              );
            }
            final shown = bookings.where(_filter.matches).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _Header(count: bookings.length),
                const SizedBox(height: 14),
                const _EscrowCard(),
                const SizedBox(height: 14),
                _FilterChips(
                  selected: _filter,
                  counts: {
                    for (final f in SessionFilter.values)
                      f: bookings.where(f.matches).length,
                  },
                  onSelected: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No ${_filter.label.toLowerCase()} sessions.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < shown.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FadeSlideIn(
                        index: i,
                        child: _SessionCard(
                          booking: shown[i],
                          onRate: () => _rateSession(shown[i]),
                        ),
                      ),
                    ),
              ],
            );
          },
          loading: () => const MyApplicationsSkeleton(),
          error: (err, _) => NetworkStateView.fromError(
            err,
            onRetry: () => ref.invalidate(myBookingsProvider),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '$count ${count == 1 ? 'Booking' : 'Bookings'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOnLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Shrinks (with "…") instead of overflowing on narrow screens
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/experts'),
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text(
                    'Find more mentors',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Track your 1-on-1 mentorship calls, join video meetings and see '
          'how your payment is protected.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// How session payments are held (backend: paid bookings go to the locked
/// balance, are released to the mentor when completed and refunded to the
/// user's wallet when cancelled).
class _EscrowCard extends StatelessWidget {
  const _EscrowCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.successLight, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escrow-Protected Payments',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your payment is held safely by KaamMilega until the '
                  'session is completed. If a session is cancelled, the '
                  'money is refunded to your wallet.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final SessionFilter selected;
  final Map<SessionFilter, int> counts;
  final ValueChanged<SessionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in SessionFilter.values) ...[
            ChoiceChip(
              label: Text('${f.label} (${counts[f] ?? 0})'),
              selected: f == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(f),
              selectedColor: AppColors.brandNavy,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: f == selected ? AppColors.brandNavy : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: f == selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final BookingItem booking;
  final VoidCallback? onRate;

  const _SessionCard({required this.booking, this.onRate});

  /// Status badge text and colour.
  (String, Color, IconData) get _status => switch (booking.status) {
    'confirmed' => (
      'Confirmed · Escrow protected',
      AppColors.success,
      Icons.verified_user_outlined,
    ),
    'completed' => ('Completed', AppColors.blue, Icons.check_circle_outline),
    'cancelled' => ('Cancelled', AppColors.error, Icons.cancel_outlined),
    'pending' => ('Payment pending', AppColors.warning, Icons.schedule_rounded),
    _ => (
      booking.status.isEmpty
          ? 'Unknown'
          : booking.status[0].toUpperCase() + booking.status.substring(1),
      AppColors.textSecondary,
      Icons.info_outline_rounded,
    ),
  };

  /// "PAID VIA RAZORPAY", "PAID FROM WALLET", "REFUNDED TO WALLET" ...
  String get _paymentLabel {
    if (booking.isFree) return 'FREE SESSION';
    return switch (booking.paymentStatus) {
      'refunded' => 'REFUNDED TO WALLET',
      'pending' => 'PAYMENT PENDING',
      'paid' => switch (booking.paymentMethod) {
        'razorpay' => 'PAID VIA RAZORPAY',
        'wallet' => 'PAID FROM WALLET',
        _ => 'PAID',
      },
      _ => '',
    };
  }

  Future<void> _joinMeeting(BuildContext context) async {
    final uri = Uri.tryParse(booking.meetingLink);
    var opened = false;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the meeting link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = booking.mentorshipTitle.isNotEmpty
        ? booking.mentorshipTitle
        : 'Mentorship session';
    final when = booking.scheduledAt;
    final (statusText, statusColor, statusIcon) = _status;
    final payment = _paymentLabel;
    final name = booking.expertName.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date, time and status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (when == null)
                  const _DateBit(
                    icon: Icons.event_rounded,
                    color: AppColors.brandNavy,
                    text: 'Time not set',
                  )
                else ...[
                  _DateBit(
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.brandNavy,
                    text: DateFormat('EEE, d MMM yyyy').format(when),
                  ),
                  _DateBit(
                    icon: Icons.schedule_rounded,
                    color: AppColors.accent,
                    text: DateFormat('h:mm a').format(when),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusText.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Mentorship, mentor and price
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MentorAvatar(name: name, image: booking.expertImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (name.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(
                            text: 'Mentor: ',
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (booking.expertHeadline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          booking.expertHeadline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!booking.isFree)
                            Text(
                              '₹${NumberFormat.decimalPattern('en_IN').format(booking.amount.round())}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (payment.isNotEmpty)
                            Text(
                              payment,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: AppColors.textLight,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // What to do next
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _footer(context),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (booking.canJoin) {
      return SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () => _joinMeeting(context),
          icon: const Icon(Icons.videocam_rounded),
          label: const Text('Join Meeting'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    switch (booking.status) {
      case 'confirmed':
        return const _Note(
          icon: Icons.schedule_rounded,
          text: 'Mentor will share the meeting link before the call',
          color: Color(0xFFB45309), // dark amber
          background: AppColors.moduleEventsLight,
        );
      case 'pending':
        return const _Note(
          icon: Icons.info_outline_rounded,
          text: 'The booking is confirmed once the payment is complete',
          color: Color(0xFFB45309),
          background: AppColors.moduleEventsLight,
        );
      case 'cancelled':
        return _Note(
          icon: Icons.undo_rounded,
          text: booking.paymentStatus == 'refunded'
              ? 'This session was cancelled. The payment was refunded to your '
                    'wallet.'
              : 'This session was cancelled.',
          color: AppColors.error,
          background: AppColors.moduleServicesLight,
        );
      case 'completed':
        if (booking.isReviewed) {
          return _YourReview(rating: booking.rating, review: booking.review);
        }
        if (booking.canReview && onRate != null) {
          return SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onRate,
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Rate session'),
            ),
          );
        }
        return const _Note(
          icon: Icons.check_circle_outline,
          text: 'Session completed',
          color: AppColors.blue,
          background: AppColors.primaryLight,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DateBit extends StatelessWidget {
  const _DateBit({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MentorAvatar extends StatelessWidget {
  const _MentorAvatar({required this.name, required this.image});

  final String name;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'M',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.brandNavy,
              ),
            ),
          ),
          // A broken photo leaves the initial showing.
          if (image.isNotEmpty)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The user's saved rating (from the server) shown on a session card.
class _YourReview extends StatelessWidget {
  const _YourReview({required this.rating, required this.review});

  final double rating;
  final String review;

  @override
  Widget build(BuildContext context) {
    final stars = rating.round().clamp(1, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          // Own node, so the label is not merged into the card's text.
          container: true,
          label: 'Your rating: $stars out of 5',
          child: ExcludeSemantics(
            child: Row(
              children: [
                const Flexible(
                  child: Text(
                    'Your rating ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: AppColors.moduleEventsText,
                  ),
              ],
            ),
          ),
        ),
        if (review.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            review,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet to rate a completed session: 1–5 stars and an optional
/// review. Pops `true` only after the server accepted it.
class RateSessionSheet extends ConsumerStatefulWidget {
  const RateSessionSheet({super.key, required this.booking});

  final BookingItem booking;

  @override
  ConsumerState<RateSessionSheet> createState() => _RateSessionSheetState();
}

class _RateSessionSheetState extends ConsumerState<RateSessionSheet> {
  final _reviewCtrl = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please choose 1 to 5 stars.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(expertRepositoryProvider)
          .submitBookingReview(
            bookingId: widget.booking.id,
            rating: _rating,
            review: _reviewCtrl.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is AppException
            ? e.message
            : 'Could not submit your review. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final title = widget.booking.mentorshipTitle.isNotEmpty
        ? widget.booking.mentorshipTitle
        : 'Mentorship session';
    return PopScope(
      canPop: !_sending,
      child: Container(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetDragHandle(),
                const Text(
                  'Rate your session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i star${i == 1 ? '' : 's'}',
                          onPressed: _sending
                              ? null
                              : () => setState(() {
                                  _rating = i;
                                  _error = null;
                                }),
                          icon: Icon(
                            i <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 36,
                            color: AppColors.moduleEventsText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewCtrl,
                  enabled: !_sending,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What went well? (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit review'),
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
