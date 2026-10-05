import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';

/// The other person in a conversation, as sent by GET /chats (`otherUser`).
class ChatPartner {
  final String id;
  final String name;
  final String profileImage;
  final String headline;
  final bool isOnline;

  /// Account roles, e.g. `user`, `recruiter` (empty when not sent).
  final List<String> roles;

  const ChatPartner({
    required this.id,
    this.name = '',
    this.profileImage = '',
    this.headline = '',
    this.isOnline = false,
    this.roles = const [],
  });

  factory ChatPartner.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return ChatPartner(
      id: text('id'),
      name: text('name'),
      profileImage: ApiConstants.resolveImageUrl(text('profile_image')),
      headline: text('headline'),
      isOnline: json['is_online'] == true,
      roles: json['roles'] is List
          ? [for (final r in json['roles'] as List) r.toString()]
          : const [],
    );
  }
}

/// Conversation model mapped directly from km-backend
class ConversationItem {
  final String id;
  final List<String> participants;
  final String lastMessageId;
  final String lastMessage;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  /// Name, photo and online status of the other person (null on servers
  /// that do not send it; the screen then looks the person up).
  final ChatPartner? otherUser;

  /// Messages in this conversation the signed-in user has not read.
  final int unreadCount;

  const ConversationItem({
    required this.id,
    required this.participants,
    required this.lastMessageId,
    required this.lastMessage,
    this.updatedAt,
    this.createdAt,
    this.otherUser,
    this.unreadCount = 0,
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

    final other = json['otherUser'] ?? json['other_user'];
    final unread = json['unread_count'];
    return ConversationItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      participants: parseParticipants(json['participants']),
      lastMessageId: json['last_message_id']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      updatedAt: parseDate(json['updated_at']),
      createdAt: parseDate(json['created_at']),
      otherUser: other is Map
          ? ChatPartner.fromJson(Map<String, dynamic>.from(other))
          : null,
      unreadCount: unread is num && unread > 0 ? unread.toInt() : 0,
    );
  }

  /// Same conversation with no unread messages (after it is opened).
  ConversationItem markedRead() => ConversationItem(
    id: id,
    participants: participants,
    lastMessageId: lastMessageId,
    lastMessage: lastMessage,
    updatedAt: updatedAt,
    createdAt: createdAt,
    otherUser: otherUser,
  );

  /// Time for the chat list: "1:49 PM" today, "Yesterday", then "Oct 3".
  String get formattedTime => formatChatTime(updatedAt);

  /// Utility to get the other participant ID given current user ID
  String getOtherParticipant(String currentUserId) {
    final fromServer = otherUser?.id ?? '';
    if (fromServer.isNotEmpty) return fromServer;
    return participants.firstWhere(
      (p) => p != currentUserId,
      orElse: () => '', // unknown: no made-up ID
    );
  }
}

/// "1:49 PM" today, "Yesterday", then "Oct 3" ("" when unknown).
String formatChatTime(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final date = time.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final days = todayDay.difference(day).inDays;
  if (days <= 0) return DateFormat('h:mm a').format(date);
  if (days == 1) return 'Yesterday';
  if (date.year == today.year) return DateFormat('MMM d').format(date);
  return DateFormat('d/M/yyyy').format(date);
}
