import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/job.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// Compact job card for lists (Jobs tab, Saved Jobs, company page).
///
/// Shows only real job data: title, company and city, the full salary
/// range (short form, so it is never cut off), job type, experience,
/// openings and when it was posted. Actions: call, chat and apply.
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final VoidCallback onApply;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final bool isApplying;
  final bool isApplied;
  final bool isSaved;
  final VoidCallback? onBookmarkToggle;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onApply,
    required this.onChat,
    required this.onCall,
    this.isApplying = false,
    this.isApplied = false,
    this.isSaved = false,
    this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    final company = job.company.trim();
    final place = job.cityName.trim().isNotEmpty
        ? job.cityName.trim()
        : job.location.trim();
    final subtitle = [company, place].where((v) => v.isNotEmpty).join(' · ');
    final posted = job.postedLabel;

    return PressableScale(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo, title, company · city, bookmark
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompanyAvatar(name: company),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onBookmarkToggle != null)
                        IconButton(
                          onPressed: onBookmarkToggle,
                          tooltip: isSaved ? 'Remove from saved' : 'Save job',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved
                                ? AppColors.accent
                                : AppColors.textLight,
                            size: 22,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Salary: full range in short form, never cut off
                  _SalaryLine(job: job),

                  const SizedBox(height: 10),

                  // Job type, experience, openings, posted
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (job.jobType.trim().isNotEmpty)
                        _Tag(label: job.jobType.trim()),
                      _Tag(label: job.formattedExperience),
                      _Tag(
                        label:
                            '${job.vacancies} ${job.vacancies == 1 ? 'opening' : 'openings'}',
                      ),
                      if (posted.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            posted,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Call, chat, apply
                  Row(
                    children: [
                      _IconAction(
                        icon: Icons.phone_outlined,
                        tooltip: 'Call',
                        onPressed: onCall,
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        tooltip: 'Chat with recruiter',
                        onPressed: onChat,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: isApplied
                            ? const _AppliedBadge()
                            : ElevatedButton(
                                onPressed: isApplying ? null : onApply,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primary
                                      .withValues(alpha: 0.6),
                                  elevation: 0,
                                  minimumSize: const Size(0, 42),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                                        'Apply now',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// Company initial on a light brand tint (the backend sends no job logos).
class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      alignment: Alignment.center,
      child: name.isEmpty
          ? const Icon(
              Icons.work_outline_rounded,
              size: 20,
              color: AppColors.primary,
            )
          : Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _SalaryLine extends StatelessWidget {
  const _SalaryLine({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final disclosed = job.hasSalary;
    return Row(
      children: [
        Icon(
          Icons.payments_outlined,
          size: 18,
          color: disclosed ? AppColors.success : AppColors.textLight,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: job.compactSalary,
                  style: TextStyle(
                    fontSize: disclosed ? 14.5 : 13,
                    fontWeight: disclosed ? FontWeight.w800 : FontWeight.w600,
                    color: disclosed
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                if (disclosed)
                  const TextSpan(
                    text: ' / month',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 19)),
      ),
    );
  }
}

class _AppliedBadge extends StatelessWidget {
  const _AppliedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 17),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Applied',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
