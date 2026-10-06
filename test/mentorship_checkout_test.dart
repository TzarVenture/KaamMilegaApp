import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_colors.dart';
import 'package:kaam_milega/features/experts/models/expert_profile.dart';
import 'package:kaam_milega/features/experts/presentation/widgets/mentorship_checkout_sheet.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';

const _expert = ExpertItem(
  id: 'm1',
  expertId: 'e1',
  title: '1-on-1 Mock Interview & Salary Negotiation Strategy',
  category: 'Interview Prep',
  duration: 45,
  price: 499,
  expertName: 'Reeta Patel',
);

/// Wallet with a fixed balance (no network).
class _Wallet extends WalletNotifier {
  _Wallet(this.initial);

  final WalletState initial;

  @override
  WalletState build() => initial;

  @override
  Future<void> loadWallet() async {}
}

/// Holds what the sheet returned.
class _Result {
  Future<SessionPayMethod?>? future;
}

Future<_Result> _open(
  WidgetTester tester, {
  double balance = 1000,
  bool walletLive = true,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final result = _Result();
  final wallet = walletLive
      ? WalletState(summary: WalletSummary(mainBalance: balance))
      : const WalletState(isComingSoon: true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [walletProvider.overrideWith(() => _Wallet(wallet))],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result.future = showMentorshipCheckout(
                context,
                expert: _expert,
                scheduledAt: DateTime(2026, 10, 7, 10),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('shows the session and pays from the wallet when enough', (
    tester,
  ) async {
    final r = await _open(tester);
    expect(find.text('Confirm & Checkout'), findsOneWidget);
    expect(find.text('INTERVIEW PREP'), findsOneWidget);
    expect(find.text(_expert.title), findsOneWidget);
    expect(find.text('₹499'), findsOneWidget);
    expect(find.text('Wed, 7 Oct, 2026'), findsOneWidget);
    expect(find.text('10:00 AM (45 mins)'), findsOneWidget);
    expect(find.text('Available main balance: ₹1000.00'), findsOneWidget);
    expect(find.textContaining('Short by'), findsNothing);

    await tester.tap(find.text('Pay ₹499 from Wallet'));
    await tester.pumpAndSettle();
    expect(await r.future, SessionPayMethod.wallet);
  });

  testWidgets('low balance: Pay via Razorpay Instead selects Razorpay', (
    tester,
  ) async {
    final r = await _open(tester, balance: 0);
    expect(find.text('Short by ₹499.00'), findsOneWidget);
    expect(find.text('Top Up Wallet'), findsOneWidget);

    // First tap only switches to Razorpay; the sheet stays open.
    await tester.tap(find.text('Pay via Razorpay Instead'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm & Checkout'), findsOneWidget);
    expect(find.text('Short by ₹499.00'), findsNothing);
    final proceed = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Proceed to Pay ₹499'),
    );
    expect(
      proceed.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppColors.brandNavy,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ElevatedButton, 'Proceed to Pay ₹499'),
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Proceed to Pay ₹499'));
    await tester.pumpAndSettle();
    expect(await r.future, SessionPayMethod.online);
  });

  testWidgets('choosing Razorpay changes the button', (tester) async {
    final r = await _open(tester);
    await tester.tap(find.text('UPI, Cards & NetBanking'));
    await tester.pumpAndSettle();
    expect(find.text('Proceed to Pay ₹499'), findsOneWidget);
    await tester.tap(find.text('Proceed to Pay ₹499'));
    await tester.pumpAndSettle();
    expect(await r.future, SessionPayMethod.online);
  });

  testWidgets('wallet not available: Razorpay is chosen', (tester) async {
    final r = await _open(tester, walletLive: false);
    expect(find.text('Wallet is not available right now'), findsOneWidget);
    expect(find.text('Proceed to Pay ₹499'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await r.future, isNull);
  });

  testWidgets('fits a 320px phone with large text', (tester) async {
    await _open(tester, balance: 0, size: const Size(320, 568), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Confirm & Checkout'), findsOneWidget);
  });
}
