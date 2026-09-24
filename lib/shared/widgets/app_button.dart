import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Primary full-width action button.
///
/// Visual behaviour only: a subtle press-down scale, a smooth switch between
/// the label and the loading spinner, and the brand colour is kept while
/// loading. [onPressed] is called exactly as before (never while loading).
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  /// Optional icon shown before the text.
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 52,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;
  Offset? _downAt;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.icon == null
        ? Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button,
                ),
              ),
            ],
          );

    return Listener(
      // Only drives the press animation; taps are handled by the button.
      onPointerDown: (e) {
        _downAt = e.position;
        _setPressed(_enabled);
      },
      // A scroll/drag is not a press: release as soon as the finger moves
      // (same behaviour as PressableScale).
      onPointerMove: (e) {
        if (_downAt != null && (e.position - _downAt!).distance > 8) {
          _setPressed(false);
        }
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              // While loading keep the brand colour (not the faded disabled
              // look); a truly disabled button is faded.
              disabledBackgroundColor: widget.isLoading
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35),
              disabledForegroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : KeyedSubtree(key: const ValueKey('label'), child: label),
            ),
          ),
        ),
      ),
    );
  }
}
