import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:kaam_milega/features/chat/presentation/widgets/chat_report_sheet.dart';
import 'package:kaam_milega/features/chat/providers/chat_access_provider.dart';
import 'package:kaam_milega/features/chat/providers/chat_block_provider.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/providers/user_lookup_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

/// Chat repository without a network: block status is settable and every
/// block / unblock / report call is recorded.
class _Chats extends ChatRepository {
  _Chats() : super(ApiClient());

  ChatBlockStatus status = ChatBlockStatus.none;
  int statusCalls = 0;
  final calls = <String>[];
  final reports = <({String id, String reason, String text, bool block})>[];

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async => const [];

  @override
  Future<List<ConversationItem>> getConversations() async => const [];

  @override
  Future<void> markConversationRead(
    String conversationId, {
    String otherUserId = '',
  }) async {}

  @override
  Future<ChatBlockStatus> getBlockStatus(String otherUserId) async {
    statusCalls++;
    return status;
  }

  @override
  Future<void> blockUser(String otherUserId) async =>
      calls.add('block $otherUserId');

  @override
  Future<void> unblockUser(String otherUserId) async =>
      calls.add('unblock $otherUserId');

  @override
  Future<String> reportConversation(
    String conversationId, {
    required String reason,
    String description = '',
    bool blockUser = false,
  }) async {
    reports.add((
      id: conversationId,
      reason: reason,
      text: description,
      block: blockUser,
    ));
    return 'REP-1';
  }
}

/// Socket that never connects; [push] plays a server event.
class _Socket extends ChatWebSocketService {
  _Socket() : super(isOnline: () => false, networkStatus: const Stream.empty());

  void push(Map<String, dynamic> data) => handleEvent(data);
}

Future<_Chats> _pumpChat(
  WidgetTester tester, {
  ChatBlockStatus status = ChatBlockStatus.none,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final chats = _Chats()..status = status;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatDetailScreen(
          conversationId: 'c1',
          receiverId: 'u2',
          title: 'Anwar Khan',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        conversationsProvider.overrideWith((ref) async => const []),
        userLookupProvider.overrideWith((ref, id) async => null),
        chatAccessProvider.overrideWith((ref, id) async => ChatAccess.allowed),
        chatRepositoryProvider.overrideWithValue(chats),
        chatWebSocketServiceProvider.overrideWith((ref) {
          final s = _Socket();
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

Future<void> _openMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('Chat options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('block', () {
    testWidgets('blocked by me: no composer; Unblock asks, then can chat', (
      tester,
    ) async {
      final chats = await _pumpChat(
        tester,
        status: const ChatBlockStatus(blockedByMe: true),
      );
      expect(
        find.text('You blocked Anwar Khan. Unblock to send messages.'),
        findsOneWidget,
      );
      expect(find.text('Type a message...'), findsNothing);

      chats.status = ChatBlockStatus.none;
      await tester.tap(find.widgetWithText(TextButton, 'Unblock'));
      await tester.pumpAndSettle();
      expect(find.text('Unblock Anwar Khan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Unblock').last);
      await tester.pumpAndSettle();
      expect(chats.calls, ['unblock u2']);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('blocked by the other person: cannot send, no Unblock', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        status: const ChatBlockStatus(blockedByOther: true),
      );
      expect(
        find.text('You cannot send messages to this conversation right now.'),
        findsOneWidget,
      );
      expect(find.text('Type a message...'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Unblock'), findsNothing);
    });

    testWidgets('menu: Block user asks first, then blocks', (tester) async {
      final chats = await _pumpChat(tester);
      await _openMenu(tester, 'Block user');
      expect(find.text('Block Anwar Khan?'), findsOneWidget);
      chats.status = const ChatBlockStatus(blockedByMe: true);
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(chats.calls, ['block u2']);
      expect(
        find.text('You blocked Anwar Khan. Unblock to send messages.'),
        findsOneWidget,
      );
    });

    test('USER_BLOCKED / USER_UNBLOCKED reload the status live', () async {
      final chats = _Chats();
      final socket = _Socket();
      final container = ProviderContainer(
        overrides: [
          sessionUserIdProvider.overrideWithValue('me'),
          chatRepositoryProvider.overrideWithValue(chats),
          chatWebSocketServiceProvider.overrideWithValue(socket),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(socket.dispose);
      final sub = container.listen(chatBlockStatusProvider('u2'), (_, _) {});
      addTearDown(sub.close);
      expect(
        (await container.read(chatBlockStatusProvider('u2').future)).isBlocked,
        isFalse,
      );
      expect(chats.statusCalls, 1);

      // About someone else: no reload.
      socket.push({
        'type': 'USER_BLOCKED',
        'blocked_user_id': 'u3',
        'blocked_by_me': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(chats.statusCalls, 1);

      chats.status = const ChatBlockStatus(blockedByOther: true);
      socket.push({
        'type': 'USER_BLOCKED',
        'blocked_user_id': 'u2',
        'blocked_by_me': false,
      });
      await Future<void>.delayed(Duration.zero);
      final now = await container.read(chatBlockStatusProvider('u2').future);
      expect(now.blockedByOther, isTrue);
      expect(chats.statusCalls, 2);
    });
  });

  group('report', () {
    testWidgets('sends reason, details and "also block"', (tester) async {
      final chats = await _pumpChat(tester);
      chats.status = const ChatBlockStatus(blockedByMe: true);
      await _openMenu(tester, 'Report conversation');
      expect(find.byType(ChatReportSheet), findsOneWidget);

      await tester.tap(find.text('Fraud, scam, or fake job offer'));
      await tester.enterText(
        find.descendant(
          of: find.byType(ChatReportSheet),
          matching: find.byType(TextField),
        ),
        'Asked for a fee',
      );
      await tester.ensureVisible(find.text('Also block this user'));
      await tester.tap(find.text('Also block this user'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(chats.reports.single, (
        id: 'c1',
        reason: 'Fraud, scam, or fake job offer',
        text: 'Asked for a fee',
        block: true,
      ));
      expect(find.byType(ChatReportSheet), findsNothing);
      expect(
        find.text('Report REP-1 sent. Our team will review it.'),
        findsOneWidget,
      );
      // Blocked with the report: the composer is replaced.
      expect(
        find.text('You blocked Anwar Khan. Unblock to send messages.'),
        findsOneWidget,
      );
    });
  });

  group('backend contract', () {
    late List<RequestOptions> sent;
    late ChatRepository repo;

    setUp(() {
      sent = [];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            sent.add(o);
            final data = switch (o.path) {
              '/chats/users/u2/block-status' => {
                'is_blocked_by_me': true,
                'is_blocked_by_other': false,
              },
              '/chats/c1/report' => {'id': 'r1', 'report_number': 'REP-42'},
              '/chats/c1/messages' => <dynamic>[],
              _ => {'success': true},
            };
            h.resolve(
              Response<dynamic>(requestOptions: o, statusCode: 200, data: data),
            );
          },
        ),
      );
      repo = ChatRepository(ApiClient(dio: dio));
    });

    test('block, unblock and status', () async {
      final status = await repo.getBlockStatus('u2');
      expect(status.blockedByMe, isTrue);
      expect(status.blockedByOther, isFalse);
      await repo.blockUser('u2');
      await repo.unblockUser('u2');
      expect(sent.map((o) => '${o.method} ${o.path}'), [
        'GET /chats/users/u2/block-status',
        'POST /chats/users/u2/block',
        'POST /chats/users/u2/unblock',
      ]);
    });

    test('report body and number', () async {
      final number = await repo.reportConversation(
        'c1',
        reason: 'Other concern',
        description: 'x',
        blockUser: true,
      );
      expect(number, 'REP-42');
      expect(sent.single.data, {
        'reason': 'Other concern',
        'description': 'x',
        'block_user': true,
      });
    });

    test('messages page with limit and before (no offset)', () async {
      await repo.getMessages('c1');
      await repo.getMessages('c1', before: 'm9');
      expect(sent[0].queryParameters, {'limit': 50});
      expect(sent[1].queryParameters, {'limit': 50, 'before': 'm9'});
    });
  });
}
