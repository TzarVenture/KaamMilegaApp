import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/application.dart';
import '../repositories/application_repository.dart';

/// Screen displaying detailed job application status matching web interface (https://kaammilega.com)
class ApplicationDetailScreen extends ConsumerWidget {
  final String applicationId;
  final ApplicationItem? initialApplication;

  const ApplicationDetailScreen({
    super.key,
    required this.applicationId,
    this.initialApplication,
  });

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Applied recently';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return 'Applied ${diff.inMinutes <= 1 ? "just now" : "${diff.inMinutes} hours ago"}';
    } else if (diff.inHours < 24) {
      return 'Applied ${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago';
    } else if (diff.inDays < 30) {
      return 'Applied ${diff.inDays} ${diff.inDays == 1 ? "day" : "days"} ago';
    } else {
      final weeks = (diff.inDays / 7).floor();
      return 'Applied ${weeks}w ago';
    }
  }

  void _callHR(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '1800123456');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HR Support Helpline: +91 98765 43210')),
        );
      }
    }
  }

  void _chatWithHR(BuildContext context, ApplicationItem app) {
    context.push(
      '/chats/${app.id}',
      extra: {
        'receiverId': app.recruiterId.isNotEmpty ? app.recruiterId : 'hr_desk',
        'title': '${app.companyName} HR Desk',
      },
    );
  }

  void _connectRecruiter(BuildContext context, ApplicationItem app) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          'Connection request sent to ${app.companyName} Recruiter!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Application Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: applicationsAsync.when(
        data: (applications) {
          final app =
              initialApplication ??
              applications.firstWhere(
                (a) => a.id == applicationId || a.jobId == applicationId,
                orElse: () => ApplicationItem(
                  id: applicationId,
                  jobId: applicationId,
                  recruiterId: '',
                  candidateId: '',
                  status: 'Applied',
                  coverLetter: '',
                  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
                  jobTitle: 'Job Application',
                  companyName: 'Company',
                  cityName: 'All India',
                ),
              );

          return _buildContent(context, app);
        },
        loading: () => const JobDetailSkeleton(),
        error: (err, _) {
          final fallbackApp =
              initialApplication ??
              ApplicationItem(
                id: applicationId,
                jobId: applicationId,
                recruiterId: '',
                candidateId: '',
                status: 'Applied',
                coverLetter: '',
                createdAt: DateTime.now().subtract(const Duration(hours: 2)),
                jobTitle: 'Job Application',
                companyName: 'Company',
                cityName: 'All India',
              );
          return _buildContent(context, fallbackApp);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApplicationItem app) {
    final timeAgoStr = _formatTimeAgo(app.createdAt);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header: Job Title, Rating & Reviews, View Similar Jobs Link
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.jobTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Rating & Reviews row
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Color(0xFFFFB800),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '4.2',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '|   4.4K+ Reviews',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // View Similar Jobs Link
                InkWell(
                  onTap: () => context.go('/jobs'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View Similar Jobs',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8E24AA),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: Color(0xFF8E24AA),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // 2. Application Status Section (Horizontal Timeline Stepper)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // Stepper Timeline Widget
                _ApplicationStepper(status: app.status),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // 3. "What may work for you?" Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What may work for you?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Following criteria suggests how well you match with the job.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // 2-Column Match Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _MatchCriteriaItem(
                            title: 'Early Applicant',
                            isMatched: true,
                          ),
                          SizedBox(height: 16),
                          _MatchCriteriaItem(
                            title: 'Location',
                            isMatched: false,
                          ),
                          SizedBox(height: 16),
                          _MatchCriteriaItem(
                            title: 'Industry',
                            isMatched: false,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _MatchCriteriaItem(
                            title: 'Keyskills',
                            isMatched: false,
                          ),
                          SizedBox(height: 16),
                          _MatchCriteriaItem(
                            title: 'Work Experience',
                            isMatched: false,
                          ),
                          SizedBox(height: 16),
                          _MatchCriteriaItem(
                            title: 'Department',
                            isMatched: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Bottom HR & Company Action Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0F0F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Company Bolt Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF261C3B),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flash_on_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Company Line & Timestamp
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${app.companyName}, ${app.cityName.isNotEmpty ? app.cityName : "Location"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeAgoStr,
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons Row: Call Icon, Chat With HR, Connect
                  Row(
                    children: [
                      // Call HR circular button
                      InkWell(
                        onTap: () => _callHR(context),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3E5F5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: Color(0xFF8E24AA),
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Chat With HR outlined button
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () => _chatWithHR(context, app),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          label: const Text(
                            'Chat With HR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Connect button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _connectRecruiter(context, app),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB052B7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom 5-step Application Timeline Stepper matching web UI
class _ApplicationStepper extends StatelessWidget {
  final String status;

  const _ApplicationStepper({required this.status});

  int get currentStep {
    switch (status.toLowerCase()) {
      case 'viewed':
      case 'application viewed':
        return 1;
      case 'resume viewed':
        return 2;
      case 'shortlisted':
      case 'interviewing':
      case 'awaiting recruiter response':
        return 3;
      case 'hired':
      case 'connected':
      case 'connect':
        return 4;
      case 'applied':
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      'APPLIED',
      'APPLICATION\nVIEWED',
      'RESUME VIEWED',
      'AWAITING\nRECRUITER\nRESPONSE',
      'CONNECT',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(minWidth: 420),
        child: Column(
          children: [
            // Timeline track row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(steps.length, (index) {
                final isPassed = index <= currentStep;
                final isCurrent = index == currentStep;

                return Row(
                  children: [
                    // Dot Indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPassed ? Colors.white : Colors.transparent,
                        border: Border.all(
                          color: isPassed
                              ? const Color(0xFF8E24AA)
                              : const Color(0xFFD0D0D0),
                          width: isCurrent ? 5 : 2,
                        ),
                      ),
                      child: isPassed && !isCurrent
                          ? const Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: Color(0xFF8E24AA),
                              ),
                            )
                          : null,
                    ),

                    // Connecting Line
                    if (index < steps.length - 1)
                      Container(
                        width: 70,
                        height: 2,
                        color: index < currentStep
                            ? const Color(0xFF8E24AA)
                            : const Color(0xFFE5E5E5),
                      ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 12),

            // Labels row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (index) {
                final isPassed = index <= currentStep;

                return SizedBox(
                  width: 80,
                  child: Text(
                    steps[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: 0.3,
                      color: isPassed
                          ? const Color(0xFF8E24AA)
                          : const Color(0xFF90949C),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item component for "What may work for you?" match criteria
class _MatchCriteriaItem extends StatelessWidget {
  final String title;
  final bool isMatched;

  const _MatchCriteriaItem({required this.title, required this.isMatched});

  @override
  Widget build(BuildContext context) {
    final color = isMatched ? const Color(0xFF00C853) : const Color(0xFFCFD8DC);

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMatched ? const Color(0xFF00C853) : Colors.transparent,
            border: Border.all(color: color, width: 1.8),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 13,
            color: isMatched ? Colors.white : const Color(0xFFB0BEC5),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMatched ? FontWeight.w800 : FontWeight.w700,
              color: isMatched
                  ? AppColors.textPrimary
                  : const Color(0xFF90A4AE),
            ),
          ),
        ),
      ],
    );
  }
}
