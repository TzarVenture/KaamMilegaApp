import 'package:flutter/material.dart';

/// Gentle entrance for list items: fades in while sliding up a few pixels.
///
/// Lightweight on purpose:
/// - plays once when the item is first built (no controller, no loop);
/// - only the first [maxAnimatedIndex] items animate, with a small stagger,
///   so items that appear later while scrolling show up instantly;
/// - skipped entirely when the phone's "remove animations" setting is on.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.maxAnimatedIndex = 8,
    this.offsetY = 12,
  });

  final Widget child;

  /// Position in the list (used for the small stagger).
  final int index;

  /// Items at or after this index are shown without animation.
  final int maxAnimatedIndex;

  /// How far (in pixels) the item slides up while fading in.
  final double offsetY;

  static const Duration _base = Duration(milliseconds: 320);
  static const int _staggerMs = 45;

  @override
  Widget build(BuildContext context) {
    if (index < 0 ||
        index >= maxAnimatedIndex ||
        MediaQuery.of(context).disableAnimations) {
      return child;
    }

    final delayMs = index * _staggerMs;
    final totalMs = _base.inMilliseconds + delayMs;
    final start = delayMs / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      child: child,
      builder: (context, t, child) {
        final p = Curves.easeOutCubic.transform(
          ((t - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - p)),
            child: child,
          ),
        );
      },
    );
  }
}
