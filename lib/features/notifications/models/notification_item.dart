import '../../../core/constants/api_constants.dart';

class NotificationItem {
  final String id;
  final String
  type; // 'connection', 'profile_view', 'job_alert', 'application', 'reaction'
  final String title;
  final String message;
  final String avatarUrl;
  final bool isRead;
  final DateTime createdAt;
  final String targetRoute;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.avatarUrl = '',
    this.isRead = false,
    required this.createdAt,
    this.targetRoute = '',
  });

  NotificationItem copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? avatarUrl,
    bool? isRead,
    DateTime? createdAt,
    String? targetRoute,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      targetRoute: targetRoute ?? this.targetRoute,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'job_alert',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      avatarUrl: ApiConstants.resolveImageUrl(json['avatar_url']?.toString()),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      targetRoute: json['target_route']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'message': message,
    'avatar_url': avatarUrl,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'target_route': targetRoute,
  };
}
