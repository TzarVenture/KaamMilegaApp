import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/wallet_dispute.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/wallet_dispute_provider.dart';
import '../../repositories/wallet_repository.dart';

/// Raise a refund request on a wallet payment (POST /wallet/disputes).
/// Pops `true` once the server has saved it. Nothing is refunded here: the
/// KaamMilega team reviews the request and the server credits any refund.
class RefundRequestSheet extends ConsumerStatefulWidget {
  const RefundRequestSheet({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  ConsumerState<RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends ConsumerState<RefundRequestSheet> {
  final _details = TextEditingController();
  DisputeReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Please choose a reason.');
      return;
    }
    if (_details.text.trim().isEmpty) {
      setState(() => _error = 'Please describe what went wrong.');
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
    return PopScope(
      canPop: !_sending,
      child: Container(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetDragHandle(),
                const Text(
                  'Request a refund',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${txn.title} · ₹${txn.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reason',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in DisputeReason.values)
                      ChoiceChip(
                        label: Text(r.label),
                        selected: _reason == r,
                        onSelected: _sending
                            ? null
                            : (_) => setState(() {
                                _reason = r;
                                _error = null;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _details,
                  enabled: !_sending,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'What went wrong?',
                    hintText: 'Add details that help us review this payment',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our team reviews every request. If it is approved, the '
                  'refund is added to your wallet balance.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
