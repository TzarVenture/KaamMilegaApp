import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../features/notifications/providers/notification_provider.dart';

/// The notification bell used in every header and in the drawer: a real
/// button (ripple, 40px tap area, tooltip and screen reader label) with a
/// red dot while there are unread notifications.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    this.onPressed,
    this.color = AppColors.textPrimary,
    this.size = 24,
  });

  /// Defaults to opening the Notifications screen.
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    return IconButton(
      onPressed: onPressed ?? () => context.push('/notifications'),
      tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      splashRadius: 22,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Badge(
        isLabelVisible: unread > 0,
        smallSize: 8,
        backgroundColor: AppColors.error,
        child: Icon(Icons.notifications_none_rounded, color: color, size: size),
      ),
    );
  }
}
