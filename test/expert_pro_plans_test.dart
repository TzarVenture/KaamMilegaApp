import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/core/payments/razorpay_checkout.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/experts/models/expert_plan.dart';
import 'package:kaam_milega/features/experts/presentation/apply_expert_screen.dart';
import 'package:kaam_milega/features/experts/providers/expert_plan_provider.dart';
import 'package:kaam_milega/features/experts/repositories/expert_repository.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
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

DioException _status(RequestOptions o, int code, String error) => DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: {'error': error},
  ),
);

/// Same values and perks as the backend's GetPlans.
const _plansJson = [
  {
    'plan_type': 'monthly',
    'name': 'Monthly Pro Expert',
    'price': 499.0,
    'duration_days': 30,
    'savings_percent': 0,
    'description':
        'Flexible month-to-month access to monetize your industry expertise.',
    'perks': [
      'Verified Pro Expert Badge on Profile',
      'Host Unlimited Paid 1-on-1 Mentorship Calls',
    ],
  },
  {
    'plan_type': 'yearly',
    'name': 'Annual Pro Expert',
    'price': 4499.0,
    'duration_days': 365,
    'savings_percent': 25,
    'description': 'Best value plan for dedicated professionals.',
    'perks': [
      'All Monthly Pro Expert Perks',
      'Annual Verified Mentor Certificate',
    ],
  },
];

final _plans = _plansJson.map(ExpertPlan.fromJson).toList();

class _Auth extends AuthNotifier {
  int refreshes = 0;

  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210'),
  );

  @override
  Future<void> refreshProfile() async => refreshes++;
}

/// Wallet that never calls the server; counts reloads.
class _Wallet extends WalletNotifier {
  int loads = 0;

  @override
  WalletState build() => const WalletState();

  @override
  Future<void> loadWallet() async => loads++;
}

/// Stands in for the Razorpay screen; records the orders it was opened for.
ExpertPlanPaymentLauncher _launcher(
  RazorpayResult result,
  List<String> opened,
) =>
    ({
      required String keyId,
      required String orderId,
      required int amountPaise,
      required String description,
      String? email,
      String? contact,
    }) async {
      opened.add('$orderId:$amountPaise');
      return result;
    };

final _paid = RazorpayResult.paid(
  paymentId: 'pay_1',
  orderId: 'order_1',
  signature: 'sig_1',
);

/// Routes the subscription endpoints like the backend.
Response<dynamic> Function(RequestOptions) _backend({
  DioException Function(RequestOptions o)? verifyError,
  DioException Function(RequestOptions o)? walletError,
}) {
  return (o) {
    switch (o.path) {
      case '/subscriptions/expert/plans':
        return _ok(o, _plansJson);
      case '/subscriptions/expert/my':
        return _ok(o, {'is_active': false, 'days_remaining': 0});
      case '/subscriptions/expert/create-order':
        final yearly = (o.data as Map)['plan_type'] == 'yearly';
        return _ok(o, {
          'order_id': 'order_1',
          'amount': yearly ? 4499.0 : 499.0,
          'amount_paise': yearly ? 449900 : 49900,
          'currency': 'INR',
          'key_id': 'rzp_test_key',
          'plan_type': (o.data as Map)['plan_type'],
        });
      case '/subscriptions/expert/verify-payment':
        if (verifyError != null) throw verifyError(o);
        return _ok(o, {
          'message': 'Expert Pro Subscription activated successfully!',
          'subscription': {'plan_type': (o.data as Map)['plan_type']},
        });
      case '/subscriptions/expert/wallet-checkout':
        if (walletError != null) throw walletError(o);
        return _ok(o, {
          'message':
              'Expert Pro Subscription activated successfully via Wallet!',
          'subscription': {'plan_type': (o.data as Map)['plan_type']},
          'wallet_summary': {'main_balance': 1},
        });
    }
    throw _status(o, 404, 'not found');
  };
}

List<Override> _overrides(ApiClient client, ExpertPlanPaymentLauncher pay) => [
  authProvider.overrideWith(_Auth.new),
  walletProvider.overrideWith(_Wallet.new),
  expertRepositoryProvider.overrideWithValue(ExpertRepository(client)),
  expertPlanPaymentLauncherProvider.overrideWithValue(pay),
];

ProviderContainer _container(ApiClient client, ExpertPlanPaymentLauncher pay) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: _overrides(client, pay),
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpScreen(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // No automatic retries, so failures show at once in tests.
      retry: (_, _) => null,
      overrides: overrides,
      child: const MaterialApp(home: ApplyExpertScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  group('Pro Expert plan model', () {
    test('reads the backend plan, prices in rupees', () {
      final monthly = _plans[0];
      final yearly = _plans[1];
      expect(monthly.priceLabel, '₹499');
      expect(monthly.periodLabel, 'month');
      expect(monthly.perMonthLabel, isNull);
      expect(monthly.shortName, 'Monthly');
      expect(yearly.priceLabel, '₹4,499');
      expect(yearly.periodLabel, 'year');
      expect(yearly.perMonthLabel, '₹375');
      expect(yearly.shortName, 'Annual');
      expect(yearly.perks, hasLength(2));
    });

    test('status: active plan with days left and end date', () {
      final s = ExpertSubscriptionStatus.fromJson({
        'is_active': true,
        'days_remaining': 300,
        'plan_type': 'yearly',
        'expires_at': '2027-08-12T10:00:00Z',
      });
      expect(s.isActive, isTrue);
      expect(s.planType, 'yearly');
      expect(s.daysRemaining, 300);
      expect(s.expiresLabel, contains('2027'));
      expect(
        ExpertSubscriptionStatus.fromJson({'is_active': false}).isActive,
        isFalse,
      );
    });
  });

  group('Pro Expert repository', () {
    test('plans: bare array, plans without price are skipped', () async {
      final f = _fakeClient(
        (o) => _ok(o, [
          ..._plansJson,
          {'plan_type': 'free', 'name': 'Free', 'price': 0},
        ]),
      );
      final plans = await ExpertRepository(f.client).getExpertPlans();
      expect(plans.map((p) => p.planType), ['monthly', 'yearly']);
      expect(f.sent.single.path, '/subscriptions/expert/plans');
    });

    test('a reply without the subscription is not a success', () async {
      final f = _fakeClient((o) => _ok(o, {'message': 'ok'}));
      expect(
        () => ExpertRepository(f.client).buyExpertPlanWithWallet('monthly'),
        throwsA(anything),
      );
    });
  });

  group('Pro Expert checkout', () {
    test(
      'online: order, Razorpay, then server verify with plan type',
      () async {
        final f = _fakeClient(_backend());
        final opened = <String>[];
        final c = _container(f.client, _launcher(_paid, opened));

        final result = await c
            .read(expertPlanCheckoutProvider)
            .payOnline(_plans[1]);

        expect(result.outcome, ExpertPlanOutcome.success);
        expect(opened, ['order_1:449900']);
        final verify = f.sent.last;
        expect(verify.path, '/subscriptions/expert/verify-payment');
        expect(verify.data, {
          'plan_type': 'yearly',
          'razorpay_order_id': 'order_1',
          'razorpay_payment_id': 'pay_1',
          'razorpay_signature': 'sig_1',
        });
        // Role changes on the server: profile and wallet are reloaded.
        expect((c.read(authProvider.notifier) as _Auth).refreshes, 1);
        expect((c.read(walletProvider.notifier) as _Wallet).loads, 1);
      },
    );

    test('cancelled checkout: nothing is verified', () async {
      final f = _fakeClient(_backend());
      final c = _container(
        f.client,
        _launcher(RazorpayResult.cancelled(), <String>[]),
      );
      final result = await c
          .read(expertPlanCheckoutProvider)
          .payOnline(_plans[0]);
      expect(result.outcome, ExpertPlanOutcome.cancelled);
      expect(
        f.sent.map((o) => o.path),
        isNot(contains('/subscriptions/expert/verify-payment')),
      );
    });

    test('paid but verify failed: keeps the payment for a retry', () async {
      final f = _fakeClient(
        _backend(verifyError: (o) => _status(o, 400, 'try later')),
      );
      final c = _container(f.client, _launcher(_paid, <String>[]));
      final result = await c
          .read(expertPlanCheckoutProvider)
          .payOnline(_plans[0]);
      expect(result.outcome, ExpertPlanOutcome.paidButUnconfirmed);
      expect(result.payment?.paymentId, 'pay_1');
      expect(result.message, contains('pay_1'));
    });

    test('wallet refused: server message shown, no success', () async {
      final f = _fakeClient(
        _backend(
          walletError: (o) => _status(
            o,
            400,
            'insufficient wallet balance: required ₹499.00, available ₹0.00',
          ),
        ),
      );
      final c = _container(f.client, _launcher(_paid, <String>[]));
      final result = await c
          .read(expertPlanCheckoutProvider)
          .payWithWallet(_plans[0]);
      expect(result.outcome, ExpertPlanOutcome.failed);
      expect(result.message, startsWith('Insufficient wallet balance'));
      expect(f.sent.last.data, {'plan_type': 'monthly'});
    });

    test('wallet: success', () async {
      final f = _fakeClient(_backend());
      final c = _container(f.client, _launcher(_paid, <String>[]));
      final result = await c
          .read(expertPlanCheckoutProvider)
          .payWithWallet(_plans[0]);
      expect(result.outcome, ExpertPlanOutcome.success);
      expect(f.sent.last.path, '/subscriptions/expert/wallet-checkout');
    });
  });

  group('Apply to be an Expert screen', () {
    testWidgets('shows the Pro Expert plans instead of the old form', (
      tester,
    ) async {
      final f = _fakeClient(_backend());
      await _pumpScreen(tester, _overrides(f.client, _launcher(_paid, [])));

      expect(find.text('KAAMMILEGA PRO EXPERT PROGRAM'), findsOneWidget);
      expect(find.text('Monthly Pro Expert'), findsOneWidget);
      expect(find.text('Annual Pro Expert'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('₹4,499'), findsOneWidget);
      expect(find.text('(₹375/mo)'), findsOneWidget);
      expect(find.text('Save 25% Annually'), findsOneWidget);
      expect(find.text('BEST VALUE'), findsOneWidget);
      expect(find.text("WHAT'S INCLUDED"), findsNWidgets(2));
      expect(find.text('Annual Verified Mentor Certificate'), findsOneWidget);
      expect(find.text('Upgrade to Monthly'), findsOneWidget);
      expect(find.text('Upgrade to Annual'), findsOneWidget);
      // Old application form is gone
      expect(find.text('Bio'), findsNothing);
      expect(find.text('Hourly Mentorship Rate (₹)'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('upgrade online: sheet, payment, then plan active', (
      tester,
    ) async {
      final f = _fakeClient(_backend());
      final opened = <String>[];
      await _pumpScreen(tester, _overrides(f.client, _launcher(_paid, opened)));

      await tester.tap(find.text('Upgrade to Annual'));
      await tester.pumpAndSettle();
      expect(find.text('Pay ₹4,499 for Annual Pro Expert'), findsOneWidget);

      await tester.tap(find.text('Pay online'));
      await tester.pumpAndSettle();

      expect(opened, ['order_1:449900']);
      expect(find.text('Welcome, Pro Expert'), findsOneWidget);
    });

    testWidgets('active plan: current plan marked, no second purchase', (
      tester,
    ) async {
      final f = _fakeClient(_backend());
      await _pumpScreen(tester, [
        ..._overrides(f.client, _launcher(_paid, [])),
        myExpertSubscriptionProvider.overrideWith(
          (ref) async => ExpertSubscriptionStatus(
            isActive: true,
            planType: 'yearly',
            daysRemaining: 300,
            expiresAt: DateTime(2027, 8, 12),
          ),
        ),
      ]);

      expect(find.text('You are a Pro Expert'), findsOneWidget);
      expect(find.text('Current plan'), findsOneWidget);
      expect(
        find.text('Available after your current plan ends'),
        findsOneWidget,
      );
      final buttons = tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });

    testWidgets('plan status failed: upgrades paused, Retry shown', (
      tester,
    ) async {
      final f = _fakeClient(_backend());
      await _pumpScreen(tester, [
        ..._overrides(f.client, _launcher(_paid, [])),
        myExpertSubscriptionProvider.overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      ]);

      expect(find.text('Could not check your current plan'), findsOneWidget);
      final buttons = tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });

    testWidgets('plans failed: error with Retry, not an empty page', (
      tester,
    ) async {
      final f = _fakeClient(_backend());
      await _pumpScreen(tester, [
        ..._overrides(f.client, _launcher(_paid, [])),
        expertPlansProvider.overrideWith(
          (ref) async => throw Exception('offline'),
        ),
      ]);

      expect(find.text('Could not load the plans'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
