import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/company/providers/company_provider.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/presentation/job_links.dart';
import 'package:kaam_milega/features/jobs/presentation/job_people_screen.dart';
import 'package:kaam_milega/features/jobs/presentation/related_jobs_screen.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/job_card.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/job_recruiter_card.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _job = Job(
  id: 'j1',
  recruiterId: 'r1',
  title: 'Flutter Developer',
  description: 'Build the app',
  company: 'Acme',
  cityId: 'c1',
  cityName: 'Mumbai',
  location: '',
  salaryMin: 0,
  salaryMax: 0,
  jobType: 'Full-time',
  status: 'open',
  requirements: ['Dart'],
  weOffer: [],
  gender: '',
  education: '',
  experienceMin: 0,
  experienceMax: 1,
);

const _me = UserProfile(id: 'me', mobile: '', name: 'Me', isRegistered: true);

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true, user: _me);
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

/// ApiClient whose requests are recorded and answered by [respond].
({ApiClient client, List<RequestOptions> sent}) _client(
  dynamic Function(RequestOptions o) respond,
) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, h) {
        sent.add(o);
        h.resolve(
          Response<dynamic>(
            requestOptions: o,
            statusCode: 200,
            data: respond(o),
          ),
        );
      },
    ),
  );
  return (client: ApiClient(dio: dio), sent: sent);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test('experts: shared skills first, then role words, then city', () {
    const plain = UserProfile(id: 'e1', mobile: '', name: 'Plain');
    const city = UserProfile(id: 'e2', mobile: '', name: 'C', city: 'Mumbai');
    const role = UserProfile(
      id: 'e3',
      mobile: '',
      name: 'R',
      headline: 'Flutter mentor',
    );
    const skill = UserProfile(
      id: 'e4',
      mobile: '',
      name: 'S',
      skills: ['dart'],
    );
    final ranked = rankExpertsForJob([plain, city, role, skill], _job);
    expect(ranked.map((u) => u.id), ['e4', 'e3', 'e2', 'e1']);
  });

  group('job card chips', () {
    Future<List<JobCardLink>> pumpCard(
      WidgetTester tester, {
      required bool linked,
    }) async {
      _phone(tester);
      final taps = <JobCardLink>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JobCard(
              job: _job,
              isVerifiedEmployer: true,
              onTap: () {},
              onApply: () {},
              onChat: () {},
              onCall: () {},
              onLinkTap: linked ? taps.add : null,
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('each chip opens its own page', (tester) async {
      final taps = await pumpCard(tester, linked: true);
      await tester.tap(find.text('Full-time'));
      await tester.tap(find.text('0-1 Yrs'));
      await tester.tap(find.text('1 opening'));
      await tester.tap(find.text('KM Verified Employer'));
      expect(taps, [
        JobCardLink.jobType,
        JobCardLink.experience,
        JobCardLink.openings,
        JobCardLink.verifiedEmployer,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a handler the chips are plain', (tester) async {
      final taps = await pumpCard(tester, linked: false);
      await tester.tap(find.text('Full-time'), warnIfMissed: false);
      expect(taps, isEmpty);
      expect(find.byType(InkWell), findsWidgets); // card itself
    });
  });

  testWidgets('Full-time jobs page asks the server for that job type', (
    tester,
  ) async {
    _phone(tester);
    final api = _client(
      (o) => {
        'jobs': [
          {'id': 'a', 'title': 'Cashier', 'job_type': 'Full-time'},
          {'id': 'b', 'title': 'Packer', 'job_type': 'Full-time'},
        ],
        'total': 2,
        'page': 1,
        'limit': 10,
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Guest.new),
          apiClientProvider.overrideWithValue(api.client),
          verifiedEmployerIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: const MaterialApp(home: RelatedJobsScreen(jobType: 'Full-time')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Full-time jobs'), findsOneWidget);
    expect(find.text('2 open jobs'), findsOneWidget);
    expect(find.text('Cashier'), findsOneWidget);
    expect(
      api.sent.any(
        (o) =>
            o.path.endsWith('/jobs') &&
            o.queryParameters['job_types'] == 'Full-time',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('"2-5 Yrs" page asks for jobs that overlap 2 to 5 years', (
    tester,
  ) async {
    _phone(tester);
    final api = _client(
      (o) => {
        'jobs': [
          {
            'id': 'a',
            'title': 'Flutter developer',
            'job_type': 'Full-time',
            'experience_min': 2,
            'experience_max': 5,
          },
        ],
        'total': 1,
        'page': 1,
        'limit': 10,
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Guest.new),
          apiClientProvider.overrideWithValue(api.client),
          verifiedEmployerIdsProvider.overrideWith((ref) async => <String>{}),
        ],
        child: const MaterialApp(
          home: RelatedJobsScreen(
            minExperience: 2,
            maxExperience: 5,
            experienceLabel: '2-5 Yrs',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jobs for 2-5 Yrs'), findsOneWidget);
    final q = api.sent.firstWhere((o) => o.path.endsWith('/jobs'));
    // Job's max >= 2 and job's min <= 5: a 0-1 year job is not listed.
    expect(q.queryParameters['experience_min'], 2);
    expect(q.queryParameters['experience_max'], 5);
    expect(q.queryParameters.containsKey('job_types'), isFalse);
  });

  group('recruiter card', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool signedIn,
      Future<UserProfile> Function()? load,
    }) async {
      _phone(tester);
      if (signedIn) await LocalStorage.saveToken('t');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(
                child: JobRecruiterCard(job: _job, onMessage: () {}),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(() => signedIn ? _SignedIn() : _Guest()),
            verifiedEmployerIdsProvider.overrideWith((ref) async => {'r1'}),
            if (load != null)
              memberProfileProvider('r1').overrideWith((ref) => load()),
            connectionStatusProvider('r1').overrideWith((ref) async => ''),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('signed in: real recruiter with Message and Connect', (
      tester,
    ) async {
      await pump(
        tester,
        signedIn: true,
        load: () async => const UserProfile(
          id: 'r1',
          mobile: '',
          name: 'Riya Recruiter',
          headline: 'Talent Lead at Acme',
        ),
      );
      expect(find.text('Meet the recruiter'), findsOneWidget);
      expect(find.text('Riya Recruiter'), findsOneWidget);
      expect(find.text('Talent Lead at Acme'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text('View Acme'), findsOneWidget);
    });

    testWidgets('guest: no profile request, asked to log in', (tester) async {
      await pump(tester, signedIn: false);
      expect(find.text('Acme recruiter'), findsOneWidget);
      await tester.tap(find.text('Log in to connect'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsOneWidget);
    });

    testWidgets('private profile (403) says so; Message still offered', (
      tester,
    ) async {
      await pump(
        tester,
        signedIn: true,
        load: () async => throw const AppAuthException('Private', 403),
      );
      expect(find.text("The recruiter's profile is private."), findsOneWidget);
      expect(find.text('Message recruiter'), findsOneWidget);
    });
  });

  testWidgets('people like you page: ranked members, applicants private', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Guest.new),
          networkSuggestionsProvider.overrideWith(
            (ref) async => const [
              UserProfile(id: 'u1', mobile: '', name: 'Plain Person'),
              UserProfile(
                id: 'u2',
                mobile: '',
                name: 'Skill Match',
                skills: ['dart'],
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: JobPeopleScreen(jobId: 'j1', initialJob: _job),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('People like you'), findsOneWidget);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.textContaining('Applicants stay private'), findsOneWidget);
    expect(find.text('1 with a similar profile'), findsOneWidget);
    // Best match first.
    final skill = tester.getTopLeft(find.text('Skill Match')).dy;
    final plain = tester.getTopLeft(find.text('Plain Person')).dy;
    expect(skill, lessThan(plain));
    expect(tester.takeException(), isNull);
  });
}
