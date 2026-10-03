import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/mobile_design_spec.dart';

/// Look of the bottom navigation bars (main tabs and module screens).
///
/// Mobile spec 7.2: 64px tall plus the gesture-bar area, white with a 1px
/// top border; active tab navy with a filled icon and a 3 x 24 orange bar
/// above it; inactive grey; labels always shown. With the trial switch off
/// the bars look as before.
class AppBottomNav {
  AppBottomNav._();

  /// Bar height without the bottom safe area.
  static const double height = 64;

  static BoxDecoration get decoration => kMobileDesignSpec
      ? const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        )
      : BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        );

  /// Wraps the row of tabs: fixed height under the spec, the old padding
  /// otherwise.
  static Widget frame({required List<Widget> children}) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    );
    return Container(
      decoration: decoration,
      child: SafeArea(
        top: false,
        child: kMobileDesignSpec
            ? SizedBox(height: height, child: row)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: row,
              ),
      ),
    );
  }
}

/// One tab of a bottom navigation bar.
class AppBottomNavItem extends StatelessWidget {
  const AppBottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeIcon,
    this.legacyActiveColor = AppColors.primary,
    this.legacyPadding = 10,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Active colour used when the trial is off (module bars used their
  /// service colour). Under the spec the active tab is always navy.
  final Color legacyActiveColor;

  /// Side padding of a tab when the trial is off.
  final double legacyPadding;

  @override
  Widget build(BuildContext context) {
    if (!kMobileDesignSpec) return _legacy();

    const active = AppColors.brandNavy;
    const inactive = AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Orange indicator above the active icon
              Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                selected ? (activeIcon ?? icon) : icon,
                size: 24,
                color: selected ? active : inactive,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 0.11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? active : inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bars as they were before the trial.
  Widget _legacy() {
    final color = selected ? legacyActiveColor : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: legacyPadding, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? (activeIcon ?? icon) : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round (+) button in the middle of a bottom bar. Under the spec it
/// is the orange action button with a navy icon (7.16); with the trial off
/// it is [legacy], the button as it was.
class AppNavCenterButton extends StatelessWidget {
  const AppNavCenterButton({
    super.key,
    required this.onTap,
    required this.legacy,
    this.tooltip = 'Quick actions',
  });

  final VoidCallback onTap;
  final Widget legacy;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (!kMobileDesignSpec) {
      return GestureDetector(onTap: onTap, child: legacy);
    }
    return Expanded(
      child: Center(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: AppColors.brandNavy.withValues(alpha: 0.3),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.onAccent,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
