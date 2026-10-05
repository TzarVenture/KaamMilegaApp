import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/applications/presentation/apply_modal.dart';
import 'package:kaam_milega/features/applications/repositories/application_repository.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';
import 'package:kaam_milega/features/jobs/models/job.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _job = Job.fromJson({
  'id': 'j1',
  'title': 'Supervisor',
  'company': 'Shree Facility Services',
});

UserProfile _user({bool verified = true, String resumeUrl = ''}) => UserProfile(
  id: 'me',
  mobile: '',
  name: 'Dev Test',
  email: 'dev@example.com',
  isEmailVerified: verified,
  resumeUrl: resumeUrl,
);

class _SignedIn extends AuthNotifier {
  _SignedIn(this.user);
  final UserProfile user;

  @override
  AuthState build() => AuthState(isAuthenticated: true, user: user);
}

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

Response<dynamic> _ok(RequestOptions o, dynamic data, [int code = 200]) =>
    Response<dynamic>(requestOptions: o, statusCode: code, data: data);

Never _fail(RequestOptions o, int code, String msg) => throw DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: {'error': msg},
  ),
);

const _uploaded = 'https://kaammilega.com/uploads/1_cv.pdf';

Response<dynamic> _server(RequestOptions o) {
  if (o.path == '/files/upload') return _ok(o, {'url': _uploaded}, 201);
  if (o.path == '/applications') return _ok(o, {'id': 'a1'}, 201);
  return _fail(o, 404, 'not found');
}

Future<void> _open(
  WidgetTester tester, {
  required ApiClient client,
  UserProfile? user,
  ResumePicker? picker,
  VoidCallback? onSuccess,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ApplyModalSheet(
                  job: _job,
                  onSuccess: onSuccess ?? () {},
                  pickResume: picker ?? () async => null,
                ),
              ),
              child: const Text('Apply Now'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/applications/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Application ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(() => _SignedIn(user ?? _user())),
        authRepositoryProvider.overrideWithValue(AuthRepository(client)),
        applicationRepositoryProvider.overrideWithValue(
          ApplicationRepository(client),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.tap(find.text('Apply Now'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  testWidgets('matches the website sheet and fits a 320px phone', (
    tester,
  ) async {
    final f = _fakeClient(_server);
    await _open(
      tester,
      client: f.client,
      size: const Size(320, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Apply for Position'), findsOneWidget);
    expect(find.text('Supervisor • Shree Facility Services'), findsOneWidget);
    expect(find.text('Dev Test'), findsOneWidget);
    expect(find.text('dev@example.com'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('PDF, DOC, DOCX up to 5MB'), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Submit Application'), findsOneWidget);
    expect(f.sent, isEmpty); // nothing is sent until Submit
  });

  testWidgets('no Verified badge unless the server says so', (tester) async {
    final f = _fakeClient(_server);
    await _open(tester, client: f.client, user: _user(verified: false));
    expect(find.text('Verified'), findsNothing);
  });

  testWidgets('note counter counts up and stops at 500', (tester) async {
    final f = _fakeClient(_server);
    await _open(tester, client: f.client);
    await tester.enterText(find.byType(TextField), 'Available now');
    await tester.pump();
    expect(find.text('13/500'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a' * 600);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
  });

  testWidgets('a file over 5MB is refused', (tester) async {
    final f = _fakeClient(_server);
    await _open(
      tester,
      client: f.client,
      picker: () async => PickedResume(
        name: 'big.pdf',
        bytes: List<int>.filled(ApplyModalSheet.maxResumeBytes + 1, 0),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Attach resume'));
    await tester.pumpAndSettle();
    expect(find.text('Resume file must be under 5MB.'), findsOneWidget);
    expect(find.text('big.pdf'), findsNothing);
  });

  testWidgets('attached resume is uploaded, then sent with the application', (
    tester,
  ) async {
    final f = _fakeClient(_server);
    var succeeded = false;
    await _open(
      tester,
      client: f.client,
      user: _user(resumeUrl: 'https://kaammilega.com/uploads/old.pdf'),
      onSuccess: () => succeeded = true,
      picker: () async =>
          PickedResume(name: 'cv.pdf', bytes: List<int>.filled(2048, 1)),
    );
    await tester.tap(find.bySemanticsLabel('Attach resume'));
    await tester.pumpAndSettle();
    expect(find.text('cv.pdf'), findsOneWidget);
    expect(find.text('2.0 KB • Attached'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' Can join Monday ');
    await tester.tap(find.text('Submit Application'));
    await tester.pumpAndSettle();

    expect(f.sent.map((o) => o.path), ['/files/upload', '/applications']);
    expect(f.sent.last.data, {
      'job_id': 'j1',
      'cover_letter': 'Can join Monday',
      'resume_url': _uploaded,
    });
    expect(succeeded, isTrue);
    expect(find.text('Application j1'), findsOneWidget);
  });

  testWidgets('removing the file sends the profile resume instead', (
    tester,
  ) async {
    final f = _fakeClient(_server);
    await _open(
      tester,
      client: f.client,
      user: _user(resumeUrl: 'https://kaammilega.com/uploads/old.pdf'),
      picker: () async =>
          PickedResume(name: 'cv.pdf', bytes: List<int>.filled(10, 1)),
    );
    expect(
      find.text('If you skip this, the resume on your profile is sent.'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Attach resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Application'));
    await tester.pumpAndSettle();

    expect(f.sent.map((o) => o.path), ['/applications']);
    expect(
      (f.sent.single.data as Map)['resume_url'],
      'https://kaammilega.com/uploads/old.pdf',
    );
  });

  testWidgets('upload failure keeps the sheet open and sends nothing', (
    tester,
  ) async {
    final f = _fakeClient((o) {
      if (o.path == '/files/upload') _fail(o, 500, 'disk full');
      return _server(o);
    });
    await _open(
      tester,
      client: f.client,
      picker: () async =>
          PickedResume(name: 'cv.pdf', bytes: List<int>.filled(10, 1)),
    );
    await tester.tap(find.bySemanticsLabel('Attach resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Application'));
    await tester.pumpAndSettle();

    expect(f.sent.map((o) => o.path), ['/files/upload']);
    expect(find.textContaining('Could not upload your resume'), findsOneWidget);
    expect(find.text('Apply for Position'), findsOneWidget);
  });

  testWidgets('409 already applied: sheet closes and the job is marked', (
    tester,
  ) async {
    final f = _fakeClient((o) => _fail(o, 409, 'already applied for this job'));
    var marked = false;
    await _open(tester, client: f.client, onSuccess: () => marked = true);
    await tester.tap(find.text('Submit Application'));
    await tester.pumpAndSettle();

    expect(marked, isTrue);
    expect(find.text('Apply for Position'), findsNothing);
    expect(find.text('You have already applied for this job.'), findsOneWidget);
  });

  testWidgets('a closed job (400) shows the server message', (tester) async {
    final f = _fakeClient(
      (o) =>
          _fail(o, 400, 'job is closed and no longer accepting applications'),
    );
    await _open(tester, client: f.client);
    await tester.tap(find.text('Submit Application'));
    await tester.pumpAndSettle();

    expect(
      find.text('job is closed and no longer accepting applications'),
      findsOneWidget,
    );
    expect(find.text('Apply for Position'), findsOneWidget);
  });

  testWidgets('Edit Profile closes the sheet and opens the profile', (
    tester,
  ) async {
    final f = _fakeClient(_server);
    await _open(tester, client: f.client);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile page'), findsOneWidget);
  });
}
