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

/// Mentorship sessions booked by the signed-in user
/// (GET /mentorships/bookings/my).
class MySessionsScreen extends ConsumerWidget {
  const MySessionsScreen({super.key});

  /// Opens the rating sheet; on success reloads the list so the stars shown
  /// are the ones saved by the server.
  Future<void> _rateSession(
    BuildContext context,
    WidgetRef ref,
    BookingItem booking,
  ) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RateSessionSheet(booking: booking),
    );
    if (submitted != true || !context.mounted) return;
    ref.invalidate(myBookingsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks! Your review was submitted.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Sessions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myBookingsProvider.future),
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
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => FadeSlideIn(
                index: index,
                child: _SessionCard(
                  booking: bookings[index],
                  onRate: () => _rateSession(context, ref, bookings[index]),
                ),
              ),
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

class _SessionCard extends StatelessWidget {
  final BookingItem booking;
  final VoidCallback? onRate;

  const _SessionCard({required this.booking, this.onRate});

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  String get _priceLine {
    if (booking.isFree) return 'Free session';
    final amount = NumberFormat.decimalPattern('en_IN')
        .format(booking.amount.round());
    final payment = switch (booking.paymentStatus) {
      'paid' => 'Paid',
      'refunded' => 'Refunded',
      'pending' => 'Payment pending',
      _ => '',
    };
    return payment.isEmpty ? '₹$amount' : '₹$amount • $payment';
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
    final statusColor = _statusColor(booking.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(booking.status),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (booking.expertName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: booking.expertImage.isNotEmpty
                      ? NetworkImage(booking.expertImage)
                      : null,
                  child: booking.expertImage.isEmpty
                      ? Text(
                          booking.expertName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.expertName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (booking.expertHeadline.isNotEmpty)
                        Text(
                          booking.expertHeadline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.event_rounded,
            text: when == null
                ? 'Time not set'
                : DateFormat('EEE, d MMM yyyy • h:mm a').format(when),
          ),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.payments_outlined, text: _priceLine),
          if (booking.canJoin) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _joinMeeting(context),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join Meeting'),
              ),
            ),
          ] else if (booking.status == 'confirmed') ...[
            const SizedBox(height: 10),
            const Text(
              'The meeting link will appear here once the expert adds it.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (booking.isReviewed) ...[
            const SizedBox(height: 12),
            _YourReview(rating: booking.rating, review: booking.review),
          ] else if (booking.canReview && onRate != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('Rate session'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
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
                    color: AppColors.moduleEvents,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                            color: AppColors.moduleEvents,
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
