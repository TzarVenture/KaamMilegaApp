import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/applications/models/application.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/models/conversation.dart';
import 'package:kaam_milega/features/chat/presentation/chat_list_screen.dart';
import 'package:kaam_milega/features/chat/providers/chat_provider.dart';
import 'package:kaam_milega/features/chat/repositories/chat_repository.dart';
import 'package:kaam_milega/features/chat/services/chat_websocket_service.dart';
import 'package:kaam_milega/features/jobs/models/job_filter.dart';
import 'package:kaam_milega/features/jobs/models/jobs_response.dart';
import 'package:kaam_milega/features/jobs/providers/jobs_provider.dart';
import 'package:kaam_milega/features/jobs/repositories/job_repository.dart';
import 'package:kaam_milega/shared/widgets/login_required_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth without network: start as guest, sign in as a user, log out.
class _FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);

  void signInAs(String id) {
    state = AuthState(
      isAuthenticated: true,
      user: UserProfile(id: id, mobile: '98765$id', isRegistered: true),
    );
  }

  @override
  Future<void> logout() async {
    await LocalStorage.clearSession();
    state = const AuthState();
  }
}

/// Counts calls and returns one application per signed-in user.
class _FakeApplications extends ApplicationRepository {
  _FakeApplications() : super(ApiClient());
  final calls = <String>[];
  String currentUser = '';

  @override
  Future<List<ApplicationItem>> getMyApplications() async {
    calls.add(currentUser);
    return [
      ApplicationItem(
        id: 'app-$currentUser',
        jobId: 'job',
        recruiterId: 'rec',
        candidateId: currentUser,
        status: 'Applied',
        coverLetter: '',
        jobTitle: 'Job of $currentUser',
        companyName: 'Co',
        cityName: 'Pune',
      ),
    ];
  }
}

class _FakeChats extends ChatRepository {
  _FakeChats() : super(ApiClient());
  int calls = 0;

  @override
  Future<List<ConversationItem>> getConversations() async {
    calls++;
    return const [];
  }
}

class _FakeJobs extends JobRepository {
  _FakeJobs() : super(ApiClient());

  @override
  Future<JobsResponse> getJobs(JobFilter filter) async =>
      const JobsResponse(jobs: [], total: 0, page: 1, limit: 10);

  @override
  Future<Set<String>> getBookmarkedJobIds() async => {'saved-by-A'};
}

class _Mock401Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error": "Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test(
    'session id: null for guests and after logout, set when signed in',
    () async {
      final auth = _FakeAuth();
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => auth)],
      );
      addTearDown(container.dispose);

      expect(container.read(sessionUserIdProvider), isNull);
      auth.signInAs('A');
      expect(container.read(sessionUserIdProvider), 'A');
      await auth.logout();
      expect(container.read(sessionUserIdProvider), isNull);
    },
  );

  test('guests never call the applications / chats APIs', () async {
    final apps = _FakeApplications();
    final chats = _FakeChats();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _FakeAuth()),
        applicationRepositoryProvider.overrideWithValue(apps),
        chatRepositoryProvider.overrideWithValue(chats),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(myApplicationsProvider.future), isEmpty);
    expect(await container.read(conversationsProvider.future), isEmpty);
    expect(apps.calls, isEmpty);
    expect(chats.calls, 0);
  });

  test(
    'logout drops user A\'s applications; user B gets only their own',
    () async {
      final auth = _FakeAuth();
      final apps = _FakeApplications();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => auth),
          applicationRepositoryProvider.overrideWithValue(apps),
        ],
      );
      addTearDown(container.dispose);
      // Keep the provider alive like a screen watching it.
      final sub = container.listen(myApplicationsProvider, (_, _) {});
      addTearDown(sub.close);

      apps.currentUser = 'A';
      auth.signInAs('A');
      final listA = await container.read(myApplicationsProvider.future);
      expect(listA.single.jobTitle, 'Job of A');

      await auth.logout();
      expect(await container.read(myApplicationsProvider.future), isEmpty);

      apps.currentUser = 'B';
      auth.signInAs('B');
      final listB = await container.read(myApplicationsProvider.future);
      expect(listB.single.jobTitle, 'Job of B');
      expect(apps.calls, ['A', 'B']);
    },
  );

  test(
    'logout closes the chat socket service; next user gets a new one',
    () async {
      final auth = _FakeAuth();
      final container = ProviderContainer(
        overrides: [authProvider.overrideWith(() => auth)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatWebSocketServiceProvider, (_, _) {});
      addTearDown(sub.close);

      auth.signInAs('A');
      final serviceA = container.read(chatWebSocketServiceProvider);
      var serviceAClosed = false;
      serviceA.statusStream.listen(null, onDone: () => serviceAClosed = true);

      await auth.logout();
      final serviceAfter = container.read(chatWebSocketServiceProvider);
      await Future<void>.delayed(Duration.zero);

      expect(identical(serviceA, serviceAfter), isFalse);
      expect(serviceAClosed, isTrue); // disposed: socket + streams closed
      expect(serviceAfter.status, WebSocketStatus.disconnected);
    },
  );

  test('logout forgets the saved jobs of the signed-out account', () async {
    SharedPreferences.setMockInitialValues({
      'km_auth_token': 'token-A',
      'km_saved_job_ids': ['saved-by-A'],
    });
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());

    final auth = _FakeAuth();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => auth),
        jobRepositoryProvider.overrideWithValue(_FakeJobs()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(jobsProvider, (_, _) {});
    addTearDown(sub.close);

    auth.signInAs('A');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(jobsProvider).savedJobIds, {'saved-by-A'});

    await auth.logout();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(jobsProvider).savedJobIds, isEmpty);
    expect(LocalStorage.getSavedJobIds(), isEmpty);
  });

  testWidgets('Chats tab for a guest shows Sign In, no chats request', (
    tester,
  ) async {
    final chats = _FakeChats();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _FakeAuth()),
          chatRepositoryProvider.overrideWithValue(chats),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginRequiredView), findsOneWidget);
    expect(find.text('Sign in to view your chats'), findsOneWidget);
    expect(chats.calls, 0);
  });

  test('sessionExpired resets AuthState with expired message and clears sessionUserId', () {
    final auth = _FakeAuth();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith(() => auth)],
    );
    addTearDown(container.dispose);

    container.read(sessionUserIdProvider);
    auth.signInAs('user123');
    expect(container.read(sessionUserIdProvider), 'user123');
    expect(container.read(authProvider).isAuthenticated, isTrue);

    auth.sessionExpired();
    expect(container.read(sessionUserIdProvider), isNull);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(
      container.read(authProvider).error,
      'Your session has expired. Please log in again.',
    );
  });

  test('ApiClient triggers onUnauthenticated on 401 status code', () async {
    var callbackInvoked = false;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
    dio.httpClientAdapter = _Mock401Adapter();

    final client = ApiClient(
      dio: dio,
      onUnauthenticated: () {
        callbackInvoked = true;
      },
    );

    try {
      await client.get('/test');
    } catch (_) {}

    expect(callbackInvoked, isTrue);
  });
}
