import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/chat_message.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

/// A local stand-in for km-backend's chat hub (GET /api/ws/chats?token=...):
/// it accepts the socket, can push NEW_MESSAGE events and can drop sockets.
class _FakeHub {
  late final HttpServer server;
  final List<WebSocket> sockets = [];
  final List<String> tokens = [];
  int get port => server.port;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path != '/api/ws/chats') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      tokens.add(request.uri.queryParameters['token'] ?? '');
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
    });
  }

  void push(Map<String, dynamic> message) {
    final payload = jsonEncode({'type': 'NEW_MESSAGE', 'message': message});
    for (final s in sockets) {
      if (s.readyState == WebSocket.open) s.add(payload);
    }
  }

  Future<void> dropAll() async {
    for (final s in sockets) {
      await s.close();
    }
  }

  Future<void> stop() => server.close(force: true);
}

Map<String, dynamic> _msg(String id, {String conv = 'c1'}) => {
  'id': id,
  'conversation_id': conv,
  'sender_id': 'u2',
  'content': 'hello $id',
  'is_read': false,
  'created_at': '2026-09-29T09:00:00Z',
};

class _Chats extends ChatRepository {
  _Chats() : super(ApiClient());
  List<ChatMessage> history = [];
  final List<int> offsets = [];

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    offsets.add(offset);
    return history.skip(offset).take(limit).toList();
  }
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue);
}

void main() {
  late _FakeHub hub;
  late ChatWebSocketService service;

  setUpAll(() => HttpOverrides.global = null); // real sockets
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt-abc'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
    hub = _FakeHub();
    await hub.start();
    service = ChatWebSocketService(
      // Same path and token as production, pointed at the local hub.
      connector: (url) async => IOWebSocketChannel(
        await WebSocket.connect(
          Uri.parse(url)
              .replace(scheme: 'ws', host: '127.0.0.1', port: hub.port)
              .toString(),
        ),
      ),
      networkStatus: const Stream.empty(),
      isOnline: () => true,
    );
  });
  tearDown(() async {
    service.dispose();
    await hub.stop();
  });

  test('socket URL matches the backend route and carries the token', () {
    expect(
      ChatWebSocketService.socketUrl('https://api.kaammilega.com/api', 'a.b'),
      'wss://api.kaammilega.com/api/ws/chats?token=a.b',
    );
    expect(
      ChatWebSocketService.socketUrl('http://10.0.2.2:8000/api', 't'),
      'ws://10.0.2.2:8000/api/ws/chats?token=t',
    );
  });

  test('connects once, even when asked twice at the same time', () async {
    await Future.wait([service.connect(), service.connect()]);
    expect(service.status, WebSocketStatus.connected);
    await _until(() => hub.sockets.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(hub.sockets, hasLength(1)); // the server keeps one per user
    expect(hub.tokens.single, 'jwt-abc');
  });

  test('delivers NEW_MESSAGE in real time, each message once', () async {
    final received = <ChatMessage>[];
    service.messageStream.listen(received.add);
    await service.connect();
    await _until(() => hub.sockets.isNotEmpty);

    hub.push(_msg('m1'));
    hub.push(_msg('m1')); // the sender also gets the echo
    await _until(() => received.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.map((m) => m.id), ['m1']);
    expect(received.single.content, 'hello m1');
  });

  test('server drops the socket: reconnects by itself', () async {
    final statuses = <WebSocketStatus>[];
    service.statusStream.listen(statuses.add);
    var reconnects = 0;
    service.reconnected.listen((_) => reconnects++);

    await service.connect();
    await _until(() => hub.sockets.length == 1);
    await hub.dropAll();

    await _until(() => reconnects == 1);
    expect(service.status, WebSocketStatus.connected);
    expect(hub.sockets, hasLength(2));
    expect(statuses, contains(WebSocketStatus.disconnected));
  });

  test(
    'open chat reads the full history and catches up after a reconnect',
    () async {
      final chats = _Chats()
        ..history = [
          for (var i = 0; i < 60; i++) ChatMessage.fromJson(_msg('h$i')),
        ];
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chats),
          chatWebSocketServiceProvider.overrideWithValue(service),
          // Signed in as u1 without starting the real sign-in flow.
          sessionUserIdProvider.overrideWithValue('u1'),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatMessagesProvider('c1'), (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(chatMessagesProvider('c1'));

      // 60 messages: two pages, so the newest ones are not cut off.
      await _until(() => notifier.messages.length == 60);
      expect(chats.offsets, [0, 50]);
      expect(notifier.messages.last.id, 'h59');

      // Live message.
      await _until(() => hub.sockets.isNotEmpty);
      hub.push(_msg('live1'));
      await _until(() => notifier.messages.length == 61);

      // A message sent while the socket is down is picked up on reconnect.
      await hub.dropAll();
      chats.history = [
        ...chats.history,
        ChatMessage.fromJson(_msg('live1')),
        ChatMessage.fromJson(_msg('missed')),
      ];
      await _until(() => notifier.messages.any((m) => m.id == 'missed'));
      expect(notifier.messages.where((m) => m.id == 'live1'), hasLength(1));
    },
  );
}
