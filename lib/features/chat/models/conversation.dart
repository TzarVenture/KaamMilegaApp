import 'package:intl/intl.dart';

/// Conversation model mapped directly from km-backend
class ConversationItem {
  final String id;
  final List<String> participants;
  final String lastMessageId;
  final String lastMessage;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const ConversationItem({
    required this.id,
    required this.participants,
    required this.lastMessageId,
    required this.lastMessage,
    this.updatedAt,
    this.createdAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    List<String> parseParticipants(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return ConversationItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      participants: parseParticipants(json['participants']),
      lastMessageId: json['last_message_id']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      updatedAt: parseDate(json['updated_at']),
      createdAt: parseDate(json['created_at']),
    );
  }

  /// Formatted date string for chat list tile
  String get formattedTime {
    if (updatedAt == null) return '';
    final now = DateTime.now();
    final date = updatedAt!.toLocal();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat('h:mm a').format(date);
    }
    return DateFormat('MMM d').format(date);
  }

  /// Utility to get the other participant ID given current user ID
  String getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : 'User',
    );
  }
}
