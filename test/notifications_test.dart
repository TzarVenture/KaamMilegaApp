import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/services/notification_sound.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/presentation/active_chat.dart';
import 'package:kaam_milega/features/notifications/models/notification_item.dart';
import 'package:kaam_milega/features/notifications/models/notification_target.dart';
import 'package:kaam_milega/features/notifications/presentation/in_app_notification_host.dart';
import 'package:kaam_milega/features/notifications/presentation/notifications_screen.dart';
import 'package:kaam_milega/features/notifications/providers/notification_provider.dart';
import 'package:kaam_milega/features/notifications/repositories/notification_repository.dart';
import 'package:kaam_milega/features/notifications/services/notification_socket_service.dart';
import 'package:kaam_milega/shared/widgets/app_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

// ---------------------------------------------------------------- helpers

Map<String, dynamic> _n(
  String id, {
  String type = 'application_status',
  String category = 'jobs',
  String link = '/applications',
  bool read = false,
  String createdAt = '2026-10-05T07:00:00Z',
  Map<String, dynamic>? metadata,
  String actorName = '',
}) => {
  'id': id,
  'user_id': 'u1',
  'type': type,
  'category': category,
  'title': 'Title $id',
  'message': 'Message $id',
  'link': link,
  'is_read': read,
  'created_at': createdAt,
  'actor_name': actorName,
  'metadata': ?metadata,
};

NotificationItem _item(
  String id, {
  String link = '/applications',
  String type = 'application_status',
  Map<String, dynamic>? metadata,
  String actorName = '',
}) => NotificationItem.fromJson(
  _n(id, link: link, type: type, metadata: metadata, actorName: actorName),
);

class _Server {
  _Server(this.respond);

  final Response<dynamic> Function(RequestOptions o) respond;
  final sent = <RequestOptions>[];

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, handler) {
          sent.add(o);
          try {
            handler.resolve(respond(o));
          } on DioException catch (e) {
            handler.reject(e);
          }
        },
      ),
    );
    return ApiClient(dio: dio);
  }

  List<String> get calls => [for (final o in sent) '${o.method} ${o.path}'];
}

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

Never _fail(RequestOptions o, int code) => throw DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: {'error': 'failed'},
  ),
);

/// GET list (by category / offset), unread count, read, read-all, delete.
Response<dynamic> Function(RequestOptions) _backend({
  List<Map<String, dynamic>>? all,
  int unread = 3,
  bool failWrites = false,
}) {
  final items = all ?? [_n('n1'), _n('n2'), _n('n3', read: true)];
  return (o) {
    if (o.method == 'GET' && o.path == '/notifications') {
      final category = o.queryParameters['category'] as String?;
      final offset = o.queryParameters['offset'] as int? ?? 0;
      final limit = o.queryParameters['limit'] as int? ?? 20;
      final unreadOnly = o.queryParameters['unread_only'] == true;
      final matching = items
          .where((e) => category == null || e['category'] == category)
          .where((e) => !unreadOnly || e['is_read'] != true)
          .toList();
      return _ok(o, {
        'notifications': matching.skip(offset).take(limit).toList(),
        'total': matching.length,
        'limit': limit,
        'offset': offset,
      });
    }
    if (o.path == '/notifications/unread-count') {
      return _ok(o, {'unread_count': unread});
    }
    if (failWrites) _fail(o, 500);
    return _ok(o, {'message': 'ok'});
  };
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9000000000'),
  );
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

ProviderContainer _container(
  _Server server, {
  Stream<NotificationEvent>? events,
}) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authProvider.overrideWith(_SignedIn.new),
      notificationRepositoryProvider.overrideWithValue(
        NotificationRepository(server.client()),
      ),
      notificationEventsProvider.overrideWith(
        (ref) => events ?? const Stream.empty(),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

// ------------------------------------------------------------------ tests

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
    ActiveChat.partnerId.value = null;
  });

  group('NotificationItem', () {
    test('reads the backend fields', () {
      final n = NotificationItem.fromJson({
        ..._n(
          'n1',
          type: 'chat_message',
          category: 'messages',
          link: '/chat?user=u9',
          metadata: {'conversation_id': 'c7', 'sender_id': 'u9'},
          actorName: 'Ravi',
        ),
        'actor_id': 'u9',
        'actor_avatar': 'https://kaammilega.com/uploads/r.png',
      });
      expect(n.id, 'n1');
      expect(n.category, NotificationCategory.messages);
      expect(n.link, '/chat?user=u9');
      expect(n.actorName, 'Ravi');
      expect(n.actorAvatar, 'https://kaammilega.com/uploads/r.png');
      expect(n.meta('conversation_id'), 'c7');
      expect(n.isRead, isFalse);
      expect(n.createdAt.toUtc(), DateTime.utc(2026, 10, 5, 7));
    });
  });

  group('Notification links open app screens', () {
    final cases = <String, NotificationTarget?>{
      '/applications': const RouteTarget('/my-applications'),
      '/candidate/applications': const RouteTarget('/my-applications'),
      '/interviews': const RouteTarget('/interviews'),
      '/network': const RouteTarget('/network'),
      '/profile/u5': const RouteTarget('/members/u5'),
      '/wallet': const RouteTarget('/wallet'),
      '/wallet/transactions': const RouteTarget('/wallet/transactions'),
      '/mentorship': const RouteTarget('/my-sessions'),
      '/expert/mentorship': const RouteTarget('/expert-dashboard'),
      '/events': const RouteTarget('/events'),
      '/instant-work': const RouteTarget('/instant-work'),
      // Recruiter-only and unknown pages open nothing.
      '/recruiter/applications?job_id=j1': null,
      '/instant-hire': null,
      '/something-new': null,
      '': null,
    };
    cases.forEach((link, expected) {
      test('"$link"', () {
        expect(notificationTarget(_item('n', link: link)), expected);
      });
    });

    test('event confirmations open My Tickets', () {
      expect(
        notificationTarget(
          _item('n', link: '/events', type: 'event_confirmed'),
        ),
        const RouteTarget('/my-tickets'),
      );
    });

    test('chat opens the conversation with the sender', () {
      final target = notificationTarget(
        _item(
          'n',
          type: 'chat_message',
          link: '/chat?user=u9',
          metadata: {'conversation_id': 'c7', 'sender_id': 'u9'},
          actorName: 'Ravi',
        ),
      );
      expect(target, const ChatTarget(userId: 'u9', conversationId: 'c7'));
      expect((target as ChatTarget).route, '/chats/c7');
      expect(target.title, 'Ravi');
      // No conversation yet: a new chat with that person.
      expect(const ChatTarget(userId: 'u9').route, '/chats/new-u9');
    });
  });

  group('NotificationRepository', () {
    test('GET /notifications sends paging and the category', () async {
      final server = _Server(_backend());
      final repo = NotificationRepository(server.client());
      final page = await repo.getNotificationsPage(
        category: NotificationCategory.jobs,
        offset: 20,
      );
      final q = server.sent.single.queryParameters;
      expect(q, {'category': 'jobs', 'limit': 20, 'offset': 20});
      expect(page.total, 3);

      await repo.getNotificationsPage();
      expect(server.sent.last.queryParameters.containsKey('category'), false);
    });

    test('a broken reply is an error, not an empty list', () async {
      final repo = NotificationRepository(
        _Server((o) => _ok(o, {'data': []})).client(),
      );
      expect(
        repo.getNotificationsPage(),
        throwsA(isA<AppValidationException>()),
      );
      expect(repo.getUnreadCount(), throwsA(isA<AppValidationException>()));
    });

    test('read, read-all and delete use the backend routes', () async {
      final server = _Server(_backend());
      final repo = NotificationRepository(server.client());
      expect(await repo.getUnreadCount(), 3);
      await repo.markAsRead('n1');
      await repo.markAllAsRead();
      await repo.delete('n2');
      expect(server.calls, [
        'GET /notifications/unread-count',
        'PUT /notifications/n1/read',
        'PUT /notifications/read-all',
        'DELETE /notifications/n2',
      ]);
    });
  });

  group('Notifications list and badge', () {
    test('badge comes from the server count', () async {
      final c = _container(_Server(_backend(unread: 7)));
      c.listen(unreadNotificationsCountProvider, (_, _) {});
      for (var i = 0; i < 50; i++) {
        if (c.read(unreadNotificationsCountProvider) == 7) break;
        await _settle();
      }
      expect(c.read(unreadNotificationsCountProvider), 7);
    });

    test('mark read is saved on the server; a refusal undoes it', () async {
      final ok = _container(_Server(_backend()));
      ok.listen(unreadNotificationsCountProvider, (_, _) {});
      await ok.read(notificationsProvider.future);
      await _settle();
      expect(
        await ok.read(notificationsProvider.notifier).markAsRead('n1'),
        true,
      );
      expect(ok.read(notificationsProvider).value!.items.first.isRead, true);
      expect(ok.read(unreadNotificationsCountProvider), 2);

      final failing = _container(_Server(_backend(failWrites: true)));
      failing.listen(unreadNotificationsCountProvider, (_, _) {});
      await failing.read(notificationsProvider.future);
      await _settle();
      expect(
        await failing.read(notificationsProvider.notifier).markAsRead('n1'),
        false,
      );
      expect(
        failing.read(notificationsProvider).value!.items.first.isRead,
        false,
      );
      expect(failing.read(unreadNotificationsCountProvider), 3);
    });

    test(
      'mark all read: everything read and badge 0; refusal undoes',
      () async {
        final ok = _container(_Server(_backend()));
        ok.listen(unreadNotificationsCountProvider, (_, _) {});
        await ok.read(notificationsProvider.future);
        await _settle();
        await ok.read(notificationsProvider.notifier).markAllAsRead();
        expect(
          ok.read(notificationsProvider).value!.items.every((n) => n.isRead),
          true,
        );
        expect(ok.read(unreadNotificationsCountProvider), 0);

        final failing = _container(_Server(_backend(failWrites: true)));
        failing.listen(unreadNotificationsCountProvider, (_, _) {});
        await failing.read(notificationsProvider.future);
        await _settle();
        expect(
          await failing.read(notificationsProvider.notifier).markAllAsRead(),
          false,
        );
        expect(failing.read(unreadNotificationsCountProvider), 3);
        expect(
          failing.read(notificationsProvider).value!.items.first.isRead,
          false,
        );
      },
    );

    test('delete removes it; a refusal puts it back in place', () async {
      final failing = _container(_Server(_backend(failWrites: true)));
      await failing.read(notificationsProvider.future);
      expect(
        await failing.read(notificationsProvider.notifier).delete('n2'),
        false,
      );
      expect(
        failing.read(notificationsProvider).value!.items.map((n) => n.id),
        ['n1', 'n2', 'n3'],
      );

      final ok = _container(_Server(_backend()));
      await ok.read(notificationsProvider.future);
      expect(await ok.read(notificationsProvider.notifier).delete('n2'), true);
      final feed = ok.read(notificationsProvider).value!;
      expect(feed.items.map((n) => n.id), ['n1', 'n3']);
      expect(feed.total, 2);
    });

    test('load more appends the next page until all are loaded', () async {
      final all = [for (var i = 0; i < 25; i++) _n('n$i')];
      final server = _Server(_backend(all: all));
      final c = _container(server);
      final first = await c.read(notificationsProvider.future);
      expect(first.items, hasLength(20));
      expect(first.hasMore, true);

      expect(await c.read(notificationsProvider.notifier).loadMore(), true);
      final feed = c.read(notificationsProvider).value!;
      expect(feed.items, hasLength(25));
      expect(feed.hasMore, false);
      expect(server.sent.last.queryParameters['offset'], 20);
    });

    test('changing the tab loads that category', () async {
      final server = _Server(
        _backend(
          all: [
            _n('j1'),
            _n('k1', category: 'network', type: 'connection_request'),
          ],
        ),
      );
      final c = _container(server);
      c.listen(notificationsProvider, (_, _) {});
      await c.read(notificationsProvider.future);
      c.read(notificationCategoryProvider.notifier).select('network');
      final feed = await c.read(notificationsProvider.future);
      expect(feed.items.map((n) => n.id), ['k1']);
      expect(server.sent.last.queryParameters['category'], 'network');
    });

    List<Map<String, dynamic>> withChats() => [
      _n('n1'),
      _n(
        'm1',
        category: 'messages',
        type: 'chat_message',
        link: '/chat?user=u9',
        metadata: {'sender_id': 'u9', 'conversation_id': 'c9'},
      ),
      _n(
        'm2',
        category: 'messages',
        type: 'chat_message',
        link: '/chat?user=u7',
        metadata: {'sender_id': 'u7', 'conversation_id': 'c7'},
      ),
    ];

    Future<void> countsLoaded(ProviderContainer c) async {
      for (var i = 0; i < 50; i++) {
        if (c.read(unreadChatsCountProvider) > 0) return;
        await _settle();
      }
    }

    test('chat messages are listed too; the bell counts everything', () async {
      final c = _container(_Server(_backend(all: withChats(), unread: 3)));
      c.listen(unreadNotificationsCountProvider, (_, _) {});
      c.listen(unreadChatsCountProvider, (_, _) {});
      final feed = await c.read(notificationsProvider.future);
      expect(feed.items.map((n) => n.id), ['n1', 'm1', 'm2']);
      expect(feed.hasMore, isFalse);
      await countsLoaded(c);
      expect(c.read(unreadChatsCountProvider), 2);
      expect(c.read(unreadNotificationsCountProvider), 3); // bell badge
    });

    test('Unread only asks the server for unread ones', () async {
      final server = _Server(_backend(all: [_n('n1'), _n('n2', read: true)]));
      final c = _container(server);
      c.listen(notificationsProvider, (_, _) {});
      await c.read(notificationsProvider.future);
      c.read(notificationUnreadOnlyProvider.notifier).set(true);
      final feed = await c.read(notificationsProvider.future);
      expect(server.sent.last.queryParameters['unread_only'], true);
      expect(feed.items.map((n) => n.id), ['n1']);
    });

    test('quick action labels match the website', () {
      NotificationItem n(String type, String category, String link) =>
          NotificationItem.fromJson(
            _n('x', type: type, category: category, link: link),
          );
      expect(
        notificationActionLabel(n('chat_message', 'messages', '/chat?user=u9')),
        'Reply',
      );
      expect(
        notificationActionLabel(
          n('application_status', 'jobs', '/applications'),
        ),
        'View',
      );
      expect(
        notificationActionLabel(n('connection_request', 'network', '/network')),
        'View',
      );
      expect(
        notificationActionLabel(n('wallet_credit', 'system', '/wallet')),
        'Open',
      );
      // Nothing to open in the app: no button.
      expect(
        notificationActionLabel(n('x', 'jobs', '/recruiter/applications')),
        isNull,
      );
    });

    test('accepted invite opens the profile of the person who accepted', () {
      final item = NotificationItem.fromJson({
        ..._n(
          'x',
          type: 'connection_accepted',
          category: 'network',
          link: '/network',
        ),
        'actor_id': 'u5',
      });
      expect(notificationTarget(item), const RouteTarget('/members/u5'));
      expect(notificationActionLabel(item), 'Profile');
    });

    test('opening a chat marks only that person\'s messages read', () async {
      final server = _Server(_backend(all: withChats(), unread: 3));
      final c = _container(server);
      c.listen(unreadCountsProvider, (_, _) {});
      await countsLoaded(c);
      await c.read(unreadCountsProvider.notifier).markChatRead('u9');
      expect(server.calls, contains('PUT /notifications/m1/read'));
      expect(server.calls, isNot(contains('PUT /notifications/m2/read')));
    });

    test('live events update the list and the badge', () async {
      final events = StreamController<NotificationEvent>.broadcast();
      addTearDown(events.close);
      final c = _container(_Server(_backend()), events: events.stream);
      c.listen(unreadNotificationsCountProvider, (_, _) {});
      c.listen(notificationsProvider, (_, _) {});
      await c.read(notificationsProvider.future);
      await _settle();

      events.add(
        NotificationEvent(
          type: NotificationEventType.created,
          unreadCount: 4,
          notification: _item('n9'),
        ),
      );
      await _settle();
      var feed = c.read(notificationsProvider).value!;
      expect(feed.items.first.id, 'n9');
      expect(feed.total, 4);
      expect(c.read(unreadNotificationsCountProvider), 4);

      // Same chat notification updated (debounced): moved up, not doubled.
      events.add(
        NotificationEvent(
          type: NotificationEventType.created,
          unreadCount: 4,
          notification: _item('n2'),
        ),
      );
      await _settle();
      feed = c.read(notificationsProvider).value!;
      expect(feed.items.map((n) => n.id), ['n2', 'n9', 'n1', 'n3']);
      expect(feed.total, 4);

      events.add(
        const NotificationEvent(
          type: NotificationEventType.read,
          notificationId: 'n9',
          unreadCount: 3,
        ),
      );
      events.add(
        const NotificationEvent(
          type: NotificationEventType.deleted,
          notificationId: 'n1',
          unreadCount: 2,
        ),
      );
      await _settle();
      feed = c.read(notificationsProvider).value!;
      expect(feed.items.firstWhere((n) => n.id == 'n9').isRead, true);
      expect(feed.items.any((n) => n.id == 'n1'), false);
      expect(c.read(unreadNotificationsCountProvider), 2);

      events.add(
        const NotificationEvent(
          type: NotificationEventType.allRead,
          unreadCount: 0,
        ),
      );
      await _settle();
      expect(
        c.read(notificationsProvider).value!.items.every((n) => n.isRead),
        true,
      );
      expect(c.read(unreadNotificationsCountProvider), 0);
    });

    test('a guest makes no request and has no badge', () async {
      final server = _Server(_backend());
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Guest.new),
          notificationRepositoryProvider.overrideWithValue(
            NotificationRepository(server.client()),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(unreadNotificationsCountProvider, (_, _) {});
      expect((await c.read(notificationsProvider.future)).items, isEmpty);
      await _settle();
      expect(c.read(unreadNotificationsCountProvider), 0);
      expect(server.sent, isEmpty);
    });
  });

  group('Notifications screen', () {
    Future<_Server> pump(
      WidgetTester tester, {
      Size size = const Size(360, 740),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = _Server(
        _backend(
          all: [
            _n('n1', link: '/interviews'),
            _n(
              'n2',
              category: 'network',
              type: 'connection_request',
              link: '/network',
            ),
            _n('n3', read: true, link: '/recruiter/applications?job_id=j'),
          ],
        ),
      );
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/interviews',
            builder: (_, _) => const Scaffold(body: Text('Interviews page')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            notificationRepositoryProvider.overrideWithValue(
              NotificationRepository(server.client()),
            ),
            notificationEventsProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return server;
    }

    testWidgets('categories, count, Unread only and rows', (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Messages & Chat'), findsOneWidget);
      expect(find.textContaining('(3)'), findsOneWidget);
      expect(find.text('Unread only'), findsOneWidget);
      expect(find.text('Filter by name, company or keyword'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^(TODAY|YESTERDAY|EARLIER)$')),
        findsWidgets,
      );
      expect(find.textContaining('Title n1'), findsOneWidget);
      expect(find.text('View'), findsWidgets); // quick action
      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('fits a small phone', (tester) async {
      await pump(tester, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      // The categories scroll sideways.
      await tester.dragUntilVisible(
        find.text('System & Alerts'),
        find.byType(ListView).first,
        const Offset(-150, 0),
      );
      expect(find.text('System & Alerts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap marks read on the server and opens the screen', (
      tester,
    ) async {
      final server = await pump(tester);
      await tester.tap(find.textContaining('Title n1'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('PUT /notifications/n1/read'));
      expect(find.text('Interviews page'), findsOneWidget);
    });

    testWidgets('check button marks one read without opening it', (
      tester,
    ) async {
      final server = await pump(tester);
      await tester.tap(find.byTooltip('Mark as read').first);
      await tester.pumpAndSettle();
      expect(server.calls, contains('PUT /notifications/n1/read'));
      expect(find.text('Interviews page'), findsNothing);
    });

    testWidgets('a recruiter-only link opens nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.textContaining('Title n3'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Title n3'), findsOneWidget); // still here
    });

    testWidgets('keyword filter narrows the list', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'message n2');
      await tester.pumpAndSettle();
      expect(find.textContaining('Title n2'), findsOneWidget);
      expect(find.textContaining('Title n1'), findsNothing);
      expect(find.textContaining('1 of 3'), findsOneWidget);
    });

    testWidgets('swipe deletes on the server', (tester) async {
      final server = await pump(tester);
      await tester.fling(
        find.byKey(const ValueKey('notification-n2')),
        const Offset(-300, 0),
        1500,
      );
      await tester.pumpAndSettle();
      // The delete is sent on the last frame of the swipe animation; let
      // the request go out before checking.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(server.calls, contains('DELETE /notifications/n2'));
      expect(find.textContaining('Title n2'), findsNothing);
    });

    testWidgets('a category asks the server for it', (tester) async {
      final server = await pump(tester);
      // The category chips scroll sideways; the test font is wide, so
      // this chip starts off-screen.
      await tester.dragUntilVisible(
        find.text('Network & Invites'),
        find.byType(ListView).first,
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network & Invites'));
      await tester.pumpAndSettle();
      expect(server.sent.last.queryParameters['category'], 'network');
      expect(find.textContaining('Title n2'), findsOneWidget);
      expect(find.textContaining('Title n1'), findsNothing);
    });

    testWidgets('Unread only switch', (tester) async {
      final server = await pump(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(server.sent.last.queryParameters['unread_only'], true);
      expect(find.textContaining('Title n3'), findsNothing); // read
      expect(find.textContaining('Title n1'), findsOneWidget);
    });
  });

  group('In-app banner', () {
    var tones = 0;

    Future<({_Server server, StreamController<NotificationEvent> events})> pump(
      WidgetTester tester,
    ) async {
      tones = 0;
      final events = StreamController<NotificationEvent>.broadcast();
      addTearDown(events.close);
      final server = _Server(_backend());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home page')),
          ),
          GoRoute(
            path: '/interviews',
            builder: (_, _) => const Scaffold(body: Text('Interviews page')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            notificationRepositoryProvider.overrideWithValue(
              NotificationRepository(server.client()),
            ),
            notificationEventsProvider.overrideWith((ref) => events.stream),
            notificationSoundProvider.overrideWithValue(() async => tones++),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => InAppNotificationHost(
              router: router,
              displayDuration: const Duration(seconds: 5),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (server: server, events: events);
    }

    NotificationEvent created(NotificationItem n) => NotificationEvent(
      type: NotificationEventType.created,
      unreadCount: 1,
      notification: n,
    );

    testWidgets('shows, opens the screen on tap and marks it read', (
      tester,
    ) async {
      final h = await pump(tester);
      h.events.add(created(_item('n5', link: '/interviews')));
      await tester.pumpAndSettle();
      expect(find.text('Title n5'), findsOneWidget);
      expect(tones, 0); // not a chat message: banner only

      await tester.tap(find.text('Title n5'));
      await tester.pumpAndSettle();
      expect(find.text('Interviews page'), findsOneWidget);
      expect(h.server.calls, contains('PUT /notifications/n5/read'));
      expect(find.text('Title n5'), findsNothing);
    });

    testWidgets('closes by itself after 5 seconds', (tester) async {
      final h = await pump(tester);
      h.events.add(created(_item('n5')));
      await tester.pumpAndSettle();
      expect(find.text('Title n5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Title n5'), findsNothing);
    });

    testWidgets('quiet for messages from the person whose chat is open', (
      tester,
    ) async {
      final h = await pump(tester);
      ActiveChat.enter('u9');
      addTearDown(() => ActiveChat.leave('u9'));
      h.events.add(
        created(
          _item(
            'c1',
            type: 'chat_message',
            link: '/chat?user=u9',
            metadata: {'sender_id': 'u9'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Title c1'), findsNothing);
      expect(tones, 0); // muted while chatting with them

      // Someone else: shown.
      h.events.add(
        created(
          _item(
            'c2',
            type: 'chat_message',
            link: '/chat?user=u7',
            metadata: {'sender_id': 'u7'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Title c2'), findsOneWidget);
      expect(tones, 1); // a message from someone else: one tone
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('Notification socket', () {
    late HttpServer server;
    late NotificationSocketService service;
    final sockets = <WebSocket>[];
    final paths = <String>[];

    setUpAll(() => HttpOverrides.global = null); // real sockets
    setUp(() async {
      SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt-abc'});
      LocalStorage.setMockInstance(await SharedPreferences.getInstance());
      sockets.clear();
      paths.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        paths.add('${request.uri.path}?${request.uri.query}');
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((_) {});
        socket.add(jsonEncode({'type': 'INIT', 'unread_count': 2}));
      });
      service = NotificationSocketService(
        connector: (url) async => IOWebSocketChannel(
          await WebSocket.connect(
            Uri.parse(url)
                .replace(scheme: 'ws', host: '127.0.0.1', port: server.port)
                .toString(),
          ),
        ),
        networkStatus: const Stream.empty(),
        isOnline: () => true,
      );
    });
    tearDown(() async {
      service.dispose();
      await server.close(force: true);
    });

    test(
      'opens /api/ws/notifications with the token and reads events',
      () async {
        final received = <NotificationEvent>[];
        service.events.listen(received.add);
        await service.connect();
        for (var i = 0; i < 100 && received.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(paths.single, '/api/ws/notifications?token=jwt-abc');
        expect(received.first.type, NotificationEventType.init);
        expect(received.first.unreadCount, 2);

        sockets.single.add(
          jsonEncode({
            'type': 'NEW_NOTIFICATION',
            'notification': _n('n7'),
            'unread_count': 3,
          }),
        );
        sockets.single.add(
          jsonEncode({
            'type': 'NOTIFICATION_DELETED',
            'notification_id': 'n7',
            'unread_count': 2,
          }),
        );
        sockets.single.add('not json');
        for (var i = 0; i < 100 && received.length < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(received[1].type, NotificationEventType.created);
        expect(received[1].notification!.id, 'n7');
        expect(received[1].unreadCount, 3);
        expect(received[2].type, NotificationEventType.deleted);
        expect(received[2].notificationId, 'n7');
      },
    );
  });

  testWidgets('Chats tab shows the unread badge', (tester) async {
    Widget bar(int count) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AppBottomNav.frame(
          children: [
            AppBottomNavItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chats',
              selected: false,
              onTap: () {},
              badgeCount: count,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(bar(3));
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(bar(150));
    expect(find.text('99+'), findsOneWidget);
    await tester.pumpWidget(bar(0));
    expect(find.byType(Badge), findsNothing);
  });
}
