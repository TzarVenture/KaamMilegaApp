import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';

/// Navy card at the top of the Jobs tab (scrolls away; the job count, sort
/// and filters bar stays pinned). Shows only real numbers: the open-job
/// count from the server and the user's saved jobs.
class JobsHeroCard extends StatelessWidget {
  const JobsHeroCard({
    super.key,
    required this.openJobs,
    required this.savedCount,
    required this.onSavedJobs,
  });

  /// Total open jobs from GET /jobs, or null while loading / when a search
  /// or filter makes the number mean something else.
  final int? openJobs;
  final int savedCount;
  final VoidCallback onSavedJobs;

  @override
  Widget build(BuildContext context) {
    final count = openJobs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandNavy, AppColors.navy, AppColors.brandNavy],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Soft blue glow, as on the website card
            Positioned(
              right: -60,
              top: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue.withValues(alpha: 0.35),
                      AppColors.blue.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: AppColors.moduleSkillsLight,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Verified Indian Employment Portal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Find Jobs & Connect Direct',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Direct candidate-to-recruiter hiring with 1-click apply '
                    'and real-time interview management.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (count != null && count > 0)
                        _Fact(
                          icon: Icons.trending_up_rounded,
                          color: AppColors.success,
                          label:
                              '${NumberFormat.decimalPattern('en_IN').format(count)} '
                              'Active ${count == 1 ? 'Listing' : 'Listings'}',
                        ),
                      const _Fact(
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppColors.accentBright,
                        label: 'Direct Recruiter Chat',
                      ),
                      const _Fact(
                        icon: Icons.bolt_rounded,
                        color: AppColors.moduleEvents,
                        label: 'Instant Application',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onSavedJobs,
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              size: 19,
                              color: AppColors.moduleEventsText,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Saved Jobs ($savedCount)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}
