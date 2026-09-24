import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/wallet/models/wallet_summary.dart';
import 'package:kaam_milega/features/wallet/models/wallet_transaction.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_add_money_screen.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_screen.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_transactions_screen.dart';
import 'package:kaam_milega/features/wallet/presentation/wallet_withdraw_screen.dart';
import 'package:kaam_milega/features/wallet/providers/wallet_provider.dart';

void main() {
  group('WalletTransaction Model Tests', () {
    test('WalletTransaction parses from JSON correctly', () {
      final json = {
        'id': 'txn_101',
        'title': 'Gig Milestone Payout',
        'description': 'Flutter app feature',
        'amount': 2500.0,
        'type': 'credit',
        'status': 'completed',
        'created_at': '2026-09-20T12:00:00.000Z',
        'reference_id': 'REF98765',
        'payment_method': 'UPI',
        'category': 'payout',
      };

      final txn = WalletTransaction.fromJson(json);

      expect(txn.id, 'txn_101');
      expect(txn.title, 'Gig Milestone Payout');
      expect(txn.amount, 2500.0);
      expect(txn.type, TransactionType.credit);
      expect(txn.status, TransactionStatus.completed);
      expect(txn.referenceId, 'REF98765');
      expect(txn.paymentMethod, 'UPI');
    });

    test('WalletTransaction serializes to JSON correctly', () {
      final txn = WalletTransaction(
        id: 'txn_102',
        title: 'Platform Fee',
        amount: 50.0,
        type: TransactionType.debit,
        status: TransactionStatus.completed,
        createdAt: DateTime.parse('2026-09-20T12:00:00.000Z'),
        referenceId: 'REF123',
      );

      final json = txn.toJson();

      expect(json['id'], 'txn_102');
      expect(json['amount'], 50.0);
      expect(json['type'], 'debit');
      expect(json['status'], 'completed');
      expect(json['reference_id'], 'REF123');
    });
  });

  group('WalletScreen Widget Tests', () {
    testWidgets('WalletScreen renders balance, quick actions and empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _MockAuthNotifier(
                const UserProfile(
                  id: 'usr_1',
                  mobile: '9876543210',
                  isEmailVerified: true,
                ),
              ),
            ),
            // Balances now come from GET /wallet/balance (walletProvider),
            // not from the user profile. Supply them without a network call.
            walletProvider.overrideWith(
              () => _MockWalletNotifier(
                const WalletState(
                  summary: WalletSummary(totalBalance: 1250, mainBalance: 1250),
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: WalletScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Title and Subtitle
      expect(find.text('Digital Wallet & Ledger'), findsOneWidget);
      expect(find.text('KaamMilega Escrow & Payouts'), findsOneWidget);

      // Real balance from the wallet service (Indian number format)
      expect(
        find.text('₹1,250'),
        findsNWidgets(2),
      ); // total in primary card + main wallet row in breakdown
      expect(find.text('Verified'), findsOneWidget);

      // Quick Actions
      expect(find.text('Add Money'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      // Zero-mock-data empty transactions state
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
    });
  });

  group('WalletAddMoneyScreen Widget Tests', () {
    testWidgets('WalletAddMoneyScreen renders input and payment options', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: WalletAddMoneyScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add Money to Wallet'), findsOneWidget);
      expect(find.text('+₹100'), findsOneWidget);
      expect(find.text('+₹500'), findsOneWidget);
      expect(find.text('+₹1000'), findsOneWidget);
      expect(find.text('+₹2000'), findsOneWidget);
      expect(find.text('Proceed to Pay'), findsOneWidget);
    });
  });

  group('WalletWithdrawScreen Widget Tests', () {
    testWidgets('WalletWithdrawScreen renders withdrawal options', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: WalletWithdrawScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.text('Withdraw Funds'), findsOneWidget);
      expect(find.text('Instant UPI'), findsOneWidget);
      expect(find.text('Bank Transfer'), findsOneWidget);
      expect(find.text('Request Payout'), findsOneWidget);
    });
  });

  group('WalletTransactionsScreen Widget Tests', () {
    testWidgets('WalletTransactionsScreen renders ledger tabs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: WalletTransactionsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Transactions Ledger'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.text('Debits'), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
    });
  });
}

/// Wallet notifier that returns fixed balances and never calls the server
class _MockWalletNotifier extends WalletNotifier {
  final WalletState _initial;
  _MockWalletNotifier(this._initial);

  @override
  WalletState build() => _initial;

  @override
  Future<void> loadWallet() async {}
}

class _MockAuthNotifier extends AuthNotifier {
  final UserProfile _user;
  _MockAuthNotifier(this._user);

  @override
  AuthState build() {
    return AuthState(isAuthenticated: true, user: _user);
  }

  @override
  Future<void> refreshProfile() async {}
}
