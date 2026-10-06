import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/chat_block_status.dart';
import 'package:kaam_milega/features/chat/models/chat_message.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/presentation/chat_detail_screen.dart';
import 'package:kaam_milega/features/chat/providers/chat_access_provider.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/providers/user_lookup_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

ConversationItem _conv(List<String> roles) => ConversationItem.fromJson({
  'id': 'c1',
  'participants': ['me', 'u2'],
  'last_message': 'hello',
  'otherUser': {'id': 'u2', 'name': 'Anwar Khan', 'roles': roles},
});

/// Chat repository without a network: records what is sent.
class _Chats extends ChatRepository {
  _Chats() : super(ApiClient());

  final sent = <String>[];

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async => const [];

  @override
  Future<ChatBlockStatus> getBlockStatus(String otherUserId) async =>
      ChatBlockStatus.none;

  @override
  Future<List<ConversationItem>> getConversations() async => const [];

  @override
  Future<void> markConversationRead(
    String conversationId, {
    String otherUserId = '',
  }) async {}

  @override
  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
    ChatAttachment? attachment,
  }) async {
    sent.add(content);
    return ChatMessage(
      id: 'n${sent.length}',
      conversationId: 'c1',
      senderId: 'me',
      content: content,
    );
  }
}

/// [status] is GET /network/status/:id; null makes that request fail.
List<Override> _overrides({
  List<ConversationItem> conversations = const [],
  UserProfile? profile,
  String? status,
  List<String>? statusCalls,
}) => [
  authProvider.overrideWith(_SignedIn.new),
  conversationsProvider.overrideWith((ref) async => conversations),
  userLookupProvider.overrideWith((ref, id) async => profile),
  connectionStatusProvider.overrideWith((ref, id) async {
    statusCalls?.add(id);
    if (status == null) throw Exception('offline');
    return status;
  }),
];

Future<ChatAccess> _access(List<Override> overrides) async {
  final c = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(chatAccessProvider('u2'), (_, _) {});
  return c.read(chatAccessProvider('u2').future);
}

Future<_Chats> _pumpChat(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final chats = _Chats();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatDetailScreen(
          conversationId: 'new-u2',
          receiverId: 'u2',
          title: 'Anwar Khan',
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...overrides,
        chatRepositoryProvider.overrideWithValue(chats),
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
  await tester.pumpAndSettle();
  return chats;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Who can be messaged', () {
    test('a recruiter directly, without checking the connection', () async {
      final calls = <String>[];
      final access = await _access(
        _overrides(
          profile: const UserProfile(
            id: 'u2',
            mobile: '',
            roles: ['recruiter'],
          ),
          status: '',
          statusCalls: calls,
        ),
      );
      expect(access, ChatAccess.allowed);
      expect(calls, isEmpty);
    });

    test('recruiter role from GET /chats is enough', () async {
      final access = await _access(
        _overrides(
          conversations: [
            _conv(['recruiter']),
          ],
          status: '',
        ),
      );
      expect(access, ChatAccess.allowed);
    });

    test('anyone else: only an accepted connection', () async {
      const member = UserProfile(id: 'u2', mobile: '', roles: ['user']);
      expect(
        await _access(_overrides(profile: member, status: 'accepted')),
        ChatAccess.allowed,
      );
      expect(
        await _access(_overrides(profile: member, status: '')),
        ChatAccess.notConnected,
      );
      expect(
        await _access(_overrides(profile: member, status: 'pending')),
        ChatAccess.requestPending,
      );
      expect(
        await _access(_overrides(profile: member, status: 'ignored')),
        ChatAccess.requestPending,
      );
      // Private profile (no roles known): the connection decides.
      expect(await _access(_overrides(status: '')), ChatAccess.notConnected);
    });

    test('a failed connection check is an error, not "allowed"', () async {
      await expectLater(
        _access(
          _overrides(
            profile: const UserProfile(id: 'u2', mobile: ''),
            status: null,
          ),
        ),
        throwsA(anything),
      );
    });
  });

  group('Chat screen', () {
    testWidgets('not connected: Connect instead of the message box', (
      tester,
    ) async {
      final chats = await _pumpChat(
        tester,
        _overrides(
          profile: const UserProfile(id: 'u2', mobile: '', name: 'Anwar Khan'),
          status: '',
        ),
      );
      expect(find.text('Connect to chat'), findsOneWidget);
      expect(
        find.text('Connect with Anwar Khan to send messages.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Connect'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(chats.sent, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('request pending: says so, no message box', (tester) async {
      await _pumpChat(
        tester,
        _overrides(
          profile: const UserProfile(id: 'u2', mobile: '', name: 'Anwar Khan'),
          status: 'pending',
        ),
      );
      expect(find.text('Connection request pending'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Pending'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('check failed: Retry, no message box', (tester) async {
      await _pumpChat(
        tester,
        _overrides(
          profile: const UserProfile(id: 'u2', mobile: '', name: 'Anwar Khan'),
          status: null,
        ),
      );
      expect(
        find.text('Could not check if you can message this person.'),
        findsOneWidget,
      );
      // Retry in the same bar (the offline banner has its own Retry).
      final bar = find.ancestor(
        of: find.text('Could not check if you can message this person.'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: bar.first, matching: find.text('Retry')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('connected: the message box sends', (tester) async {
      final chats = await _pumpChat(
        tester,
        _overrides(
          profile: const UserProfile(id: 'u2', mobile: '', name: 'Anwar Khan'),
          status: 'accepted',
        ),
      );
      expect(find.text('Connect to chat'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(chats.sent, ['Hello']);
    });

    testWidgets('recruiter: the message box sends without connecting', (
      tester,
    ) async {
      final chats = await _pumpChat(
        tester,
        _overrides(
          profile: const UserProfile(
            id: 'u2',
            mobile: '',
            name: 'Anwar Khan',
            roles: ['recruiter'],
          ),
          status: '',
        ),
      );
      await tester.enterText(find.byType(TextField), 'About the job');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(chats.sent, ['About the job']);
    });
  });
}
