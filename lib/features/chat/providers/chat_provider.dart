import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';

/// Provider for candidate's conversations list
final conversationsProvider = FutureProvider<List<ConversationItem>>((ref) {
  return ref.watch(chatRepositoryProvider).getConversations();
});

/// Stream provider for WebSocket connection status
final webSocketStatusStreamProvider = StreamProvider<WebSocketStatus>((ref) {
  final wsService = ref.watch(chatWebSocketServiceProvider);
  return wsService.statusStream;
});

/// State notifier for managing 1-on-1 chat messages in a conversation
class ChatMessagesNotifier extends ChangeNotifier {
  final ChatRepository _repository;
  final ChatWebSocketService _wsService;
  final Ref _ref;
  final String _conversationId;
  StreamSubscription<ChatMessage>? _subscription;

  /// The real conversation ID. For a brand-new chat the screen is opened
  /// with a temporary ID; after the first message is sent the server
  /// returns the real conversation ID and we switch to it, so live replies
  /// (which carry the real ID) keep appearing.
  late String _activeConversationId = _conversationId;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatMessagesNotifier(
    this._repository,
    this._wsService,
    this._ref,
    this._conversationId,
  ) {
    _init();
  }

  void _init() {
    _wsService.connect();
    _subscription = _wsService.messageStream.listen((newMsg) {
      if (newMsg.conversationId == _activeConversationId) {
        _appendMessage(newMsg);
      }
    });
    _fetchMessageHistory();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessageHistory() async {
    try {
      final history = await _repository.getMessages(_activeConversationId);
      _messages = history;
      notifyListeners();
    } catch (_) {}
  }

  void _appendMessage(ChatMessage msg) {
    if (_messages.any((m) => m.id == msg.id && m.id.isNotEmpty)) return;
    _messages = [..._messages, msg];
    notifyListeners();
  }

  /// Send message to receiver
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    try {
      final sentMessage = await _repository.sendMessage(
        receiverId: receiverId,
        content: content,
      );
      _appendMessage(sentMessage);
      final realId = sentMessage.conversationId;
      if (realId.isNotEmpty && realId != _activeConversationId) {
        _activeConversationId = realId;
      }
      _ref.invalidate(conversationsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final chatMessagesProvider =
    ChangeNotifierProvider.family<ChatMessagesNotifier, String>((
      ref,
      conversationId,
    ) {
      final repository = ref.watch(chatRepositoryProvider);
      final wsService = ref.watch(chatWebSocketServiceProvider);
      return ChatMessagesNotifier(repository, wsService, ref, conversationId);
    });
