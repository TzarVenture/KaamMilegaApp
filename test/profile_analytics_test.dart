import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/network/repositories/network_repository.dart';
import 'package:kaam_milega/features/network/services/impression_tracker.dart';
import 'package:kaam_milega/features/profile/presentation/widgets/profile_analytics_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

({ApiClient client, List<RequestOptions> sent}) _fakeClient(dynamic data) {
  final sent = <RequestOptions>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) {
        sent.add(o);
        handler.resolve(
          Response<dynamic>(requestOptions: o, statusCode: 200, data: data),
        );
      },
    ),
  );
  return (client: ApiClient(dio: dio), sent: sent);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Impression tracker (POST /user/impressions)', () {
    const delay = Duration(milliseconds: 20);
    Future<void> wait() =>
        Future<void>.delayed(const Duration(milliseconds: 60));

    test(
      'once per member, never self or guests, batched after a pause',
      () async {
        final batches = <List<String>>[];
        final t = ImpressionTracker(
          (ids) async => batches.add(ids),
          selfId: 'me',
          flushDelay: delay,
        );
        t.record('a');
        t.record('a'); // same card again this session
        t.record('me'); // own card
        t.record('b');
        expect(batches, isEmpty);
        await wait();
        expect(batches, [
          ['a', 'b'],
        ]);

        final guest = ImpressionTracker(
          (ids) async => batches.add(ids),
          selfId: null,
          flushDelay: delay,
        );
        guest.record('c');
        await wait();
        expect(batches, hasLength(1));
      },
    );

    test('15 cards: sent at once', () async {
      final batches = <List<String>>[];
      final t = ImpressionTracker(
        (ids) async => batches.add(ids),
        selfId: 'me',
        flushDelay: const Duration(minutes: 1),
      );
      for (var i = 0; i < 15; i++) {
        t.record('u$i');
      }
      await Future<void>.delayed(Duration.zero);
      expect(batches.single, hasLength(15));
      t.dispose();
    });

    test('logout drops unsent ids', () async {
      final batches = <List<String>>[];
      final t = ImpressionTracker(
        (ids) async => batches.add(ids),
        selfId: 'me',
        flushDelay: delay,
      );
      t.record('a');
      t.dispose();
      await wait();
      expect(batches, isEmpty);
    });

    test('a failed batch never throws', () async {
      final t = ImpressionTracker(
        (ids) async => throw Exception('offline'),
        selfId: 'me',
        flushDelay: delay,
      );
      t.record('a');
      await t.flush();
    });

    test('request body', () async {
      final f = _fakeClient({'status': 'ok'});
      await NetworkRepository(f.client).recordImpressions(['a', 'b']);
      expect(f.sent.single.path, '/user/impressions');
      expect(f.sent.single.data, {
        'author_ids': ['a', 'b'],
      });
    });
  });

  group('Profile viewers (GET /user/viewers)', () {
    test('list, and null from the server means nobody yet', () async {
      final f = _fakeClient([
        {'id': 'v1', 'name': 'Asha'},
      ]);
      final viewers = await NetworkRepository(f.client).getProfileViewers();
      expect(viewers.single.name, 'Asha');
      expect(f.sent.single.path, '/user/viewers');

      final empty = _fakeClient(null);
      expect(
        await NetworkRepository(empty.client).getProfileViewers(),
        isEmpty,
      );
    });
  });

  group('Analytics card', () {
    testWidgets('real counters in three tiles; views open the viewers list', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileAnalyticsCard(
              user: const UserProfile(
                id: 'me',
                mobile: '9876543210',
                profileViewsCount: 2,
                postImpressionsCount: 1250,
                searchAppearancesCount: 15,
              ),
              onViewersTap: () => opened++,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Profile views'), findsOneWidget);
      expect(find.text('Post impressions'), findsOneWidget);
      expect(find.text('Search appearances'), findsOneWidget);

      await tester.tap(find.text('Profile views'));
      await tester.tap(find.text("See who's viewed your profile"));
      expect(opened, 2);

      await tester.tap(find.text('Search appearances'));
      await tester.pumpAndSettle();
      expect(find.textContaining('searched for people'), findsOneWidget);
    });
  });
}
