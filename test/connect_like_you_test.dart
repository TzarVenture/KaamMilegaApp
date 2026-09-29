import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/home/presentation/widgets/connect_like_you_section.dart';
import 'package:kaam_milega/features/network/presentation/member_profile_screen.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:kaam_milega/features/network/repositories/network_repository.dart';
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

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

/// Public people list as km-backend returns it (a bare array of users,
/// which also carries contact fields the app must not show).
final _people = [
  {'id': 'me', 'name': 'Me Myself', 'mobile': '9000000000'},
  {
    'id': 'u2',
    'name': 'Asha Verma',
    'headline': 'Delivery Partner',
    'city': 'Pune',
    'mobile': '9111111111',
    'email': 'asha@example.com',
  },
  {'id': 'u3', 'name': 'Ravi Kumar', 'mobile': '9222222222'},
];

/// /community/users, /network/status/:id (u2 is already connected) and
/// /network/connect (then u3 becomes pending).
Response<dynamic> Function(RequestOptions) _backend() {
  final requested = <String>{};
  return (o) {
    if (o.path == '/community/users') return _ok(o, _people);
    if (o.path == '/user/u2') {
      return _ok(o, {
        ..._people[1],
        'about': 'Five years in last-mile delivery.',
        'skills': ['Two-wheeler', 'Route planning'],
        'experience': [
          <String, dynamic>{
            'title': 'Delivery Partner',
            'company_name': 'QuickShip',
          },
        ],
      });
    }
    if (o.path == '/user/private-one') {
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: o,
          statusCode: 403,
          data: <String, dynamic>{
            'error': 'This profile is private',
            'visible': false,
          },
        ),
      );
    }
    if (o.path.startsWith('/network/status/')) {
      final id = o.path.split('/').last;
      final status = id == 'u2'
          ? 'accepted'
          : (requested.contains(id) ? 'pending' : '');
      return _ok(o, {'status': status});
    }
    if (o.path == '/network/connect') {
      requested.add((o.data as Map)['receiver_id'] as String);
      return _ok(o, {'message': 'Invitation sent'});
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
  };
}

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000'),
  );
}

class _Guest extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isGuest: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> storage({String? token}) async {
    SharedPreferences.setMockInitialValues(
      token == null ? {} : {'km_auth_token': token},
    );
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  }

  test('people: GET /community/users, never yourself, at most 8', () async {
    await storage(token: 't');
    final many = [
      {'id': 'me', 'name': 'Me'},
      for (var i = 0; i < 12; i++) {'id': 'p$i', 'name': 'Person $i'},
    ];
    final f = _fakeClient((o) => _ok(o, many));
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        networkRepositoryProvider.overrideWithValue(
          NetworkRepository(f.client),
        ),
      ],
    );
    addTearDown(container.dispose);

    final people = await container.read(communityUsersProvider.future);
    expect(people.length, 8);
    expect(people.any((u) => u.id == 'me'), isFalse);
    expect(f.sent.single.path, '/community/users');
  });

  Future<List<RequestOptions>> pump(
    WidgetTester tester, {
    required bool signedIn,
  }) async {
    await storage(token: signedIn ? 't' : null);
    final f = _fakeClient(_backend());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(signedIn ? _SignedIn.new : _Guest.new),
          networkRepositoryProvider.overrideWithValue(
            NetworkRepository(f.client),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ConnectLikeYouSection())),
      ),
    );
    await tester.pumpAndSettle();
    return f.sent;
  }

  testWidgets('guest sees people but must log in to connect', (tester) async {
    final sent = await pump(tester, signedIn: false);

    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    // Headline and city share one line; no filler text when both are empty
    expect(find.text('Delivery Partner · Pune'), findsOneWidget);
    expect(find.text('KaamMilega member'), findsNothing);
    // Contact details from the response are never shown
    expect(find.textContaining('9111111111'), findsNothing);
    expect(find.textContaining('asha@example.com'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Connect').first);
    await tester.pumpAndSettle();
    expect(find.text('Login Required'), findsOneWidget);
    expect(sent.where((o) => o.path.startsWith('/network')), isEmpty);
  });

  testWidgets('signed in: server status, connect, then pending', (
    tester,
  ) async {
    final sent = await pump(tester, signedIn: true);
    // The signed-in member never sees their own card
    expect(find.text('Me Myself'), findsNothing);

    final connected = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Connected'),
    );
    expect(connected.onPressed, isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
    await tester.pumpAndSettle();

    final connect = sent.singleWhere((o) => o.path == '/network/connect');
    expect(connect.data, {'receiver_id': 'u3'});
    expect(find.text('Connection request sent to Ravi Kumar.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pending'), findsOneWidget);
  });

  group('Member profile', () {
    Future<void> open(WidgetTester tester, String id) async {
      // Tall screen so every profile section is built (the list is lazy)
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await storage(token: 't');
      final f = _fakeClient(_backend());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_SignedIn.new),
            networkRepositoryProvider.overrideWithValue(
              NetworkRepository(f.client),
            ),
          ],
          child: MaterialApp(home: MemberProfileScreen(userId: id)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows public details, Connect and Message', (tester) async {
      await open(tester, 'u2');
      expect(find.text('Asha Verma'), findsWidgets);
      expect(find.text('Five years in last-mile delivery.'), findsOneWidget);
      expect(find.text('Route planning'), findsOneWidget);
      expect(find.text('QuickShip'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Connected'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      // Contact details from the response are never shown
      expect(find.textContaining('9111111111'), findsNothing);
      expect(find.textContaining('asha@example.com'), findsNothing);
    });

    testWidgets('private profile (403) says so', (tester) async {
      await open(tester, 'private-one');
      expect(find.text('This profile is private'), findsOneWidget);
    });
  });
}
