import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/booking.dart';
import '../repositories/expert_repository.dart';

/// Mentorship sessions booked by the signed-in user
/// (GET /mentorships/bookings/my).
class MySessionsScreen extends ConsumerWidget {
  const MySessionsScreen({super.key});

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
                child: _SessionCard(booking: bookings[index]),
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

  const _SessionCard({required this.booking});

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
