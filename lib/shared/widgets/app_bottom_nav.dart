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
  ///
  /// With [activeIndex] (the position of the selected child; every child
  /// takes an equal share of the width) one orange bar slides smoothly to
  /// the selected tab. Its tabs use `indicatorInBar: true`.
  static Widget frame({required List<Widget> children, int? activeIndex}) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    );
    return Container(
      decoration: decoration,
      child: SafeArea(
        top: false,
        child: kMobileDesignSpec
            ? SizedBox(
                height: height,
                child: activeIndex == null
                    ? row
                    : Stack(
                        children: [
                          row,
                          _SlidingIndicator(
                            index: activeIndex,
                            count: children.length,
                          ),
                        ],
                      ),
              )
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
    this.badgeCount = 0,
    this.indicatorInBar = false,
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

  /// Unread count shown on the icon (hidden at 0).
  final int badgeCount;

  /// The bar draws one sliding orange indicator ([AppBottomNav.frame]
  /// with `activeIndex`); this tab only keeps its space.
  final bool indicatorInBar;

  Widget _withBadge(Widget icon) {
    if (badgeCount <= 0) return icon;
    return Badge(
      label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
      backgroundColor: AppColors.error,
      textColor: AppColors.white,
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kMobileDesignSpec) return _legacy();

    const active = AppColors.brandNavy;
    const inactive = AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: badgeCount > 0 ? '$label, $badgeCount unread' : label,
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
                  color: selected && !indicatorInBar
                      ? AppColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              _withBadge(
                Icon(
                  selected ? (activeIcon ?? icon) : icon,
                  size: 24,
                  color: selected ? active : inactive,
                ),
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
            _withBadge(
              Icon(
                selected ? (activeIcon ?? icon) : icon,
                color: color,
                size: 24,
              ),
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

/// The orange bar above the active tab, sliding to the new tab when the
/// selection changes. Sits where [AppBottomNavItem] keeps its space: the
/// tab's column (indicator 3, gap 6, icon 24, gap 4, label) is centred in
/// the bar.
class _SlidingIndicator extends StatelessWidget {
  const _SlidingIndicator({required this.index, required this.count});

  final int index;
  final int count;

  static const double _width = 24;
  static const double _height = 3;

  @override
  Widget build(BuildContext context) {
    final label = MediaQuery.textScalerOf(context).scale(11) * 1.2;
    final column = _height + 6 + 24 + 4 + label;
    final top = ((AppBottomNav.height - column) / 2).clamp(
      0.0,
      AppBottomNav.height,
    );
    final instant = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / count;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: instant
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: slot * index + (slot - _width) / 2,
              top: top,
              width: _width,
              height: _height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
