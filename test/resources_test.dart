import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/resources/models/course.dart';
import 'package:kaam_milega/features/resources/presentation/resources_screen.dart';
import 'package:kaam_milega/features/resources/presentation/widgets/course_youtube_player.dart';
import 'package:kaam_milega/features/resources/repositories/course_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _course(
  String id, {
  String title = 'Overfitting Explained',
  String expertId = 'expert1',
  int views = 2,
}) => {
  'id': id,
  'title': title,
  'description': 'A 9th-order polynomial passes through all ten readings.',
  'youtube_url': 'https://www.youtube.com/watch?v=abcdefghijk',
  'youtube_video_id': 'abcdefghijk',
  'thumbnail_url': '',
  'duration': '15mins',
  'category': 'Technology',
  'expert_id': expertId,
  'expert_name': 'Sam Sam',
  'views': views,
  'created_at': '2026-10-12T10:00:00Z',
};

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'expert1', mobile: '', name: 'Sam Sam'),
  );
}

/// Fake backend for /courses: [pages] are returned in order of `page`.
class _Server {
  _Server({this.total = 1, List<List<Map<String, dynamic>>>? pages})
    : pages =
          pages ??
          [
            [_course('c1')],
          ];

  final List<List<Map<String, dynamic>>> pages;
  final int total;
  final List<RequestOptions> sent = [];
  int serverViews = 3;
  bool failList = false;
  bool failView = false;

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          if (o.path.endsWith('/view')) {
            if (failView) {
              return h.reject(
                DioException(
                  requestOptions: o,
                  response: Response(requestOptions: o, statusCode: 500),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
            return h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {'message': 'View recorded', 'views': serverViews},
              ),
            );
          }
          if (failList) {
            return h.reject(
              DioException(
                requestOptions: o,
                response: Response(requestOptions: o, statusCode: 500),
                type: DioExceptionType.badResponse,
              ),
            );
          }
          final page = (o.queryParameters['page'] as int?) ?? 1;
          final data = page <= pages.length ? pages[page - 1] : const [];
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'data': data,
                'total': total,
                'page': page,
                'limit': 10,
                'total_pages': pages.length,
              },
            ),
          );
        },
      ),
    );
    return ApiClient(dio: dio);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  final opened = <Uri>[];

  Future<void> pump(
    WidgetTester tester,
    _Server server, {
    bool signedIn = false,
  }) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened.clear();
    if (signedIn) await LocalStorage.saveToken('t');
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(() => signedIn ? _SignedIn() : _Guest()),
          apiClientProvider.overrideWithValue(server.client()),
          courseVideoLauncherProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
          // The real YouTube player needs a platform web view.
          courseVideoPlayerProvider.overrideWithValue(
            (id) => Text('Player $id'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ResourcesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Course model', () {
    test('viewer labels follow the website', () {
      expect(Course.formatViewers(0), '0 Viewers');
      expect(Course.formatViewers(1), '1 Viewer');
      expect(Course.formatViewers(2), '2 Viewers');
      expect(Course.formatViewers(1250), '1.3K Viewers');
      expect(Course.formatViewers(3400000), '3.4M Viewers');
    });

    test('fallbacks: duration, thumbnail, watch URL', () {
      final c = Course.fromJson({
        'id': 'x',
        'title': 'T',
        'youtube_video_id': 'abcdefghijk',
      });
      expect(c.durationLabel, '30 Min');
      expect(
        c.thumbnail,
        'https://img.youtube.com/vi/abcdefghijk/hqdefault.jpg',
      );
      expect(c.watchUrl, 'https://www.youtube.com/watch?v=abcdefghijk');
      expect(c.releasedLabel, 'Released recently');
    });
  });

  testWidgets('shows the course card like the website', (tester) async {
    await pump(tester, _Server());

    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('Overfitting Explained'), findsOneWidget);
    expect(find.text('Technology'), findsOneWidget);
    expect(find.text('By Sam Sam'), findsOneWidget);
    expect(find.text('2 Viewers'), findsOneWidget);
    expect(find.text('Released 12 Oct 2026'), findsOneWidget);
    expect(find.text('15mins'), findsWidgets);
    expect(find.text('1 learning video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a video plays it in the app and counts one view', (
    tester,
  ) async {
    final server = _Server()..serverViews = 7;
    await pump(tester, server);

    await tester.tap(find.text('Overfitting Explained'));
    await tester.pumpAndSettle();

    expect(find.text('Player abcdefghijk'), findsOneWidget);
    expect(opened, isEmpty); // not sent to YouTube
    expect(find.text('7 Viewers'), findsOneWidget);

    // Watch on YouTube from the player: opens YouTube, no second view
    await tester.tap(find.text('Watch on YouTube'));
    await tester.pumpAndSettle();
    expect(
      opened.single.toString(),
      'https://www.youtube.com/watch?v=abcdefghijk',
    );
    expect(
      server.sent.where((o) => o.path.endsWith('/courses/c1/view')),
      hasLength(1),
    );
  });

  testWidgets('the YouTube button on the card opens YouTube and counts', (
    tester,
  ) async {
    final server = _Server()..serverViews = 3;
    await pump(tester, server);

    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();

    expect(find.text('Player abcdefghijk'), findsNothing);
    expect(
      opened.single.toString(),
      'https://www.youtube.com/watch?v=abcdefghijk',
    );
    expect(
      server.sent.where((o) => o.path.endsWith('/courses/c1/view')),
      hasLength(1),
    );
    expect(find.text('3 Viewers'), findsOneWidget);
  });

  testWidgets('a failed view request puts the old number back', (tester) async {
    final server = _Server()..failView = true;
    await pump(tester, server);

    await tester.tap(find.text('Overfitting Explained'));
    await tester.pumpAndSettle();

    expect(find.text('Player abcdefghijk'), findsOneWidget); // still plays
    expect(find.text('2 Viewers'), findsOneWidget);
  });

  testWidgets('uploader: no +1 on screen, "Your video" label', (tester) async {
    final server = _Server()..serverViews = 2; // backend does not count
    await pump(tester, server, signedIn: true);

    expect(find.text('Your video'), findsOneWidget);
    await tester.tap(find.text('Overfitting Explained'));
    await tester.pump();
    expect(find.text('3 Viewers'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('2 Viewers'), findsOneWidget);
  });

  testWidgets('search sends the text (special characters escaped)', (
    tester,
  ) async {
    final server = _Server();
    await pump(tester, server);

    await tester.enterText(find.byType(TextField), 'C++');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final last = server.sent.lastWhere((o) => o.path.endsWith('/courses'));
    expect(last.queryParameters['search'], r'C\+\+');
    expect(last.queryParameters['page'], 1);
  });

  testWidgets('no courses: friendly empty state', (tester) async {
    await pump(tester, _Server(total: 0, pages: [[]]));
    expect(find.text('No courses found'), findsOneWidget);
  });

  testWidgets('server error: message with Retry, not "no courses"', (
    tester,
  ) async {
    final server = _Server()..failList = true;
    await pump(tester, server);

    expect(find.text('No courses found'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    server.failList = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Overfitting Explained'), findsOneWidget);
  });

  testWidgets('loads the next page when the end is reached', (tester) async {
    final server = _Server(
      total: 2,
      pages: [
        [_course('c1')],
        [_course('c2', title: 'Fourier Transform')],
      ],
    );
    await pump(tester, server);

    expect(find.text('Fourier Transform'), findsOneWidget);
    expect(find.text("You've seen all courses"), findsOneWidget);
  });
}
