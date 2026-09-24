import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_provider.dart';
import '../providers/wallet_provider.dart';
import '../../../shared/widgets/app_dialog.dart';

class WalletAddMoneyScreen extends ConsumerStatefulWidget {
  const WalletAddMoneyScreen({super.key});

  @override
  ConsumerState<WalletAddMoneyScreen> createState() =>
      _WalletAddMoneyScreenState();
}

class _WalletAddMoneyScreenState extends ConsumerState<WalletAddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '100',
  );
  String _selectedMethod = 'UPI';
  bool _isProcessing = false;

  final List<int> _quickAmounts = [100, 500, 1000, 2000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amt) {
    setState(() {
      _amountController.text = amt.toString();
    });
  }

  Future<void> _handleProceed() async {
    if (_isProcessing) return;

    if (!ref.read(isOnlineProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Internet connection required to perform this transaction.',
          ),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final text = _amountController.text.trim();
    final amount = double.tryParse(text);

    // Same limits as the backend: ₹10 – ₹1,00,000
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum amount is ₹10'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum deposit amount per transaction is ₹1,00,000'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Server order -> Razorpay checkout -> server verification.
      // The wallet is credited ONLY after the server verifies the payment.
      final result = await ref
          .read(walletProvider.notifier)
          .addMoney(
            amount: amount,
            preferredMethod: _razorpayMethod(_selectedMethod),
          );
      if (!mounted) return;

      switch (result.outcome) {
        case TopupOutcome.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          context.pop();
          break;
        case TopupOutcome.cancelled:
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(result.message)));
          break;
        case TopupOutcome.comingSoon:
          _showBackendNotice(context, amount, result.message);
          break;
        case TopupOutcome.paidButUnverified:
          // Money may have left the user's account: explain clearly
          await showAppDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Payment received, confirming'),
              content: Text(result.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          break;
        case TopupOutcome.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Maps the selected tile to Razorpay's preferred checkout method
  String? _razorpayMethod(String selected) {
    switch (selected) {
      case 'UPI':
        return 'upi';
      case 'Cards':
        return 'card';
      case 'NetBanking':
        return 'netbanking';
      default:
        return null;
    }
  }

  void _showBackendNotice(BuildContext context, double amount, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Adding money to your wallet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Deposit Amount',
                    '₹${amount.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Payment Method', _selectedMethod),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Status', 'Not charged'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Return to Wallet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    // Real main balance from GET /wallet/balance
    final currentBalance = walletState.summary?.mainBalance ?? 0;

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
              context.go('/wallet');
            }
          },
        ),
        title: const Text(
          'Add Money to Wallet',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF1A2B8C),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Current Wallet Balance:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4338CA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${currentBalance.toStringAsFixed(currentBalance % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2B8C),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Amount Input
            const Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2B8C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Quick Amount Buttons
            Row(
              children: _quickAmounts.map((amt) {
                final isSelected = _amountController.text == amt.toString();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _selectQuickAmount(amt),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1A2B8C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1A2B8C)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+₹$amt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Payment Methods Selector
            const Text(
              'Select Payment Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            _buildPaymentMethodTile(
              id: 'UPI',
              title: 'UPI (GPay / PhonePe / Paytm / BHIM)',
              subtitle: 'Instant deposit • Zero transaction fee',
              icon: Icons.qr_code_2_rounded,
            ),
            const SizedBox(height: 10),
            _buildPaymentMethodTile(
              id: 'Cards',
              title: 'Debit / Credit Card (Visa, RuPay, Mastercard)',
              subtitle: 'Instant authorization',
              icon: Icons.credit_card_rounded,
            ),
            const SizedBox(height: 10),
            _buildPaymentMethodTile(
              id: 'NetBanking',
              title: 'Net Banking (All Major Indian Banks)',
              subtitle: 'Secure direct bank transfer',
              icon: Icons.account_balance_rounded,
            ),

            const SizedBox(height: 24),

            // Security Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payments are secured by 256-bit SSL encryption & RBI-compliant gateway partners.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: walletState.isActionLoading ? null : _handleProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B8C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: walletState.isActionLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Proceed to Pay',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A2B8C)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF1A2B8C)
                    : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1A2B8C)
                      : const Color(0xFFCBD5E1),
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
