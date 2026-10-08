import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Navy band at the top of the Jobs tab, joined to the navy app bar (as on
/// Home): a title, one line with the real open-job count, the search box
/// ([search]) and a Saved jobs shortcut. Scrolls away; the job count, sort
/// and filters bar below stays pinned.
class JobsHeroCard extends StatelessWidget {
  const JobsHeroCard({
    super.key,
    required this.openJobs,
    required this.savedCount,
    required this.onSavedJobs,
    this.search,
  });

  /// Total open jobs from GET /jobs, or null while loading / when a search
  /// or filter makes the number mean something else.
  final int? openJobs;
  final int savedCount;
  final VoidCallback onSavedJobs;

  /// The search box (owned by the Jobs screen).
  final Widget? search;

  @override
  Widget build(BuildContext context) {
    final count = openJobs;
    final subtitle = count == null
        ? 'Apply directly and chat with recruiters.'
        : '${NumberFormat.decimalPattern('en_IN').format(count)} '
              '${count == 1 ? 'open job' : 'open jobs'} · '
              'Apply directly';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Find your next job',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SavedChip(count: savedCount, onTap: onSavedJobs),
            ],
          ),
          if (search != null) ...[const SizedBox(height: 16), search!],
        ],
      ),
    );
  }
}

/// "Saved 3" pill: opens the saved jobs.
class _SavedChip extends StatelessWidget {
  const _SavedChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Saved jobs: $count',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white.withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.22)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bookmark_rounded,
                  size: 16,
                  color: AppColors.accentBright,
                ),
                const SizedBox(width: 5),
                Text(
                  'Saved $count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
