import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/presentation/chat_list_screen.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/providers/user_lookup_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:kaam_milega/features/notifications/services/notification_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ConversationItem _conv(
  String id, {
  required String otherId,
  required String name,
  String last = 'hello',
  int unread = 0,
  bool online = false,
  String updatedAt = '2026-10-05T08:19:00Z',
}) => ConversationItem.fromJson({
  'id': id,
  'participants': ['me', otherId],
  'last_message': last,
  'updated_at': updatedAt,
  'unread_count': unread,
  'otherUser': {'id': otherId, 'name': name, 'is_online': online},
});

class _Chats extends ChatRepository {
  _Chats(List<ConversationItem> conversations, {this.people = const []})
    : conversations = List.of(conversations),
      super(ApiClient());

  final List<ConversationItem> conversations;
  final List<UserProfile> people;
  final searches = <String>[];
  final deleted = <String>[];
  bool failDelete = false;

  @override
  Future<void> deleteConversation(String conversationId) async {
    if (failDelete) throw Exception('delete failed');
    deleted.add(conversationId);
    conversations.removeWhere((c) => c.id == conversationId);
  }

  int loads = 0;

  @override
  Future<List<ConversationItem>> getConversations() async {
    loads++;
    return conversations;
  }

  @override
  Future<List<UserProfile>> searchPeople(String query) async {
    searches.add(query);
    return people;
  }
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Chats chats, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ChatListScreen()),
      GoRoute(
        path: '/chats/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, String>?;
          return Scaffold(
            body: Text(
              'Chat ${state.pathParameters['id']} '
              'with ${extra?['receiverId']} (${extra?['title']})',
            ),
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
        notificationEventsProvider.overrideWith((ref) => const Stream.empty()),
        // Offline chat socket: nothing connects during widget tests.
        chatWebSocketServiceProvider.overrideWith((ref) {
          final service = ChatWebSocketService(
            isOnline: () => false,
            networkStatus: const Stream.empty(),
          );
          ref.onDispose(service.dispose);
          return service;
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // A saved token: the screen treats the user as signed in.
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Conversation from GET /chats', () {
    test('reads otherUser and unread_count', () {
      final c = _conv(
        'c1',
        otherId: 'u2',
        name: 'Anwar Khan',
        unread: 2,
        online: true,
      );
      expect(c.otherUser!.name, 'Anwar Khan');
      expect(c.otherUser!.isOnline, isTrue);
      expect(c.unreadCount, 2);
      expect(c.getOtherParticipant('me'), 'u2');
      expect(c.markedRead().unreadCount, 0);
    });

    test('nothing made up when the server sends less', () {
      final c = ConversationItem.fromJson({
        'id': 'c9',
        'participants': ['me'],
      });
      expect(c.otherUser, isNull);
      expect(c.getOtherParticipant('me'), ''); // no fake ID
      expect(displayNameFor(null), 'Unknown user');
    });

    test('time label: today, yesterday, date', () {
      final now = DateTime(2026, 10, 5, 15);
      expect(
        formatChatTime(DateTime(2026, 10, 5, 13, 49), now: now),
        '1:49 PM',
      );
      expect(formatChatTime(DateTime(2026, 10, 4, 9), now: now), 'Yesterday');
      expect(formatChatTime(DateTime(2026, 9, 28), now: now), 'Sep 28');
      expect(formatChatTime(null, now: now), '');
    });

    test('Chats tab badge adds up unread messages', () async {
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_SignedIn.new),
          chatRepositoryProvider.overrideWithValue(
            _Chats([
              _conv('c1', otherId: 'u2', name: 'A', unread: 2),
              _conv('c2', otherId: 'u3', name: 'B', unread: 3),
              _conv('c3', otherId: 'u4', name: 'C'),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(unreadChatMessagesProvider, (_, _) {});
      await c.read(conversationsProvider.future);
      expect(c.read(unreadChatMessagesProvider), 5);
    });
  });

  group('Messages screen', () {
    final conversations = [
      _conv('c1', otherId: 'u2', name: 'Anwar Khan', online: true),
      _conv(
        'c2',
        otherId: 'u3',
        name: 'Priya Sharma',
        last: 'Can we talk tomorrow?',
        unread: 2,
      ),
    ];

    testWidgets('looks like the website list', (tester) async {
      await _pump(tester, _Chats(conversations));
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('All Chats'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Search chats or find people...'), findsOneWidget);
      expect(find.text('Anwar Khan'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // initial avatar
      expect(
        find.bySemanticsLabel(RegExp(r'^Anwar Khan, online, hello')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Priya Sharma, 2 unread, Can we talk')),
        findsOneWidget,
      );
    });

    testWidgets('Unread shows only chats with unread messages', (tester) async {
      await _pump(tester, _Chats(conversations));
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Anwar Khan'), findsNothing);
    });

    testWidgets('search filters chats and finds people to message', (
      tester,
    ) async {
      final chats = _Chats(
        conversations,
        people: const [
          UserProfile(id: 'u2', mobile: '', name: 'Anwar Khan'), // has a chat
          UserProfile(id: 'me', mobile: '', name: 'Me'), // the user
          UserProfile(
            id: 'u9',
            mobile: '',
            name: 'Anil Verma',
            headline: 'Electrician',
          ),
        ],
      );
      await _pump(tester, chats);
      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(chats.searches, ['an']);
      expect(find.text('CHATS'), findsOneWidget);
      expect(find.text('Anwar Khan'), findsOneWidget); // only under Chats
      expect(find.text('Priya Sharma'), findsOneWidget); // "Sharma" has "an"
      expect(find.text('PEOPLE ON KAAMMILEGA'), findsOneWidget);
      expect(find.text('Anil Verma'), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
      expect(find.text('KaamMilega member'), findsNothing); // no fake headline
    });

    testWidgets('tapping a chat opens that conversation', (tester) async {
      await _pump(tester, _Chats(conversations));
      await tester.tap(find.text('Priya Sharma'));
      await tester.pumpAndSettle();
      expect(find.text('Chat c2 with u3 (Priya Sharma)'), findsOneWidget);
    });

    testWidgets('long-press a chat: delete it after confirming', (
      tester,
    ) async {
      final chats = _Chats(conversations);
      await _pump(tester, chats);
      await tester.longPress(find.text('Priya Sharma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete chat'));
      await tester.pumpAndSettle();
      expect(find.text('Delete chat?'), findsOneWidget);
      expect(
        find.text(
          'Your chat with Priya Sharma will be removed from your inbox only. '
          'Priya Sharma keeps it, and it comes back if a new message arrives.',
        ),
        findsOneWidget,
      );

      // Cancel keeps it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(chats.deleted, isEmpty);
      expect(find.text('Priya Sharma'), findsOneWidget);

      await tester.longPress(find.text('Priya Sharma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(chats.deleted, ['c2']);
      expect(find.text('Priya Sharma'), findsNothing);
      expect(find.text('Anwar Khan'), findsOneWidget);
      expect(find.text('Chat deleted.'), findsOneWidget);

      // Deleted for this user only: a new message brings it back.
      chats.conversations.add(
        _conv(
          'c2',
          otherId: 'u3',
          name: 'Priya Sharma',
          last: 'Are you there?',
        ),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('swipe left deletes; a server refusal keeps the chat', (
      tester,
    ) async {
      final chats = _Chats(conversations)..failDelete = true;
      await _pump(tester, chats);
      await tester.fling(find.text('Anwar Khan'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Delete chat?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not delete the chat. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Anwar Khan'), findsOneWidget);

      chats.failDelete = false;
      await tester.fling(find.text('Anwar Khan'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(chats.deleted, ['c1']);
      expect(find.text('Anwar Khan'), findsNothing);
    });

    testWidgets('Refresh turns while the list reloads, then stops', (
      tester,
    ) async {
      final chats = _Chats(conversations);
      await _pump(tester, chats);
      final before = chats.loads;
      RotationTransition spinner() => tester.widget<RotationTransition>(
        find.descendant(
          of: find.byTooltip('Refresh'),
          matching: find.byType(RotationTransition),
        ),
      );
      expect(spinner().turns.value, 0);

      await tester.tap(find.byTooltip('Refresh'));
      // First frame starts the animation clock; the next one moves it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(spinner().turns.value, greaterThan(0));

      await tester.pumpAndSettle();
      expect(spinner().turns.value, 0);
      expect(chats.loads, before + 1);
    });

    testWidgets('no chats: friendly empty state', (tester) async {
      await _pump(tester, _Chats(const []));
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('fits a 320px phone with large text', (tester) async {
      await _pump(
        tester,
        _Chats([
          _conv(
            'c1',
            otherId: 'u2',
            name: 'A very long name that will not fit on a small phone',
            last: 'A long last message ' * 6,
            unread: 120,
            online: true,
          ),
        ]),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('99+'), findsWidgets);
    });
  });
}
