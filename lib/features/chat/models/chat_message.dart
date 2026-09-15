import 'package:intl/intl.dart';

/// Message model mapped directly from km-backend
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return ChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
    );
  }

  /// Formatted message timestamp
  String get formattedTime {
    if (createdAt == null) return '';
    return DateFormat('h:mm a').format(createdAt!.toLocal());
  }
}
