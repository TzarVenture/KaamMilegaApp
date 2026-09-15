import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/job.dart';

/// Reusable Job Card component matching the design of kaammilega.com/jobs
class JobCard extends StatelessWidget {
  final Job job;
  final bool isTopMatch;
  final VoidCallback onTap;
  final VoidCallback onApply;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final bool isApplying;
  final bool isApplied;

  const JobCard({
    super.key,
    required this.job,
    this.isTopMatch = false,
    required this.onTap,
    required this.onApply,
    required this.onChat,
    required this.onCall,
    this.isApplying = false,
    this.isApplied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isTopMatch ? AppColors.topMatchBorder : AppColors.borderLight,
          width: isTopMatch ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Match Badge
                if (isTopMatch)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.topMatchGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'TOP MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Job Title
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Company Name + Hiring Now badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        job.company.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Hiring Now',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Salary and Location Grid
                Row(
                  children: [
                    // Salary Box
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                '₹',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MONTHLY SALARY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textLight,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  job.formattedSalary,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Location Box
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LOCATION',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textLight,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  job.formattedLocation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Tags Row (Hot, Job Type, Openings, KM Verified)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Hot badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hotRoseBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.hotRoseBorder),
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.hotRose,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    // Job Type
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        job.jobType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    // Openings
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${job.vacancies} OPENINGS',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    // KM Verified badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.verifiedBlueBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.verifiedBlueBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: AppColors.verifiedBlue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'KM VERIFIED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.verifiedBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Action Buttons Row (Phone, Chat, Apply)
                Row(
                  children: [
                    // Phone button
                    IconButton.filledTonal(
                      onPressed: onCall,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 20),
                    ),

                    const SizedBox(width: 8),

                    // Chat button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: onChat,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'CHAT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Apply Now / Applied button
                    Expanded(
                      flex: 3,
                      child: isApplied
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'APPLIED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.success,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryGradientStart,
                                    AppColors.primaryGradientEnd,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isApplying ? null : onApply,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                ),
                                child: isApplying
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'APPLY NOW',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                          fontStyle: FontStyle.italic,
                                        ),
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
      ),
    );
  }
}
