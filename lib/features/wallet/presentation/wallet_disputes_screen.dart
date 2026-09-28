import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../models/wallet_dispute.dart';
import '../models/wallet_transaction.dart';
import '../providers/wallet_dispute_provider.dart';

/// Refund requests raised on wallet payments (GET /wallet/my/disputes).
class WalletDisputesScreen extends ConsumerWidget {
  const WalletDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(myWalletDisputesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Refund Requests',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myWalletDisputesProvider.future),
        child: disputesAsync.when(
          data: (disputes) {
            if (disputes.isEmpty) {
              return NetworkStateView(
                isEmpty: true,
                emptyTitle: 'No refund requests',
                emptyMessage:
                    'To request a refund, open a payment in Transactions and '
                    'tap "Request a refund".',
                emptyAction: ElevatedButton(
                  onPressed: () => context.push('/wallet/transactions'),
                  child: const Text('View Transactions'),
                ),
                child: const SizedBox.shrink(),
              );
            }
            return DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: AppFonts.secondary),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: disputes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => FadeSlideIn(
                  index: index,
                  child: DisputeCard(dispute: disputes[index]),
                ),
              ),
            );
          },
          loading: () => const ShimmerLoadingList(count: 4, itemHeight: 110),
          error: (err, _) => NetworkStateView.fromError(
            err,
            onRetry: () => ref.invalidate(myWalletDisputesProvider),
          ),
        ),
      ),
    );
  }
}

/// One refund request with its review status.
class DisputeCard extends StatelessWidget {
  const DisputeCard({super.key, required this.dispute});

  final WalletDispute dispute;

  static Color _statusColor(DisputeStatus status) {
    switch (status) {
      case DisputeStatus.approved:
        return AppColors.success;
      case DisputeStatus.rejected:
        return AppColors.error;
      case DisputeStatus.underReview:
        return AppColors.blue;
      case DisputeStatus.pending:
        return AppColors.textSecondary;
    }
  }

  static String _date(DateTime? d) =>
      d == null ? '' : DateFormat('d MMM yyyy').format(d.toLocal());

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(dispute.status);
    final created = _date(dispute.createdAt);
    final resolved = _date(dispute.resolvedAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  WalletTransaction.titleForCategory(dispute.category),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${dispute.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dispute.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (created.isNotEmpty)
                Text(
                  'Raised $created',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (dispute.reasonLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              dispute.reasonLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (dispute.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dispute.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (dispute.status == DisputeStatus.approved) ...[
            const SizedBox(height: 10),
            Text(
              resolved.isEmpty
                  ? 'Approved. The refund was added to your wallet balance.'
                  : 'Approved on $resolved. The refund was added to your '
                        'wallet balance.',
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
          if (dispute.status == DisputeStatus.rejected && resolved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Reviewed on $resolved.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (dispute.adminNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Note from KaamMilega: ${dispute.adminNotes}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
