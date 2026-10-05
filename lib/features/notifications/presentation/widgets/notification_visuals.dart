import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../models/notification_item.dart';
import '../../models/notification_target.dart';

/// Icon for a notification, from its type and category.
IconData notificationIcon(NotificationItem item) {
  final type = item.type;
  if (type == 'chat_message') return Icons.chat_bubble_rounded;
  if (type.startsWith('application')) return Icons.assignment_turned_in_rounded;
  if (type.startsWith('interview')) return Icons.event_available_rounded;
  if (type.startsWith('connection')) return Icons.people_alt_rounded;
  if (type.startsWith('wallet')) return Icons.account_balance_wallet_rounded;
  if (type.startsWith('event')) return Icons.confirmation_number_rounded;
  if (type.startsWith('mentorship')) return Icons.school_rounded;
  if (type.startsWith('instant')) return Icons.bolt_rounded;
  switch (item.category) {
    case NotificationCategory.messages:
      return Icons.chat_bubble_rounded;
    case NotificationCategory.jobs:
      return Icons.work_rounded;
    case NotificationCategory.network:
      return Icons.people_alt_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

/// Sender's photo when there is one, otherwise the notification's icon.
class NotificationAvatar extends StatelessWidget {
  const NotificationAvatar({super.key, required this.item, this.radius = 22});

  final NotificationItem item;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = item.actorAvatar;
    final hasPhoto = url.startsWith('http://') || url.startsWith('https://');
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.blue.withValues(alpha: 0.1),
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Icon(notificationIcon(item), size: radius, color: AppColors.blue),
    );
  }
}

/// Opens the app screen a notification points to.
void openNotificationTarget(GoRouter router, NotificationTarget target) {
  switch (target) {
    case RouteTarget(:final path):
      router.push(path);
    case ChatTarget chat:
      router.push(
        chat.route,
        extra: <String, String>{'receiverId': chat.userId, 'title': chat.title},
      );
  }
}
