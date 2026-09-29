import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:kaam_milega/features/peer_to_peer/presentation/peer_to_peer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request locally (no network).
ApiClient _fakeClient() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, handler) {
        // Suggestions come from the public member list, not a search
        if (o.path == '/community/users') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: [
                {
                  'id': 'p1',
                  'name': 'Priya Sharma',
                  'headline': 'Delivery Partner',
                  'city': 'Pune',
                },
              ],
            ),
          );
        } else if (o.path.startsWith('/network/status/')) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: o,
              statusCode: 200,
              data: {'status': ''},
            ),
          );
        } else {
          handler.reject(
            DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(requestOptions: o, statusCode: 404),
            ),
          );
        }
      },
    ),
  );
  return ApiClient(dio: dio);
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9876543210', name: 'Me Myself'),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  testWidgets('People You May Know: tap opens profile; Connect and Message', (
    tester,
  ) async {
    // Wide enough for the test font (wider than real fonts) in the
    // module's bottom bar.
    tester.view.physicalSize = const Size(1800, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PeerToPeerScreen()),
        GoRoute(
          path: '/members/:id',
          builder: (_, state) =>
              Scaffold(body: Text('member ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Auth.new),
          apiClientProvider.overrideWithValue(_fakeClient()),
          pendingInvitationsProvider.overrideWith((ref) async => const []),
          connectionsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Connect'), findsOneWidget);
    expect(find.byTooltip('Message Priya Sharma'), findsOneWidget);

    await tester.tap(find.text('Priya Sharma'));
    await tester.pumpAndSettle();
    expect(find.text('member p1'), findsOneWidget);
  });
}
