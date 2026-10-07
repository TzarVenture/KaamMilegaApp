import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/wallet_dispute.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/wallet_dispute_provider.dart';
import 'refund_request_sheet.dart';

/// Badge for a ledger category: what the money was for, at a glance.
class TxnCategoryStyle {
  const TxnCategoryStyle(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static TxnCategoryStyle of(String? category) => switch (category) {
    'topup' => const TxnCategoryStyle(
      'Recharge',
      Icons.credit_card_rounded,
      AppColors.blue,
    ),
    'pass_purchase' => const TxnCategoryStyle(
      'Platform Pass',
      Icons.bolt_rounded,
      AppColors.accent,
    ),
    'session_booking' || 'session_payout' => const TxnCategoryStyle(
      'Mentorship',
      Icons.people_alt_outlined,
      AppColors.moduleExperts,
    ),
    'gig_payout' => const TxnCategoryStyle(
      'Gig Payout',
      Icons.work_outline_rounded,
      AppColors.success,
    ),
    'withdrawal' => const TxnCategoryStyle(
      'Withdrawal',
      Icons.account_balance_outlined,
      AppColors.moduleP2P,
    ),
    'bonus_reward' => const TxnCategoryStyle(
      'Bonus',
      Icons.card_giftcard_rounded,
      AppColors.moduleEvents,
    ),
    'refund' => const TxnCategoryStyle(
      'Refund',
      Icons.undo_rounded,
      AppColors.success,
    ),
    'subscription' => const TxnCategoryStyle(
      'Pro Expert',
      Icons.workspace_premium_rounded,
      AppColors.moduleExperts,
    ),
    'event_ticket' => const TxnCategoryStyle(
      'Event',
      Icons.confirmation_number_outlined,
      AppColors.moduleEvents,
    ),
    _ => const TxnCategoryStyle(
      'Wallet',
      Icons.account_balance_wallet_outlined,
      AppColors.textSecondary,
    ),
  };
}

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _date = DateFormat('d MMM yyyy, h:mm a');

String formatWalletAmount(double v) => _money.format(v);

/// One ledger entry, as on the website: arrow, category badge, the
/// server's description, date, which balance moved, reference, balance
/// after, status and (for payments) Dispute / Refund.
class WalletTransactionTile extends ConsumerWidget {
  const WalletTransactionTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txn = transaction;
    final credit = txn.isCredit;
    final style = TxnCategoryStyle.of(txn.category);
    final amountColor = credit ? AppColors.success : AppColors.brandNavy;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showWalletTransactionDetails(context, txn),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DirectionIcon(credit: credit),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _CategoryBadge(style: style),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${credit ? '+' : '-'}${formatWalletAmount(txn.amount)}',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      txn.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _date.format(txn.createdAt.toLocal()),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (txn.balanceLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              txn.balanceLabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (txn.shortReference.isNotEmpty)
                          Text(
                            txn.shortReference,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusPill(status: txn.status),
                        if (txn.balanceAfter != null)
                          Text(
                            'After: ${formatWalletAmount(txn.balanceAfter!)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (txn.canRequestRefund)
                          _RefundAction(transaction: txn, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionIcon extends StatelessWidget {
  const _DirectionIcon({required this.credit});

  final bool credit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: credit ? AppColors.successLight : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: credit
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Icon(
        credit ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: 20,
        color: credit ? AppColors.success : AppColors.brandNavy,
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.style});

  final TxnCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: style.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      TransactionStatus.completed => (
        AppColors.success,
        AppColors.successLight,
      ),
      TransactionStatus.pending => (
        const Color(0xFFB45309), // dark amber on light amber
        AppColors.moduleEventsLight,
      ),
      TransactionStatus.failed => (
        AppColors.error,
        AppColors.moduleServicesLight,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

/// "Dispute / Refund" for a payment, or the state of the request already
/// raised for it (the server allows one per payment).
class _RefundAction extends ConsumerWidget {
  const _RefundAction({required this.transaction, this.compact = false});

  final WalletTransaction transaction;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(myWalletDisputesProvider);
    WalletDispute? existing;
    for (final d in disputes.asData?.value ?? const <WalletDispute>[]) {
      if (d.transactionId == transaction.id) {
        existing = d;
        break;
      }
    }

    if (existing != null) {
      return _Pill(
        icon: Icons.assignment_return_outlined,
        label: 'Refund: ${existing.status.label}',
        color: AppColors.blue,
        onTap: () => context.push('/wallet/disputes'),
      );
    }
    // While the requests load, nothing is offered; on an error the button
    // is shown (the server still refuses a second request).
    if (disputes.isLoading && !disputes.hasValue) {
      return const SizedBox.shrink();
    }
    return _Pill(
      icon: Icons.error_outline_rounded,
      label: 'Dispute / Refund',
      color: const Color(0xFFB45309), // dark amber
      background: AppColors.moduleEventsLight,
      onTap: () => openRefundRequest(context, transaction),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Refund request for a payment (backend F73).
Future<void> openRefundRequest(
  BuildContext context,
  WalletTransaction txn,
) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RefundRequestSheet(transaction: txn),
  );
  if (submitted != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Refund request submitted. You can follow it in Refund requests.',
      ),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'View',
        textColor: Colors.white,
        onPressed: () => context.push('/wallet/disputes'),
      ),
    ),
  );
}

/// Full details of one ledger entry.
Future<void> showWalletTransactionDetails(
  BuildContext context,
  WalletTransaction txn,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder: (ctx) => _TransactionDetails(transaction: txn),
  );
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    final credit = txn.isCredit;
    final style = TxnCategoryStyle.of(txn.category);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetDragHandle(),
              Center(child: _CategoryBadge(style: style)),
              const SizedBox(height: 12),
              Text(
                '${credit ? '+' : '-'}${formatWalletAmount(txn.amount)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: credit ? AppColors.success : AppColors.brandNavy,
                ),
              ),
              const SizedBox(height: 6),
              Center(child: _StatusPill(status: txn.status)),
              const SizedBox(height: 14),
              Text(
                txn.displayTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // What the money was for, in plain words
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: style.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txn.purpose,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                'Type',
                credit ? 'Money in (credit)' : 'Money out (debit)',
              ),
              if (txn.balanceLabel != null)
                _DetailRow('Balance', txn.balanceLabel!),
              if (txn.balanceAfter != null)
                _DetailRow(
                  'Balance after',
                  formatWalletAmount(txn.balanceAfter!),
                ),
              _DetailRow('Date', _date.format(txn.createdAt.toLocal())),
              if ((txn.referenceId ?? '').isNotEmpty)
                _DetailRow('Reference', txn.referenceId!),
              if ((txn.paymentMethod ?? '').isNotEmpty)
                _DetailRow('Method', txn.paymentMethod!),
              if (txn.id.isNotEmpty) _DetailRow('Entry ID', txn.id),
              if (txn.canRequestRefund) ...[
                const SizedBox(height: 14),
                Center(child: _RefundAction(transaction: txn)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
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
