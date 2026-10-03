import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/wallet_dispute.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/wallet_dispute_provider.dart';
import '../../repositories/wallet_repository.dart';

/// Raise a refund request / dispute on a wallet payment
/// (POST /wallet/disputes), as on the website. Pops `true` once the server
/// has saved it. Nothing is refunded here: the KaamMilega team reviews the
/// request and, if approved, the server credits the Main balance.
class RefundRequestSheet extends ConsumerStatefulWidget {
  const RefundRequestSheet({super.key, required this.transaction});

  final WalletTransaction transaction;

  /// Same limits as the website form.
  static const int minLength = 10;
  static const int maxLength = 1000;

  @override
  ConsumerState<RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends ConsumerState<RefundRequestSheet> {
  static const _amberDark = Color(0xFFB45309);

  final _details = TextEditingController();
  DisputeReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _details.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  int get _length => _details.text.trim().length;

  bool get _canSubmit =>
      !_sending && _reason != null && _length >= RefundRequestSheet.minLength;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Please choose a reason.');
      return;
    }
    if (_length < RefundRequestSheet.minLength) {
      setState(
        () => _error =
            'Please write at least ${RefundRequestSheet.minLength} characters.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(walletRepositoryProvider)
          .createDispute(
            transactionId: widget.transaction.id,
            reason: reason,
            description: _details.text,
          );
      if (!mounted) return;
      ref.invalidate(myWalletDisputesProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // It may have been saved: show the server's list, not a guess.
      if (e is WalletApiException && e.isOutcomeUnknown) {
        ref.invalidate(myWalletDisputesProvider);
      }
      setState(() {
        _sending = false;
        _error = e is WalletApiException || e is AppException
            ? e.toString()
            : 'Could not submit your request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final txn = widget.transaction;
    final reference = txn.shortReference;

    return PopScope(
      canPop: !_sending,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetDragHandle(),
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.moduleEventsLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.moduleEvents.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: _amberDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Request Refund / Raise Dispute',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (reference.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reference $reference',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // The payment being disputed
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        'Transaction',
                        NumberFormat.currency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 2,
                        ).format(txn.amount),
                        valueStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      _SummaryRow('Description', txn.displayTitle),
                      _SummaryRow(
                        'Date & Time',
                        DateFormat('d MMM yyyy, h:mm a')
                            .format(txn.createdAt.toLocal()),
                      ),
                      if (txn.balanceLabel != null)
                        _SummaryRow(
                          'Balance debited',
                          txn.balanceLabel!,
                          valueStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.moduleExperts,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Reason
                const _FieldLabel(
                  icon: Icons.help_outline_rounded,
                  text: 'Reason for dispute',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DisputeReason>(
                  initialValue: _reason,
                  isExpanded: true,
                  hint: const Text('Choose a reason'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  decoration: _inputDecoration(),
                  borderRadius: BorderRadius.circular(14),
                  items: [
                    for (final r in DisputeReason.values)
                      DropdownMenuItem(
                        value: r,
                        child: Text(
                          r.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  onChanged: _sending
                      ? null
                      : (r) => setState(() {
                          _reason = r;
                          _error = null;
                        }),
                ),
                if (_reason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _reason!.hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Explanation
                const _FieldLabel(
                  icon: Icons.description_outlined,
                  text: 'Detailed explanation',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _details,
                  enabled: !_sending,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: RefundRequestSheet.maxLength,
                  buildCounter: (
                    _, {
                    required currentLength,
                    maxLength,
                    required isFocused,
                  }) => null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hint:
                        'Please describe what happened, dates, names, or any '
                        'evidence supporting your refund request...',
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _length >= RefundRequestSheet.minLength
                            ? 'Looks good'
                            : 'Minimum ${RefundRequestSheet.minLength} '
                                  'characters required',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _length >= RefundRequestSheet.minLength
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${_details.text.length}/${RefundRequestSheet.maxLength}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // What happens next
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.moduleEventsLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.moduleEvents.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: _amberDark,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    'Disputes are reviewed by the KaamMilega '
                                    'team, usually within ',
                              ),
                              TextSpan(
                                text: '24 to 48 hours',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text:
                                    '. If approved, the amount is credited '
                                    'back to your ',
                              ),
                              TextSpan(
                                text: 'Main balance',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: _amberDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onAccent,
                            disabledBackgroundColor: AppColors.accent
                                .withValues(alpha: _sending ? 0.8 : 0.45),
                            disabledForegroundColor: AppColors.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit dispute',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration({String? hint}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      disabledBorder: border(AppColors.borderLight),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
