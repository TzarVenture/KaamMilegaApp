import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/chat/providers/user_lookup_provider.dart';
import 'package:kaam_milega/features/network/models/connection_request.dart';
import 'package:kaam_milega/features/network/presentation/network_screen.dart';
import 'package:kaam_milega/features/network/providers/network_provider.dart';
import 'package:kaam_milega/features/network/repositories/network_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'me', mobile: '9000000000', isRegistered: true),
  );
}

/// Records what the screen asks the server to do.
class _Network extends NetworkRepository {
  _Network() : super(ApiClient());

  final calls = <String>[];

  @override
  Future<void> acceptInvitation(String senderId) async =>
      calls.add('accept $senderId');

  @override
  Future<void> ignoreInvitation(String senderId) async =>
      calls.add('ignore $senderId');

  @override
  Future<void> deleteConnection(String otherUserId) async =>
      calls.add('remove $otherUserId');

  @override
  Future<void> recordImpressions(List<String> authorIds) async {}
}

const _people = {
  'c1': UserProfile(
    id: 'c1',
    mobile: '',
    name: 'Anwar Khan',
    headline: 'Painter',
    city: 'Mumbai',
  ),
  's1': UserProfile(
    id: 's1',
    mobile: '',
    name: 'Dilip Kumar',
    headline: 'Self respect',
    city: 'Ahmedabad',
  ),
  's2': UserProfile(id: 's2', mobile: '', name: 'Aditya Raj', city: 'Delhi'),
  'r1': UserProfile(
    id: 'r1',
    mobile: '',
    name: 'Harahad Shelke',
    headline: 'Telecaller',
  ),
};

Future<_Network> _pump(WidgetTester tester, {int tab = 0}) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = _Network();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => NetworkScreen(initialTab: tab),
      ),
      GoRoute(
        path: '/members/:id',
        builder: (_, s) =>
            Scaffold(body: Text('member ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/experts',
        builder: (_, _) => const Scaffold(body: Text('experts page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        networkRepositoryProvider.overrideWithValue(repo),
        networkSuggestionsProvider.overrideWith(
          (ref) async => [_people['c1']!, _people['s1']!, _people['s2']!],
        ),
        connectionsProvider.overrideWith((ref) async => ['c1']),
        pendingInvitationsProvider.overrideWith(
          (ref) async => const [
            ConnectionRequestItem(
              id: 'q1',
              senderId: 'r1',
              receiverId: 'me',
              status: 'pending',
            ),
          ],
        ),
        userLookupProvider.overrideWith((ref, id) async => _people[id]),
        connectionStatusProvider.overrideWith(
          (ref, id) async => id == 'c1' ? 'accepted' : '',
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'jwt'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  testWidgets('Grow Network: suggestions, hide with X, links, mentor card', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('People You May Know'), findsOneWidget);
    expect(find.text('View Connections (1)'), findsOneWidget);
    // Already connected people are not suggested.
    expect(find.text('Dilip Kumar'), findsOneWidget);
    expect(find.text('Aditya Raj'), findsOneWidget);
    expect(find.text('Anwar Khan'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Connect'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Hide Dilip Kumar'));
    await tester.pumpAndSettle();
    expect(find.text('Dilip Kumar'), findsNothing);
    expect(find.text('Aditya Raj'), findsOneWidget);

    expect(find.text('Verified Experts'), findsOneWidget);
    expect(find.text('Networking Events'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Become a Verified Mentor'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('Become a Verified Mentor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.text('Verified Experts'),
      find.byType(ListView).first,
      const Offset(0, 200),
    );
    await tester.tap(find.text('Verified Experts'));
    await tester.pumpAndSettle();
    expect(find.text('experts page'), findsOneWidget);
  });

  testWidgets('Connections: real names, Message, remove after confirming', (
    tester,
  ) async {
    final repo = await _pump(tester, tab: NetworkScreen.connectionsTab);
    expect(find.text('Anwar Khan'), findsOneWidget);
    expect(find.text('Painter · Mumbai'), findsOneWidget);
    expect(find.textContaining('Member #'), findsNothing);
    final message = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Message'),
    );
    expect(message.onPressed, isNotNull);

    await tester.tap(find.byTooltip('More options for Anwar Khan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove connection'));
    await tester.pumpAndSettle();
    expect(find.text('Remove connection?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['remove c1']);
  });

  testWidgets('Invitations: who sent it, Accept and Ignore', (tester) async {
    final repo = await _pump(tester, tab: NetworkScreen.invitationsTab);
    expect(find.text('Harahad Shelke'), findsOneWidget);
    expect(find.text('Wants to connect with you'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Accept'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['accept r1']);
    expect(
      find.text('You are now connected with Harahad Shelke.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ignore'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'ignore r1');
  });
}
