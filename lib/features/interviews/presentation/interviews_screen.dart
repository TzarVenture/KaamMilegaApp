import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/interview.dart';
import '../repositories/interview_repository.dart';

/// Candidate Interview Schedule & Tracking Screen
class InterviewsScreen extends ConsumerWidget {
  const InterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewsAsync = ref.watch(myInterviewsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Interview Schedule',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myInterviewsProvider),
        child: interviewsAsync.when(
          data: (interviews) {
            if (interviews.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Scheduled Interviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Apply to active jobs near you to get direct interview calls from HR!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/jobs'),
                        icon: const Icon(Icons.work_outline_rounded, size: 18),
                        label: const Text(
                          'Explore Active Jobs',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: interviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final interview = interviews[index];
                return _InterviewCard(interview: interview);
              },
            );
          },
          loading: () => const MyApplicationsSkeleton(),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load interviews: $err',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(myInterviewsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  final InterviewItem interview;

  const _InterviewCard({required this.interview});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.videocam_rounded;
      case 'in-person':
        return Icons.business_rounded;
      default:
        return Icons.phone_in_talk_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(interview.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Company & Status Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                interview.companyName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  interview.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Job Title
          Text(
            interview.jobTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Schedule Date & Time Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardLightBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(interview.type),
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        interview.formattedScheduleDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Interview Mode: ${interview.type}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (interview.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    interview.location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (interview.recruiterName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  'Interviewer: ${interview.recruiterName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
