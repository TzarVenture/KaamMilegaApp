import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';

/// A file uploaded for a chat message (POST /files/upload).
class ChatAttachment {
  const ChatAttachment({
    required this.url,
    this.type = '',
    this.name = '',
    this.size = 0,
  });

  /// As stored on the server (may be a path like `/uploads/x.png`).
  final String url;

  /// MIME type, e.g. `image/jpeg` or `application/pdf`.
  final String type;
  final String name;

  /// Bytes.
  final int size;

  /// Full https link to open or show the file.
  String get resolvedUrl => ApiConstants.resolveImageUrl(url);

  bool get isImage =>
      type.startsWith('image/') ||
      RegExp(
        r'\.(jpg|jpeg|png|webp|gif)$',
        caseSensitive: false,
      ).hasMatch(Uri.tryParse(url)?.path ?? url);

  /// "245 KB", "1.2 MB" ('' when unknown).
  String get sizeLabel => formatFileSize(size);
}

/// "245 KB", "1.2 MB" ('' for 0 or less).
String formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Message model mapped directly from km-backend
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime? createdAt;

  /// Image or file sent with the message (null when none).
  final ChatAttachment? attachment;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    this.createdAt,
    this.attachment,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    final url = json['attachment_url']?.toString().trim() ?? '';
    final size = json['attachment_size'];
    return ChatMessage(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
      attachment: url.isEmpty
          ? null
          : ChatAttachment(
              url: url,
              type: json['attachment_type']?.toString() ?? '',
              name: json['attachment_name']?.toString() ?? '',
              size: size is num ? size.toInt() : 0,
            ),
    );
  }

  /// Same message, read (or not) by the other person.
  ChatMessage copyWith({bool? isRead}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    content: content,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    attachment: attachment,
  );

  /// Formatted message timestamp
  String get formattedTime {
    if (createdAt == null) return '';
    return DateFormat('h:mm a').format(createdAt!.toLocal());
  }
}
