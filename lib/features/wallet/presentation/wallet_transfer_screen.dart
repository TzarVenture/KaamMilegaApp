import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_provider.dart';
import '../providers/wallet_provider.dart';
import '../repositories/wallet_repository.dart';

class WalletTransferScreen extends ConsumerStatefulWidget {
  const WalletTransferScreen({super.key});

  @override
  ConsumerState<WalletTransferScreen> createState() =>
      _WalletTransferScreenState();
}

class _WalletTransferScreenState extends ConsumerState<WalletTransferScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleTransfer(int currentBalance) async {
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

    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter recipient mobile number or KaamMilega ID',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid transfer amount'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds your available wallet balance'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ref
          .read(walletProvider.notifier)
          .transfer(
            amount: amount,
            recipientIdentifier: recipient,
            note: _noteController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully transferred ₹$amount to $recipient!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      context.pop();
    } on WalletApiException catch (e) {
      if (!mounted) return;
      if (e.isBackendPending) {
        _showBackendNotice(context, amount, recipient, e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      // Offline / server error: show the real reason, not a "coming soon" notice
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showBackendNotice(
    BuildContext context,
    double amount,
    String recipient,
    String message,
  ) {
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFF059669),
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
                        'Send money to KaamMilega users',
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
                    'Transfer Amount',
                    '₹${amount.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Recipient', recipient),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Service Fee', '₹0 (Free)'),
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
    final currentBalance = (walletState.summary?.mainBalance ?? 0).floor();

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
          'Transfer Balance',
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
                    'Available Balance:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4338CA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹$currentBalance',
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

            // Recipient Input
            const Text(
              'Recipient Mobile / KaamMilega ID',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _recipientController,
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile or KaamMilega ID',
                prefixIcon: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Amount Input
            const Text(
              'Transfer Amount',
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
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 26,
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

            const SizedBox(height: 20),

            // Note Input
            const Text(
              'Add a Note (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'e.g. Gig milestone payment, service fee',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
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
                  Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct wallet-to-wallet transfers are instant and 100% free of charge.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
                onPressed: walletState.isActionLoading
                    ? null
                    : () => _handleTransfer(currentBalance),
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
                        'Transfer Now',
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
}
