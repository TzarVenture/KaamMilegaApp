import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/job.dart';
import '../job_links.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// Compact job card for lists (Jobs tab, Saved Jobs, company page).
///
/// Shows only real job data: title, company and city, the full salary
/// range (short form, so it is never cut off), job type, experience,
/// openings, "KM Verified Employer" when the server marks the employer as
/// verified ([isVerifiedEmployer]), and when it was posted. Actions: call,
/// chat and apply.
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

  /// The employer is verified by the KaamMilega team (from the server;
  /// see `verifiedEmployerIdsProvider`). Off by default.
  final bool isVerifiedEmployer;

  /// Makes the chips (type, experience, openings, KM Verified) tappable;
  /// see [openJobLink]. Plain chips when null.
  final ValueChanged<JobCardLink>? onLinkTap;

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
    this.isVerifiedEmployer = false,
    this.onLinkTap,
  });

  VoidCallback? _link(JobCardLink link) {
    final tap = onLinkTap;
    return tap == null ? null : () => tap(link);
  }

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
                                fontWeight: FontWeight.w700,
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

                  // Job type, experience, openings, KM Verified, posted
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (job.jobType.trim().isNotEmpty)
                        _Tag(
                          icon: Icons.work_outline_rounded,
                          label: job.jobType.trim(),
                          hint: 'Show more ${job.jobType.trim()} jobs',
                          onTap: _link(JobCardLink.jobType),
                        ),
                      _Tag(
                        icon: Icons.schedule_rounded,
                        label: job.formattedExperience,
                        hint: 'Show jobs for this experience',
                        onTap: _link(JobCardLink.experience),
                      ),
                      _Tag(
                        icon: Icons.people_outline_rounded,
                        label:
                            '${job.vacancies} ${job.vacancies == 1 ? 'opening' : 'openings'}',
                        hint: 'Show people like you for this role',
                        onTap: _link(JobCardLink.openings),
                      ),
                      if (isVerifiedEmployer)
                        _VerifiedEmployerTag(
                          onTap: _link(JobCardLink.verifiedEmployer),
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
                                        'View & Apply',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w700,
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
                    fontWeight: disclosed ? FontWeight.w700 : FontWeight.w600,
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

/// Small grey chip with an icon (job type, experience, openings). Same
/// height as the KM Verified chip so the row lines up on every phone.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    this.hint = '',
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      onTap: onTap,
      hint: hint,
      background: AppColors.background,
      border: AppColors.border,
      icon: icon,
      iconColor: AppColors.textSecondary,
      label: label,
      labelStyle: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// "KM Verified Employer": light-blue chip with a verified tick, as on the
/// website. Shown only for employers the server marks as verified.
class _VerifiedEmployerTag extends StatelessWidget {
  const _VerifiedEmployerTag({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KaamMilega verified employer',
      child: _Chip(
        onTap: onTap,
        hint: 'Open the company page',
        background: AppColors.primaryLight,
        border: AppColors.primaryLightBorder,
        icon: Icons.verified_rounded,
        iconColor: AppColors.blue,
        label: 'KM Verified Employer',
        labelStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    this.onTap,
    this.hint = '',
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelStyle,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextStyle labelStyle;
  final VoidCallback? onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    // Ink (not Container) so the tap ripple shows on the chip colour.
    final chip = Ink(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return chip;
    return Semantics(
      button: true,
      hint: hint.isEmpty ? null : hint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(8),
          child: chip,
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
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
