import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/auth_guard.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/instant_work/models/nearby_professional.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/instant_location_bar.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/nearby_professionals_section.dart';
import 'package:kaam_milega/features/instant_work/providers/instant_milega_provider.dart';
import 'package:kaam_milega/features/instant_work/repositories/nearby_professionals_repository.dart';
import 'package:kaam_milega/features/instant_work/services/location_service.dart';

const _here = DeviceLocation(
  latitude: 18.5204,
  longitude: 73.8567,
  accuracyMeters: 25,
);

/// Device location answered by the test.
class _FakeLocation extends LocationService {
  _FakeLocation(this.answer);

  /// Result for each call (the last one repeats).
  final List<Future<LocationResult> Function()> answer;
  int calls = 0;
  bool openedAppSettings = false;
  bool openedLocationSettings = false;

  @override
  Future<LocationResult> currentLocation() {
    final i = calls < answer.length ? calls : answer.length - 1;
    calls++;
    return answer[i]();
  }

  @override
  Future<bool> openAppSettings() async => openedAppSettings = true;

  @override
  Future<bool> openLocationSettings() async => openedLocationSettings = true;
}

Future<LocationResult> _found() async => const LocationFound(_here);
Future<LocationResult> Function() _failed(LocationFailure f) =>
    () async => LocationFailed(f);

/// Test-only repository (fixtures live only in this test file).
class _Repo implements NearbyProfessionalsRepository {
  _Repo(this.answer);
  final Future<List<NearbyProfessional>> Function() answer;
  final queries = <NearbyProfessionalsQuery>[];

  @override
  Future<List<NearbyProfessional>> findNearby(NearbyProfessionalsQuery q) {
    queries.add(q);
    return answer();
  }
}

/// Opens the location the way InstantWorkScreen does (after first frame).
class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(instantMilegaProvider.notifier).locate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [InstantLocationBar(), NearbyProfessionalsSection()],
      ),
    );
  }
}

Widget _app(LocationService location, NearbyProfessionalsRepository repo) {
  return ProviderScope(
    overrides: [
      locationServiceProvider.overrideWithValue(location),
      nearbyProfessionalsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: const _Host()),
  );
}

void main() {
  test('guests and signed-in users can open Instant Milega', () {
    expect(
      AuthGuard.redirect(
        const AuthState(isGuest: true),
        Uri.parse('/instant-work'),
      ),
      isNull,
    );
  });

  test('model shows only the values it has (no invented defaults)', () {
    const p = NearbyProfessional(
      id: 'p1',
      name: 'Test Name',
      service: 'Electrician',
      location: GeoPoint(18.5, 73.8),
    );
    expect(p.distanceLabel, isNull);
    expect(p.priceLabel, isNull);
    expect(p.rating, isNull);
    expect(p.isAvailable, isNull);

    const q = NearbyProfessional(
      id: 'p2',
      name: 'Test Name',
      service: 'Plumbing',
      location: GeoPoint(18.5, 73.8),
      distanceKm: 0.85,
      price: 300,
      priceUnit: 'hour',
    );
    expect(q.distanceLabel, '850 m');
    expect(q.priceLabel, '₹300 / hour');
    expect(
      const NearbyProfessional(
        id: 'p3',
        name: 'N',
        service: 'S',
        location: GeoPoint(0, 0),
        distanceKm: 2.46,
      ).distanceLabel,
      '2.5 km',
    );
  });

  test('pending repository makes no request and returns no data', () async {
    await expectLater(
      const PendingNearbyProfessionalsRepository().findNearby(
        const NearbyProfessionalsQuery(location: GeoPoint(18.5, 73.8)),
      ),
      throwsA(isA<NearbyProfessionalsNotAvailable>()),
    );
  });

  testWidgets('while locating: loading state', (tester) async {
    final pending = Completer<LocationResult>();
    final location = _FakeLocation([() => pending.future]);
    await tester.pumpWidget(_app(location, _Repo(() async => const [])));
    await tester.pump();
    await tester.pump();

    expect(location.calls, 1);
    expect(find.text('Finding your location…'), findsOneWidget);
  });

  testWidgets('location found: shown with accuracy; backend pending', (
    tester,
  ) async {
    final location = _FakeLocation([_found]);
    await tester.pumpWidget(
      _app(location, const PendingNearbyProfessionalsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Your current location'), findsOneWidget);
    expect(find.textContaining('about 25 m'), findsOneWidget);
    expect(
      find.text(
        'Nearby professionals will appear here once services are '
        'available.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ProfessionalCard), findsNothing);

    // "Update location" reads the location again.
    await tester.tap(find.byTooltip('Update location'));
    await tester.pumpAndSettle();
    expect(location.calls, 2);
  });

  testWidgets('permission denied: explained, and can be asked again', (
    tester,
  ) async {
    final location = _FakeLocation([_failed(LocationFailure.permissionDenied)]);
    await tester.pumpWidget(_app(location, _Repo(() async => const [])));
    await tester.pumpAndSettle();

    expect(find.text('Location permission is off'), findsOneWidget);
    expect(
      find.text('Turn on location to see who is near you'),
      findsOneWidget,
    );

    await tester.tap(find.text('Allow location'));
    await tester.pumpAndSettle();
    expect(location.calls, 2);
  });

  testWidgets('permission blocked: opens app settings', (tester) async {
    final location = _FakeLocation([
      _failed(LocationFailure.permissionDeniedForever),
    ]);
    await tester.pumpWidget(_app(location, _Repo(() async => const [])));
    await tester.pumpAndSettle();

    expect(find.text('Location is blocked for KaamMilega'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(location.openedAppSettings, isTrue);
  });

  testWidgets('location services off: opens location settings', (tester) async {
    final location = _FakeLocation([_failed(LocationFailure.serviceDisabled)]);
    await tester.pumpWidget(_app(location, _Repo(() async => const [])));
    await tester.pumpAndSettle();

    expect(find.text('Location services are turned off'), findsOneWidget);
    await tester.tap(find.text('Turn on location'));
    await tester.pumpAndSettle();
    expect(location.openedLocationSettings, isTrue);
  });

  testWidgets('location unavailable: Retry reads the location again', (
    tester,
  ) async {
    final location = _FakeLocation([
      _failed(LocationFailure.unavailable),
      _found,
    ]);
    await tester.pumpWidget(
      _app(location, const PendingNearbyProfessionalsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t get your location'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(location.calls, 2);
    expect(find.textContaining('Your current location'), findsOneWidget);
  });

  testWidgets('a future API with no results: "no professionals nearby"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeLocation([_found]), _Repo(() async => const [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('No professionals nearby right now'), findsOneWidget);
  });

  testWidgets('a future API error is shown as an error with Retry', (
    tester,
  ) async {
    final repo = _Repo(() async => throw const AppServerException());
    await tester.pumpWidget(_app(_FakeLocation([_found]), repo));
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t load nearby professionals'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.queries, hasLength(2));
  });

  testWidgets('results render as cards; category is sent', (tester) async {
    // Test fixture only (never used by the app).
    const fixture = NearbyProfessional(
      id: 'p1',
      name: 'Fixture Person',
      service: 'Electrician',
      location: GeoPoint(18.521, 73.857),
      distanceKm: 1.2,
    );
    final repo = _Repo(() async => const [fixture]);
    await tester.pumpWidget(_app(_FakeLocation([_found]), repo));
    await tester.pumpAndSettle();

    expect(find.byType(ProfessionalCard), findsOneWidget);
    expect(find.text('Fixture Person'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    // No actions are offered until booking / profiles exist.
    expect(find.text('Book Now'), findsNothing);
    expect(repo.queries.single.categoryId, isNull);
    expect(repo.queries.single.location, const GeoPoint(18.5204, 73.8567));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Electrician'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.categoryId, 'electrician');
  });
}
