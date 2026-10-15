import 'dart:typed_data';

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
import 'package:kaam_milega/features/events/presentation/create_event_screen.dart';
import 'package:kaam_milega/features/events/providers/create_event_provider.dart';
import 'package:kaam_milega/features/experts/models/expert_plan.dart';
import 'package:kaam_milega/features/experts/providers/expert_plan_provider.dart';
import 'package:kaam_milega/features/notifications/providers/notification_provider.dart';
import 'package:kaam_milega/features/profile/presentation/widgets/profile_drawer.dart';
import 'package:kaam_milega/features/resources/models/course.dart';
import 'package:kaam_milega/features/resources/presentation/my_courses_screen.dart';
import 'package:kaam_milega/features/resources/repositories/course_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activePass = ExpertSubscriptionStatus(
  isActive: true,
  planType: 'monthly',
  daysRemaining: 29,
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9876543210', name: 'Asha'),
  );
}

/// Answers every request locally and records it. [respond] may throw a
/// [DioException] to fail a request.
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

  Iterable<RequestOptions> where(String method, String path) =>
      sent.where((o) => o.method == method && o.path == path);
}

DioException _fail(RequestOptions o, int status) => DioException(
  requestOptions: o,
  response: Response(requestOptions: o, statusCode: status),
  type: DioExceptionType.badResponse,
);

Map<String, dynamic> _course(
  String id, {
  String title = 'Overfitting Explained',
  int views = 5,
  String category = 'Technology',
}) => {
  'id': id,
  'title': title,
  'description': 'Why a model can fit noise.',
  'youtube_url': 'https://www.youtube.com/watch?v=abcdefghijk',
  'youtube_video_id': 'abcdefghijk',
  'thumbnail_url': '',
  'duration': '15mins',
  'category': category,
  'expert_id': 'me',
  'expert_name': 'Asha',
  'views': views,
  'created_at': '2026-10-12T10:00:00Z',
};

List<Override> _overrides(
  _Server server, {
  ExpertSubscriptionStatus pass = _activePass,
}) => [
  authProvider.overrideWith(_Auth.new),
  apiClientProvider.overrideWithValue(server.client()),
  myExpertSubscriptionProvider.overrideWith((ref) async => pass),
  unreadNotificationsCountProvider.overrideWithValue(0),
  courseVideoLauncherProvider.overrideWithValue((_) async => true),
];

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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Drawer Expert Portal', () {
    Future<void> openDrawer(WidgetTester tester, ExpertSubscriptionStatus p) {
      return _pump(
        tester,
        const Scaffold(endDrawer: ProfileDrawer(), body: SizedBox()),
        _overrides(_Server((_) => const {'data': []}), pass: p),
      ).then((_) async {
        tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('active pass: Expert Portal with its three pages', (
      tester,
    ) async {
      await openDrawer(tester, _activePass);

      expect(find.text('EXPERT PORTAL'), findsOneWidget);
      expect(find.text('Monthly Pro Expert'), findsOneWidget);
      expect(find.text('29 days remaining'), findsOneWidget);
      expect(find.text('Create Event'), findsOneWidget);
      expect(find.text('My Courses'), findsOneWidget);
      expect(find.text('Manage Mentorships'), findsOneWidget);
      expect(find.text('Apply to be an Expert'), findsNothing);
    });

    testWidgets('no pass: no Expert Portal, the offer to become an Expert', (
      tester,
    ) async {
      await openDrawer(tester, ExpertSubscriptionStatus.none);

      expect(find.text('Create Event'), findsNothing);
      expect(find.text('My Courses'), findsNothing);
      expect(find.text('Manage Mentorships'), findsNothing);
      expect(find.text('Apply to be an Expert'), findsOneWidget);
    });
  });

  testWidgets('Expert Portal pages need the pass; nothing is loaded', (
    tester,
  ) async {
    final server = _Server((o) => throw StateError('no request expected'));
    await _pump(
      tester,
      const MyCoursesScreen(),
      _overrides(server, pass: ExpertSubscriptionStatus.none),
    );
    expect(find.text('Expert Portal only'), findsOneWidget);
    expect(find.text('View Expert Pass plans'), findsOneWidget);
    expect(server.sent, isEmpty);
  });

  group('Create Event', () {
    test('banner is uploaded, then the website fields are posted', () async {
      final server = _Server((o) {
        if (o.path == '/files/upload') {
          return {'url': 'https://cdn.example/b.jpg'};
        }
        if (o.path == '/events' && o.method == 'POST') {
          return {
            'id': 'e1',
            ...(o.data as Map<String, dynamic>),
            'is_paid': false,
          };
        }
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      final container = ProviderContainer(overrides: _overrides(server));
      addTearDown(container.dispose);

      final result = await container
          .read(eventCreatorProvider)
          .create(
            EventDraft(
              title: ' Resume Masterclass ',
              organizer: 'Asha',
              description: 'Make your resume stand out.',
              date: DateTime(2026, 11, 5),
              time: const TimeOfDay(hour: 9, minute: 5),
              location: 'Online',
              bannerName: 'b.jpg',
              bannerBytes: Uint8List.fromList([1, 2, 3]),
            ),
          );

      expect(result.event?.id, 'e1');
      expect(server.where('POST', '/events').single.data, {
        'title': 'Resume Masterclass',
        'organizer': 'Asha',
        'description': 'Make your resume stand out.',
        'date': '2026-11-05',
        'time': '09:05',
        'location': 'Online',
        'image_url': 'https://cdn.example/b.jpg',
      });
    });

    test('banner upload fails: the event is not created', () async {
      final server = _Server((o) {
        if (o.path == '/files/upload') throw _fail(o, 500);
        throw StateError('unexpected ${o.method} ${o.path}');
      });
      final container = ProviderContainer(overrides: _overrides(server));
      addTearDown(container.dispose);

      final result = await container
          .read(eventCreatorProvider)
          .create(
            EventDraft(
              title: 'T',
              organizer: 'O',
              description: 'D',
              date: DateTime(2026, 11, 5),
              time: const TimeOfDay(hour: 9, minute: 0),
              location: 'L',
              bannerName: 'b.jpg',
              bannerBytes: Uint8List.fromList([1]),
            ),
          );

      expect(result.event, isNull);
      expect(result.message, contains('banner photo could not be uploaded'));
      expect(server.where('POST', '/events'), isEmpty);
    });

    testWidgets('empty form: errors shown, nothing sent', (tester) async {
      final server = _Server((o) => throw StateError('no request expected'));
      await _pump(tester, const CreateEventScreen(), _overrides(server));

      expect(find.text('Asha'), findsOneWidget); // organizer filled in
      await tester.tap(find.text('Create Event'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the event title'), findsOneWidget);
      expect(find.text('Pick a date'), findsOneWidget);
      expect(find.text('Pick a time'), findsOneWidget);
      expect(find.text('Please enter the organizer name'), findsNothing);
      expect(server.sent, isEmpty);
    });
  });

  group('My Courses', () {
    test('YouTube links: watch, short, shorts; others refused', () {
      expect(
        Course.extractVideoId('https://www.youtube.com/watch?v=abcdefghijk'),
        'abcdefghijk',
      );
      expect(
        Course.extractVideoId('https://youtu.be/abcdefghijk?t=3'),
        'abcdefghijk',
      );
      expect(
        Course.extractVideoId('https://youtube.com/shorts/abcdefghijk'),
        'abcdefghijk',
      );
      expect(Course.extractVideoId('https://vimeo.com/123'), isNull);
      expect(Course.extractVideoId(''), isNull);
    });

    _Server coursesServer() => _Server((o) {
      if (o.path == '/courses/my') {
        return {
          'data': [_course('c1'), _course('c2', title: 'Fourier', views: 7)],
          'total': 2,
          'page': 1,
          'limit': 20,
          'total_pages': 1,
        };
      }
      if (o.path == '/courses' && o.method == 'POST') {
        final d = o.data as Map<String, dynamic>;
        return _course('c3', title: d['title'] as String, views: 0);
      }
      if (o.path == '/courses/c1' && o.method == 'PUT') {
        final d = o.data as Map<String, dynamic>;
        return _course('c1', title: d['title'] as String);
      }
      if (o.path == '/courses/c1' && o.method == 'DELETE') {
        return {'message': 'Course deleted successfully'};
      }
      throw StateError('unexpected ${o.method} ${o.path}');
    });

    testWidgets('lists my courses with counts', (tester) async {
      final server = coursesServer();
      await _pump(tester, const MyCoursesScreen(), _overrides(server));

      expect(server.sent.first.queryParameters, {'page': 1, 'limit': 20});
      expect(find.text('Overfitting Explained'), findsOneWidget);
      expect(find.text('Fourier'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // courses
      expect(find.text('12'), findsOneWidget); // total views
      expect(find.text('7 Viewers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('publish a course from a YouTube link', (tester) async {
      final server = coursesServer();
      await _pump(tester, const MyCoursesScreen(), _overrides(server));

      await tester.tap(find.text('Add New Course'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'https://youtu.be/abcdefghijk');
      await tester.pump();
      expect(find.text('Video found'), findsOneWidget);
      await tester.enterText(fields.at(1), 'Basics of House Wiring');
      await tester.tap(find.text('30 Min'));
      await tester.pump();
      await tester.tap(find.text('Publish Course'));
      await tester.pumpAndSettle();

      expect(server.where('POST', '/courses').single.data, {
        'title': 'Basics of House Wiring',
        'youtube_url': 'https://youtu.be/abcdefghijk',
        'duration': '30 Min',
        'category': 'Vocational Skills',
        'description': '',
      });
      expect(find.text('Course published to Resources.'), findsOneWidget);
      expect(find.text('Basics of House Wiring'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // courses count went up
    });

    testWidgets('word limit and a non-YouTube link are refused', (
      tester,
    ) async {
      final server = coursesServer();
      await _pump(tester, const MyCoursesScreen(), _overrides(server));
      await tester.tap(find.text('Add New Course'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'https://vimeo.com/123');
      await tester.enterText(
        fields.at(1),
        'one two three four five six seven eight nine ten eleven',
      );
      await tester.enterText(fields.at(2), '20 Min');
      await tester.tap(find.text('Publish Course'));
      await tester.pumpAndSettle();

      expect(find.text('This is not a YouTube video link'), findsOneWidget);
      expect(find.text('Use 10 words or fewer'), findsOneWidget);
      expect(find.text('11/10 words'), findsOneWidget);
      expect(server.where('POST', '/courses'), isEmpty);
    });

    testWidgets('edit keeps the video; only details are sent', (tester) async {
      final server = coursesServer();
      await _pump(tester, const MyCoursesScreen(), _overrides(server));

      await tester.tap(find.text('Overfitting Explained'));
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Video found'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Overfitting, Simply Explained',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final put = server.where('PUT', '/courses/c1').single;
      expect(put.data, {
        'title': 'Overfitting, Simply Explained',
        'duration': '15mins',
        'category': 'Technology',
        'description': 'Why a model can fit noise.',
      });
      expect(find.text('Overfitting, Simply Explained'), findsOneWidget);
    });

    testWidgets('delete asks first, then removes the course', (tester) async {
      final server = coursesServer();
      await _pump(tester, const MyCoursesScreen(), _overrides(server));

      await tester.tap(find.byTooltip('Course options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete course'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this course?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.where('DELETE', '/courses/c1'), hasLength(1));
      expect(find.text('Overfitting Explained'), findsNothing);
      expect(find.text('Course deleted.'), findsOneWidget);
    });
  });
}
