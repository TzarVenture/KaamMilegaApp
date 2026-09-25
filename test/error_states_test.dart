import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/core/network/connectivity_service.dart';
import 'package:kaam_milega/core/network/network_status.dart';
import 'package:kaam_milega/core/network/response_list.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/chat/models/chat_message.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/interviews/presentation/interviews_screen.dart';
import 'package:kaam_milega/features/interviews/repositories/interview_repository.dart';
import 'package:kaam_milega/features/network/repositories/network_repository.dart';
import 'package:kaam_milega/shared/widgets/network_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaam_milega/core/network/provider_retry.dart';

/// ApiClient whose requests are answered locally (no network).
ApiClient _fakeClient(Response<dynamic> Function(RequestOptions o) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          handler.resolve(respond(options));
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return ApiClient(dio: dio);
}

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

DioException _status(RequestOptions o, int code) => DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: <String, dynamic>{'error': 'failure $code'},
  ),
);

DioException _offline(RequestOptions o) =>
    DioException(requestOptions: o, type: DioExceptionType.connectionError);

class _FailingChats extends ChatRepository {
  _FailingChats() : super(ApiClient());
  int historyCalls = 0;

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    historyCalls++;
    throw const AppServerException();
  }

  @override
  Future<List<ConversationItem>> getConversations() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  tearDown(() => ConnectivityService().updateStatus(NetworkStatus.online));

  group('readListResponse', () {
    test('array, {data: [...]}, null and {data: null} are valid', () {
      expect(
        readListResponse([
          {'id': 'a'},
        ]),
        hasLength(1),
      );
      expect(
        readListResponse({
          'data': [
            {'id': 'a'},
          ],
        }),
        hasLength(1),
      );
      // Go encodes an empty slice as null: that is "no items".
      expect(readListResponse(null), isEmpty);
      expect(readListResponse({'data': null}), isEmpty);
      expect(readListResponse(''), isEmpty);
    });

    test('an unexpected shape is an error, not an empty list', () {
      expect(
        () => readListResponse({'something': 'else'}),
        throwsA(isA<AppValidationException>()),
      );
      expect(
        () => readListResponse('<html>'),
        throwsA(isA<AppValidationException>()),
      );
    });
  });

  group('Repositories report failures instead of empty lists', () {
    test('interviews: 200 [] is empty; 404 and 500 are errors', () async {
      expect(
        await InterviewRepository(_fakeClient((o) => _ok(o, [])))
            .getMyInterviews(),
        isEmpty,
      );
      await expectLater(
        InterviewRepository(_fakeClient((o) => throw _status(o, 404)))
            .getMyInterviews(),
        throwsA(isA<AppNotFoundException>()),
      );
      await expectLater(
        InterviewRepository(_fakeClient((o) => throw _status(o, 500)))
            .getMyInterviews(),
        throwsA(isA<AppServerException>()),
      );
    });

    test('network: pending / connections / status rethrow errors', () async {
      final repo = NetworkRepository(_fakeClient((o) => throw _status(o, 500)));
      await expectLater(
        repo.getPendingInvitations(),
        throwsA(isA<AppServerException>()),
      );
      await expectLater(
        repo.getConnections(),
        throwsA(isA<AppServerException>()),
      );
      await expectLater(
        repo.getConnectionStatus('u2'),
        throwsA(isA<AppServerException>()),
      );
    });

    test('network: connections list of ids is read', () async {
      final repo = NetworkRepository(_fakeClient((o) => _ok(o, ['u2', 'u3'])));
      expect(await repo.getConnections(), ['u2', 'u3']);
    });

    test('chat: conversations 401 is an auth error, not "no chats"', () async {
      await expectLater(
        ChatRepository(_fakeClient((o) => throw _status(o, 401)))
            .getConversations(),
        throwsA(isA<AppAuthException>()),
      );
    });

    test('applications: offline shows the last list (job title kept); '
        'a server error is reported even with a saved list', () async {
      final live = ApplicationRepository(
        _fakeClient(
          (o) => _ok(o, [
            {
              'id': 'app1',
              'job_id': 'job1',
              'status': 'Applied',
              'job': {'title': 'Delivery Executive', 'company': 'Acme'},
            },
          ]),
        ),
      );
      final fresh = await live.getMyApplications();
      expect(fresh.single.jobTitle, 'Delivery Executive');
      await Future<void>.delayed(Duration.zero); // cache write finishes

      final offline = ApplicationRepository(
        _fakeClient((o) => throw _offline(o)),
      );
      final cached = await offline.getMyApplications();
      expect(cached.single.jobTitle, 'Delivery Executive');
      expect(cached.single.companyName, 'Acme');

      final broken = ApplicationRepository(
        _fakeClient((o) => throw _status(o, 500)),
      );
      await expectLater(
        broken.getMyApplications(),
        throwsA(isA<AppServerException>()),
      );
    });

    test('applications: offline without a saved list is an error', () async {
      final offline = ApplicationRepository(
        _fakeClient((o) => throw _offline(o)),
      );
      await expectLater(
        offline.getMyApplications(),
        throwsA(isA<AppNetworkException>()),
      );
    });
  });

  group('Chat history', () {
    test('a failed load is an error with Retry, not an empty chat', () async {
      final chats = _FailingChats();
      final container = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(chats)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatMessagesProvider('c1'), (_, _) {});
      addTearDown(sub.close);

      final notifier = container.read(chatMessagesProvider('c1'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isLoading, isFalse);
      expect(notifier.error, isA<AppServerException>());
      expect(notifier.messages, isEmpty);

      await notifier.retryHistory();
      expect(chats.historyCalls, 2);
    });

    test('a brand-new chat (temporary id) does not request history', () async {
      final chats = _FailingChats();
      final container = ProviderContainer(
        overrides: [chatRepositoryProvider.overrideWithValue(chats)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatMessagesProvider('new-u2'), (_, _) {});
      addTearDown(sub.close);

      final notifier = container.read(chatMessagesProvider('new-u2'));
      await Future<void>.delayed(Duration.zero);
      expect(chats.historyCalls, 0);
      expect(notifier.error, isNull);
      expect(notifier.isLoading, isFalse);
    });
  });

  group('Automatic retry policy (main.dart ProviderScope)', () {
    test('only temporary failures are retried, at most twice', () {
      for (final error in <Object>[
        const AppNetworkException(),
        const AppTimeoutException(),
        const AppServerException(),
      ]) {
        expect(appProviderRetry(0, error), isNotNull);
        expect(appProviderRetry(1, error), isNotNull);
        expect(appProviderRetry(2, error), isNull);
      }
    });

    test('404 / session / validation errors are never retried', () {
      for (final error in <Object>[
        const AppNotFoundException(),
        const AppAuthException(),
        const AppValidationException('bad'),
        StateError('bug'),
      ]) {
        expect(appProviderRetry(0, error), isNull);
      }
    });
  });

  group('Error views', () {
    test('messages by error type', () {
      expect(
        NetworkStateView.errorMessageFor(const AppNotFoundException()),
        contains('not available'),
      );
      expect(
        NetworkStateView.errorMessageFor(const AppAuthException()),
        contains('session has expired'),
      );
      expect(
        NetworkStateView.errorMessageFor(const AppServerException()),
        const AppServerException().message,
      );
      expect(
        NetworkStateView.errorMessageFor(StateError('x')),
        'Something went wrong while loading. Please try again.',
      );
    });

    testWidgets('Interviews: a server error shows an error with Retry', (
      tester,
    ) async {
      var loads = 0;
      await tester.pumpWidget(
        ProviderScope(
          // No automatic retries: this test checks the Retry button.
          retry: (_, _) => null,
          overrides: [
            myInterviewsProvider.overrideWith((ref) async {
              loads++;
              throw const AppServerException();
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const InterviewsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(loads, 2);
    });

    testWidgets('offline error shows the No Internet state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStateView.fromError(
              const AppNetworkException(),
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No Internet Connection'), findsOneWidget);
    });
  });
}
