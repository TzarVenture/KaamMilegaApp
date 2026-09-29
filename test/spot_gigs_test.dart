import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/instant_work/models/spot_gig.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/spot_gigs_widgets.dart';
import 'package:kaam_milega/features/instant_work/providers/instant_milega_provider.dart';
import 'package:kaam_milega/features/instant_work/providers/spot_gigs_provider.dart';
import 'package:kaam_milega/features/instant_work/repositories/instant_candidate_repository.dart';
import 'package:kaam_milega/features/instant_work/services/location_service.dart';
import 'package:kaam_milega/features/wallet/models/wallet_transaction.dart';
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

DioException _status(RequestOptions o, int code, Map<String, dynamic> body) =>
    DioException(
      requestOptions: o,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: code,
        data: body,
      ),
    );

Map<String, dynamic> _gigJson({
  String id = 'g1',
  String status = 'DISPATCHING',
  int minutes = 3,
}) => {
  'id': id,
  'recruiter_id': 'r1',
  'recruiter_name': 'Ravi',
  'company_name': 'Acme Movers',
  'recruiter_mobile': '9000000001',
  'skill': 'electrician',
  'address': 'Baner Road, Pune',
  'pay_rate': 350,
  'rate_type': 'hourly',
  'duration_hours': 4,
  'required_workers': 1,
  'notes': 'Bring your own tools',
  'status': status,
  'distance_km': 1.24,
  'location': {
    'type': 'Point',
    'coordinates': [73.8, 18.5],
  },
  'expires_at': DateTime.now()
      .toUtc()
      .add(Duration(minutes: minutes))
      .toIso8601String(),
};

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210'),
  );
}

class _Located extends InstantMilegaNotifier {
  @override
  InstantMilegaState build() => const InstantMilegaState(
    locationStatus: LocationStatus.ready,
    location: DeviceLocation(latitude: 18.52, longitude: 73.85),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('SpotGig', () {
    test('reads the backend job; pay, total, distance, time left', () {
      final g = SpotGig.fromJson(_gigJson());
      expect(g.title, 'Electrician');
      expect(g.employer, 'Acme Movers');
      expect(g.payLabel, '₹350 / hour');
      expect(g.totalLabel, '₹1,400 for 4 hours');
      expect(g.distanceLabel, '1.2 km away');
      expect(g.location?.lat, 18.5);
      expect(g.minutesLeft(DateTime.now()), inInclusiveRange(2, 3));
      expect(g.status, SpotGigStatus.dispatching);
      expect(g.canComplete, isFalse);
    });

    test('earnings: completed gig payouts only, today and 7 days', () {
      final now = DateTime(2026, 9, 29, 15);
      WalletTransaction t(double amount, DateTime at, {String? cat}) =>
          WalletTransaction(
            id: '$amount',
            title: '',
            description: '',
            amount: amount,
            type: TransactionType.credit,
            status: TransactionStatus.completed,
            createdAt: at,
            category: cat ?? GigEarnings.category,
          );
      final e = GigEarnings.from([
        t(500, DateTime(2026, 9, 29, 9)),
        t(300, DateTime(2026, 9, 27, 9)),
        t(999, DateTime(2026, 9, 10, 9)), // older than 7 days
        t(99, DateTime(2026, 9, 29, 10), cat: 'topup'),
      ], now);
      expect(e.today, 500);
      expect(e.todayGigs, 1);
      expect(e.week, 800);
      expect(e.weekGigs, 2);
    });
  });

  group('Repository', () {
    test(
      'feed: "All" sends no trade; claim conflict keeps the reason',
      () async {
        final f = _fakeClient((o) {
          if (o.path == '/instant-work/candidate/feed') return _ok(o, null);
          if (o.path == '/instant-work/claim') {
            throw _status(o, 409, {
              'error': 'this gig has already been claimed by another candidate',
            });
          }
          if (o.path == '/instant-work/candidate/active-job') {
            return _ok(o, null);
          }
          throw StateError(o.path);
        });
        final repo = InstantCandidateRepository(f.client);
        expect(await repo.getNearbyGigs(lat: 1, lng: 2, skill: 'All'), isEmpty);
        expect(f.sent.first.queryParameters.containsKey('skill'), isFalse);
        expect(await repo.getActiveGig(), isNull);
        await expectLater(
          repo.claimGig('g1'),
          throwsA(
            isA<AppValidationException>().having(
              (e) => e.message,
              'message',
              startsWith('This gig has already been claimed'),
            ),
          ),
        );
      },
    );

    test('claim without pass gigs: InstantPassRequired', () async {
      final f = _fakeClient(
        (o) => throw _status(o, 402, {
          'error': 'your InstantPass quota has been exhausted',
          'requires_pass': true,
        }),
      );
      await expectLater(
        InstantCandidateRepository(f.client).claimGig('g1'),
        throwsA(isA<InstantPassRequired>()),
      );
    });
  });

  testWidgets('claim a gig, then mark it complete', (tester) async {
    var claimed = false;
    var completed = false;
    final f = _fakeClient((o) {
      switch (o.path) {
        case '/instant-work/candidate/status':
          return _ok(o, {
            'is_free_now': true,
            'active_skill': 'All',
            'quota_remaining': 7,
            'has_active_pass': true,
          });
        case '/instant-work/candidate/feed':
          return _ok(o, claimed ? [] : [_gigJson()]);
        case '/instant-work/candidate/active-job':
          if (!claimed) return _ok(o, null);
          return _ok(o, _gigJson(status: completed ? 'COMPLETED' : 'ACCEPTED'));
        case '/instant-work/claim':
          claimed = true;
          return _ok(o, _gigJson(status: 'ACCEPTED'));
        case '/instant-work/jobs/g1/complete':
          completed = true;
          return _ok(o, _gigJson(status: 'COMPLETED'));
        case '/wallet/transactions':
          return _ok(o, {'transactions': []});
      }
      throw StateError('unexpected ${o.path}');
    });

    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Auth.new),
          instantMilegaProvider.overrideWith(_Located.new),
          apiClientProvider.overrideWithValue(f.client),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ActiveGigCard(),
                  SpotGigsSection(),
                  GigEarningsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('₹350 / hour'), findsOneWidget);
    expect(find.text('1.2 km away'), findsOneWidget);
    // The employer's phone is not shown before claiming
    expect(find.text('Call'), findsNothing);
    expect(find.text('₹0'), findsNWidgets(2)); // no gig pay yet

    await tester.tap(find.text('Claim gig'));
    await tester.pumpAndSettle();
    expect(find.textContaining('uses 1 of your 7 pass gigs'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Claim gig'));
    await tester.pumpAndSettle();

    final claim = f.sent.lastWhere((o) => o.path == '/instant-work/claim');
    expect(claim.data, {'job_id': 'g1'});
    expect(find.text('ACTIVE GIG'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);

    await tester.tap(find.text('Mark as complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mark complete'));
    await tester.pumpAndSettle();

    expect(
      f.sent.map((o) => o.path),
      contains('/instant-work/jobs/g1/complete'),
    );
    expect(find.text('Waiting for employer'), findsOneWidget);
    expect(find.text('Mark as complete'), findsNothing);
  });
}
