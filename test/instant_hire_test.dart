import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/instant_work/models/nearby_professional.dart';
import 'package:kaam_milega/features/instant_work/models/spot_gig.dart';
import 'package:kaam_milega/features/instant_work/presentation/hire_request_screen.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/instant_hire_widgets.dart';
import 'package:kaam_milega/features/instant_work/providers/instant_hire_provider.dart';
import 'package:kaam_milega/features/instant_work/providers/instant_milega_provider.dart';
import 'package:kaam_milega/features/instant_work/repositories/instant_hire_repository.dart';
import 'package:kaam_milega/features/instant_work/repositories/nearby_professionals_repository.dart';
import 'package:kaam_milega/features/instant_work/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _here = DeviceLocation(latitude: 18.52, longitude: 73.85);

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9876543210', name: 'Rahul'),
  );
}

class _Location extends LocationService {
  @override
  Future<LocationResult> currentLocation() async => const LocationFound(_here);
}

/// Answers every request locally and records it.
class _Server {
  _Server(this.respond);

  final dynamic Function(RequestOptions o) respond;
  final List<RequestOptions> sent = [];

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          try {
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: respond(o)),
            );
          } on DioException catch (e) {
            h.reject(e);
          }
        },
      ),
    );
    return ApiClient(dio: dio);
  }
}

DioException _fail(RequestOptions o, int status, [String? error]) =>
    DioException(
      requestOptions: o,
      response: Response(
        requestOptions: o,
        statusCode: status,
        data: error == null ? null : {'error': error},
      ),
      type: DioExceptionType.badResponse,
    );

Map<String, dynamic> _job({
  String status = 'DISPATCHING',
  DateTime? expires,
  String candidate = '',
  String mobile = '',
}) => {
  'id': 'j1',
  'recruiter_id': 'me',
  'skill': 'Electrician',
  'address': 'Shop 4, MG Road',
  'pay_rate': 300,
  'rate_type': 'hourly',
  'duration_hours': 2,
  'required_workers': 1,
  'status': status,
  'candidate_name': candidate,
  'candidate_mobile': mobile,
  'expires_at': (expires ?? DateTime.now().add(const Duration(minutes: 2)))
      .toUtc()
      .toIso8601String(),
};

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// Reads the location like the Instant Milega screen, then shows [child].
class _Host extends ConsumerStatefulWidget {
  const _Host(this.child);
  final Widget child;

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
  Widget build(BuildContext context) => Scaffold(
    body: ListView(padding: const EdgeInsets.all(16), children: [widget.child]),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 't'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Hire repository', () {
    test('radar: real fields only, skill and radius sent', () async {
      final server = _Server(
        (o) => [
          {
            'id': 'w-doc',
            'user_id': 'u1',
            'name': 'Sunil',
            'avatar': '',
            'active_skill': 'Electrician',
            'hourly_rate': 250,
            'rating': 4.9, // server default for new workers: not shown
            'total_gigs': 12,
            'distance_meters': 1200,
            'distance_km': 1.2,
            'location': {
              'type': 'Point',
              'coordinates': [73.85, 18.52],
            },
            'is_masked': true,
          },
        ],
      );
      final list = await InstantHireRepository(server.client())
          .findWorkers(lat: 18.5, lng: 73.8, skill: 'Electrician', radiusKm: 5);

      final q = server.sent.single;
      expect(q.path, '/instant-work/recruiter/radar');
      expect(q.queryParameters, {
        'lat': 18.5,
        'lng': 73.8,
        'radius_km': 5.0,
        'skill': 'Electrician',
      });
      final w = list.single;
      expect(w.id, 'u1');
      expect(w.service, 'Electrician');
      expect(w.rating, isNull);
      expect(w.reviewCount, isNull);
      expect(w.priceLabel, '₹250 / hour');
      expect(w.distanceLabel, '1.2 km');
      expect(w.isAvailable, isTrue);
    });

    test('dispatch sends the form; one worker; active job parsed', () async {
      final server = _Server((o) {
        if (o.method == 'POST') return _job();
        return null; // no active job
      });
      final repo = InstantHireRepository(server.client());
      final gig = await repo.postRequest(
        const HireRequestDraft(
          skill: 'Plumbing',
          address: ' Flat 2, Lake Road ',
          lat: 18.5,
          lng: 73.8,
          payRate: 400,
          hourly: false,
          durationHours: 3,
          radiusKm: 10,
          notes: ' Bring tools ',
        ),
      );
      expect(gig.status, SpotGigStatus.dispatching);
      expect(server.sent.single.path, '/instant-work/dispatch');
      expect(server.sent.single.data, {
        'skill': 'Plumbing',
        'lat': 18.5,
        'lng': 73.8,
        'address': 'Flat 2, Lake Road',
        'radius_km': 10.0,
        'pay_rate': 400.0,
        'rate_type': 'flat',
        'duration_hours': 3,
        'required_workers': 1,
        'notes': 'Bring tools',
      });
      expect(await repo.getActiveRequest(), isNull);
    });

    test('guests: no radar request, sign-in asked', () {
      final server = _Server((o) => throw StateError('no request expected'));
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_Guest.new),
          apiClientProvider.overrideWithValue(server.client()),
        ],
      );
      addTearDown(container.dispose);
      expect(
        () => container
            .read(nearbyProfessionalsRepositoryProvider)
            .findNearby(
              const NearbyProfessionalsQuery(location: GeoPoint(18.5, 73.8)),
            ),
        throwsA(isA<NearbyProfessionalsSignInRequired>()),
      );
      expect(server.sent, isEmpty);
    });
  });

  testWidgets('Hire | Work switch changes only what is shown', (tester) async {
    final server = _Server((o) => throw StateError('no request expected'));
    await _pump(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              const InstantModeToggle(),
              Text('mode ${ref.watch(instantModeProvider).name}'),
            ],
          ),
        ),
      ),
      [
        authProvider.overrideWith(_SignedIn.new),
        apiClientProvider.overrideWithValue(server.client()),
      ],
    );

    expect(find.text('mode work'), findsOneWidget);
    expect(find.text('Work: find quick paid gigs near you.'), findsOneWidget);
    await tester.tap(find.text('Hire'));
    await tester.pumpAndSettle();
    expect(find.text('mode hire'), findsOneWidget);
    expect(
      find.text('Hire: get a worker near you for a quick job.'),
      findsOneWidget,
    );
    expect(server.sent, isEmpty); // switching sends nothing
  });

  group('Hire section', () {
    testWidgets('guest: sign in to hire; no hiring request', (tester) async {
      final server = _Server((o) => throw StateError('no request expected'));
      await _pump(tester, const _Host(InstantHireSection()), [
        authProvider.overrideWith(_Guest.new),
        apiClientProvider.overrideWithValue(server.client()),
        locationServiceProvider.overrideWithValue(_Location()),
      ]);

      expect(find.text('Sign in to hire'), findsOneWidget);
      expect(find.text('Sign in to see workers near you'), findsOneWidget);
      expect(server.sent, isEmpty);

      await tester.tap(find.text('Sign in to hire'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsOneWidget);
    });

    testWidgets('signed in: workers near you and my open request', (
      tester,
    ) async {
      final server = _Server((o) {
        if (o.path.endsWith('/recruiter/radar')) {
          return [
            {
              'user_id': 'u1',
              'name': 'Sunil',
              'active_skill': 'Electrician',
              'hourly_rate': 250,
              'distance_km': 0.8,
            },
          ];
        }
        if (o.path.endsWith('/recruiter/active-job')) return _job();
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      await _pump(tester, const _Host(InstantHireSection()), [
        authProvider.overrideWith(_SignedIn.new),
        apiClientProvider.overrideWithValue(server.client()),
        locationServiceProvider.overrideWithValue(_Location()),
      ]);

      expect(find.text('Post a quick job'), findsOneWidget);
      expect(find.text('Looking for a worker'), findsOneWidget);
      expect(find.text('Sunil'), findsOneWidget);
      expect(find.text('800 m'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });
  });

  group('My request status', () {
    Future<void> pumpCard(WidgetTester tester, dynamic job) async {
      final server = _Server((o) {
        if (job is int) throw _fail(o, job);
        return job;
      });
      await _pump(tester, const Scaffold(body: HireActiveRequestCard()), [
        authProvider.overrideWith(_SignedIn.new),
        apiClientProvider.overrideWithValue(server.client()),
      ]);
    }

    testWidgets('worker accepted: name and Call', (tester) async {
      await pumpCard(
        tester,
        _job(status: 'ACCEPTED', candidate: 'Sunil', mobile: '9000000000'),
      );
      expect(find.text('Sunil accepted your job'), findsOneWidget);
      expect(find.text('Call worker'), findsOneWidget);
    });

    testWidgets('window passed: no worker accepted in time', (tester) async {
      await pumpCard(
        tester,
        _job(expires: DateTime.now().subtract(const Duration(minutes: 1))),
      );
      expect(find.text('No worker accepted in time'), findsOneWidget);
    });

    testWidgets('worker marked done: pay directly (no in-app pay)', (
      tester,
    ) async {
      await pumpCard(tester, _job(status: 'COMPLETED', candidate: 'Sunil'));
      expect(find.text('The worker marked the job done'), findsOneWidget);
      expect(find.textContaining('not available yet'), findsOneWidget);
    });

    testWidgets('server error: message with Retry, not "no request"', (
      tester,
    ) async {
      await pumpCard(tester, 500);
      expect(find.text('Could not load your request'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Post a quick job', () {
    Future<_Server> pumpForm(
      WidgetTester tester,
      dynamic Function(RequestOptions o) respond,
    ) async {
      final server = _Server(respond);
      await _pump(tester, const HireRequestScreen(location: _here), [
        authProvider.overrideWith(_SignedIn.new),
        apiClientProvider.overrideWithValue(server.client()),
      ]);
      return server;
    }

    testWidgets('empty form: errors, nothing sent', (tester) async {
      final server = await pumpForm(
        tester,
        (o) => throw StateError('no request expected'),
      );
      await tester.tap(find.text('Send to workers near me'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the kind of worker you need'), findsOneWidget);
      expect(find.text('Please enter the address'), findsOneWidget);
      expect(find.text('Please enter the pay'), findsOneWidget);
      expect(server.sent, isEmpty);
    });

    testWidgets('filled form: one request with the location', (tester) async {
      final server = await pumpForm(tester, (o) => _job());
      await tester.tap(find.text('Electrician'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Shop 4, MG Road');
      await tester.enterText(fields.at(1), '300');
      await tester.pump();
      expect(find.text('About ₹600 for 2 hours'), findsOneWidget);

      await tester.tap(find.text('Send to workers near me'));
      await tester.tap(
        find.text('Send to workers near me'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final posts = server.sent.where((o) => o.method == 'POST');
      expect(posts, hasLength(1));
      final body = posts.single.data as Map<String, dynamic>;
      expect(body['skill'], 'Electrician');
      expect(body['lat'], 18.52);
      expect(body['lng'], 73.85);
      expect(body['pay_rate'], 300.0);
      expect(body['rate_type'], 'hourly');
      expect(body['radius_km'], 5.0);
      expect(find.text('Request sent to workers near you.'), findsOneWidget);
    });

    testWidgets('server refuses: its message, form stays open', (tester) async {
      await pumpForm(
        tester,
        (o) => throw _fail(o, 400, 'invalid spot job payload'),
      );
      await tester.tap(find.text('Plumbing'));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Flat 2');
      await tester.enterText(fields.at(1), '500');
      await tester.tap(find.text('Send to workers near me'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid spot job payload'), findsOneWidget);
      expect(find.text('Post a quick job'), findsOneWidget); // still open
    });
  });
}
