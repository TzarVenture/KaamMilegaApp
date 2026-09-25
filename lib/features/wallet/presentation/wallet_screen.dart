import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';
import '../providers/wallet_provider.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/pressable_scale.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final user = authState.user;
    // Real balances from GET /wallet/balance (null until loaded)
    final summary = walletState.summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              context.go('/home');
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Wallet & Ledger',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'KaamMilega Escrow & Payouts',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF475569),
            ),
            tooltip: 'Wallet Info',
            onPressed: () => _showWalletInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Refresh Balance',
            onPressed: () async {
              await ref.read(walletProvider.notifier).refreshWallet();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet data synced with server'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1A2B8C),
        onRefresh: () async {
          await ref.read(walletProvider.notifier).refreshWallet();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Color(0xFFE11D48),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're offline. Balance may have changed since last sync.",
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Wallet service is not live on the backend yet
              if (walletState.isComingSoon) _buildComingSoonBanner(),

              // 1. MAIN BALANCE CARD
              _buildBalanceCard(
                context,
                summary,
                user?.isEmailVerified ?? false,
              ),

              const SizedBox(height: 20),

              // 2. QUICK ACTIONS
              _buildQuickActions(context),

              const SizedBox(height: 20),

              // 3. BALANCE BREAKDOWN / WALLET TYPES
              _buildWalletTypesSection(summary),

              const SizedBox(height: 20),

              // 4. KYC & LIMITS CARD
              _buildKycAndLimitsCard(context, user?.isEmailVerified ?? false),

              const SizedBox(height: 24),

              // 5. RECENT TRANSACTIONS / LEDGER
              _buildRecentTransactionsHeader(context),
              const SizedBox(height: 12),
              _buildRecentTransactionsBody(context, walletState),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Deep Navy Primary Card with real balance and verification badge
  /// Indian-rupee format, e.g. ₹1,250 or ₹99.50
  static String _inr(double value) {
    final hasPaise = (value * 100).round() % 100 != 0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: hasPaise ? 2 : 0,
    ).format(value);
  }

  Widget _buildBalanceCard(
    BuildContext context,
    WalletSummary? summary,
    bool isVerified,
  ) {
    return FadeSlideIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0C1738), Color(0xFF172B5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C1738).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'TOTAL BALANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVerified
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        size: 13,
                        color: isVerified
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Verified' : 'Not verified',
                        style: TextStyle(
                          color: isVerified
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              _inr(summary?.totalBalance ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Total balance (added money + earnings + bonus)',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Earnings',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _inr(summary?.earningsBalance ?? 0),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'In Escrow',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _inr(summary?.lockedBalance ?? 0),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 4 Quick Action Buttons designed for mobile touch
  Widget _buildQuickActions(BuildContext context) {
    return FadeSlideIn(
      index: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              context: context,
              icon: Icons.add_circle_outline_rounded,
              label: 'Add Money',
              color: const Color(0xFF1A2B8C),
              onTap: () => context.push('/wallet/add-money'),
            ),
            _buildActionButton(
              context: context,
              icon: Icons.payments_outlined,
              label: 'Pay',
              color: const Color(0xFF6366F1),
              onTap: () => _showPayModal(context),
            ),
            _buildActionButton(
              context: context,
              icon: Icons.arrow_circle_up_rounded,
              label: 'Withdraw',
              color: const Color(0xFFF97316),
              onTap: () => context.push('/wallet/withdraw'),
            ),
            _buildActionButton(
              context: context,
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer',
              color: const Color(0xFF10B981),
              onTap: () => context.push('/wallet/transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Wallet Types Breakdown Card
  Widget _buildWalletTypesSection(WalletSummary? summary) {
    return FadeSlideIn(
      index: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wallet Accounts',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildWalletTypeRow(
              title: 'Main Wallet (Added Money)',
              subtitle: 'Use for session bookings and services',
              amount: _inr(summary?.mainBalance ?? 0),
              icon: Icons.wallet_rounded,
              color: const Color(0xFF1A2B8C),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            _buildWalletTypeRow(
              title: 'Earnings',
              subtitle: 'Money you earned (withdrawable)',
              amount: _inr(summary?.earningsBalance ?? 0),
              icon: Icons.monetization_on_outlined,
              color: const Color(0xFF10B981),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            _buildWalletTypeRow(
              title: 'Escrow Protected',
              subtitle: 'Held safely until the session is completed',
              amount: _inr(summary?.lockedBalance ?? 0),
              icon: Icons.shield_outlined,
              color: const Color(0xFFF59E0B),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            _buildWalletTypeRow(
              title: 'Bonus Credits',
              subtitle: 'Promotional rewards (not withdrawable)',
              amount: _inr(summary?.bonusBalance ?? 0),
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFF9333EA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletTypeRow({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// KYC & Limits Status Card
  Widget _buildKycAndLimitsCard(BuildContext context, bool isVerified) {
    return FadeSlideIn(
      index: 3,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      size: 18,
                      color: Color(0xFF1A2B8C),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Limits & Compliance',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  // Email verification is not KYC; real KYC is not built yet
                  isVerified ? 'Email verified' : 'Email not verified',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Transfer Limit',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                Text(
                  '₹50,000 / day',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Withdrawal Limit',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                Text(
                  '₹2,00,000 / month',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Payments are processed securely by Razorpay. Withdrawal limits and KYC will apply once withdrawals go live.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recent Transactions Header with "View All"
  Widget _buildRecentTransactionsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/wallet/transactions'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'View All',
            style: TextStyle(
              color: Color(0xFF1A2B8C),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  /// Friendly notice shown while the wallet service is not live yet
  Widget _buildComingSoonBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'KaamMilega Wallet is coming soon. Balances, payments, '
              'withdrawals and transfers will be available here once the '
              'wallet goes live.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Recent Transactions list with zero-mock-data empty state
  Widget _buildRecentTransactionsBody(
    BuildContext context,
    WalletState walletState,
  ) {
    if (walletState.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const ShimmerLoadingList(count: 3, itemHeight: 60),
      );
    }

    if (walletState.transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 32,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              walletState.isComingSoon
                  ? 'Transactions coming soon'
                  : 'No transactions yet',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your deposits, gig payments, and withdrawals will appear here once active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // If transactions exist from backend:
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: walletState.transactions.take(5).length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: Builder(
              builder: (context) {
                final txn = walletState.transactions[index];
                final isCredit = txn.type == TransactionType.credit;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCredit
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFEF4444).withValues(alpha: 0.12),
                    child: Icon(
                      isCredit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isCredit
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    txn.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    txn.createdAt.toLocal().toString().split('.').first,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  trailing: Text(
                    '${isCredit ? "+" : "-"}₹${txn.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCredit
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletInfoDialog(BuildContext context) {
    showAppDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF1A2B8C)),
            SizedBox(width: 8),
            Text(
              'About KaamMilega Wallet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KaamMilega Wallet holds credits for hiring, job applications, interview bookings, and candidate escrow payouts.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '• Secure 256-bit encrypted ledger\n• Zero processing fees on direct transfers\n• Instant bank settlement on approved earnings',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showPayModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
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
              const SizedBox(height: 16),
              const Text(
                'Make a Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pay candidate for gig milestones or service fees directly from your wallet balance.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B8C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF1A2B8C),
                  ),
                ),
                title: const Text(
                  'Scan KaamMilega QR',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Scan candidate or expert payment QR code',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showBackendRequiredModal(context, 'QR Code Scanner');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: Color(0xFF10B981),
                  ),
                ),
                title: const Text(
                  'Pay to Phone / ID',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Send money directly to candidate phone',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/wallet/transfer');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackendRequiredModal(BuildContext context, String feature) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$feature is coming soon',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'We are still setting this up. It will be available in a future update of KaamMilega.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Understood',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
