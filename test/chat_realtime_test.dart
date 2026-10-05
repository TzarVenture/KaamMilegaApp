import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/chat_message.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/presentation/chat_detail_screen.dart';
import 'package:kaam_milega/features/chat/providers/chat_access_provider.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:kaam_milega/features/notifications/models/notification_item.dart';
import 'package:kaam_milega/features/notifications/models/notification_target.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

/// Local stand-in for km-backend's chat hub: pushes events, records what
/// the app sends.
class _FakeHub {
  late final HttpServer server;
  final List<WebSocket> sockets = [];
  final List<Map<String, dynamic>> received = [];

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        if (raw is String) {
          received.add(jsonDecode(raw) as Map<String, dynamic>);
        }
      });
    });
  }

  void push(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    for (final s in sockets) {
      if (s.readyState == WebSocket.open) s.add(payload);
    }
  }

  Future<void> stop() => server.close(force: true);
}

Map<String, dynamic> _msg(
  String id, {
  String sender = 'me',
  bool read = false,
}) => {
  'id': id,
  'conversation_id': 'c1',
  'sender_id': sender,
  'content': 'text $id',
  'is_read': read,
  'created_at': '2026-10-05T09:00:00Z',
};

class _Chats extends ChatRepository {
  _Chats(this.history) : super(ApiClient());

  List<ChatMessage> history;
  bool fail = false;
  final calls = <String>[];

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async => history.skip(offset).take(limit).toList();

  @override
  Future<List<ConversationItem>> getConversations() async => const [];

  @override
  Future<void> markConversationRead(
    String conversationId, {
    String otherUserId = '',
  }) async {}

  @override
  Future<void> deleteMessage(String messageId) async {
    calls.add('delete message $messageId');
    if (fail) throw Exception('refused');
  }

  @override
  Future<void> clearChat(String conversationId) async {
    calls.add('clear $conversationId');
    if (fail) throw Exception('refused');
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    calls.add('delete conversation $conversationId');
    if (fail) throw Exception('refused');
  }
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  expect(done(), isTrue);
}

void main() {
  // Widget tests first: the socket group below turns on real network
  // access for the rest of this file.
  group('Chat screen', () {
    late _Chats chats;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
      LocalStorage.setMockInstance(await SharedPreferences.getInstance());
      chats = _Chats([
        ChatMessage.fromJson(_msg('m1', read: true)),
        ChatMessage.fromJson(_msg('m2', sender: 'u2')),
        ChatMessage.fromJson(_msg('m3')),
      ]);
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push(
                    '/chats/c1',
                    extra: <String, String>{
                      'receiverId': 'u2',
                      'title': 'Anwar Khan',
                    },
                  ),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/chats/:id',
            builder: (_, state) {
              final extra = state.extra as Map<String, String>?;
              return ChatDetailScreen(
                conversationId: state.pathParameters['id']!,
                receiverId: extra?['receiverId'] ?? '',
                title: extra?['title'] ?? 'Chat',
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            chatRepositoryProvider.overrideWithValue(chats),
            // Allowed to message (connection rules: chat_access_test).
            chatAccessProvider.overrideWith(
              (ref, id) async => ChatAccess.allowed,
            ),
            // Offline socket: nothing connects during widget tests.
            chatWebSocketServiceProvider.overrideWith((ref) {
              final s = ChatWebSocketService(
                isOnline: () => false,
                networkStatus: const Stream.empty(),
              );
              ref.onDispose(s.dispose);
              return s;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
    }

    testWidgets('ticks: two when read, one when only sent', (tester) async {
      await pump(tester);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget); // m1
      expect(find.byIcon(Icons.done_rounded), findsOneWidget); // m3
    });

    testWidgets('long-press my message: delete for everyone', (tester) async {
      await pump(tester);
      await tester.longPress(find.text('text m3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete for everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Delete message?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chats.calls, ['delete message m3']);
      expect(find.text('text m3'), findsNothing);
    });

    testWidgets("the other person's message cannot be deleted", (tester) async {
      await pump(tester);
      await tester.longPress(find.text('text m2'));
      await tester.pumpAndSettle();
      expect(find.text('Delete for everyone'), findsNothing);
    });

    testWidgets('delete conversation closes the chat', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chats.calls, ['delete conversation c1']);
      expect(find.text('Open chat'), findsOneWidget); // back
      expect(find.text('Conversation deleted.'), findsOneWidget);
    });

    testWidgets('clear chat empties it', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Chat options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(chats.calls, ['clear c1']);
      expect(find.text('text m1'), findsNothing);
    });
  });

  group('Live chat events (real socket)', () {
    late _FakeHub hub;
    late ChatWebSocketService service;
    late _Chats chats;
    late ProviderContainer container;

    setUpAll(() => HttpOverrides.global = null);
    setUp(() async {
      SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
      LocalStorage.setMockInstance(await SharedPreferences.getInstance());
      hub = _FakeHub();
      await hub.start();
      service = ChatWebSocketService(
        connector: (url) async => IOWebSocketChannel(
          await WebSocket.connect(
            Uri.parse(url)
                .replace(scheme: 'ws', host: '127.0.0.1', port: hub.server.port)
                .toString(),
          ),
        ),
        networkStatus: const Stream.empty(),
        isOnline: () => true,
      );
      chats = _Chats([
        ChatMessage.fromJson(_msg('m1')),
        ChatMessage.fromJson(_msg('m2', sender: 'u2')),
        ChatMessage.fromJson(_msg('m3')),
      ]);
      container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chats),
          chatWebSocketServiceProvider.overrideWithValue(service),
          sessionUserIdProvider.overrideWithValue('me'),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      service.dispose();
      await hub.stop();
    });

    Future<ChatMessagesNotifier> openChat() async {
      final sub = container.listen(chatMessagesProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(chatMessagesProvider('c1'));
      await _until(() => notifier.messages.length == 3);
      await _until(() => hub.sockets.isNotEmpty);
      return notifier;
    }

    test('read receipt turns my messages to read', () async {
      final notifier = await openChat();
      expect(notifier.messages.where((m) => m.isRead), isEmpty);
      hub.push({
        'type': 'MESSAGES_READ',
        'conversation_id': 'c1',
        'reader_id': 'u2',
      });
      await _until(() => notifier.messages.first.isRead);
      // Mine are read; the other person's own message is unchanged.
      expect(notifier.messages.map((m) => m.isRead), [true, false, true]);
    });

    test('deleted / cleared / conversation deleted arrive live', () async {
      final notifier = await openChat();
      hub.push({
        'type': 'MESSAGE_DELETED',
        'conversation_id': 'c1',
        'message_id': 'm2',
      });
      await _until(() => notifier.messages.length == 2);

      hub.push({'type': 'CHAT_CLEARED', 'conversation_id': 'c1'});
      await _until(() => notifier.messages.isEmpty);

      hub.push({'type': 'CONVERSATION_DELETED', 'conversation_id': 'c1'});
      await _until(() => notifier.conversationDeleted);
    });

    test('events for another conversation are ignored', () async {
      final notifier = await openChat();
      hub.push({'type': 'CHAT_CLEARED', 'conversation_id': 'other'});
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(notifier.messages, hasLength(3));
    });

    test('typing: shown, then cleared by "stopped" and by a message', () async {
      container.listen(typingUsersProvider, (_, _) {});
      await service.connect();
      await _until(() => hub.sockets.isNotEmpty);

      hub.push({
        'type': 'USER_TYPING',
        'conversation_id': 'c1',
        'sender_id': 'u2',
        'is_typing': true,
      });
      await _until(() => container.read(typingUsersProvider).contains('u2'));
      hub.push({
        'type': 'USER_TYPING',
        'conversation_id': 'c1',
        'sender_id': 'u2',
        'is_typing': false,
      });
      await _until(() => container.read(typingUsersProvider).isEmpty);

      hub.push({
        'type': 'USER_TYPING',
        'conversation_id': 'c1',
        'sender_id': 'u2',
        'is_typing': true,
      });
      await _until(() => container.read(typingUsersProvider).isNotEmpty);
      hub.push({'type': 'NEW_MESSAGE', 'message': _msg('m9', sender: 'u2')});
      await _until(() => container.read(typingUsersProvider).isEmpty);
    });

    test('sendTyping sends the backend TYPING event', () async {
      await service.connect();
      await _until(() => hub.sockets.isNotEmpty);
      expect(
        service.sendTyping(
          receiverId: 'u2',
          conversationId: 'c1',
          isTyping: true,
        ),
        isTrue,
      );
      await _until(() => hub.received.isNotEmpty);
      expect(hub.received.single, {
        'type': 'TYPING',
        'conversation_id': 'c1',
        'receiver_id': 'u2',
        'is_typing': true,
      });
    });

    test('delete message: removed; a refusal puts it back', () async {
      final notifier = await openChat();
      chats.fail = true;
      expect(await notifier.deleteMessage('m1'), isFalse);
      expect(notifier.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      chats.fail = false;
      expect(await notifier.deleteMessage('m1'), isTrue);
      expect(notifier.messages.map((m) => m.id), ['m2', 'm3']);
      expect(chats.calls.last, 'delete message m1');
    });

    test('clear chat and delete conversation call the backend', () async {
      final notifier = await openChat();
      expect(await notifier.clearChat(), isTrue);
      expect(notifier.messages, isEmpty);
      expect(await notifier.deleteConversation(), isTrue);
      expect(notifier.conversationDeleted, isTrue);
      expect(chats.calls, ['clear c1', 'delete conversation c1']);
    });
  });

  test('connection request notification opens Pending Requests', () {
    final item = NotificationItem.fromJson({
      'id': 'n1',
      'type': 'connection_request',
      'category': 'network',
      'title': 'New request',
      'message': 'Ravi wants to connect',
      'link': '/network',
      'created_at': '2026-10-05T09:00:00Z',
    });
    expect(notificationTarget(item), const RouteTarget('/network?tab=pending'));
  });
}
