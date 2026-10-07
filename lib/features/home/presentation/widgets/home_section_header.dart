import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// The one header style used by every Home section: title, an optional
/// one-line description and an optional "See All" on the right.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  /// Space between the header and the section's content.
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('See All'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The look shared by every Home card: white, rounded, a soft shadow and
/// no outline (the Home page behind is the light brand background).
abstract final class HomeCard {
  static const double radius = 16;

  static final List<BoxShadow> shadow = [
    BoxShadow(
      color: AppColors.brandNavy.withValues(alpha: 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration decoration({double radius = radius}) => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadow,
  );
}

/// Puts the Home card shadow around a card built with [Material] + InkWell
/// (so the tap ripple stays inside the card).
class HomeCardShadow extends StatelessWidget {
  const HomeCardShadow({
    super.key,
    required this.child,
    this.radius = HomeCard.radius,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: HomeCard.shadow,
      ),
      child: child,
    );
  }
}
