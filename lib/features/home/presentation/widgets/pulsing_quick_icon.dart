import 'package:flutter/material.dart';

/// A round quick-action icon that keeps drawing the eye: a soft glow, and
/// in a calm loop two "radar" rings spread out while the icon gives a small
/// bounce, followed by a short rest.
///
/// Light on the phone: one controller, only transforms and opacity are
/// animated, the painting is isolated ([RepaintBoundary]), and the loop
/// pauses whenever the screen is not visible (another page on top, another
/// tab, app in the background). Reduced-motion settings show it still.
class PulsingQuickIcon extends StatefulWidget {
  const PulsingQuickIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  /// One loop: rings and bounce in the first part, then a rest.
  static const Duration cycle = Duration(milliseconds: 2800);

  @override
  State<PulsingQuickIcon> createState() => _PulsingQuickIconState();
}

class _PulsingQuickIconState extends State<PulsingQuickIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PulsingQuickIcon.cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0 → 1 over [start, end] of the loop, else 0 (before) / 1 (after).
  static double _phase(double v, double start, double end) =>
      ((v - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.color;
    final icon = Icon(widget.icon, color: color, size: size * 0.5);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _controller,
          child: icon,
          builder: (context, child) {
            final v = _controller.value;
            // Two rings, the second slightly later, in the first 65%.
            final r1 = Curves.easeOut.transform(_phase(v, 0.0, 0.5));
            final r2 = Curves.easeOut.transform(_phase(v, 0.15, 0.65));
            // Bounce in the first 25%: up and back.
            final b = _phase(v, 0.0, 0.25);
            final bounce =
                1 + 0.12 * Curves.easeInOut.transform(1 - (b * 2 - 1).abs());
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _Ring(size: size, color: color, progress: r1),
                _Ring(size: size, color: color, progress: r2),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: widget.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Transform.scale(scale: bounce, child: child),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One spreading ring: grows to 1.45x while fading out.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.size,
    required this.color,
    required this.progress,
  });

  final double size;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: Transform.scale(
        scale: 1 + 0.45 * progress,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.5 * (1 - progress)),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
