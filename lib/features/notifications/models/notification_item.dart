import '../../../core/constants/api_constants.dart';

/// Notification categories used by km-backend (`category` field and the
/// `?category=` filter of GET /notifications).
class NotificationCategory {
  NotificationCategory._();

  static const String all = 'all';
  static const String messages = 'messages';
  static const String jobs = 'jobs';
  static const String network = 'network';
  static const String system = 'system';
}

/// One in-app notification from GET /notifications or the live socket.
class NotificationItem {
  final String id;

  /// e.g. chat_message, application_status, interview_scheduled,
  /// connection_request, connection_accepted, event_confirmed,
  /// wallet_credit, wallet_withdrawal, mentorship_booked, ...
  final String type;
  final String category;
  final String title;
  final String message;

  /// Website path the notification points to (e.g. `/applications`,
  /// `/chat?user=<id>`). Turned into an app screen by `notificationTarget`.
  final String link;
  final String actorId;
  final String actorName;
  final String actorAvatar;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.category = NotificationCategory.system,
    this.link = '',
    this.actorId = '',
    this.actorName = '',
    this.actorAvatar = '',
    this.metadata = const {},
    this.isRead = false,
  });

  /// A text value from [metadata] ('' when missing).
  String meta(String key) => metadata[key]?.toString() ?? '';

  /// A chat message; these are shown on the Chats tab, not in the
  /// Notifications list.
  bool get isMessage =>
      type == 'chat_message' || category == NotificationCategory.messages;

  /// Sent by [userId] (chat message notifications).
  bool isFromUser(String userId) =>
      userId.isNotEmpty &&
      (meta('sender_id') == userId ||
          actorId == userId ||
          Uri.tryParse(link)?.queryParameters['user'] == userId);

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      category: category,
      title: title,
      message: message,
      link: link,
      actorId: actorId,
      actorName: actorName,
      actorAvatar: actorAvatar,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    final created = DateTime.tryParse(text('created_at'));
    final metadata = json['metadata'];
    return NotificationItem(
      id: text('id'),
      type: text('type'),
      category: text('category').isEmpty
          ? NotificationCategory.system
          : text('category'),
      title: text('title'),
      message: text('message'),
      link: text('link'),
      actorId: text('actor_id'),
      actorName: text('actor_name'),
      actorAvatar: ApiConstants.resolveImageUrl(text('actor_avatar')),
      metadata: metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : const <String, dynamic>{},
      isRead: json['is_read'] == true,
      // A missing date sorts as oldest instead of pretending to be new.
      createdAt: created?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// One page of GET /notifications.
class NotificationsPage {
  const NotificationsPage({required this.items, required this.total});

  final List<NotificationItem> items;

  /// All notifications matching the filter on the server.
  final int total;
}
