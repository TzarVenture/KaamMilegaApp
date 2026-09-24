import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/application.dart';
import '../repositories/application_repository.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';

/// Screen displaying the candidate's applied jobs with real-time status
class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Applications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.event_available_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Interview Schedule',
            onPressed: () => context.push('/interviews'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myApplicationsProvider);
          await ref.read(myApplicationsProvider.future);
        },
        child: applicationsAsync.when(
          data: (applications) {
            if (applications.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: FadeSlideIn(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.work_outline_rounded,
                                size: 38,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No applications yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Explore jobs matching your skills and apply in 1 tap!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => context.go('/jobs'),
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
                              child: const Text('Find Jobs Now'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: applications.length + 1,
              itemBuilder: (context, index) => FadeSlideIn(
                index: index,
                child: Builder(
                  builder: (context) {
                    if (index == 0) {
                      // Interviews quick banner
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.deepPurpleHeader,
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.deepPurpleHeader.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => context.push('/interviews'),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Interview Schedule',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'View your scheduled HR rounds & calls',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final app = applications[index - 1];
                    return _ApplicationCard(application: app);
                  },
                ),
              ),
            );
          },
          loading: () => const MyApplicationsSkeleton(),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load applications: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(myApplicationsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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

class _ApplicationCard extends StatelessWidget {
  final ApplicationItem application;

  const _ApplicationCard({required this.application});

  String _formatAppliedBadgeTime(DateTime? date) {
    if (date == null) return 'Applied recently';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes <= 1 ? 1 : diff.inMinutes;
      return 'Applied $mins ${mins == 1 ? "min" : "mins"} ago';
    } else if (diff.inHours < 24) {
      return 'Applied ${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago';
    } else {
      return 'Applied ${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appliedBadgeStr = _formatAppliedBadgeTime(application.createdAt);

    return PressableScale(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFEBEE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              context.push('/applications/${application.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real application status from the API
                  _StatusPill(status: application.status),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    application.jobTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Rating & Reviews row
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFFFB800),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '4.2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '|   4.4K+ Reviews',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Applied Badge & Recruiter Last Active Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Green Applied Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              appliedBadgeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recruiter Last Active (shrinks instead of overflowing)
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Recruiter last active 5w ago',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

/// Coloured pill for the application's real status (from the API).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final (Color fg, Color bg, IconData icon) = switch (s) {
      'shortlisted' => (
        AppColors.success,
        AppColors.successLight,
        Icons.star_rounded,
      ),
      'interview' || 'interview_scheduled' || 'interviewing' => (
        AppColors.accentDark,
        AppColors.accentLight,
        Icons.event_available_rounded,
      ),
      'hired' || 'selected' || 'accepted' => (
        AppColors.success,
        AppColors.successLight,
        Icons.verified_rounded,
      ),
      'rejected' || 'declined' => (
        AppColors.error,
        const Color(0xFFFEF2F2),
        Icons.cancel_rounded,
      ),
      _ => (AppColors.primary, AppColors.primaryLight, Icons.send_rounded),
    };
    final label = s.isEmpty
        ? 'Applied'
        : s
              .split('_')
              .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
              .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
