import 'package:flutter/material.dart';

/// Shows a dialog like [showDialog], with a gentle entrance: fade in plus a
/// small scale from 95% to 100% (reverse on close).
///
/// Only the animation differs from [showDialog]: same barrier colour, same
/// tap-outside-to-close behaviour, same safe area and the same return value
/// from `Navigator.pop(context, value)`.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    useRootNavigator: useRootNavigator,
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) =>
        SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
