import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:kaam_milega/features/jobs/presentation/widgets/people_like_you_card.dart';
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
  requirements: ['Dart', 'Firebase'],
  weOffer: [],
  gender: '',
  education: '',
  experienceMin: 0,
  experienceMax: 0,
);

const _plain = UserProfile(id: 'u1', mobile: '', name: 'Plain Person');
const _sameCity = UserProfile(
  id: 'u2',
  mobile: '',
  name: 'City Match',
  city: 'mumbai',
);
const _role = UserProfile(
  id: 'u3',
  mobile: '',
  name: 'Role Match',
  headline: 'Senior Flutter Engineer',
);
const _skills = UserProfile(
  id: 'u4',
  mobile: '',
  name: 'Skill Match',
  headline: 'Mobile developer',
  city: 'Pune',
  skills: ['dart', 'Go'],
);

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

/// No real network: connection status is "none", anything else is 404.
ApiClient _fakeClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) {
        if (o.path.startsWith('/network/status/')) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: {'status': ''},
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: o,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(requestOptions: o, statusCode: 404),
          ),
        );
      },
    ),
  );
  return ApiClient(dio: dio);
}

Future<void> _pump(
  WidgetTester tester,
  Future<List<UserProfile>> Function() load, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_Guest.new),
        apiClientProvider.overrideWithValue(_fakeClient()),
        communityUsersProvider.overrideWith((ref) => load()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: PeopleLikeYouCard(job: _job),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('rankPeopleLikeYou', () {
    test('skills first, then role, then city; ties keep server order', () {
      final ranked = rankPeopleLikeYou([
        _plain,
        _sameCity,
        _role,
        _skills,
      ], _job);
      expect(ranked.map((p) => p.user.id), ['u4', 'u3', 'u2']);
      expect(ranked.map((p) => p.match), [
        'Similar skills',
        'Similar role',
        'Same city',
      ]);
    });

    test('no match: server order, no reason shown', () {
      final ranked = rankPeopleLikeYou([_plain, _plain], _job, count: 5);
      expect(ranked, hasLength(2));
      expect(ranked.first.match, isEmpty);
    });
  });

  group('People Like You card', () {
    testWidgets('shows the best three with Chat and Connect on a phone', (
      tester,
    ) async {
      await _pump(tester, () async => [_plain, _sameCity, _role, _skills]);
      expect(tester.takeException(), isNull);
      expect(find.text('Skill Match'), findsOneWidget);
      expect(find.text('Role Match'), findsOneWidget);
      expect(find.text('City Match'), findsOneWidget);
      expect(find.text('Plain Person'), findsNothing); // only three shown
      expect(find.text('MOBILE DEVELOPER'), findsOneWidget);
      expect(find.text('Similar skills'), findsOneWidget);
      expect(find.text('Chat'), findsNWidgets(3));
      expect(find.text('SHOW ALL MEMBERS'), findsOneWidget);
    });

    testWidgets('no members: the card is hidden', (tester) async {
      await _pump(tester, () async => []);
      expect(find.textContaining('Like You'), findsNothing);
    });

    testWidgets('server error: message with Retry, not "no people"', (
      tester,
    ) async {
      await _pump(tester, () async => throw Exception('500'));
      expect(find.text('Could not load people right now.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('guest tapping Chat is asked to log in', (tester) async {
      await _pump(tester, () async => [_skills]);
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Login Required'), findsOneWidget);
    });
  });
}
