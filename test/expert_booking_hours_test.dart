import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/experts/models/expert_offering.dart';
import 'package:kaam_milega/features/experts/models/expert_profile.dart';
import 'package:kaam_milega/features/experts/presentation/expert_detail_screen.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _client(Response<dynamic> Function(RequestOptions o) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api'));
  dio.interceptors.add(
    InterceptorsWrapper(onRequest: (o, h) => h.resolve(respond(o))),
  );
  return ApiClient(dio: dio);
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210'),
  );
}

class _Wallet extends WalletNotifier {
  @override
  WalletState build() => const WalletState(summary: WalletSummary());

  @override
  Future<void> loadWallet() async {}
}

const _expert = ExpertItem(
  id: 'm1',
  expertId: 'e1',
  title: 'Mock interview',
  duration: 60,
  price: 0,
  expertName: 'Asha Rao',
);

Future<void> _pump(WidgetTester tester, List<dynamic> hours) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final client = _client((o) {
    if (o.path == '/mentorships/expert/e1/availability') {
      return Response<dynamic>(requestOptions: o, statusCode: 200, data: hours);
    }
    return Response<dynamic>(requestOptions: o, statusCode: 200, data: []);
  });
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_Auth.new),
        walletProvider.overrideWith(_Wallet.new),
        expertRepositoryProvider.overrideWithValue(ExpertRepository(client)),
      ],
      child: const MaterialApp(home: ExpertDetailScreen(expert: _expert)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  // Monday 5 Oct 2026, 09:00 local
  final monday9 = DateTime(2026, 10, 5, 9);
  const monday10to12 = WeeklyHours(
    dayOfWeek: 1,
    start: TimeOfDay(hour: 10, minute: 0),
    end: TimeOfDay(hour: 12, minute: 0),
  );

  test('slots: every 30 min where the whole session fits', () {
    final slots = WeeklyHours.slots(
      [monday10to12],
      monday9,
      60,
      earliest: monday9,
    );
    expect(slots, const [
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 10, minute: 30),
      TimeOfDay(hour: 11, minute: 0),
    ]);
  });

  test('slots: nothing before the earliest time; other days empty', () {
    final at1015 = DateTime(2026, 10, 5, 10, 15);
    expect(
      WeeklyHours.slots([monday10to12], monday9, 60, earliest: at1015),
      const [TimeOfDay(hour: 10, minute: 30), TimeOfDay(hour: 11, minute: 0)],
    );
    final tuesday = DateTime(2026, 10, 6);
    expect(
      WeeklyHours.slots([monday10to12], tuesday, 60, earliest: monday9),
      isEmpty,
    );
  });

  test('first bookable day skips days without hours or time left', () {
    // Monday 11:30: no 60-minute slot left today -> next Monday
    final late = DateTime(2026, 10, 5, 11, 30);
    expect(
      WeeklyHours.firstBookableDay([monday10to12], 60, earliest: late),
      DateTime(2026, 10, 12),
    );
    expect(WeeklyHours.firstBookableDay(const [], 60, earliest: late), isNull);
  });

  testWidgets("booking shows only the expert's free times", (tester) async {
    await _pump(tester, [
      for (var d = 0; d < 7; d++)
        {'day_of_week': d, 'start_time': '10:00', 'end_time': '12:00'},
    ]);
    expect(find.text('Available times'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.textContaining('has not set fixed hours'), findsNothing);
  });

  testWidgets('expert without hours: free choice, expert confirms', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.textContaining('has not set fixed hours'), findsOneWidget);
    expect(find.text('Available times'), findsNothing);
  });
}
