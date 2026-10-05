import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/live_socket.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';

enum NotificationEventType { init, created, read, allRead, deleted }

/// One event from the notification socket.
class NotificationEvent {
  const NotificationEvent({
    required this.type,
    this.unreadCount,
    this.notification,
    this.notificationId = '',
  });

  final NotificationEventType type;

  /// Server's unread total after this event (null when not sent).
  final int? unreadCount;

  /// The new or updated notification ([NotificationEventType.created]).
  /// Several chat messages from one person within 15 minutes come as the
  /// same notification (same id) with an updated message.
  final NotificationItem? notification;

  /// The read or deleted notification.
  final String notificationId;
}

/// Live notification socket: GET /api/ws/notifications?token=JWT.
///
/// The server sends `INIT` (unread_count) on connect, then
/// `NEW_NOTIFICATION`, `NOTIFICATION_READ`, `ALL_READ` and
/// `NOTIFICATION_DELETED`, each with the new `unread_count`.
class NotificationSocketService extends LiveSocket {
  NotificationSocketService({
    super.connector,
    super.pingInterval,
    super.connectTimeout,
    super.networkStatus,
    super.isOnline,
  }) : super(
         path: ApiConstants.wsNotifications,
         logTag: 'NotificationSocketService',
       );

  final _events = StreamController<NotificationEvent>.broadcast();

  Stream<NotificationEvent> get events => _events.stream;

  @override
  void handleEvent(Map<String, dynamic> data) {
    final count = data['unread_count'];
    final unread = count is num ? count.toInt() : null;
    final id = data['notification_id']?.toString() ?? '';
    NotificationEvent? event;
    switch (data['type']) {
      case 'INIT':
        event = NotificationEvent(
          type: NotificationEventType.init,
          unreadCount: unread,
        );
      case 'NEW_NOTIFICATION':
        final raw = data['notification'];
        if (raw is! Map) return;
        final item = NotificationItem.fromJson(Map<String, dynamic>.from(raw));
        if (item.id.isEmpty) return;
        event = NotificationEvent(
          type: NotificationEventType.created,
          unreadCount: unread,
          notification: item,
        );
      case 'NOTIFICATION_READ':
        event = NotificationEvent(
          type: NotificationEventType.read,
          unreadCount: unread,
          notificationId: id,
        );
      case 'ALL_READ':
        event = NotificationEvent(
          type: NotificationEventType.allRead,
          unreadCount: unread ?? 0,
        );
      case 'NOTIFICATION_DELETED':
        event = NotificationEvent(
          type: NotificationEventType.deleted,
          unreadCount: unread,
          notificationId: id,
        );
    }
    if (event != null && !_events.isClosed) _events.add(event);
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

/// One socket per signed-in account; disposed (closed) on logout or account
/// switch. It is opened by `InAppNotificationHost` (the running app), and
/// only when a token exists, so guests get no connection.
final notificationSocketServiceProvider = Provider<NotificationSocketService>((
  ref,
) {
  ref.watch(sessionUserIdProvider);
  final service = NotificationSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Live notification events of the signed-in user.
final notificationEventsProvider = StreamProvider<NotificationEvent>((ref) {
  return ref.watch(notificationSocketServiceProvider).events;
});
