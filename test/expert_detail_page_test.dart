import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
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
  WalletState build() =>
      const WalletState(summary: WalletSummary(mainBalance: 1000));

  @override
  Future<void> loadWallet() async {}
}

ExpertItem _expert({
  String description = 'Real interview practice and feedback.',
  List<String> languages = const [],
  List<String> takeaways = const [],
}) => ExpertItem(
  id: 'm1',
  expertId: 'e1',
  title: '1-on-1 Mock Interview',
  description: description,
  category: 'Interview Prep',
  duration: 45,
  price: 499,
  expertName: 'Reeta Patel',
  expertHeadline: 'HR Lead',
  expertBio: 'Ten years of hiring.',
  languages: languages,
  takeaways: takeaways,
);

/// The one day (two days from now) the mentor works, 10:00 to 12:00.
DateTime get _workDay =>
    DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2));

Future<void> _pump(
  WidgetTester tester,
  ExpertItem expert, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = _client((o) {
    if (o.path == '/mentorships/expert/e1/availability') {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: [
          {
            'day_of_week': _workDay.weekday % 7,
            'start_time': '10:00',
            'end_time': '12:00',
          },
        ],
      );
    }
    if (o.path == '/mentorships/expert/e1/reviews') {
      return Response<dynamic>(
        requestOptions: o,
        statusCode: 200,
        data: {
          'average_rating': 0,
          'total_reviews': 0,
          'distribution': <String, dynamic>{},
          'reviews': <dynamic>[],
        },
      );
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
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ExpertDetailScreen(expert: expert),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  testWidgets('header, fee, 7-day grid with Off days, session window', (
    tester,
  ) async {
    await _pump(tester, _expert());
    expect(tester.takeException(), isNull);
    expect(find.text('INTERVIEW PREP'), findsOneWidget);
    expect(find.text('New'), findsOneWidget); // no reviews: no invented score
    expect(find.text('1-on-1 Mock Interview'), findsOneWidget);
    expect(find.text('45 Mins'), findsOneWidget);
    expect(find.text('1-on-1'), findsOneWidget);
    expect(find.text('LANGUAGES'), findsNothing); // backend does not send it
    expect(find.text('SESSION FEE'), findsOneWidget);

    // Only the work day is open; the first free slot is chosen for it.
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Off'), findsNWidgets(6));
    expect(find.text('Session Window: 10:00 AM – 12:00 PM'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '10:00 AM'), findsOneWidget);
    final first = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '10:00 AM'),
    );
    expect(first.selected, isTrue);

    // Fixed bottom bar
    expect(
      find.text('₹499'),
      findsOneWidget,
    ); // bottom bar (fee card is rich text)
    expect(find.text('Book Session'), findsOneWidget);
    expect(
      find.text('Protected by KaamMilega Escrow Guarantee'),
      findsOneWidget,
    );
  });

  testWidgets('about, mentor and reviews come from the backend data', (
    tester,
  ) async {
    await _pump(tester, _expert());
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Real interview practice and feedback.'),
      200,
      scrollable: list,
    );
    expect(find.text('About this Mentorship Session'), findsOneWidget);
    expect(find.text('Key Takeaways from this session:'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ten years of hiring.'),
      200,
      scrollable: list,
    );
    expect(find.text('Meet Your Mentor'), findsOneWidget);
    expect(find.text('Reeta Patel'), findsOneWidget);
    expect(find.text('HR Lead'), findsOneWidget);
    expect(find.text('Top Rated Mentor'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('No Reviews Yet'),
      200,
      scrollable: list,
    );
    expect(find.text('Candidate Ratings & Reviews'), findsOneWidget);
  });

  testWidgets('languages and takeaways show once the backend sends them', (
    tester,
  ) async {
    await _pump(
      tester,
      _expert(
        languages: const ['Hindi', 'English'],
        takeaways: const ['Personal career roadmap'],
      ),
    );
    expect(find.text('Hindi / English'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Personal career roadmap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Key Takeaways from this session:'), findsOneWidget);
  });

  testWidgets('no description and no takeaways: About is hidden', (
    tester,
  ) async {
    await _pump(tester, _expert(description: ''));
    await tester.scrollUntilVisible(
      find.text('Meet Your Mentor'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('About this Mentorship Session'), findsNothing);
  });

  testWidgets('Book Session opens the checkout for the chosen slot', (
    tester,
  ) async {
    await _pump(tester, _expert());
    await tester.tap(find.text('Book Session'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm & Checkout'), findsOneWidget);
    expect(find.text('10:00 AM (45 mins)'), findsOneWidget);
  });

  testWidgets('parses languages and key_takeaways when present', (
    tester,
  ) async {
    final item = ExpertItem.fromJson({
      'mentorship': {
        'id': 'm1',
        'expert_id': 'e1',
        'title': 'T',
        'languages': ['Hindi', ' English ', ''],
        'key_takeaways': 'One, Two',
      },
      'expert': {'id': 'e1', 'name': 'A'},
    });
    expect(item.languages, ['Hindi', 'English']);
    expect(item.takeaways, ['One', 'Two']);
    expect(item.expertHeadline, ''); // no invented headline
    final none = ExpertItem.fromJson({'id': 'm2', 'title': 'T'});
    expect(none.languages, isEmpty);
    expect(none.takeaways, isEmpty);
  });

  testWidgets('fits a 320px phone with large text', (tester) async {
    await _pump(
      tester,
      _expert(languages: const ['Hindi', 'English']),
      size: const Size(320, 568),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Book Session'), findsOneWidget);
  });
}
