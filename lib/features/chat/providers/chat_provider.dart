import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_websocket_service.dart';

/// Provider for candidate's conversations list
/// (Rebuilt on logout / account switch; no request without a session.)
final conversationsProvider = FutureProvider<List<ConversationItem>>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) {
    return const <ConversationItem>[];
  }
  return ref.watch(chatRepositoryProvider).getConversations();
});

/// Unread messages over all conversations (Chats tab badge), from the
/// `unread_count` of each conversation in GET /chats.
final unreadChatMessagesProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider).value;
  if (conversations == null) return 0;
  return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// Live chat connection status. Starts with the current status (the
/// service's stream only reports changes), then follows every change.
final webSocketStatusStreamProvider = StreamProvider<WebSocketStatus>((
  ref,
) async* {
  final wsService = ref.watch(chatWebSocketServiceProvider);
  yield wsService.status;
  yield* wsService.statusStream;
});

/// State notifier for managing 1-on-1 chat messages in a conversation
class ChatMessagesNotifier extends ChangeNotifier {
  final ChatRepository _repository;
  final ChatWebSocketService _wsService;
  final Ref _ref;
  final String _conversationId;
  StreamSubscription<ChatMessage>? _subscription;
  StreamSubscription<void>? _reconnectSubscription;
  StreamSubscription<ChatEvent>? _eventSubscription;

  /// True once the user deleted the conversation from this screen; the
  /// chat screen closes.
  bool get conversationDeleted => _conversationDeleted;
  bool _conversationDeleted = false;

  /// The conversation's real ID ('' while it is a new chat with no
  /// messages on the server yet).
  String get conversationId => _isNewChat ? '' : _activeConversationId;

  /// GET /chats/:id/messages returns the newest [pageSize] messages; older
  /// ones are read [pageSize] at a time with `before=<oldest id>` when the
  /// user scrolls up ([loadOlder]).
  static const int pageSize = 50;

  /// The real conversation ID. For a brand-new chat the screen is opened
  /// with a temporary ID; after the first message is sent the server
  /// returns the real conversation ID and we switch to it, so live replies
  /// (which carry the real ID) keep appearing.
  late String _activeConversationId = _conversationId;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  Object? _error;
  bool _disposed = false;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  Object? _olderError;

  /// More (older) messages are on the server.
  bool get hasOlder => _hasOlder;

  /// True while older messages are loading.
  bool get loadingOlder => _loadingOlder;

  /// Why loading older messages failed (null when it did not).
  Object? get olderError => _olderError;

  /// True while the message history is loading.
  bool get isLoading => _isLoading;

  /// Why the message history could not be loaded (null when it loaded).
  /// Shown as an error with Retry, never as an empty chat.
  Object? get error => _error;

  /// A chat opened before its first message has a temporary `new-…` ID; it
  /// has no history on the server yet.
  bool get _isNewChat => _activeConversationId.startsWith('new-');

  ChatMessagesNotifier(
    this._repository,
    this._wsService,
    this._ref,
    this._conversationId,
  ) {
    _init();
  }

  void _init() {
    _subscription = _wsService.messageStream.listen((newMsg) {
      if (newMsg.conversationId == _activeConversationId) {
        _appendMessage(newMsg);
      }
    });
    // Messages sent while the socket was down are not pushed again by the
    // server: read them from the history once it is back.
    _eventSubscription = _wsService.events.listen(_onEvent);
    _reconnectSubscription = _wsService.reconnected.listen(
      (_) => _refreshSilently(),
    );
    _wsService.connect();
    _fetchMessageHistory();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _reconnectSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessageHistory() async {
    if (_isNewChat) return; // nothing on the server yet
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final history = await _repository.getMessages(
        _activeConversationId,
        limit: pageSize,
      );
      if (_disposed) return;
      _mergeNewest(history);
      _hasOlder = history.length >= pageSize;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _error = e;
      notifyListeners();
    }
  }

  /// Puts the newest page (oldest to newest) in place: older messages
  /// already loaded stay before it, live messages it does not contain yet
  /// stay after it, and messages in both take the server's copy (read
  /// ticks, deletions).
  void _mergeNewest(List<ChatMessage> page) {
    if (page.isEmpty) return;
    final ids = {
      for (final m in page)
        if (m.id.isNotEmpty) m.id,
    };
    final overlap = _messages.indexWhere((m) => ids.contains(m.id));
    final List<ChatMessage> before;
    final List<ChatMessage> after;
    if (overlap >= 0) {
      before = _messages.sublist(0, overlap);
      after = _messages.sublist(overlap);
    } else {
      // No message in common: older ones (by time) go before the page.
      final start = page.first.createdAt;
      bool older(ChatMessage m) =>
          start != null && m.createdAt != null && m.createdAt!.isBefore(start);
      before = _messages.where(older).toList();
      after = _messages.where((m) => !older(m)).toList();
    }
    bool keep(ChatMessage m) => m.id.isEmpty || !ids.contains(m.id);
    _messages = [...before.where(keep), ...page, ...after.where(keep)];
  }

  /// Reads the [pageSize] messages before the oldest one shown (when the
  /// user scrolls to the top). On failure [olderError] is set and the
  /// next call tries again.
  Future<void> loadOlder() async {
    if (_disposed || _isNewChat || !_hasOlder || _loadingOlder) return;
    final oldest = _messages.where((m) => m.id.isNotEmpty).firstOrNull;
    if (oldest == null) return;
    _loadingOlder = true;
    _olderError = null;
    notifyListeners();
    try {
      final batch = await _repository.getMessages(
        _activeConversationId,
        limit: pageSize,
        before: oldest.id,
      );
      if (_disposed) return;
      final ids = _messages.map((m) => m.id).toSet();
      _messages = [...batch.where((m) => !ids.contains(m.id)), ..._messages];
      _hasOlder = batch.length >= pageSize;
    } catch (e) {
      if (_disposed) return;
      _olderError = e;
    }
    _loadingOlder = false;
    notifyListeners();
  }

  /// Catch up after a reconnect without showing a loader; on failure the
  /// messages already on screen stay as they are.
  Future<void> _refreshSilently() async {
    if (_disposed || _isNewChat || _isLoading) return;
    try {
      final history = await _repository.getMessages(
        _activeConversationId,
        limit: pageSize,
      );
      if (_disposed) return;
      _mergeNewest(history);
      if (_messages.isEmpty && history.isEmpty) _hasOlder = false;
      _error = null;
      notifyListeners();
    } catch (_) {
      // Keep what is shown; the next reconnect or Retry tries again.
    }
  }

  /// Retry loading the message history after an error.
  Future<void> retryHistory() => _fetchMessageHistory();

  void _onEvent(ChatEvent event) {
    if (_disposed || event.conversationId != _activeConversationId) return;
    switch (event) {
      case MessagesReadEvent(:final readerId):
        // The other person read the chat: their read ticks turn on.
        bool unreadByThem(ChatMessage m) => !m.isRead && m.senderId != readerId;
        if (_messages.any(unreadByThem)) {
          _messages = [
            for (final m in _messages)
              unreadByThem(m) ? m.copyWith(isRead: true) : m,
          ];
          notifyListeners();
        }
      case MessageDeletedEvent(:final messageId):
        // The sender deleted it: both people see "This message was deleted".
        if (_messages.any((m) => m.id == messageId && !m.isDeleted)) {
          _messages = [
            for (final m in _messages) m.id == messageId ? m.asDeleted() : m,
          ];
          notifyListeners();
        }
      case ChatClearedEvent():
        _messages = [];
        _hasOlder = false;
        notifyListeners();
      case ConversationDeletedEvent():
        // Cleared or removed by this user (here or on another device):
        // older messages are hidden for them; the chat stays usable and a
        // new message brings the conversation back.
        _messages = [];
        _hasOlder = false;
        notifyListeners();
      case TypingEvent():
      case BlockChangedEvent():
        break; // see typingUsersProvider / chatBlockStatusProvider
    }
  }

  /// DELETE /chats/messages/:id — only the sender's own message; both
  /// people then see "This message was deleted". False when the server
  /// refused (the message comes back).
  Future<bool> deleteMessage(String messageId) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || _messages[index].isDeleted) return false;
    final original = _messages[index];
    _messages = [..._messages]..[index] = original.asDeleted();
    notifyListeners();
    try {
      await _repository.deleteMessage(messageId);
      _ref.invalidate(conversationsProvider); // last message may change
      return true;
    } catch (_) {
      if (_disposed) return false;
      _messages = [for (final m in _messages) m.id == messageId ? original : m];
      notifyListeners();
      return false;
    }
  }

  /// DELETE /chats/:id/messages — clears the chat for this user only (the
  /// other person keeps their messages).
  Future<bool> clearChat() async {
    if (_isNewChat) return false;
    try {
      await _repository.clearChat(_activeConversationId);
      if (_disposed) return true;
      _messages = [];
      _hasOlder = false;
      notifyListeners();
      _ref.invalidate(conversationsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /chats/:id — removes the conversation from this user's inbox
  /// only (the other person keeps it).
  Future<bool> deleteConversation() async {
    if (_isNewChat) return false;
    try {
      await _repository.deleteConversation(_activeConversationId);
      _ref.invalidate(conversationsProvider);
      if (!_disposed) {
        _messages = [];
        _conversationDeleted = true;
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _appendMessage(ChatMessage msg) {
    if (_disposed) return;
    if (_messages.any((m) => m.id == msg.id && m.id.isNotEmpty)) return;
    _messages = [..._messages, msg];
    notifyListeners();
  }

  /// Send message to receiver
  Future<bool> sendMessage({
    required String receiverId,
    required String content,
    ChatAttachment? attachment,
  }) async {
    try {
      final sentMessage = await _repository.sendMessage(
        receiverId: receiverId,
        content: content,
        attachment: attachment,
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

/// People typing to the signed-in user right now (their user IDs), from
/// the chat socket. A "typing" signal expires after 6 s without news, and
/// a new message from that person ends it.
class TypingUsersNotifier extends Notifier<Set<String>> {
  final Map<String, Timer> _timers = {};

  @override
  Set<String> build() {
    final service = ref.watch(chatWebSocketServiceProvider);
    ref.watch(sessionUserIdProvider);
    final events = service.events.listen((e) {
      if (e is TypingEvent && e.senderId.isNotEmpty) {
        _set(e.senderId, e.isTyping);
      }
    });
    final messages = service.messageStream.listen(
      (m) => _set(m.senderId, false),
    );
    ref.onDispose(() {
      events.cancel();
      messages.cancel();
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  void _set(String userId, bool typing) {
    if (!ref.mounted) return;
    _timers.remove(userId)?.cancel();
    if (typing) {
      _timers[userId] = Timer(
        const Duration(seconds: 6),
        () => _set(userId, false),
      );
      if (!state.contains(userId)) state = {...state, userId};
    } else if (state.contains(userId)) {
      state = {...state}..remove(userId);
    }
  }
}

final typingUsersProvider = NotifierProvider<TypingUsersNotifier, Set<String>>(
  TypingUsersNotifier.new,
);

/// Disposed when the chat screen closes (stops listening to the socket) and
/// rebuilt on logout / account switch.
final chatMessagesProvider = ChangeNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, String>((ref, conversationId) {
      ref.watch(sessionUserIdProvider);
      final repository = ref.watch(chatRepositoryProvider);
      final wsService = ref.watch(chatWebSocketServiceProvider);
      return ChatMessagesNotifier(repository, wsService, ref, conversationId);
    });
