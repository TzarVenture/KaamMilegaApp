import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../../auth/models/user_profile.dart';

/// Profile "Analytics - Private to you": the three counters the server
/// keeps for this user (profile_views, post_impressions,
/// search_appearances from GET /user/profile). Three tiles side by side
/// that fit any phone width; Profile views opens the list of viewers.
class ProfileAnalyticsCard extends StatelessWidget {
  const ProfileAnalyticsCard({
    super.key,
    required this.user,
    required this.onViewersTap,
  });

  final UserProfile? user;
  final VoidCallback onViewersTap;

  static String formatCount(int n) => n < 100000
      ? NumberFormat.decimalPattern('en_IN').format(n)
      : NumberFormat.compact(locale: 'en_IN').format(n);

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: AppColors.textLight,
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Private to you',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.blue,
                    value: formatCount(u?.profileViewsCount ?? 0),
                    label: 'Profile views',
                    onTap: onViewersTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.insights_rounded,
                    color: AppColors.moduleP2P,
                    value: formatCount(u?.postImpressionsCount ?? 0),
                    label: 'Post impressions',
                    onTap: () => _explain(
                      context,
                      'Post impressions',
                      'How many times your profile card was shown to other '
                          'members, for example in Network and in "Connect '
                          'Just Like You". Each member counts once per visit.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.search_rounded,
                    color: AppColors.moduleExperts,
                    value: formatCount(u?.searchAppearancesCount ?? 0),
                    label: 'Search appearances',
                    onTap: () => _explain(
                      context,
                      'Search appearances',
                      'How many times you appeared in the results when '
                          'other members searched for people.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onViewersTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    "See who's viewed your profile",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _explain(BuildContext context, String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetDragHandle(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(height: 10),
                // Big numbers shrink instead of being cut off
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.textSecondary,
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
