import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import 'widgets/wallet_transaction_tile.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class WalletTransactionsScreen extends ConsumerStatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  ConsumerState<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState
    extends ConsumerState<WalletTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/wallet');
            }
          },
        ),
        title: const Text(
          'Transactions Ledger',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.assignment_return_outlined,
              color: Color(0xFF475569),
            ),
            tooltip: 'Refund requests',
            onPressed: () => context.push('/wallet/disputes'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Credits'),
            Tab(text: 'Debits'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(walletProvider.notifier).loadTransactions(),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTransactionsList(walletState.transactions, 'all'),
            _buildTransactionsList(
              walletState.transactions
                  .where((t) => t.type == TransactionType.credit)
                  .toList(),
              'credit',
            ),
            _buildTransactionsList(
              walletState.transactions
                  .where((t) => t.type == TransactionType.debit)
                  .toList(),
              'debit',
            ),
          ],
        ),
      ),
    );
  }

  /// Transaction ledger in the secondary font (Inter), per brand spec.
  Widget _buildTransactionsList(
    List<WalletTransaction> transactions,
    String filter,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: AppFonts.secondary),
      child: _buildTransactionsListContent(transactions, filter),
    );
  }

  Widget _buildTransactionsListContent(
    List<WalletTransaction> transactions,
    String filter,
  ) {
    if (transactions.isEmpty) {
      // Wallet service not live yet: say so instead of "no transactions"
      final isComingSoon = ref.watch(walletProvider).isComingSoon;
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isComingSoon
                    ? 'Transactions coming soon'
                    : filter == 'credit'
                    ? 'No credits yet'
                    : filter == 'debit'
                    ? 'No debits yet'
                    : 'No transactions yet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you deposit money, receive payouts, or pay for services, your entries will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => FadeSlideIn(
        index: index,
        child: WalletTransactionTile(transaction: transactions[index]),
      ),
    );
  }
}
