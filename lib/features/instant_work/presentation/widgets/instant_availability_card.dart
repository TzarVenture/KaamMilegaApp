import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/sheet_drag_handle.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../models/instant_candidate.dart';
import '../../models/nearby_professional.dart';
import '../../providers/instant_candidate_provider.dart';

/// InstantMilega "go online" card: the online switch, the primary trade
/// and the InstantPass status, as on the website. Everything shown comes
/// from GET /instant-work/candidate/status.
class InstantAvailabilityCard extends ConsumerWidget {
  const InstantAvailabilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = AuthGuard.isSignedIn(ref.watch(authProvider));
    if (!signedIn) return const _GuestCard();

    final state = ref.watch(instantCandidateProvider);
    final status = state.status;
    if (status == null) {
      if (state.error != null && !state.isLoading) {
        return _Shell(
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Could not load your InstantMilega status.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(instantCandidateProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return const ShimmerBox(
        width: double.infinity,
        height: 170,
        borderRadius: 20,
      );
    }

    final online = status.isOnline;
    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PowerSwitch(
                value: online,
                busy: state.isBusy,
                onChanged: (v) => _toggle(context, ref, v),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: online
                                ? AppColors.success
                                : AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            online ? 'ONLINE NOW' : 'CURRENTLY OFFLINE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: online
                                  ? AppColors.success
                                  : AppColors.brandNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            online
                                ? 'Nearby employers can find you and send '
                                      'gig requests'
                                : 'Turn on status to receive instant hiring '
                                      'requests',
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TradeChip(
            skill: state.skill,
            enabled: !state.isBusy,
            onTap: () => _pickTrade(context, ref, state.skill),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _PassLabel(status: status),
              if (!status.canGoOnline)
                ElevatedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => showInstantPassSheet(context),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: Text('Activate Pass (${InstantPassTerms.priceLabel})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool online,
  ) async {
    final result = await ref
        .read(instantCandidateProvider.notifier)
        .setOnline(online);
    if (!context.mounted) return;
    switch (result.outcome) {
      case InstantActionOutcome.passRequired:
        await showInstantPassSheet(context);
      case InstantActionOutcome.success:
      case InstantActionOutcome.noLocation:
      case InstantActionOutcome.failed:
      case InstantActionOutcome.unknown:
        _snack(
          context,
          result.message,
          isError: result.outcome != InstantActionOutcome.success,
        );
    }
  }

  static Future<void> _pickTrade(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TradeSheet(current: current),
    );
    if (picked == null || !context.mounted) return;
    final result = await ref
        .read(instantCandidateProvider.notifier)
        .setSkill(picked);
    if (context.mounted && result.message.isNotEmpty) {
      _snack(
        context,
        result.outcome == InstantActionOutcome.success
            ? 'Primary trade: $picked'
            : result.message,
        isError: result.outcome != InstantActionOutcome.success,
      );
    }
  }
}

void _snack(BuildContext context, String message, {bool isError = false}) {
  if (message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      child: Row(
        children: [
          const _PowerSwitch(value: false, busy: false, onChanged: null),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Log in to go online and receive instant hiring requests.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}

/// Large on/off switch with a power icon on the knob.
class _PowerSwitch extends StatelessWidget {
  const _PowerSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && !busy;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: 'Online for InstantMilega',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? AppColors.success : AppColors.border,
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                      color: value
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TradeChip extends StatelessWidget {
  const _TradeChip({
    required this.skill,
    required this.enabled,
    required this.onTap,
  });

  final String skill;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.build_outlined,
                size: 15,
                color: AppColors.accent,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Primary Trade: ',
                    children: [
                      TextSpan(
                        text: skill,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandNavy,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassLabel extends StatelessWidget {
  const _PassLabel({required this.status});

  final InstantCandidateStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status.canGoOnline;
    final String text;
    if (active) {
      final until = status.passExpiresLabel;
      text =
          'InstantPass: ${status.quotaRemaining} of ${InstantPassTerms.gigs} '
          'gigs left${until.isEmpty ? '' : ' · till $until'}';
    } else if (status.hasActivePass) {
      text = 'Pass used up (0 gigs left)';
    } else {
      text = 'Pass inactive (0 gigs)';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.verified_rounded : Icons.confirmation_number_outlined,
          size: 16,
          color: active ? AppColors.success : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeSheet extends StatelessWidget {
  const _TradeSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetDragHandle(),
              const Text(
                'Your primary trade',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Employers looking for this trade will see you.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final c in InstantServiceCategory.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(c.icon, color: AppColors.accent),
                  title: Text(
                    c.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: c.label == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.brandNavy,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, c.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ₹99 InstantPass sheet (website: "InstantMilega™ Candidate Pass").
Future<void> showInstantPassSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const InstantPassSheet(),
  );
}

class InstantPassSheet extends ConsumerStatefulWidget {
  const InstantPassSheet({super.key});

  @override
  ConsumerState<InstantPassSheet> createState() => _InstantPassSheetState();
}

class _InstantPassSheetState extends ConsumerState<InstantPassSheet> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Fresh balance from the server before offering the wallet
    Future.microtask(() {
      if (mounted) ref.read(walletProvider.notifier).loadWallet();
    });
  }

  Future<void> _pay() async {
    setState(() => _error = null);
    final result = await ref
        .read(instantCandidateProvider.notifier)
        .buyPassWithWallet();
    if (!mounted) return;
    switch (result.outcome) {
      case InstantActionOutcome.success:
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('${result.message} You can now go online.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case InstantActionOutcome.unknown:
        // The sheet closes; the notice opens over the page.
        final pageContext = Navigator.of(context, rootNavigator: true).context;
        Navigator.pop(context);
        if (!pageContext.mounted) return;
        await showAppDialog<void>(
          context: pageContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Could not confirm purchase'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case InstantActionOutcome.failed:
      case InstantActionOutcome.passRequired:
      case InstantActionOutcome.noLocation:
        setState(() => _error = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final busy = ref.watch(instantCandidateProvider.select((s) => s.isBusy));
    final summary = wallet.summary;
    final balance = summary?.mainBalance;
    final walletReady = summary != null && !wallet.isComingSoon;
    final enough = balance != null && balance >= InstantPassTerms.priceInr;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Navy header
              Container(
                color: AppColors.brandNavy,
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'InstantMilega™ Candidate Pass',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Go online and claim on-demand spot gigs near you',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PriceCard(),
                    const SizedBox(height: 18),
                    const Text(
                      'Select payment method',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _MethodTile(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'KaamMilega Wallet',
                              subtitle: !walletReady
                                  ? (wallet.isLoading
                                        ? 'Checking balance...'
                                        : 'Wallet unavailable')
                                  : 'Balance: ${_rupees(balance!)}',
                              subtitleColor: walletReady
                                  ? (enough
                                        ? AppColors.success
                                        : AppColors.error)
                                  : AppColors.textSecondary,
                              selected: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Online payment is switched off until the
                          // server stops also debiting the wallet for it.
                          const Expanded(
                            child: _MethodTile(
                              icon: Icons.credit_card_rounded,
                              title: 'Online payment',
                              subtitle: 'Temporarily unavailable',
                              subtitleColor: AppColors.textSecondary,
                              selected: false,
                              disabled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _Perk(
                      title: '${InstantPassTerms.gigs} gig claims',
                      text: 'Your quota goes down only when you claim a gig.',
                    ),
                    const _Perk(
                      title: 'Direct employer contact',
                      text: 'Talk to the employer directly after you claim.',
                    ),
                    const _Perk(
                      title: '${InstantPassTerms.validityDays} days validity',
                      text: 'Use your gigs any time within 30 days.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: busy || !walletReady || !enough
                            ? null
                            : _pay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandNavy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: busy
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
                                  const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Pay ${InstantPassTerms.priceLabel} '
                                      'from KaamMilega Wallet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (walletReady && !enough)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/wallet');
                        },
                        child: const Text('Add money to your wallet'),
                      ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Paid from your wallet · Pass starts at once',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
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

  static String _rupees(double v) =>
      '₹${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';
}

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CANDIDATE ACCESS PASS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: InstantPassTerms.priceLabel,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandNavy,
                  ),
                  children: const [
                    TextSpan(
                      text: ' / ${InstantPassTerms.gigs} gigs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${InstantPassTerms.perGigLabel} / gig',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '${InstantPassTerms.validityDays} days validity',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.selected,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brandNavy : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, size: 17, color: AppColors.brandNavy),
                ),
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.brandNavy,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$title: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
