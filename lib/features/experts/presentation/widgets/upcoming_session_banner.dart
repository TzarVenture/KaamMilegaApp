import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../repositories/expert_repository.dart';

/// The user's next confirmed mentorship call, shown at the top of the
/// Experts page, with "View Session / Join Call" (opens My Booked
/// Sessions). Hidden for guests and when there is no upcoming call.
class UpcomingSessionBanner extends ConsumerWidget {
  const UpcomingSessionBanner({super.key, this.now});

  /// For tests; the current time otherwise.
  final DateTime? now;

  /// A call counts as upcoming until an hour after its start time.
  static const Duration _grace = Duration(hours: 1);

  /// Soonest confirmed session that has not finished, or null.
  static BookingItem? nextCall(List<BookingItem> bookings, DateTime now) {
    BookingItem? next;
    for (final b in bookings) {
      final at = b.scheduledAt;
      if (b.status != 'confirmed' || at == null) continue;
      if (at.isBefore(now.subtract(_grace))) continue;
      if (next == null || at.isBefore(next.scheduledAt!)) next = b;
    }
    return next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guests get an empty list without any request.
    final bookings = ref.watch(myBookingsProvider).asData?.value;
    if (bookings == null) return const SizedBox.shrink();
    final current = now ?? DateTime.now();
    final call = nextCall(bookings, current);
    if (call == null) return const SizedBox.shrink();

    final at = call.scheduledAt!;
    final live = !at.isAfter(current);
    final title = call.mentorshipTitle.isNotEmpty
        ? call.mentorshipTitle
        : 'Mentorship session';
    final mentor = call.expertName.trim();
    final day = DateUtils.isSameDay(at, current)
        ? 'Today'
        : DateFormat('EEE, d MMM').format(at);
    final time = DateFormat('h:mm a').format(at);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentLight, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: live
                              ? AppColors.successLight
                              : AppColors.moduleEventsLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          live ? 'HAPPENING NOW' : 'UPCOMING CALL',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: live
                                ? AppColors.success
                                : const Color(0xFFB45309), // dark amber
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (mentor.isNotEmpty) ...[
                              const TextSpan(text: 'Mentor: '),
                              TextSpan(
                                text: mentor,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const TextSpan(text: ' • '),
                            ],
                            TextSpan(text: '$day at $time'),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => context.push('/my-sessions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'View Session / Join Call',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
