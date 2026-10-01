import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/experts/models/expert_offering.dart';
import 'package:kaam_milega/features/experts/presentation/expert_dashboard_screen.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request locally (no network); records each request.
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

/// A booking as GET /mentorships/bookings/expert sends it.
Map<String, dynamic> _booking(
  String id, {
  required String status,
  required DateTime at,
  double amount = 500,
  String payment = 'paid',
}) => {
  'id': id,
  'mentorship_id': 'm1',
  'expert_id': 'me',
  'user_id': 'u2',
  'scheduled_at': at.toUtc().toIso8601String(),
  'status': status,
  'amount': amount,
  'payment_status': payment,
  'payment_method': 'wallet',
  'mentorship_title': 'Mock interview',
  'mentee_name': 'Ravi Kumar',
};

class _Auth extends AuthNotifier {
  _Auth({this.expert = true});
  final bool expert;

  @override
  AuthState build() => AuthState(
    isAuthenticated: true,
    user: UserProfile(
      id: 'me',
      mobile: '9876543210',
      name: 'Asha',
      roles: expert ? const ['user', 'expert'] : const ['user'],
    ),
  );
}

class _Wallet extends WalletNotifier {
  @override
  WalletState build() => const WalletState(
    summary: WalletSummary(withdrawableBalance: 1200, lockedBalance: 500),
  );

  @override
  Future<void> loadWallet() async {}
}

List<Override> _overrides(ApiClient client, {bool expert = true}) => [
  authProvider.overrideWith(() => _Auth(expert: expert)),
  walletProvider.overrideWith(_Wallet.new),
  expertRepositoryProvider.overrideWithValue(ExpertRepository(client)),
];

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1400, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: const MaterialApp(home: ExpertDashboardScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Repository', () {
    test('bookings with me: soonest first, with the mentee name', () async {
      final now = DateTime.now();
      final f = _fakeClient(
        (o) => _ok(o, [
          _booking(
            'late',
            status: 'pending',
            at: now.add(const Duration(days: 3)),
          ),
          _booking(
            'soon',
            status: 'pending',
            at: now.add(const Duration(days: 1)),
          ),
        ]),
      );
      final list = await ExpertRepository(f.client).getExpertBookings();
      expect(f.sent.single.path, '/mentorships/bookings/expert');
      expect(list.map((b) => b.id), ['soon', 'late']);
      expect(list.first.menteeName, 'Ravi Kumar');
    });

    test(
      'status change sends {status}; unknown statuses are refused',
      () async {
        final f = _fakeClient((o) => _ok(o, {'message': 'ok'}));
        final repo = ExpertRepository(f.client);
        await repo.updateBookingStatus('b1', 'completed');
        expect(f.sent.single.method, 'PATCH');
        expect(f.sent.single.path, '/mentorships/bookings/b1/status');
        expect(f.sent.single.data, {'status': 'completed'});

        expect(() => repo.updateBookingStatus('b1', 'paid'), throwsA(anything));
        expect(f.sent, hasLength(1));
      },
    );

    test('meeting links: https added, invalid refused', () {
      expect(
        ExpertRepository.normalizeMeetingLink('meet.google.com/abc-defg-hij'),
        'https://meet.google.com/abc-defg-hij',
      );
      expect(
        ExpertRepository.normalizeMeetingLink('https://zoom.us/j/123'),
        'https://zoom.us/j/123',
      );
      expect(ExpertRepository.normalizeMeetingLink('not a link'), isNull);
      expect(ExpertRepository.normalizeMeetingLink('hello'), isNull);
    });

    test(
      'offering: create is POST, edit is PATCH, incomplete is refused',
      () async {
        final f = _fakeClient((o) => _ok(o, {'id': 'm1'}));
        final repo = ExpertRepository(f.client);
        const draft = ExpertOfferingDraft(
          title: 'Mock interview',
          description: 'Practice questions for electricians',
          category: 'Interview Prep',
          durationMinutes: 30,
          price: 199,
        );
        await repo.saveOffering(draft);
        await repo.saveOffering(draft, id: 'm1');
        expect(f.sent.map((o) => '${o.method} ${o.path}'), [
          'POST /mentorships',
          'PATCH /mentorships/m1',
        ]);
        expect(f.sent.first.data, {
          'title': 'Mock interview',
          'description': 'Practice questions for electricians',
          'category': 'Interview Prep',
          'duration': 30,
          'price': 199.0,
        });

        const incomplete = ExpertOfferingDraft(
          title: 'Hi',
          description: '',
          category: '',
          durationMinutes: 0,
          price: 0,
        );
        expect(incomplete.problem, isNotNull);
        expect(() => repo.saveOffering(incomplete), throwsA(anything));
        expect(f.sent, hasLength(2));
      },
    );

    test('hours: Sunday is 0, bad rows skipped, saved as a list', () async {
      final f = _fakeClient((o) {
        if (o.method == 'GET') {
          return _ok(o, [
            {'day_of_week': 0, 'start_time': '10:00', 'end_time': '14:00'},
            {'day_of_week': 9, 'start_time': '10:00', 'end_time': '14:00'},
            {'day_of_week': 2, 'start_time': 'x', 'end_time': '14:00'},
          ]);
        }
        return _ok(o, null);
      });
      final repo = ExpertRepository(f.client);
      final hours = await repo.getMyAvailability();
      expect(hours.single.dayName, 'Sunday');

      await repo.saveAvailability(hours);
      expect(f.sent.last.method, 'PUT');
      expect(f.sent.last.data, [
        {'day_of_week': 0, 'start_time': '10:00', 'end_time': '14:00'},
      ]);

      // A session must fit inside the hours of its day
      final sunday = DateTime(2026, 10, 4, 13, 0); // a Sunday
      expect(hours.single.fits(sunday, 60), isTrue);
      expect(hours.single.fits(sunday, 90), isFalse);
      expect(hours.single.fits(DateTime(2026, 10, 5, 11), 30), isFalse);
    });
  });

  group('Screen', () {
    testWidgets('not an Expert: no dashboard, offer to become one', (
      tester,
    ) async {
      final f = _fakeClient((o) => throw StateError('no request expected'));
      await _pump(tester, _overrides(f.client, expert: false));
      expect(
        find.text('Only KaamMilega Experts can use this dashboard'),
        findsOneWidget,
      );
      expect(f.sent, isEmpty);
    });

    testWidgets('confirm a new booking; completing waits for the session', (
      tester,
    ) async {
      final now = DateTime.now();
      final f = _fakeClient((o) {
        if (o.path == '/mentorships/bookings/expert') {
          return _ok(o, [
            _booking(
              'new1',
              status: 'pending',
              at: now.add(const Duration(days: 2)),
            ),
            _booking(
              'future',
              status: 'confirmed',
              at: now.add(const Duration(days: 1)),
            ),
          ]);
        }
        if (o.method == 'PATCH') return _ok(o, {'message': 'ok'});
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      await _pump(tester, _overrides(f.client));

      expect(find.text('₹1,200'), findsOneWidget); // withdrawable
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsNWidgets(2));

      // Future confirmed session: cannot be completed yet
      final complete = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Mark completed'),
      );
      expect(complete.onPressed, isNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm this booking?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();

      final patch = f.sent.singleWhere((o) => o.method == 'PATCH');
      expect(patch.path, '/mentorships/bookings/new1/status');
      expect(patch.data, {'status': 'confirmed'});
      expect(find.text('Booking confirmed.'), findsOneWidget);
    });

    testWidgets('a started session can be completed; money is explained', (
      tester,
    ) async {
      final f = _fakeClient((o) {
        if (o.path == '/mentorships/bookings/expert') {
          return _ok(o, [
            _booking(
              'done',
              status: 'confirmed',
              at: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ]);
        }
        if (o.method == 'PATCH') return _ok(o, {'message': 'ok'});
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      await _pump(tester, _overrides(f.client));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark completed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('₹500 held for it'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Mark completed'));
      await tester.pumpAndSettle();

      final patch = f.sent.singleWhere((o) => o.method == 'PATCH');
      expect(patch.data, {'status': 'completed'});
    });

    testWidgets('hours: turn Monday on and save 9 to 5', (tester) async {
      final f = _fakeClient((o) {
        if (o.path == '/mentorships/bookings/expert') return _ok(o, []);
        if (o.path == '/mentorships/expert/my') return _ok(o, []);
        if (o.path == '/mentorships/availability' && o.method == 'GET') {
          return _ok(o, []);
        }
        if (o.method == 'PUT') return _ok(o, null);
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      await _pump(tester, _overrides(f.client));

      await tester.tap(find.text('Hours'));
      await tester.pumpAndSettle();
      expect(find.text('Monday'), findsOneWidget);

      await tester.tap(find.byType(Switch).first); // Monday
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save hours'));
      await tester.pumpAndSettle();

      final put = f.sent.singleWhere((o) => o.method == 'PUT');
      expect(put.path, '/mentorships/availability');
      expect(put.data, [
        {'day_of_week': 1, 'start_time': '09:00', 'end_time': '17:00'},
      ]);
      expect(find.text('Your hours are saved.'), findsOneWidget);
    });
  });
}
