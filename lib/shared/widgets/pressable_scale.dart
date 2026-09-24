import 'package:flutter/material.dart';

/// Shrinks its child slightly while a finger is pressing it, like a real
/// button. Purely visual: taps still go to the child's own InkWell /
/// GestureDetector, exactly as before.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  Offset? _downAt;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _downAt = e.position;
        _set(true);
      },
      // A scroll/drag is not a press: release as soon as the finger moves.
      onPointerMove: (e) {
        if (_downAt != null && (e.position - _downAt!).distance > 8) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
