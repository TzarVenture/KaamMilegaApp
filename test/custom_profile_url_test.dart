import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';
import 'package:kaam_milega/features/profile/presentation/widgets/edit_public_url_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request locally (no network); records each request.
({ApiClient client, List<RequestOptions> sent}) _fakeClient(
  Response<dynamic> Function(RequestOptions options) respond,
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

Response<dynamic> _ok(RequestOptions o, Map<String, dynamic> data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

/// Behaves like km-backend: `taken-name` belongs to someone else.
Response<dynamic> _backend(RequestOptions o) {
  if (o.path == '/user/username/check') {
    final name = o.queryParameters['username'] as String;
    final taken = name == 'taken-name';
    return _ok(o, {
      'available': !taken,
      'message': taken
          ? 'This URL is already taken. Please try another.'
          : 'Username is available',
      'username': name,
    });
  }
  if (o.path == '/user/username' && o.method == 'PATCH') {
    final name = (o.data as Map)['username'];
    return _ok(o, {
      'message': 'Custom URL updated successfully',
      'username': name,
      'user': {'id': 'u1', 'mobile': '9876543210', 'username': name},
    });
  }
  throw DioException(
    requestOptions: o,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: o,
      statusCode: 404,
      data: <String, dynamic>{'error': 'not found'},
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Profile link', () {
    test('uses the custom URL name, or the id until one is set', () {
      final named = UserProfile.fromJson({
        'id': 'u1',
        'mobile': '9876543210',
        'username': 'priya-sharma',
      });
      expect(named.username, 'priya-sharma');
      expect(
        named.fullPublicProfileUrl,
        'https://kaammilega.com/profile/priya-sharma',
      );
      expect(named.publicProfileUrl, 'kaammilega.com/profile/priya-sharma');
      expect(UserProfile.fromJson(named.toJson()).username, 'priya-sharma');

      const unnamed = UserProfile(id: 'u1', mobile: '9876543210');
      expect(unnamed.fullPublicProfileUrl, 'https://kaammilega.com/profile/u1');
    });

    test('format rules match the backend', () {
      expect(validateUsernameFormat('priya-sharma'), isNull);
      expect(validateUsernameFormat('abc'), isNull);
      expect(validateUsernameFormat('ab'), isNotNull);
      expect(validateUsernameFormat('a' * 31), isNotNull);
      expect(validateUsernameFormat('-priya'), isNotNull);
      expect(validateUsernameFormat('priya-'), isNotNull);
      expect(validateUsernameFormat('priya--sharma'), isNotNull);
      expect(validateUsernameFormat('priya_sharma'), isNotNull);
    });
  });

  group('Username API', () {
    test('check: GET /user/username/check?username=', () async {
      final f = _fakeClient(_backend);
      final result = await AuthRepository(f.client).checkUsername('Taken-Name');
      expect(result.available, isFalse);
      expect(result.message, contains('already taken'));
      expect(f.sent.single.path, '/user/username/check');
      expect(f.sent.single.queryParameters, {'username': 'taken-name'});
    });

    test('check: an answer without "available" is an error', () async {
      final f = _fakeClient((o) => _ok(o, {'message': 'ok'}));
      await expectLater(
        AuthRepository(f.client).checkUsername('priya'),
        throwsA(isA<AppValidationException>()),
      );
    });

    test(
      'save: PATCH /user/username and returns the updated profile',
      () async {
        final f = _fakeClient(_backend);
        final user = await AuthRepository(f.client)
            .updateUsername(' new-name ');
        expect(user.username, 'new-name');
        expect(f.sent.single.method, 'PATCH');
        expect(f.sent.single.data, {'username': 'new-name'});
      },
    );
  });

  group('Edit Custom URL dialog', () {
    Future<List<RequestOptions>> openDialog(
      WidgetTester tester,
      void Function(bool?) onResult,
    ) async {
      final f = _fakeClient(_backend);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(AuthRepository(f.client)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => onResult(
                    await showEditPublicUrlDialog(
                      context,
                      currentUsername: 'old-name',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return f.sent;
    }

    ElevatedButton saveButton(WidgetTester tester) =>
        tester.widget(find.widgetWithText(ElevatedButton, 'Save URL'));

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    }

    testWidgets('current URL: nothing to save, no request', (tester) async {
      final sent = await openDialog(tester, (_) {});
      expect(find.text('This is your current URL'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(sent.where((o) => o.path.startsWith('/user/username')), isEmpty);
    });

    testWidgets('too short: local error, no server check', (tester) async {
      final sent = await openDialog(tester, (_) {});
      await type(tester, 'ab');
      expect(find.text('Must be between 3 and 30 characters'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(sent.where((o) => o.path == '/user/username/check'), isEmpty);
    });

    testWidgets('taken: server message, save disabled', (tester) async {
      await openDialog(tester, (_) {});
      await type(tester, 'taken-name');
      expect(
        find.text('This URL is already taken. Please try another.'),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('available: saves the lowercase name on the server', (
      tester,
    ) async {
      bool? result;
      final sent = await openDialog(tester, (r) => result = r);
      await type(tester, 'New-Name');
      expect(find.text('Username is available'), findsOneWidget);
      expect(find.text('kaammilega.com/profile/new-name'), findsOneWidget);

      final save = find.widgetWithText(ElevatedButton, 'Save URL');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      final patch = sent.singleWhere((o) => o.method == 'PATCH');
      expect(patch.data, {'username': 'new-name'});
    });
  });
}
