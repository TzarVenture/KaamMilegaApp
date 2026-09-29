import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/wallet/models/wallet_dispute.dart';
import 'package:kaam_milega/features/wallet/models/wallet_transaction.dart';
import 'package:kaam_milega/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_dispute_provider.dart';

/// A ledger row exactly as GET /wallet/transactions sends it.
Map<String, dynamic> _row({
  String id = '66f8a1c2d3e4f5a61dd2703a',
  String type = 'debit',
  String category = 'pass_purchase',
  String target = 'main',
  double amount = 99,
  double after = 1,
  String description = 'InstantPass Activation (10 Spot Gigs)',
}) => {
  'id': id,
  'type': type,
  'target_balance': target,
  'category': category,
  'amount': amount,
  'balance_after': after,
  'status': 'completed',
  'description': description,
  'created_at': '2026-09-29T05:28:00Z',
};

Future<void> _pump(
  WidgetTester tester,
  WalletTransaction txn, {
  List<WalletDispute> disputes = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myWalletDisputesProvider.overrideWith((ref) async => disputes),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: WalletTransactionTile(transaction: txn),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('reads balance, balance after and the server description', () {
    final t = WalletTransaction.fromJson(_row());
    expect(t.displayTitle, 'InstantPass Activation (10 Spot Gigs)');
    expect(t.balanceLabel, 'Main balance');
    expect(t.balanceAfter, 1);
    expect(t.shortReference, '#1dd2703a');
    expect(t.purpose, contains('InstantPass'));
    // No description from the server: the category name is used.
    expect(
      WalletTransaction.fromJson(_row(description: '')).displayTitle,
      'InstantPass purchase',
    );
  });

  test('mentorship escrow is explained as held money', () {
    final t = WalletTransaction.fromJson(
      _row(type: 'credit', category: 'session_booking', target: 'locked'),
    );
    expect(t.balanceLabel, 'Locked balance');
    expect(t.purpose, contains('held safely'));
  });

  testWidgets('pass payment: badge, amount, details and Dispute / Refund', (
    tester,
  ) async {
    await _pump(tester, WalletTransaction.fromJson(_row()));

    expect(find.text('Platform Pass'), findsOneWidget);
    expect(find.text('-₹99.00'), findsOneWidget);
    expect(find.text('InstantPass Activation (10 Spot Gigs)'), findsOneWidget);
    expect(find.text('Main balance'), findsOneWidget);
    expect(find.text('#1dd2703a'), findsOneWidget);
    expect(find.text('After: ₹1.00'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('Dispute / Refund'), findsOneWidget);
  });

  testWidgets('money in (recharge): no dispute option', (tester) async {
    await _pump(
      tester,
      WalletTransaction.fromJson(
        _row(
          type: 'credit',
          category: 'topup',
          amount: 100,
          after: 100,
          description: 'Wallet Recharge via Razorpay',
        ),
      ),
    );
    expect(find.text('Recharge'), findsOneWidget);
    expect(find.text('+₹100.00'), findsOneWidget);
    expect(find.text('Dispute / Refund'), findsNothing);
  });

  testWidgets('a refund already requested shows its status', (tester) async {
    final txn = WalletTransaction.fromJson(_row());
    await _pump(
      tester,
      txn,
      disputes: [
        WalletDispute.fromJson({
          'id': 'd1',
          'transaction_id': txn.id,
          'amount': 99,
          'category': 'pass_purchase',
          'reason': 'service_not_provided',
          'status': 'pending',
        }),
      ],
    );
    expect(find.text('Dispute / Refund'), findsNothing);
    expect(find.textContaining('Refund: '), findsOneWidget);
  });

  testWidgets('tap opens details with the purpose in plain words', (
    tester,
  ) async {
    await _pump(tester, WalletTransaction.fromJson(_row()));
    await tester.tap(find.text('InstantPass Activation (10 Spot Gigs)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lets you go online'), findsOneWidget);
    expect(find.text('Money out (debit)'), findsOneWidget);
  });
}
