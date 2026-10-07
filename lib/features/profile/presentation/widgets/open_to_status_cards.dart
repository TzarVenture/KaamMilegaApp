import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/models/user_profile.dart';

/// The "Open to work" and "Providing services" cards shown under the
/// Open To buttons. Each card appears only while that status is on in the
/// backend (`open_to_work.is_open`, `providing_services.is_providing`).
/// Side by side on wide screens, one under the other on phones.
class OpenToStatusCards extends StatelessWidget {
  const OpenToStatusCards({
    super.key,
    required this.user,
    required this.onEditWork,
    required this.onEditServices,
  });

  final UserProfile user;
  final VoidCallback onEditWork;
  final VoidCallback onEditServices;

  @override
  Widget build(BuildContext context) {
    final work = user.openToWorkPreferences;
    final services = user.providingServicesPreferences;
    final cards = <Widget>[
      if (work != null && work.isOpen)
        OpenToWorkCard(prefs: work, onEdit: onEditWork),
      if (services != null && services.isProviding)
        ProvidingServicesCard(prefs: services, onEdit: onEditServices),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards.first),
                  const SizedBox(width: 12),
                  Expanded(
                    child: cards.length > 1 ? cards[1] : const SizedBox(),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                cards[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Blue card: job titles, job types and locations, and who can see it.
class OpenToWorkCard extends StatelessWidget {
  const OpenToWorkCard({super.key, required this.prefs, required this.onEdit});

  final OpenToWorkPreferences prefs;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final details = [
      prefs.jobTypes.join(', '),
      prefs.locations.join(', '),
    ].where((s) => s.isNotEmpty).join(' · ');
    return _StatusCard(
      dotColor: AppColors.success,
      title: 'Open to work',
      badge: prefs.visibility == OpenToWorkPreferences.visibilityRecruiters
          ? 'RECRUITERS ONLY'
          : 'ALL MEMBERS',
      main: prefs.jobTitles.isNotEmpty
          ? prefs.jobTitles.join(', ')
          : 'Open to opportunities',
      details: details,
      actionLabel: 'Update preferences',
      background: AppColors.primaryLight,
      border: AppColors.primaryLightBorder,
      accent: AppColors.primary,
      onTap: onEdit,
    );
  }
}

/// Orange card: services, starting rate and service details.
class ProvidingServicesCard extends StatelessWidget {
  const ProvidingServicesCard({
    super.key,
    required this.prefs,
    required this.onEdit,
  });

  final ProvidingServicesPreferences prefs;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      dotColor: AppColors.accent,
      title: 'Providing services',
      badge: prefs.rateLabel,
      main: prefs.services.isNotEmpty
          ? prefs.services.join(', ')
          : 'Services offered',
      details: prefs.description.trim(),
      actionLabel: 'Update details',
      background: AppColors.accentLight,
      border: AppColors.accentBorder,
      accent: AppColors.accentText,
      onTap: onEdit,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.dotColor,
    required this.title,
    required this.badge,
    required this.main,
    required this.details,
    required this.actionLabel,
    required this.background,
    required this.border,
    required this.accent,
    required this.onTap,
  });

  final Color dotColor;
  final String title;

  /// Small pill next to the title; hidden when empty.
  final String badge;
  final String main;

  /// Smaller grey line under [main]; hidden when empty.
  final String details;
  final String actionLabel;
  final Color background;
  final Color border;

  /// Colour of the badge text and the action link.
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Column(
            // Keeps the action at the bottom when cards share a row.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    main,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 12),
                  Divider(height: 1, color: border),
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            actionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
