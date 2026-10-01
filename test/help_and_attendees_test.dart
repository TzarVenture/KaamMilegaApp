import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/events/models/event_participant.dart';
import 'package:kaam_milega/features/events/presentation/widgets/event_attendees.dart';
import 'package:kaam_milega/features/events/repositories/event_repository.dart';
import 'package:kaam_milega/features/help/presentation/help_screen.dart';
import 'package:kaam_milega/features/help/repositories/help_repository.dart';
import 'package:kaam_milega/shared/widgets/network_state_view.dart';
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

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

final _attendees = {
  'event_id': 'e1',
  'event_title': 'Career fair',
  'total_joined': 3,
  'attendees': [
    {
      'id': 'a1',
      'name': 'Ravi Kumar',
      'headline': 'Electrician',
      'ticket_number': 'TKT-1',
      'payment_type': 'paid',
    },
    {'id': 'a2', 'name': 'Meena', 'city': 'Pune'},
    {'id': 'a3', 'name': ''},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Help & FAQ', () {
    test('reads {data: [...]}; incomplete entries are left out', () async {
      final f = _fakeClient(
        (o) => _ok(o, {
          'data': [
            {'id': 'q1', 'question': 'How do I apply?', 'answer': 'Tap Apply.'},
            {'id': 'q2', 'question': 'Empty answer', 'answer': ''},
          ],
          'total': 2,
        }),
      );
      final faqs = await HelpRepository(f.client).getFaqs();
      expect(f.sent.single.path, '/questions');
      expect(faqs.map((q) => q.id), ['q1']);
    });

    testWidgets('shows questions; tapping one shows the answer', (
      tester,
    ) async {
      final f = _fakeClient(
        (o) => _ok(o, {
          'data': [
            {
              'id': 'q1',
              'question': 'How do I apply for a job?',
              'answer': 'Open the job and tap Apply.',
            },
          ],
        }),
      );
      await _pump(tester, const HelpScreen(), [
        helpRepositoryProvider.overrideWithValue(HelpRepository(f.client)),
      ]);
      expect(find.text('How do I apply for a job?'), findsOneWidget);
      await tester.tap(find.text('How do I apply for a job?'));
      await tester.pumpAndSettle();
      expect(find.text('Open the job and tap Apply.'), findsOneWidget);
    });

    testWidgets('server error is an error with Retry, not "no questions"', (
      tester,
    ) async {
      final f = _fakeClient((o) => _fail(o, 500));
      await _pump(tester, const HelpScreen(), [
        helpRepositoryProvider.overrideWithValue(HelpRepository(f.client)),
      ]);
      expect(find.byType(NetworkStateView), findsOneWidget);
      expect(
        find.textContaining('No questions have been published'),
        findsNothing,
      );
    });
  });

  group('Event attendees', () {
    test('public fields only; total from the server', () {
      final list = EventAttendees.fromJson(_attendees);
      expect(list.total, 3);
      expect(list.people.first.subtitle, 'Electrician');
      expect(list.people[1].subtitle, 'Pune');
      expect(list.people[2].displayName, 'KaamMilega member');
    });

    testWidgets('row shows the count; See all lists everyone', (tester) async {
      final f = _fakeClient((o) {
        if (o.path == '/events/e1/attendees') return _ok(o, _attendees);
        throw StateError('unexpected ${o.path}');
      });
      await _pump(
        tester,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: EventAttendeesRow(eventId: 'e1'),
          ),
        ),
        [eventRepositoryProvider.overrideWithValue(EventRepository(f.client))],
      );
      expect(find.text('3 attending'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Meena'), findsOneWidget);
      expect(find.textContaining('TKT-1'), findsNothing); // never shown
    });

    testWidgets('no one yet: an invitation, not an error', (tester) async {
      final f = _fakeClient(
        (o) => _ok(o, {'total_joined': 0, 'attendees': null}),
      );
      await _pump(
        tester,
        const Scaffold(body: EventAttendeesRow(eventId: 'e1')),
        [eventRepositoryProvider.overrideWithValue(EventRepository(f.client))],
      );
      expect(find.text('No one has joined yet. Be the first.'), findsOneWidget);
    });
  });
}
