import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/events/models/event.dart';
import 'package:kaam_milega/features/events/presentation/event_detail_screen.dart';
import 'package:kaam_milega/features/events/presentation/widgets/event_attendees.dart';
import 'package:kaam_milega/features/events/providers/event_provider.dart';
import 'package:kaam_milega/features/events/repositories/event_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

({ApiClient client, List<RequestOptions> sent}) _fakeClient(
  Response<dynamic> Function(RequestOptions o) respond,
) {
  final sent = <RequestOptions>[];
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
  return (client: ApiClient(dio: dio), sent: sent);
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

Map<String, dynamic> _event(String id, {int seats = 12}) => {
  'id': id,
  'title': 'Event $id',
  'organizer': 'KaamMilega',
  'date': '2026-10-12',
  'time': '5:00 PM',
  'location': 'Pune',
  'is_paid': true,
  'price': 499,
  'currency': 'INR',
  'capacity': 50,
  'available_seats': seats,
  'participants': <String>[],
};

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

ProviderContainer _container(ApiClient client) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authProvider.overrideWith(_Guest.new),
      eventRepositoryProvider.overrideWithValue(EventRepository(client)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Events from the server', () {
    test('filters, sort and page go to GET /events; total is read', () async {
      final f = _fakeClient(
        (o) => _ok(o, {
          'data': [_event('e1')],
          'total': 31,
          'page': 2,
          'limit': 20,
        }),
      );
      final page = await EventRepository(f.client).getEventsPage(
        search: ' career ',
        isPaid: false,
        upcomingFirst: true,
        page: 2,
      );
      final q = f.sent.single.queryParameters;
      expect(f.sent.single.path, '/events');
      expect(q['search'], 'career');
      expect(q['is_paid'], false);
      expect(q['sort'], 'Upcoming');
      expect(q['page'], 2);
      expect(q['limit'], 20);
      expect(page.total, 31);
      expect(page.items.single.id, 'e1');
    });

    test('no filters: no extra parameters (newest first)', () async {
      final f = _fakeClient((o) => _ok(o, {'data': [], 'total': 0}));
      await EventRepository(f.client).getEventsPage();
      expect(
        f.sent.single.queryParameters.keys,
        unorderedEquals(['page', 'limit']),
      );
    });

    test('changing the query reloads page 1 with the new filters', () async {
      final f = _fakeClient(
        (o) => _ok(o, {
          'data': [_event('e1')],
          'total': 1,
        }),
      );
      final c = _container(f.client);
      await c.read(eventsProvider.future);
      c
          .read(eventsQueryProvider.notifier)
          .set(const EventsQuery(isPaid: true, upcomingFirst: true));
      await c.read(eventsProvider.future);
      final q = f.sent.last.queryParameters;
      expect(q['is_paid'], true);
      expect(q['sort'], 'Upcoming');
      expect(q['page'], 1);
    });

    test('load more adds the next page until all are loaded', () async {
      final f = _fakeClient((o) {
        final page = o.queryParameters['page'];
        return _ok(o, {
          'data': page == 1
              ? [_event('e1'), _event('e2')]
              : [_event('e2'), _event('e3')], // e2 repeated: shown once
          'total': 3,
        });
      });
      final c = _container(f.client);
      expect((await c.read(eventsProvider.future)).length, 2);
      final notifier = c.read(eventsProvider.notifier);
      expect(notifier.hasMore, isTrue);

      expect(await notifier.loadMore(), isTrue);
      expect(f.sent.last.queryParameters['page'], 2);
      expect(c.read(eventsProvider).value!.map((e) => e.id), [
        'e1',
        'e2',
        'e3',
      ]);
      expect(notifier.hasMore, isFalse);
    });

    test('load more failing keeps the list and says so', () async {
      final f = _fakeClient((o) {
        if (o.queryParameters['page'] == 2) _fail(o, 500);
        return _ok(o, {
          'data': [_event('e1')],
          'total': 5,
        });
      });
      final c = _container(f.client);
      await c.read(eventsProvider.future);
      expect(await c.read(eventsProvider.notifier).loadMore(), isFalse);
      expect(c.read(eventsProvider).value!.single.id, 'e1');
      expect(c.read(eventsProvider.notifier).hasMore, isTrue);
    });

    test('GET /events/:id; a non-object reply is an error', () async {
      final f = _fakeClient((o) => _ok(o, _event('e1', seats: 3)));
      final e = await EventRepository(f.client).getEvent('e1');
      expect(f.sent.single.path, '/events/e1');
      expect(e.seatsLeft, 3);

      final bad = _fakeClient((o) => _ok(o, []));
      expect(
        EventRepository(bad.client).getEvent('e1'),
        throwsA(isA<AppServerException>()),
      );
    });
  });

  group('Event screens', () {
    testWidgets('event page shows fresh seats from GET /events/:id', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = _fakeClient((o) {
        if (o.path == '/events/e1') return _ok(o, _event('e1', seats: 3));
        if (o.path == '/events/e1/attendees') {
          return _ok(o, {'total_joined': 0, 'attendees': []});
        }
        return _fail(o, 404);
      });
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_Guest.new),
            eventRepositoryProvider.overrideWithValue(
              EventRepository(f.client),
            ),
          ],
          child: MaterialApp(
            // The list copy says 12 seats; the server now says 3.
            home: EventDetailScreen(event: EventItem.fromJson(_event('e1'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('3 seats left'), findsWidgets);
      expect(find.textContaining('12 seats left'), findsNothing);
    });

    testWidgets('attendee list opens from anywhere and loads itself', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = _fakeClient(
        (o) => _ok(o, {
          'total_joined': 2,
          'attendees': [
            {'id': 'a1', 'name': 'Ravi Kumar'},
            {'id': 'a2', 'name': 'Meena'},
          ],
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_Guest.new),
            eventRepositoryProvider.overrideWithValue(
              EventRepository(f.client),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEventAttendeesFor(context, 'e1'),
                  child: const Text('2 attending'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('2 attending'));
      await tester.pumpAndSettle();
      expect(f.sent.single.path, '/events/e1/attendees');
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Meena'), findsOneWidget);
    });
  });
}
