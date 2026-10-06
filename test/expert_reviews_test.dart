import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/experts/models/expert_profile.dart';
import 'package:kaam_milega/features/experts/models/expert_review.dart';
import 'package:kaam_milega/features/experts/presentation/widgets/expert_reviews_section.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Never _fail(RequestOptions o, int code) => throw DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: {'error': 'failed'},
  ),
);

Map<String, dynamic> _review(String id, num rating, {String text = ''}) => {
  'id': id,
  'booking_id': id,
  'mentee_id': 'm$id',
  'mentee_name': 'Mentee $id',
  'mentee_headline': 'Student',
  'mentorship_title': 'Resume review',
  'rating': rating,
  'review': text,
  'created_at': '2026-09-20T10:00:00Z',
};

/// Response shape of GET /mentorships/expert/:id/reviews (km-backend
/// MentorshipReviewsResponse).
final _reviews = {
  'average_rating': 4.3,
  'total_reviews': 4,
  'distribution': {
    '5_star': 2,
    '4_star': 1,
    '3_star': 1,
    '2_star': 0,
    '1_star': 0,
  },
  'reviews': [
    _review('r1', 5, text: 'Very helpful. ' * 20),
    _review('r2', 5, text: 'Great advice'),
    _review('r3', 4),
    _review('r4', 3, text: 'Okay'),
  ],
};

Future<List<RequestOptions>> _pump(
  WidgetTester tester,
  Response<dynamic> Function(RequestOptions o) respond,
) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = _fakeClient(respond);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        expertRepositoryProvider.overrideWithValue(ExpertRepository(f.client)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ExpertReviewsSection(expertId: 'e1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return f.sent;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Expert reviews data', () {
    test('reads average, star counts and reviews', () {
      final data = ExpertReviews.fromJson(_reviews);
      expect(data.averageRating, 4.3);
      expect(data.totalReviews, 4);
      expect(data.starCounts, [0, 0, 1, 1, 2]);
      expect(data.share(5), 0.5);
      expect(data.reviews.first.displayName, 'Mentee r1');
      expect(data.reviews.first.sessionTitle, 'Resume review');
    });

    test('out-of-range ratings are left out; missing fields are safe', () {
      final data = ExpertReviews.fromJson({
        'reviews': [
          _review('bad', 0),
          {'id': 'x', 'rating': 4},
        ],
      });
      expect(data.reviews.map((r) => r.id), ['x']);
      expect(data.reviews.single.displayName, 'KaamMilega member');
      expect(data.totalReviews, 0);
      expect(data.starCounts, [0, 0, 0, 0, 0]);
    });

    test('no rating from the server shows "New", never an invented 5.0', () {
      final unrated = ExpertItem.fromJson({
        'mentorship': {'id': 'm1', 'expert_id': 'e1', 'title': 'Mock'},
      });
      expect(unrated.rating, 0);
      expect(unrated.ratingLabel, 'New');
      final rated = ExpertItem.fromJson({
        'id': 'm2',
        'rating': 4.6,
        'reviews': 12,
      });
      expect(rated.ratingLabel, '4.6 (12)');
    });

    test('GET /mentorships/expert/:id/reviews; a non-object reply is an '
        'error, not "no reviews"', () async {
      final f = _fakeClient((o) => _ok(o, _reviews));
      final data = await ExpertRepository(f.client).getExpertReviews('e1');
      expect(f.sent.single.path, '/mentorships/expert/e1/reviews');
      expect(data.totalReviews, 4);

      final bad = _fakeClient((o) => _ok(o, []));
      expect(
        ExpertRepository(bad.client).getExpertReviews('e1'),
        throwsA(isA<AppServerException>()),
      );
    });
  });

  group('Ratings & Reviews section', () {
    testWidgets('summary, three reviews, See all opens the full list', (
      tester,
    ) async {
      await _pump(tester, (o) => _ok(o, _reviews));
      expect(tester.takeException(), isNull);
      expect(find.text('Candidate Ratings & Reviews'), findsOneWidget);
      // Header badge and summary both show the average.
      expect(find.text('4.3'), findsNWidgets(2));
      expect(find.text('50%'), findsOneWidget); // 2 of 4 are five stars
      expect(find.text('Verified Candidate Feedback'), findsOneWidget);
      expect(find.text('4 reviews'), findsOneWidget);
      expect(find.text('Mentee r1'), findsOneWidget);
      expect(find.text('Mentee r3'), findsOneWidget);
      expect(find.text('Mentee r4'), findsNothing); // fourth is in the sheet
      expect(find.text('Verified session'), findsNWidgets(3));

      // Long review folds; Read more shows the rest.
      expect(find.text('Read more'), findsOneWidget);
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

      await tester.ensureVisible(find.text('See all 4 reviews'));
      await tester.tap(find.text('See all 4 reviews'));
      await tester.pumpAndSettle();
      expect(find.text('Mentee r4'), findsOneWidget);
    });

    testWidgets('no reviews yet: says so', (tester) async {
      await _pump(
        tester,
        (o) => _ok(o, {
          'average_rating': 0,
          'total_reviews': 0,
          'distribution': <String, dynamic>{},
          'reviews': <dynamic>[],
        }),
      );
      expect(find.text('No Reviews Yet'), findsOneWidget);
      expect(find.text('Verified Candidate Feedback'), findsOneWidget);
    });

    testWidgets('server error: Retry, not "no reviews"', (tester) async {
      final sent = await _pump(tester, (o) => _fail(o, 500));
      expect(find.text('Could not load reviews right now.'), findsOneWidget);
      expect(find.text('No Reviews Yet'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(sent, hasLength(2));
    });

    testWidgets('endpoint not on this server (404): not available yet', (
      tester,
    ) async {
      await _pump(tester, (o) => _fail(o, 404));
      expect(find.text('Reviews are not available yet.'), findsOneWidget);
      expect(find.text('No Reviews Yet'), findsNothing);
    });
  });
}
