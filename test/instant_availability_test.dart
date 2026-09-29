import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/instant_work/models/instant_candidate.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/instant_availability_card.dart';
import 'package:kaam_milega/features/instant_work/repositories/instant_candidate_repository.dart';
import 'package:kaam_milega/features/instant_work/services/location_service.dart';
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

Map<String, dynamic> _status({bool pass = false, bool online = false}) => {
  'is_free_now': online,
  'active_skill': '',
  'hourly_rate': 0,
  'quota_remaining': pass ? 7 : 0,
  'has_active_pass': pass,
  'current_location': {
    'type': 'Point',
    'coordinates': [72.8777, 19.076],
  },
};

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210'),
  );
}

class _Wallet extends WalletNotifier {
  @override
  WalletState build() =>
      const WalletState(summary: WalletSummary(mainBalance: 150));

  @override
  Future<void> loadWallet() async {}
}

class _Location extends LocationService {
  const _Location();

  @override
  Future<LocationResult> currentLocation() async =>
      const LocationFound(DeviceLocation(latitude: 18.52, longitude: 73.85));
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: InstantAvailabilityCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _overrides(ApiClient client) => [
  authProvider.overrideWith(_Auth.new),
  walletProvider.overrideWith(_Wallet.new),
  locationServiceProvider.overrideWithValue(const _Location()),
  instantCandidateRepositoryProvider.overrideWithValue(
    InstantCandidateRepository(client),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test('status: GeoJSON is [longitude, latitude]', () {
    final s = InstantCandidateStatus.fromJson(_status(pass: true));
    expect(s.lastLocation?.lat, 19.076);
    expect(s.lastLocation?.lng, 72.8777);
    expect(s.canGoOnline, isTrue);
    expect(InstantPassTerms.perGigLabel, '₹9.90');
  });

  test('HTTP 402 requires_pass becomes InstantPassRequired', () async {
    final f = _fakeClient(
      (o) => throw DioException(
        requestOptions: o,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: o,
          statusCode: 402,
          data: {
            'error': 'an active InstantPass (₹99) is required',
            'requires_pass': true,
          },
        ),
      ),
    );
    expect(
      () => InstantCandidateRepository(f.client).setAvailability(
        online: true,
        skill: 'All',
        hourlyRate: 0,
        lat: 1,
        lng: 2,
      ),
      throwsA(isA<InstantPassRequired>()),
    );
  });

  testWidgets('no pass: offline, Activate Pass; switch opens the pass sheet', (
    tester,
  ) async {
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') return _ok(o, _status());
      if (o.path == '/instant-work/pass/pay-wallet') {
        return _ok(o, {
          'pass': {'quota_remaining': 10},
          'message': 'InstantPass activated successfully from wallet balance',
        });
      }
      throw StateError('unexpected ${o.path}');
    });
    await _pump(tester, _overrides(f.client));

    expect(find.text('CURRENTLY OFFLINE'), findsOneWidget);
    expect(find.text('Pass inactive (0 gigs)'), findsOneWidget);
    expect(find.text('Activate Pass (₹99)'), findsOneWidget);

    // Going online without a pass opens the pass sheet (no request sent)
    await tester.tap(find.bySemanticsLabel('Online for InstantMilega'));
    await tester.pumpAndSettle();
    expect(find.text('InstantMilega™ Candidate Pass'), findsOneWidget);
    expect(find.text('Balance: ₹150'), findsOneWidget);
    expect(find.text('Temporarily unavailable'), findsOneWidget);
    expect(
      f.sent.where((o) => o.path == '/instant-work/availability'),
      isEmpty,
    );

    await tester.tap(find.text('Pay ₹99 from KaamMilega Wallet'));
    await tester.pumpAndSettle();
    expect(
      f.sent.map((o) => o.path),
      contains('/instant-work/pass/pay-wallet'),
    );
    expect(find.textContaining('You can now go online'), findsOneWidget);
  });

  testWidgets('with a pass: goes online with the phone location', (
    tester,
  ) async {
    var online = false;
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') {
        return _ok(o, _status(pass: true, online: online));
      }
      if (o.path == '/instant-work/availability') {
        online = (o.data as Map)['is_free_now'] == true;
        return _ok(o, {'is_free_now': online});
      }
      throw StateError('unexpected ${o.path}');
    });
    await _pump(tester, _overrides(f.client));

    expect(
      find.textContaining('InstantPass: 7 of 10 gigs left'),
      findsOneWidget,
    );
    expect(find.text('Activate Pass (₹99)'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Online for InstantMilega'));
    await tester.pumpAndSettle();

    final sent = f.sent.lastWhere(
      (o) => o.path == '/instant-work/availability',
    );
    expect(sent.data, {
      'is_free_now': true,
      'skill': 'All',
      'hourly_rate': 0.0,
      'lat': 18.52,
      'lng': 73.85,
    });
    expect(find.text('ONLINE NOW'), findsOneWidget);
  });
}
