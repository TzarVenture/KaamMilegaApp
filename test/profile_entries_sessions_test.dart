import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';
import 'package:kaam_milega/features/experts/models/booking.dart';
import 'package:kaam_milega/features/experts/presentation/my_sessions_screen.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiClient answered locally; records every request.
({ApiClient client, List<RequestOptions> sent}) _fake(
  Response<dynamic> Function(RequestOptions o) respond,
) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        try {
          handler.resolve(respond(options));
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

Map<String, dynamic> _user({List<String> skills = const []}) => {
  'id': 'u1',
  'mobile': '9876543210',
  'is_registered': true,
  'skills': skills,
};

/// Skill delete answered with a chosen profile (no network).
class _SkillRepo extends AuthRepository {
  _SkillRepo(this.skillsAfter) : super(ApiClient());
  final List<String> skillsAfter;

  @override
  Future<UserProfile> deleteSkill(String skillName) async =>
      UserProfile.fromJson(_user(skills: skillsAfter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Education / experience / skills requests', () {
    test(
      'edit education: PUT /user/education/:id with the entry fields',
      () async {
        final f = _fake((o) => _ok(o, _user()));
        await AuthRepository(f.client).updateEducation(
          id: 'edu1',
          schoolName: ' IIT Delhi ',
          degree: 'B.Tech',
          fieldOfStudy: 'CS',
          startDate: '2020-08',
          endDate: '2024-05',
        );
        final req = f.sent.single;
        expect(req.method, 'PUT');
        expect(req.path, '/user/education/edu1');
        expect(req.data, {
          'school_name': 'IIT Delhi',
          'degree': 'B.Tech',
          'field_of_study': 'CS',
          'start_date': '2020-08',
          'end_date': '2024-05',
          'grade': '',
          'description': '',
        });
      },
    );

    test(
      'edit experience keeps its skills (backend replaces the entry)',
      () async {
        final f = _fake((o) => _ok(o, _user()));
        await AuthRepository(f.client).updateExperience(
          id: 'exp1',
          title: 'Driver',
          companyName: 'Acme',
          employmentType: 'Full-time',
          location: 'Pune',
          startDate: '2022-01',
          endDate: '',
          skills: const ['Driving'],
        );
        expect(f.sent.single.method, 'PUT');
        expect(f.sent.single.path, '/user/experience/exp1');
        expect((f.sent.single.data as Map)['skills'], ['Driving']);
      },
    );

    test('delete education / experience use DELETE with the id', () async {
      final f = _fake((o) => _ok(o, _user()));
      final repo = AuthRepository(f.client);
      await repo.deleteEducation('edu1');
      await repo.deleteExperience('exp1');
      expect(f.sent.map((r) => '${r.method} ${r.path}'), [
        'DELETE /user/education/edu1',
        'DELETE /user/experience/exp1',
      ]);
    });

    test('remove skill URL-encodes the name like the website', () async {
      final f = _fake((o) => _ok(o, _user()));
      await AuthRepository(f.client).deleteSkill('Driver / Chauffeur');
      expect(f.sent.single.method, 'DELETE');
      expect(f.sent.single.path, '/user/skill/Driver%20%2F%20Chauffeur');
    });

    test('an entry without an id is not sent to the server', () async {
      final f = _fake((o) => _ok(o, _user()));
      await expectLater(
        AuthRepository(f.client).deleteEducation(''),
        throwsA(isA<AppValidationException>()),
      );
      expect(f.sent, isEmpty);
    });

    test(
      'a response without a profile is an error (profile not wiped)',
      () async {
        final f = _fake((o) => _ok(o, {'message': 'ok'}));
        await expectLater(
          AuthRepository(f.client).deleteExperience('exp1'),
          throwsA(isA<AppValidationException>()),
        );
      },
    );
  });

  group('removeSkill uses the profile returned by the server', () {
    Future<(bool, AuthState)> run(List<String> skillsAfter) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SkillRepo(skillsAfter)),
        ],
      );
      addTearDown(container.dispose);
      final ok = await container
          .read(authProvider.notifier)
          .removeSkill('Driver / Chauffeur');
      return (ok, container.read(authProvider));
    }

    test('skill gone from the returned profile: success', () async {
      final (ok, state) = await run(const ['Security Guard']);
      expect(ok, isTrue);
      expect(state.user?.skills, ['Security Guard']);
    });

    test(
      'skill still in the returned profile: reported as not removed',
      () async {
        final (ok, state) = await run(const ['Driver / Chauffeur']);
        expect(ok, isFalse);
        expect(state.error, contains('Could not remove'));
      },
    );
  });

  group('My sessions', () {
    test('BookingItem reads the backend Booking fields', () {
      final b = BookingItem.fromJson({
        'id': 'b1',
        'mentorship_id': 'm1',
        'expert_id': 'e1',
        'scheduled_at': '2026-10-01T10:30:00Z',
        'status': 'confirmed',
        'amount': 499,
        'payment_status': 'paid',
        'payment_method': 'razorpay',
        'meeting_link': 'https://meet.example.com/abc',
        'mentorship_title': 'Resume Review',
        'expert_name': 'Asha Rao',
      });
      expect(b.mentorshipTitle, 'Resume Review');
      expect(b.expertName, 'Asha Rao');
      expect(b.amount, 499);
      expect(b.scheduledAt, isNotNull);
      expect(b.canJoin, isTrue);
      expect(BookingItem.fromJson({'status': 'pending'}).canJoin, isFalse);
    });

    test(
      'GET /mentorships/bookings/my: null means no sessions; newest first',
      () async {
        final empty = _fake((o) => _ok(o, null));
        expect(await ExpertRepository(empty.client).getMyBookings(), isEmpty);
        expect(empty.sent.single.path, '/mentorships/bookings/my');

        final two = _fake(
          (o) => _ok(o, [
            {'id': 'old', 'scheduled_at': '2026-01-01T10:00:00Z'},
            {'id': 'new', 'scheduled_at': '2026-09-01T10:00:00Z'},
          ]),
        );
        final list = await ExpertRepository(two.client).getMyBookings();
        expect(list.map((b) => b.id), ['new', 'old']);
      },
    );

    Widget screen(List<BookingItem> Function() load) => ProviderScope(
      overrides: [myBookingsProvider.overrideWith((ref) async => load())],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MySessionsScreen(),
      ),
    );

    testWidgets('shows booked sessions with a Join button when confirmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        screen(
          () => [
            BookingItem.fromJson({
              'id': 'b1',
              'status': 'confirmed',
              'amount': 499,
              'payment_status': 'paid',
              'scheduled_at': '2026-10-01T10:30:00Z',
              'meeting_link': 'https://meet.example.com/abc',
              'mentorship_title': 'Resume Review',
              'expert_name': 'Asha Rao',
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resume Review'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Join Meeting'), findsOneWidget);
    });

    testWidgets('no sessions: empty state (not an error)', (tester) async {
      await tester.pumpWidget(screen(() => const []));
      await tester.pumpAndSettle();
      expect(find.text('No sessions booked yet'), findsOneWidget);
    });

    testWidgets('failure: error with Retry', (tester) async {
      await tester.pumpWidget(screen(() => throw const AppServerException()));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Load Data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
