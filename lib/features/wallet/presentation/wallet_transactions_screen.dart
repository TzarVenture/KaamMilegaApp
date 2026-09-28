import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/wallet_dispute.dart';
import '../models/wallet_transaction.dart';
import '../providers/wallet_dispute_provider.dart';
import '../providers/wallet_provider.dart';
import 'widgets/refund_request_sheet.dart';
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
            fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
        child: Builder(
          builder: (context) {
            final txn = transactions[index];
            final isCredit = txn.type == TransactionType.credit;

            return InkWell(
              onTap: () => _showTransactionDetailModal(context, txn),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isCredit
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCredit
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: isCredit
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${txn.createdAt.day}/${txn.createdAt.month}/${txn.createdAt.year} • ${txn.status.label}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isCredit ? "+" : "-"}₹${txn.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isCredit
                            ? const Color(0xFF10B981)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTransactionDetailModal(
    BuildContext context,
    WalletTransaction txn,
  ) {
    final isCredit = txn.type == TransactionType.credit;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${isCredit ? "+" : "-"}₹${txn.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isCredit
                      ? const Color(0xFF10B981)
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  txn.status.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow('Transaction', txn.title),
            if (txn.description.isNotEmpty)
              _buildDetailRow('Description', txn.description),
            _buildDetailRow(
              'Date',
              txn.createdAt.toLocal().toString().split('.').first,
            ),
            if (txn.referenceId != null)
              _buildDetailRow('Ref ID', txn.referenceId!),
            if (txn.paymentMethod != null)
              _buildDetailRow('Method', txn.paymentMethod!),
            if (txn.canRequestRefund) ...[
              const SizedBox(height: 12),
              _RefundStatusSection(
                transaction: txn,
                onRequest: () {
                  Navigator.of(ctx).pop();
                  _openRefundRequest(txn);
                },
                onViewRequests: () {
                  Navigator.of(ctx).pop();
                  context.push('/wallet/disputes');
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Refund request on a debit payment (backend F73).
  Future<void> _openRefundRequest(WalletTransaction txn) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RefundRequestSheet(transaction: txn),
    );
    if (submitted != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Refund request submitted. You can follow it in Refund requests.',
        ),
        backgroundColor: AppColors.success,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => context.push('/wallet/disputes'),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows an existing refund request for [transaction], or the action to
/// raise one. The server allows one request per payment.
class _RefundStatusSection extends ConsumerWidget {
  const _RefundStatusSection({
    required this.transaction,
    required this.onRequest,
    required this.onViewRequests,
  });

  final WalletTransaction transaction;
  final VoidCallback onRequest;
  final VoidCallback onViewRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(myWalletDisputesProvider);
    final requestButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onRequest,
        icon: const Icon(Icons.assignment_return_outlined, size: 18),
        label: const Text('Request a refund'),
      ),
    );
    return disputes.when(
      loading: () => const Text(
        'Checking refund requests...',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      // The server still refuses a second request for the same payment.
      error: (_, _) => requestButton,
      data: (list) {
        WalletDispute? existing;
        for (final d in list) {
          if (d.transactionId == transaction.id) {
            existing = d;
            break;
          }
        }
        if (existing == null) return requestButton;
        return Row(
          children: [
            Expanded(
              child: Text(
                'Refund request: ${existing.status.label}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(onPressed: onViewRequests, child: const Text('View')),
          ],
        );
      },
    );
  }
}
