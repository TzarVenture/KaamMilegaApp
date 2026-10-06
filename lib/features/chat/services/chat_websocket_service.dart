import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/live_socket.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';

export '../../../core/network/live_socket.dart'
    show WebSocketConnector, WebSocketStatus;

/// Live chat events other than new messages.
sealed class ChatEvent {
  const ChatEvent(this.conversationId);
  final String conversationId;
}

/// [readerId] read the messages of [conversationId] (MESSAGES_READ).
class MessagesReadEvent extends ChatEvent {
  const MessagesReadEvent(super.conversationId, this.readerId);
  final String readerId;
}

/// [senderId] started or stopped typing to the user (USER_TYPING).
class TypingEvent extends ChatEvent {
  const TypingEvent(super.conversationId, this.senderId, this.isTyping);
  final String senderId;
  final bool isTyping;
}

/// A message was deleted for everyone (MESSAGE_DELETED).
class MessageDeletedEvent extends ChatEvent {
  const MessageDeletedEvent(super.conversationId, this.messageId);
  final String messageId;
}

/// All messages of a conversation were deleted (CHAT_CLEARED).
class ChatClearedEvent extends ChatEvent {
  const ChatClearedEvent(super.conversationId);
}

/// The signed-in user removed the conversation from their own inbox, or
/// cleared it (CONVERSATION_DELETED; sent only to that user).
class ConversationDeletedEvent extends ChatEvent {
  const ConversationDeletedEvent(super.conversationId);
}

/// The signed-in user and [otherUserId] were blocked or unblocked
/// (USER_BLOCKED / USER_UNBLOCKED); [byMe] when the signed-in user did it.
/// Not tied to one conversation ([conversationId] is empty).
class BlockChangedEvent extends ChatEvent {
  const BlockChangedEvent(
    this.otherUserId, {
    required this.blocked,
    required this.byMe,
  }) : super('');
  final String otherUserId;
  final bool blocked;
  final bool byMe;
}

/// Live chat socket: GET /api/ws/chats?token=JWT (km-backend chat hub).
///
/// The server pushes `NEW_MESSAGE` (as [messageStream]) and
/// `MESSAGES_READ`, `USER_TYPING`, `MESSAGE_DELETED`, `CHAT_CLEARED`,
/// `CONVERSATION_DELETED`, `USER_BLOCKED`, `USER_UNBLOCKED` (as [events]). Messages are sent over REST
/// (POST /chats/messages); only typing signals go over the socket
/// ([sendTyping]). Connection, ping and reconnect rules are in [LiveSocket].
class ChatWebSocketService extends LiveSocket {
  ChatWebSocketService({
    super.connector,
    super.pingInterval,
    super.connectTimeout,
    super.networkStatus,
    super.isOnline,
  }) : super(path: ApiConstants.wsChats, logTag: 'ChatWebSocketService');

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _eventController = StreamController<ChatEvent>.broadcast();
  final Set<String> _processedMessageIds = {};

  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Read receipts, typing and deletions.
  Stream<ChatEvent> get events => _eventController.stream;

  /// Tells [receiverId] that the user is (or stopped) typing. Dropped when
  /// the socket is not connected.
  bool sendTyping({
    required String receiverId,
    required String conversationId,
    required bool isTyping,
  }) {
    if (receiverId.isEmpty) return false;
    return send({
      'type': 'TYPING',
      'conversation_id': conversationId,
      'receiver_id': receiverId,
      'is_typing': isTyping,
    });
  }

  /// ws(s)://host[:port]/api/ws/chats?token=... built from [baseUrl].
  static String socketUrl(String baseUrl, String token) =>
      LiveSocket.urlFor(baseUrl, ApiConstants.wsChats, token);

  @override
  void handleEvent(Map<String, dynamic> data) {
    String text(String key) => data[key]?.toString() ?? '';
    final conversationId = text('conversation_id');
    final ChatEvent? event = switch (data['type']) {
      'MESSAGES_READ' => MessagesReadEvent(conversationId, text('reader_id')),
      'USER_TYPING' => TypingEvent(
        conversationId,
        text('sender_id'),
        data['is_typing'] == true,
      ),
      'MESSAGE_DELETED' => MessageDeletedEvent(
        conversationId,
        text('message_id'),
      ),
      'CHAT_CLEARED' => ChatClearedEvent(conversationId),
      'CONVERSATION_DELETED' => ConversationDeletedEvent(conversationId),
      'USER_BLOCKED' => BlockChangedEvent(
        text('blocked_user_id'),
        blocked: true,
        byMe: data['blocked_by_me'] == true,
      ),
      'USER_UNBLOCKED' => BlockChangedEvent(
        text('unblocked_user_id'),
        blocked: false,
        byMe: data['unblocked_by_me'] == true,
      ),
      _ => null,
    };
    if (event != null) {
      if (!_eventController.isClosed) _eventController.add(event);
      return;
    }

    final payload = data['message'];
    if (data['type'] != 'NEW_MESSAGE' || payload is! Map<String, dynamic>) {
      return;
    }
    final message = ChatMessage.fromJson(payload);
    if (message.id.isEmpty || !_processedMessageIds.add(message.id)) return;
    if (_processedMessageIds.length > 1000) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }
    if (!_messageController.isClosed) _messageController.add(message);
  }

  @override
  void dispose() {
    _messageController.close();
    _eventController.close();
    super.dispose();
  }
}

/// One socket per signed-in account: on logout or account switch the old
/// service is disposed (socket closed) and a new one is created, which only
/// connects when a token exists.
/// Live chat events (read receipts, typing, deletions) of the signed-in
/// user.
final chatEventsProvider = StreamProvider<ChatEvent>((ref) {
  return ref.watch(chatWebSocketServiceProvider).events;
});

final chatWebSocketServiceProvider = Provider<ChatWebSocketService>((ref) {
  ref.watch(sessionUserIdProvider);
  final service = ChatWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});
