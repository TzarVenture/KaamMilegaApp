import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../models/expert_plan.dart';

/// Navy header of the Pro Expert page: program pill, headline, subtitle.
class ProExpertHero extends StatelessWidget {
  const ProExpertHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandNavy, AppColors.navy],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: AppColors.accentBright,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'KAAMMILEGA PRO EXPERT PROGRAM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.accentBright,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Turn Your Industry Expertise Into '),
                TextSpan(
                  text: 'Sustainable Income',
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Host paid 1-on-1 mentorship calls, set your own session prices '
            'and keep 100% of your session earnings in your KaamMilega '
            'Wallet.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// One plan: name, description, price, perks from the server and the
/// upgrade button. The plan with savings is highlighted in orange.
class ExpertPlanCard extends StatelessWidget {
  const ExpertPlanCard({
    super.key,
    required this.plan,
    required this.onUpgrade,
    this.isCurrent = false,
    this.isBusy = false,
    this.note,
  });

  final ExpertPlan plan;

  /// Null disables the button.
  final VoidCallback? onUpgrade;
  final bool isCurrent;
  final bool isBusy;

  /// Small line under the button (e.g. days left).
  final String? note;

  bool get _highlighted => plan.savingsPercent > 0;

  @override
  Widget build(BuildContext context) {
    final highlighted = _highlighted;
    final tint = highlighted ? AppColors.accent : AppColors.primary;
    final perMonth = plan.perMonthLabel;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(top: highlighted ? 12 : 0),
          padding: EdgeInsets.fromLTRB(18, highlighted ? 26 : 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? AppColors.accent : AppColors.border,
              width: highlighted ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: highlighted
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: highlighted ? 22 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? AppColors.accentLight
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      highlighted
                          ? Icons.workspace_premium_rounded
                          : Icons.bolt_rounded,
                      color: tint,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        if (plan.savingsPercent > 0) ...[
                          const SizedBox(height: 5),
                          _Pill(
                            label: plan.isYearly
                                ? 'Save ${plan.savingsPercent}% Annually'
                                : 'Save ${plan.savingsPercent}%',
                            color: AppColors.success,
                            background: AppColors.successLight,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    const _Pill(
                      label: 'Current',
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                    ),
                  ],
                ],
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    plan.priceLabel,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ ${plan.periodLabel}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (perMonth != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '($perMonth/mo)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
              if (plan.perks.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),
                const Text(
                  "WHAT'S INCLUDED",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final perk in plan.perks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: highlighted
                              ? AppColors.accent
                              : AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            perk,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              _UpgradeButton(
                label: isCurrent
                    ? 'Current plan'
                    : 'Upgrade to ${plan.shortName}',
                color: tint,
                isCurrent: isCurrent,
                isBusy: isBusy,
                onPressed: onUpgrade,
              ),
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (highlighted)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _BestValueBadge()),
          ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({
    required this.label,
    required this.color,
    required this.isCurrent,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isCurrent
              ? AppColors.successLight
              : isBusy
              ? color.withValues(alpha: 0.7)
              : AppColors.background,
          disabledForegroundColor: isCurrent
              ? AppColors.success
              : isBusy
              ? Colors.white
              : AppColors.textLight,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrent) ...[
                    const Icon(Icons.check_circle_rounded, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isCurrent) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accentBright],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'BEST VALUE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Soft notice with an optional action (Retry), used for the plan status
/// and for load errors.
class ProExpertNotice extends StatelessWidget {
  const ProExpertNotice({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.color = AppColors.textSecondary,
    this.background = Colors.white,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color background;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}

enum ExpertPlanPaymentMethod { wallet, online }

/// Choose wallet or online payment for a plan. The wallet option is
/// enabled only when the server-reported main balance covers the price.
class ExpertPlanPaymentSheet extends StatelessWidget {
  const ExpertPlanPaymentSheet({
    super.key,
    required this.plan,
    required this.walletAvailable,
    required this.mainBalance,
  });

  final ExpertPlan plan;
  final bool walletAvailable;
  final double mainBalance;

  @override
  Widget build(BuildContext context) {
    final canUseWallet = walletAvailable && mainBalance >= plan.price;
    final balance = formatRupees(mainBalance);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetDragHandle(),
            Text(
              'Pay ${plan.priceLabel} for ${plan.name}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: canUseWallet,
              leading: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Pay from KaamMilega Wallet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                !walletAvailable
                    ? 'Wallet is not available right now'
                    : canUseWallet
                    ? 'Balance: $balance'
                    : 'Balance $balance is not enough. Add money in Wallet.',
              ),
              onTap: canUseWallet
                  ? () => Navigator.pop(context, ExpertPlanPaymentMethod.wallet)
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.payments_rounded,
                color: AppColors.accent,
              ),
              title: const Text(
                'Pay online',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('UPI, card or net banking via Razorpay'),
              onTap: () =>
                  Navigator.pop(context, ExpertPlanPaymentMethod.online),
            ),
          ],
        ),
      ),
    );
  }
}
