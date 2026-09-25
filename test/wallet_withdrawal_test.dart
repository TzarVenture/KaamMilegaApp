import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/core/network/api_client.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/models/withdrawal.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_withdraw_screen.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';
import 'package:kaam_milega/features/wallet/repositories/wallet_repository.dart';

/// Answers every request locally (no network): records the request and
/// returns [respond]'s response, or throws its DioException.
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

/// JSON bodies are `Map<String, dynamic>`, as Dio decodes them.
Response<dynamic> _json(
  RequestOptions o,
  int status,
  Map<String, Object> body,
) => Response<dynamic>(
  requestOptions: o,
  statusCode: status,
  data: Map<String, dynamic>.from(body),
);

DioException _httpError(
  RequestOptions o,
  int status,
  Map<String, Object> body,
) => DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: _json(o, status, body),
);

/// Wallet with ₹1,000 withdrawable earnings; records withdraw calls.
class _FakeWallet extends WalletNotifier {
  int calls = 0;
  WithdrawalRequest? last;

  @override
  WalletState build() => const WalletState(
    summary: WalletSummary(withdrawableBalance: 1000, earningsBalance: 1000),
  );

  @override
  Future<WithdrawalResult> withdraw(WithdrawalRequest request) async {
    calls++;
    last = request;
    return const WithdrawalResult(
      message:
          'Withdrawal request of ₹500.00 submitted successfully. '
          'Reference ID: WTH_test',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WithdrawalRequest (backend WithdrawalRequest body)', () {
    test('UPI sends payout_method "upi" + upi_id, no bank fields', () {
      const req = WithdrawalRequest.upi(
        amount: 500,
        upiId: ' ravi@okhdfcbank ',
        phoneNumber: '9876543210',
      );
      expect(req.toJson(), {
        'amount': 500.0,
        'payout_method': 'upi',
        'phone_number': '9876543210',
        'upi_id': 'ravi@okhdfcbank',
      });
    });

    test('bank sends account_number + ifsc_code (+ optional fields)', () {
      const req = WithdrawalRequest.bank(
        amount: 750,
        accountNumber: '123456789012',
        ifscCode: 'hdfc0000123',
        accountHolder: 'Ravi Kumar',
        bankName: 'HDFC Bank',
      );
      expect(req.toJson(), {
        'amount': 750.0,
        'payout_method': 'bank',
        'account_holder': 'Ravi Kumar',
        'account_number': '123456789012',
        'ifsc_code': 'HDFC0000123',
        'bank_name': 'HDFC Bank',
      });
      expect(req.maskedDestination, 'HDFC Bank ••••9012');
    });

    test('empty optional fields are not sent', () {
      const req = WithdrawalRequest.bank(
        amount: 50,
        accountNumber: '123456789',
        ifscCode: 'SBIN0001234',
      );
      expect(req.toJson().keys.toSet(), {
        'amount',
        'payout_method',
        'account_number',
        'ifsc_code',
      });
    });

    test('limits match the backend (₹50 – ₹5,00,000)', () {
      expect(WithdrawalRequest.minAmount, 50);
      expect(WithdrawalRequest.maxAmount, 500000);
    });
  });

  group('WithdrawalResult (backend WithdrawalResponse)', () {
    test('parses message, wallet and reference id', () {
      final result = WithdrawalResult.fromJson({
        'message':
            'Withdrawal request of ₹500.00 submitted successfully. '
            'Reference ID: WTH_abc',
        'wallet': {'withdrawable_balance': 500, 'earnings_balance': 500},
        'transaction': {'reference_id': 'WTH_abc', 'amount': 500},
      });
      expect(result.message, contains('WTH_abc'));
      expect(result.wallet?.withdrawableBalance, 500);
      expect(result.referenceId, 'WTH_abc');
    });

    test('a success without a readable body still counts as submitted', () {
      final result = WithdrawalResult.fromJson('');
      expect(result.message, 'Withdrawal request submitted.');
      expect(result.wallet, isNull);
    });
  });

  group('WalletRepository.requestWithdrawal (no real payouts)', () {
    const request = WithdrawalRequest.upi(amount: 500, upiId: 'ravi@ybl');

    test(
      'POSTs the exact body to /wallet/withdraw and returns the result',
      () async {
        final fake = _fakeClient(
          (o) => _json(o, 200, {
            'message': 'Withdrawal request of ₹500.00 submitted successfully.',
            'wallet': {'withdrawable_balance': 0},
            'transaction': {'reference_id': 'WTH_1'},
          }),
        );
        final repository = WalletRepository(fake.client);
        final result = await repository.requestWithdrawal(request);

        expect(fake.sent, hasLength(1));
        expect(fake.sent.single.method, 'POST');
        expect(fake.sent.single.path, '/wallet/withdraw');
        expect(fake.sent.single.data, {
          'amount': 500.0,
          'payout_method': 'upi',
          'upi_id': 'ravi@ybl',
        });
        expect(result.referenceId, 'WTH_1');
        expect(result.wallet?.withdrawableBalance, 0);
      },
    );

    test('HTTP 400 shows the backend reason (nothing withdrawn)', () async {
      final fake = _fakeClient(
        (o) => throw _httpError(o, 400, {
          'error':
              'insufficient withdrawable earnings '
              '(available: ₹100.00, requested: ₹500.00)',
        }),
      );
      await expectLater(
        WalletRepository(fake.client).requestWithdrawal(request),
        throwsA(
          isA<WalletApiException>()
              .having((e) => e.message, 'message', contains('insufficient'))
              .having((e) => e.isOutcomeUnknown, 'unknown', isFalse)
              .having((e) => e.isBackendPending, 'pending', isFalse),
        ),
      );
    });

    test('HTTP 404 means the endpoint is not live ("coming soon")', () async {
      final fake = _fakeClient(
        (o) => throw _httpError(o, 404, {'error': 'Cannot POST'}),
      );
      await expectLater(
        WalletRepository(fake.client).requestWithdrawal(request),
        throwsA(
          isA<WalletApiException>().having(
            (e) => e.isBackendPending,
            'pending',
            isTrue,
          ),
        ),
      );
    });

    test(
      'timeout / 5xx: outcome unknown, user must check before retrying',
      () async {
        for (final respond in <Response<dynamic> Function(RequestOptions)>[
          (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.receiveTimeout,
          ),
          (o) => throw _httpError(o, 502, {'error': 'bad gateway'}),
        ]) {
          final fake = _fakeClient(respond);
          await expectLater(
            WalletRepository(fake.client).requestWithdrawal(request),
            throwsA(
              isA<WalletApiException>().having(
                (e) => e.isOutcomeUnknown,
                'unknown',
                isTrue,
              ),
            ),
          );
        }
      },
    );

    test('HTTP 401 stays an auth error (session expired)', () async {
      final fake = _fakeClient(
        (o) => throw _httpError(o, 401, {'error': 'Unauthorized'}),
      );
      await expectLater(
        WalletRepository(fake.client).requestWithdrawal(request),
        throwsA(isA<AppAuthException>()),
      );
    });
  });

  group('WalletWithdrawScreen form', () {
    Future<_FakeWallet> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final wallet = _FakeWallet();
      final router = GoRouter(
        initialLocation: '/wallet/withdraw',
        routes: [
          GoRoute(
            path: '/wallet',
            builder: (_, _) => const Scaffold(body: Text('WALLET SCREEN')),
          ),
          GoRoute(
            path: '/wallet/withdraw',
            builder: (_, _) => const WalletWithdrawScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletProvider.overrideWith(() => wallet)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return wallet;
    }

    testWidgets('below ₹50 is rejected before anything is sent', (
      tester,
    ) async {
      final wallet = await pumpScreen(tester);
      await tester.enterText(find.byType(TextField).at(0), '40');
      await tester.enterText(find.byType(TextField).at(1), 'ravi@ybl');
      await tester.tap(find.text('Request Payout'));
      await tester.pumpAndSettle();

      expect(find.text('Minimum withdrawal amount is ₹50'), findsOneWidget);
      expect(find.text('Confirm withdrawal'), findsNothing);
      expect(wallet.calls, 0);
    });

    testWidgets('invalid IFSC is rejected before anything is sent', (
      tester,
    ) async {
      final wallet = await pumpScreen(tester);
      await tester.tap(find.text('Bank Transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '500');
      // Fields: amount, holder, account number, IFSC, bank name, phone
      await tester.enterText(find.byType(TextField).at(2), '123456789012');
      await tester.enterText(find.byType(TextField).at(3), 'HDFC123');
      await tester.tap(find.text('Request Payout'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid IFSC code (e.g. HDFC0000123)'),
        findsOneWidget,
      );
      expect(wallet.calls, 0);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      final wallet = await pumpScreen(tester);
      await tester.enterText(find.byType(TextField).at(0), '500');
      await tester.enterText(find.byType(TextField).at(1), 'ravi@ybl');
      await tester.tap(find.text('Request Payout'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm withdrawal'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(wallet.calls, 0);
      expect(find.byType(WalletWithdrawScreen), findsOneWidget);
    });

    testWidgets('confirmed UPI payout sends the backend request and shows '
        'the server message', (tester) async {
      final wallet = await pumpScreen(tester);
      await tester.enterText(find.byType(TextField).at(0), '500');
      await tester.enterText(find.byType(TextField).at(1), 'ravi@ybl');
      await tester.tap(find.text('Request Payout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Request Payout'));
      await tester.pumpAndSettle();

      expect(wallet.calls, 1);
      expect(wallet.last!.toJson(), {
        'amount': 500.0,
        'payout_method': 'upi',
        'upi_id': 'ravi@ybl',
      });
      expect(find.textContaining('WTH_test'), findsOneWidget);
      expect(find.text('WALLET SCREEN'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // let snackbar finish
    });
  });
}
