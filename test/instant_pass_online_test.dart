import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/payments/razorpay_checkout.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/instant_work/models/instant_candidate.dart';
import 'package:kaam_milega/features/instant_work/presentation/widgets/instant_availability_card.dart';
import 'package:kaam_milega/features/instant_work/providers/instant_candidate_provider.dart';
import 'package:kaam_milega/features/instant_work/repositories/instant_candidate_repository.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request locally (no network); records each request.
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

Response<dynamic> _ok(RequestOptions o, dynamic data) =>
    Response<dynamic>(requestOptions: o, statusCode: 200, data: data);

Never _fail(RequestOptions o, int code) => throw DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: o,
    statusCode: code,
    data: {'error': 'activation failed'},
  ),
);

/// As the backend sends it: `amount` in paise, `pass_inr` in rupees.
const _order = {
  'key_id': 'rzp_test_key',
  'order_id': 'order_pass_1',
  'amount': 9900,
  'pass_inr': 99.0,
};

final _status = {
  'is_free_now': false,
  'active_skill': '',
  'hourly_rate': 0,
  'quota_remaining': 0,
  'has_active_pass': false,
};

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: UserProfile(id: 'u1', mobile: '9876543210', email: 'a@b.in'),
  );
}

class _Wallet extends WalletNotifier {
  @override
  WalletState build() =>
      const WalletState(summary: WalletSummary(mainBalance: 20));

  @override
  Future<void> loadWallet() async {}
}

/// Records each checkout request; never opens a real payment screen.
class _Checkout {
  _Checkout(this.result);
  RazorpayResult result;
  final calls = <Map<String, Object?>>[];

  Future<RazorpayResult> launch({
    required String keyId,
    required String orderId,
    required int amountPaise,
    required String description,
    String? email,
    String? contact,
  }) async {
    calls.add({
      'keyId': keyId,
      'orderId': orderId,
      'amountPaise': amountPaise,
      'contact': contact,
    });
    return result;
  }
}

final _paid = RazorpayResult.paid(
  paymentId: 'pay_1',
  orderId: 'order_pass_1',
  signature: 'sig_1',
);

Future<void> _openSheet(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showInstantPassSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

List<Override> _overrides(
  ApiClient client,
  _Checkout checkout, {
  bool online = true,
}) => [
  authProvider.overrideWith(_Auth.new),
  walletProvider.overrideWith(_Wallet.new),
  instantCandidateRepositoryProvider.overrideWithValue(
    InstantCandidateRepository(client),
  ),
  paymentLauncherProvider.overrideWithValue(checkout.launch),
  instantPassOnlinePaymentProvider.overrideWithValue(online),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'km_auth_token': 'test-token'});
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  });

  test('online payment stays off until the backend double charge is fixed', () {
    expect(InstantPassTerms.onlinePaymentLive, isFalse);
  });

  test('pass order: amount is read as paise; verify sends the ids', () async {
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/pass/order') return _ok(o, _order);
      if (o.path == '/instant-work/pass/verify') {
        return _ok(o, {'has_active_pass': true, 'quota_remaining': 10});
      }
      throw StateError('unexpected ${o.path}');
    });
    final repo = InstantCandidateRepository(f.client);

    final order = await repo.createPassOrder();
    expect(order.amountPaise, 9900);
    expect(order.amount, 99);
    expect(order.keyId, 'rzp_test_key');

    await repo.verifyPassPayment(
      orderId: 'order_pass_1',
      paymentId: 'pay_1',
      signature: 'sig_1',
    );
    expect(f.sent.last.data, {
      'razorpay_order_id': 'order_pass_1',
      'razorpay_payment_id': 'pay_1',
      'razorpay_signature': 'sig_1',
    });
  });

  testWidgets('pays online and activates only after server verification', (
    tester,
  ) async {
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') return _ok(o, _status);
      if (o.path == '/instant-work/pass/order') return _ok(o, _order);
      if (o.path == '/instant-work/pass/verify') {
        return _ok(o, {'has_active_pass': true});
      }
      throw StateError('unexpected ${o.path}');
    });
    final checkout = _Checkout(_paid);
    await _openSheet(tester, _overrides(f.client, checkout));

    // Benefits (point 31) are shown with the pass
    expect(find.text('Get instant jobs'), findsOneWidget);
    expect(find.text('Earn money instantly'), findsOneWidget);

    // Wallet has only Rs 20: online is the way to pay
    await tester.tap(find.text('Online payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay ₹99 online'));
    await tester.pumpAndSettle();

    expect(checkout.calls.single['amountPaise'], 9900);
    expect(checkout.calls.single['orderId'], 'order_pass_1');
    expect(checkout.calls.single['contact'], '9876543210');
    expect(
      f.sent.map((o) => o.path),
      containsAllInOrder([
        '/instant-work/pass/order',
        '/instant-work/pass/verify',
      ]),
    );
    expect(find.textContaining('Payment verified'), findsOneWidget);
  });

  testWidgets('cancelled checkout: nothing verified, nothing charged', (
    tester,
  ) async {
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') return _ok(o, _status);
      if (o.path == '/instant-work/pass/order') return _ok(o, _order);
      throw StateError('unexpected ${o.path}');
    });
    final checkout = _Checkout(RazorpayResult.cancelled());
    await _openSheet(tester, _overrides(f.client, checkout));

    await tester.tap(find.text('Online payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay ₹99 online'));
    await tester.pumpAndSettle();

    expect(
      find.text('Payment cancelled. No money was charged.'),
      findsOneWidget,
    );
    expect(f.sent.where((o) => o.path == '/instant-work/pass/verify'), isEmpty);
  });

  testWidgets('paid but not verified: retry activation, never pay again', (
    tester,
  ) async {
    var verifyWorks = false;
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') return _ok(o, _status);
      if (o.path == '/instant-work/pass/order') return _ok(o, _order);
      if (o.path == '/instant-work/pass/verify') {
        if (!verifyWorks) _fail(o, 500);
        return _ok(o, {'has_active_pass': true});
      }
      throw StateError('unexpected ${o.path}');
    });
    final checkout = _Checkout(_paid);
    await _openSheet(tester, _overrides(f.client, checkout));

    await tester.tap(find.text('Online payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay ₹99 online'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Please do not pay again'), findsOneWidget);
    expect(find.textContaining('pay_1'), findsOneWidget);
    expect(find.text('Pay ₹99 online'), findsNothing); // no second payment
    expect(find.text('Retry activation'), findsOneWidget);

    verifyWorks = true;
    await tester.tap(find.text('Retry activation'));
    await tester.pumpAndSettle();

    expect(checkout.calls, hasLength(1)); // paid once only
    expect(
      f.sent.where((o) => o.path == '/instant-work/pass/verify'),
      hasLength(2),
    );
    expect(find.textContaining('Payment verified'), findsOneWidget);
  });

  testWidgets('switched off: online tile disabled, wallet only', (
    tester,
  ) async {
    final f = _fakeClient((o) {
      if (o.path == '/instant-work/candidate/status') return _ok(o, _status);
      throw StateError('unexpected ${o.path}');
    });
    final checkout = _Checkout(_paid);
    await _openSheet(tester, _overrides(f.client, checkout, online: false));

    expect(find.text('Temporarily unavailable'), findsOneWidget);
    await tester.tap(find.text('Online payment'));
    await tester.pumpAndSettle();
    expect(find.text('Pay ₹99 online'), findsNothing);
    expect(find.text('Pay ₹99 from KaamMilega Wallet'), findsOneWidget);
    expect(checkout.calls, isEmpty);
  });
}
