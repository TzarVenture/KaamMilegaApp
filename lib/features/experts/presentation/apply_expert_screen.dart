import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/expert_plan.dart';
import '../providers/expert_plan_provider.dart';
import 'widgets/expert_plan_widgets.dart';

/// "Apply to be an Expert": the KaamMilega Pro Expert Program. Plans, perks
/// and prices come from GET /subscriptions/expert/plans; the user's current
/// plan from GET /subscriptions/expert/my. Paying (wallet or Razorpay)
/// activates the plan on the server, which makes the user an expert.
class ApplyExpertScreen extends ConsumerStatefulWidget {
  const ApplyExpertScreen({super.key});

  @override
  ConsumerState<ApplyExpertScreen> createState() => _ApplyExpertScreenState();
}

class _ApplyExpertScreenState extends ConsumerState<ApplyExpertScreen> {
  /// Plan type being paid for; one purchase at a time.
  String? _busyPlan;

  Future<void> _refresh() async {
    ref.invalidate(expertPlansProvider);
    ref.invalidate(myExpertSubscriptionProvider);
    try {
      await Future.wait<Object>([
        ref.read(expertPlansProvider.future),
        ref.read(myExpertSubscriptionProvider.future),
      ]);
    } catch (_) {
      // Failures are shown on the page with a Retry button.
    }
  }

  Future<void> _upgrade(ExpertPlan plan) async {
    if (_busyPlan != null) return;

    setState(() => _busyPlan = plan.planType);
    // Fresh balances from the server before offering the wallet
    await ref.read(walletProvider.notifier).loadWallet();
    if (!mounted) return;
    setState(() => _busyPlan = null);

    final wallet = ref.read(walletProvider);
    final method = await showModalBottomSheet<ExpertPlanPaymentMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ExpertPlanPaymentSheet(
        plan: plan,
        walletAvailable: wallet.summary != null && !wallet.isComingSoon,
        mainBalance: wallet.summary?.mainBalance ?? 0,
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _busyPlan = plan.planType);
    try {
      final checkout = ref.read(expertPlanCheckoutProvider);
      final user = ref.read(authProvider).user;
      final result = method == ExpertPlanPaymentMethod.wallet
          ? await checkout.payWithWallet(plan)
          : await checkout.payOnline(
              plan,
              email: user?.email,
              contact: (user?.mobile ?? '').trim().isEmpty
                  ? null
                  : user!.mobile.trim(),
            );
      if (!mounted) return;
      // Stop the button spinner before showing the result.
      setState(() => _busyPlan = null);
      await _handleResult(plan, result);
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  Future<void> _handleResult(ExpertPlan plan, ExpertPlanResult result) async {
    switch (result.outcome) {
      case ExpertPlanOutcome.success:
        await _showNotice(
          'Welcome, Pro Expert',
          '${result.message}\n\nYour ${plan.name} plan is active. You can now '
              'host paid 1-on-1 mentorship calls.',
        );
        break;
      case ExpertPlanOutcome.cancelled:
        _showSnack(result.message);
        break;
      case ExpertPlanOutcome.failed:
        _showSnack(result.message, isError: true);
        break;
      case ExpertPlanOutcome.outcomeUnknown:
        await _showNotice('Could not confirm purchase', result.message);
        break;
      case ExpertPlanOutcome.paidButUnconfirmed:
        final retry = await _showNotice(
          'Payment received, confirming',
          result.message,
          retryLabel: 'Try again',
        );
        final payment = result.payment;
        if (retry == true && payment != null && mounted) {
          setState(() => _busyPlan = plan.planType);
          final next = await ref
              .read(expertPlanCheckoutProvider)
              .confirmOnlinePayment(plan, payment);
          if (!mounted) return;
          setState(() => _busyPlan = null);
          await _handleResult(plan, next);
        }
        break;
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Returns true when the retry action was chosen.
  Future<bool?> _showNotice(
    String title,
    String message, {
    String? retryLabel,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(retryLabel == null ? 'OK' : 'Close'),
          ),
          if (retryLabel != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(retryLabel),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(expertPlansProvider);
    final statusAsync = ref.watch(myExpertSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Apply to be an Expert',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const ProExpertHero(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._statusSection(statusAsync),
                      ..._plansSection(plansAsync, statusAsync),
                      const SizedBox(height: 8),
                      const _PaymentFootnote(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusSection(AsyncValue<ExpertSubscriptionStatus> status) {
    return status.when(
      loading: () => const [],
      // Unknown plan status: upgrades stay off so nobody pays twice.
      error: (_, _) => [
        ProExpertNotice(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Could not check your current plan',
          message: 'Upgrades are paused until your plan status loads.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(myExpertSubscriptionProvider),
        ),
        const SizedBox(height: 20),
      ],
      data: (s) {
        if (!s.isActive) return const [];
        final parts = [
          '${s.daysRemaining} ${s.daysRemaining == 1 ? 'day' : 'days'} left',
          if (s.expiresLabel.isNotEmpty) 'ends ${s.expiresLabel}',
        ];
        return [
          ProExpertNotice(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            background: AppColors.successLight,
            title: 'You are a Pro Expert',
            message: 'Your plan is active: ${parts.join(', ')}.',
          ),
          const SizedBox(height: 20),
        ];
      },
    );
  }

  List<Widget> _plansSection(
    AsyncValue<List<ExpertPlan>> plans,
    AsyncValue<ExpertSubscriptionStatus> status,
  ) {
    return plans.when(
      loading: () => const [
        ShimmerBox(width: double.infinity, height: 420, borderRadius: 20),
        SizedBox(height: 20),
        ShimmerBox(width: double.infinity, height: 420, borderRadius: 20),
        SizedBox(height: 20),
      ],
      // A failure is shown as a failure (with Retry), never as "no plans".
      error: (e, _) => [
        ProExpertNotice(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          title: 'Could not load the plans',
          message: 'Please check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(expertPlansProvider),
        ),
        const SizedBox(height: 20),
      ],
      data: (list) {
        if (list.isEmpty) {
          return [
            ProExpertNotice(
              icon: Icons.info_outline_rounded,
              title: 'No plans available right now',
              message: 'Pro Expert plans will appear here when they open.',
              actionLabel: 'Refresh',
              onAction: () => ref.invalidate(expertPlansProvider),
            ),
            const SizedBox(height: 20),
          ];
        }
        final current = status.asData?.value;
        final statusKnown = current != null;
        final hasActive = current?.isActive ?? false;
        return [
          for (final plan in list) ...[
            _card(plan, current, statusKnown: statusKnown, active: hasActive),
            const SizedBox(height: 20),
          ],
        ];
      },
    );
  }

  Widget _card(
    ExpertPlan plan,
    ExpertSubscriptionStatus? current, {
    required bool statusKnown,
    required bool active,
  }) {
    final isCurrent = active && current?.planType == plan.planType;
    String? note;
    if (isCurrent) {
      final end = current?.expiresLabel ?? '';
      note = end.isNotEmpty ? 'Active until $end' : null;
    } else if (active) {
      // The server starts a new plan from today instead of extending the
      // current one, so a second purchase now would waste the days left.
      note = 'Available after your current plan ends';
    }
    final canBuy = statusKnown && !active && _busyPlan == null;
    return ExpertPlanCard(
      plan: plan,
      isCurrent: isCurrent,
      isBusy: _busyPlan == plan.planType,
      note: note,
      onUpgrade: canBuy ? () => _upgrade(plan) : null,
    );
  }
}

class _PaymentFootnote extends StatelessWidget {
  const _PaymentFootnote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textLight),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Pay securely with UPI, card or net banking via Razorpay, or '
            'from your KaamMilega Wallet. Your plan starts as soon as the '
            'payment is confirmed.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
