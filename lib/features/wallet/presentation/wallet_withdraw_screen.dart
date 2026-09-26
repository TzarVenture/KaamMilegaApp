import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/withdrawal.dart';
import '../providers/wallet_provider.dart';
import '../repositories/wallet_repository.dart';
import '../../../app/theme/app_colors.dart';

class WalletWithdrawScreen extends ConsumerStatefulWidget {
  const WalletWithdrawScreen({super.key});

  @override
  ConsumerState<WalletWithdrawScreen> createState() =>
      _WalletWithdrawScreenState();
}

class _WalletWithdrawScreenState extends ConsumerState<WalletWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  late final TextEditingController _phoneController;

  String _destinationType = 'UPI'; // 'UPI' or 'BANK'
  bool _isProcessing = false;

  static final RegExp _upiPattern = RegExp(r'^[\w.\-]{2,}@[a-zA-Z][\w.\-]*$');
  static final RegExp _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final RegExp _accountNumberPattern = RegExp(r'^[0-9]{9,18}$');
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9]{10,13}$');

  @override
  void initState() {
    super.initState();
    // Optional contact number for the payout; pre-filled from the account.
    _phoneController = TextEditingController(
      text: ref.read(authProvider).user?.mobile.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    _accountNumberController.dispose();
    _nameController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Builds the backend request from the form, or shows why it cannot be
  /// sent. Limits follow km-backend RequestWithdrawal.
  WithdrawalRequest? _buildRequest(int withdrawableBalance) {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid withdrawal amount');
      return null;
    }
    if (amount < WithdrawalRequest.minAmount) {
      _showError('Minimum withdrawal amount is ₹50');
      return null;
    }
    if (amount > WithdrawalRequest.maxAmount) {
      _showError('Maximum single withdrawal amount is ₹5,00,000');
      return null;
    }
    if (amount > withdrawableBalance) {
      _showError(
        'Amount exceeds your withdrawable earnings (₹$withdrawableBalance)',
      );
      return null;
    }

    final phone = _phoneController.text.replaceAll(' ', '').trim();
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      _showError('Please enter a valid phone number or leave it empty');
      return null;
    }
    final holder = _nameController.text.trim();

    if (_destinationType == 'UPI') {
      final upiId = _upiController.text.trim();
      if (upiId.isEmpty) {
        _showError('Please enter your UPI ID');
        return null;
      }
      if (!_upiPattern.hasMatch(upiId)) {
        _showError('Please enter a valid UPI ID (e.g. name@bank)');
        return null;
      }
      return WithdrawalRequest.upi(
        amount: amount,
        upiId: upiId,
        accountHolder: holder,
        phoneNumber: phone,
      );
    }

    final accountNumber = _accountNumberController.text.replaceAll(' ', '');
    if (accountNumber.isEmpty) {
      _showError('Please enter your Bank Account number');
      return null;
    }
    if (!_accountNumberPattern.hasMatch(accountNumber)) {
      _showError('Account number must be 9 to 18 digits');
      return null;
    }
    final ifsc = _ifscController.text.trim().toUpperCase();
    if (ifsc.isEmpty) {
      _showError('Please enter the IFSC code');
      return null;
    }
    if (!_ifscPattern.hasMatch(ifsc)) {
      _showError('Please enter a valid IFSC code (e.g. HDFC0000123)');
      return null;
    }
    return WithdrawalRequest.bank(
      amount: amount,
      accountNumber: accountNumber,
      ifscCode: ifsc,
      accountHolder: holder,
      bankName: _bankNameController.text.trim(),
      phoneNumber: phone,
    );
  }

  Future<void> _handleWithdraw(int withdrawableBalance) async {
    if (_isProcessing || ref.read(walletProvider).isActionLoading) return;
    FocusScope.of(context).unfocus();

    if (!ref.read(isOnlineProvider)) {
      _showError('Internet connection required to perform this transaction.');
      return;
    }

    final request = _buildRequest(withdrawableBalance);
    if (request == null) return;

    // The backend deducts the amount as soon as it accepts the request.
    final confirmed = await _confirmWithdrawal(request);
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final result = await ref.read(walletProvider.notifier).withdraw(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/wallet');
      }
    } on WalletApiException catch (e) {
      if (!mounted) return;
      if (e.isBackendPending) {
        _showBackendNotice(context, request, e.message);
      } else if (e.isOutcomeUnknown) {
        _showOutcomeUnknown(e.message);
      } else {
        _showError(e.message);
      }
    } on AppException catch (e) {
      // Offline, session expired, ...: nothing was sent or accepted.
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        _showError('Could not submit the withdrawal. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool?> _confirmWithdrawal(WithdrawalRequest request) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confirm withdrawal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildSummaryRow(
                'Amount',
                '₹${request.amount.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Method',
                request.method == PayoutMethod.upi ? 'UPI' : 'Bank Transfer',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow('To', request.maskedDestination),
              const SizedBox(height: 14),
              const Text(
                'The amount is deducted from your earnings as soon as the '
                'request is submitted. Please check the details carefully.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Confirm & Request Payout',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// No answer from the server: the payout may or may not have been
  /// recorded, so the user is asked to check before trying again.
  void _showOutcomeUnknown(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdrawal not confirmed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/wallet/transactions');
            },
            child: const Text('Check transactions'),
          ),
        ],
      ),
    );
  }

  void _showBackendNotice(
    BuildContext context,
    WithdrawalRequest request,
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
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.accent,
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Withdrawals to bank / UPI',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Amount',
                    '₹${request.amount.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Method',
                    request.method == PayoutMethod.upi
                        ? 'UPI'
                        : 'Bank Transfer',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Destination', request.maskedDestination),
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
                  backgroundColor: AppColors.primary,
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

  Widget _buildOptionalFieldLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
        children: const [
          TextSpan(
            text: '  (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalTextField({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
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
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Long UPI IDs / bank names wrap instead of overflowing.
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    // Only earnings are withdrawable (backend withdrawable_balance)
    final currentBalance = (walletState.summary?.withdrawableBalance ?? 0)
        .floor();

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
          'Withdraw Funds',
          style: TextStyle(
            color: AppColors.textPrimary,
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
            // Available Balance Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available to Withdraw',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹$currentBalance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: currentBalance > 0
                        ? () {
                            setState(() {
                              _amountController.text = currentBalance
                                  .toString();
                            });
                          }
                        : null,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Withdraw All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Amount Input
            const Text(
              'Withdrawal Amount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
                      color: AppColors.accent,
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
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Min ₹50',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Destination Type Selection
            const Text(
              'Withdrawal Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _destinationType = 'UPI'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _destinationType == 'UPI'
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _destinationType == 'UPI'
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Instant UPI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _destinationType == 'UPI'
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _destinationType = 'BANK'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _destinationType == 'BANK'
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _destinationType == 'BANK'
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Bank Transfer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _destinationType == 'BANK'
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Destination fields
            if (_destinationType == 'UPI') ...[
              const Text(
                'UPI ID / VPA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _upiController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'e.g. yourname@okhdfcbank',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
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
            ] else ...[
              _buildOptionalFieldLabel('Account Holder Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Full name as per bank records',
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
              const SizedBox(height: 14),
              const Text(
                'Bank Account Number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'Enter 9-18 digit account number',
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
              const SizedBox(height: 14),
              const Text(
                'IFSC Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ifscController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. HDFC0000123',
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
              const SizedBox(height: 14),
              _buildOptionalFieldLabel('Bank Name'),
              const SizedBox(height: 8),
              _buildOptionalTextField(
                controller: _bankNameController,
                hintText: 'e.g. HDFC Bank',
                keyboardType: TextInputType.text,
              ),
            ],

            const SizedBox(height: 14),
            _buildOptionalFieldLabel('Phone Number'),
            const SizedBox(height: 8),
            _buildOptionalTextField(
              controller: _phoneController,
              hintText: 'Contact number for this payout',
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 24),

            // Payout details note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The amount is deducted from your earnings when you '
                      'submit. Your payout request is then processed by '
                      'KaamMilega and you can track it in your transactions.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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
                onPressed: (walletState.isActionLoading || _isProcessing)
                    ? null
                    : () => _handleWithdraw(currentBalance),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: (walletState.isActionLoading || _isProcessing)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Request Payout',
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
