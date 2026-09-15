import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/application.dart';
import '../repositories/application_repository.dart';

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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.work_outline_rounded,
                            size: 56,
                            color: AppColors.textLight,
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
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: applications.length + 1,
              itemBuilder: (context, index) {
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'shortlisted':
      case 'interviewing':
        return AppColors.verifiedBlue;
      case 'hired':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(application.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (application.jobId.isNotEmpty) {
              context.push('/jobs/${application.jobId}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Company
                    Text(
                      application.companyName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        application.status.toUpperCase(),
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

                // Title
                Text(
                  application.jobTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                // Salary & City
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      application.cityName.isNotEmpty
                          ? application.cityName
                          : 'All India',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.currency_rupee_rounded,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      application.formattedSalary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
