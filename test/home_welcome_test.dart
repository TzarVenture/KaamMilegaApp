import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/applications/models/application.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/home/presentation/widgets/home_welcome.dart';
import 'package:kaam_milega/features/interviews/models/interview.dart';
import 'package:kaam_milega/features/interviews/repositories/interview_repository.dart';
import 'package:kaam_milega/features/jobs/providers/jobs_provider.dart';
import 'package:kaam_milega/features/profile/models/profile_strength.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bare = UserProfile(id: 'u1', mobile: '9000000000', name: 'Riya Sharma');

const _complete = UserProfile(
  id: 'u1',
  mobile: '9000000000',
  name: 'Riya Sharma',
  headline: 'Electrician',
  city: 'Mumbai',
  about: 'Ten years of wiring work.',
  skills: ['Wiring', 'Panels', 'Safety'],
  education: [EducationItem(schoolName: 'ITI Mumbai')],
  experience: [ExperienceItem(title: 'Electrician', companyName: 'Acme')],
  profileImage: 'https://example.invalid/me.png',
  isEmailVerified: true,
);

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserProfile? user;

  @override
  AuthState build() => AuthState(isAuthenticated: user != null, user: user);
}

class _Jobs extends JobsNotifier {
  @override
  JobsState build() => const JobsState(savedJobIds: {'j1', 'j2'});
}

final _evening = DateTime(2026, 10, 7, 19);

InterviewItem _interview(
  String id,
  DateTime at, {
  String status = 'Scheduled',
}) => InterviewItem(
  id: id,
  applicationId: 'a$id',
  recruiterId: 'r1',
  candidateId: 'u1',
  scheduledAt: at,
  status: status,
  jobTitle: 'Electrician',
  companyName: 'Acme',
);

ApplicationItem _application(String id) => ApplicationItem(
  id: id,
  jobId: 'j$id',
  recruiterId: 'r1',
  candidateId: 'u1',
  status: 'applied',
  coverLetter: '',
  jobTitle: 'Electrician',
  companyName: 'Acme',
  cityName: 'Mumbai',
);

Future<List<String>> _pump(
  WidgetTester tester,
  Widget child, {
  UserProfile? user = _bare,
  List<Override> extra = const [],
}) async {
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: ListView(children: [child])),
      ),
      for (final path in ['/my-applications', '/interviews', '/saved-jobs'])
        GoRoute(
          path: path,
          builder: (_, _) {
            pushed.add(path);
            return Scaffold(body: Text('page $path'));
          },
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _Auth(user)),
        homeClockProvider.overrideWithValue(() => _evening),
        ...extra,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Good evening');
  });

  test('profile strength: score and next step (same as Profile)', () {
    final empty = ProfileStrength.of(_bare);
    expect(empty.percent, 0);
    expect(empty.next, ProfileStep.experience);
    expect(empty.missing, hasLength(7));

    final done = ProfileStrength.of(_complete);
    expect(done.percent, 100);
    expect(done.isComplete, isTrue);

    // A photo that does not load is not counted.
    final broken = ProfileStrength.of(
      _complete,
      failedPhotoUrl: 'https://example.invalid/me.png',
    );
    expect(broken.percent, 85);
    expect(broken.next, ProfileStep.photo);
  });

  test('upcoming interviews: ahead and not cancelled or done', () {
    final now = _evening;
    final list = [
      _interview('1', now.add(const Duration(days: 1))),
      _interview('2', now.subtract(const Duration(days: 1))),
      _interview('3', now.add(const Duration(days: 2)), status: 'Cancelled'),
    ];
    expect(upcomingInterviews(list, now), 1);
  });

  testWidgets('greeting: first name when signed in, plain for guests', (
    tester,
  ) async {
    await _pump(tester, const HomeGreeting());
    expect(find.text('Good evening, Riya'), findsOneWidget);
  });

  testWidgets('guest: no name', (tester) async {
    await _pump(tester, const HomeGreeting(), user: null);
    expect(find.text('Good evening'), findsOneWidget);
  });

  testWidgets('dashboard: real numbers; tap opens the list', (tester) async {
    final pushed = await _pump(
      tester,
      HomeDashboardCard(onOpenProfile: () {}),
      extra: [
        myApplicationsProvider.overrideWith(
          (ref) async => [
            _application('1'),
            _application('2'),
            _application('3'),
          ],
        ),
        myInterviewsProvider.overrideWith(
          (ref) async => [
            _interview('1', _evening.add(const Duration(days: 1))),
            _interview('2', _evening.subtract(const Duration(days: 1))),
          ],
        ),
        jobsProvider.overrideWith(_Jobs.new),
      ],
    );
    expect(find.bySemanticsLabel('Applied: 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Upcoming interviews: 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Saved jobs: 2'), findsOneWidget);

    await tester.tap(find.text('Interviews'));
    await tester.pumpAndSettle();
    expect(pushed, ['/interviews']);
  });

  testWidgets('dashboard: profile progress and next step; tap opens Profile', (
    tester,
  ) async {
    var opened = 0;
    await _pump(
      tester,
      HomeDashboardCard(onOpenProfile: () => opened++),
      extra: [
        myApplicationsProvider.overrideWith((ref) async => const []),
        myInterviewsProvider.overrideWith((ref) async => const []),
        jobsProvider.overrideWith(_Jobs.new),
      ],
    );
    expect(find.text('Profile 0% complete'), findsOneWidget);
    expect(find.text('Next: Add your work experience'), findsOneWidget);
    await tester.tap(find.text('Profile 0% complete'));
    expect(opened, 1);
  });

  testWidgets('dashboard: complete profile shows only the numbers', (
    tester,
  ) async {
    await _pump(
      tester,
      HomeDashboardCard(onOpenProfile: () {}),
      user: _complete,
      extra: [
        myApplicationsProvider.overrideWith((ref) async => const []),
        myInterviewsProvider.overrideWith((ref) async => const []),
        jobsProvider.overrideWith(_Jobs.new),
      ],
    );
    expect(find.text('Applied'), findsOneWidget);
    expect(find.textContaining('% complete'), findsNothing);
  });

  testWidgets('dashboard: a failed number shows a dash, not 0', (tester) async {
    await _pump(
      tester,
      HomeDashboardCard(onOpenProfile: () {}),
      extra: [
        myApplicationsProvider.overrideWith((ref) async => throw Exception()),
        myInterviewsProvider.overrideWith((ref) async => const []),
        jobsProvider.overrideWith(_Jobs.new),
      ],
    );
    expect(
      find.bySemanticsLabel('Applied: could not load. Opens the list.'),
      findsOneWidget,
    );
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('dashboard: nothing for guests', (tester) async {
    await _pump(tester, HomeDashboardCard(onOpenProfile: () {}), user: null);
    expect(find.text('Applied'), findsNothing);
  });
}
