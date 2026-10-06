import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../models/expert_profile.dart';

/// How the user chose to pay for a paid session.
enum SessionPayMethod { wallet, online }

/// "Confirm & Checkout" for a paid 1-on-1 session (as on the website):
/// session summary, KaamMilega Wallet or Razorpay, escrow note.
///
/// Returns the chosen method, or null when closed. Nothing is charged
/// here; the caller books with the wallet or opens Razorpay.
Future<SessionPayMethod?> showMentorshipCheckout(
  BuildContext context, {
  required ExpertItem expert,
  required DateTime scheduledAt,
}) {
  return showModalBottomSheet<SessionPayMethod>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        MentorshipCheckoutSheet(expert: expert, scheduledAt: scheduledAt),
  );
}

String _money(double v, {bool paise = false}) {
  final whole = v == v.roundToDouble();
  final text = paise || !whole ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
  return '₹$text';
}

class MentorshipCheckoutSheet extends ConsumerStatefulWidget {
  const MentorshipCheckoutSheet({
    super.key,
    required this.expert,
    required this.scheduledAt,
  });

  final ExpertItem expert;
  final DateTime scheduledAt;

  @override
  ConsumerState<MentorshipCheckoutSheet> createState() =>
      _MentorshipCheckoutSheetState();
}

class _MentorshipCheckoutSheetState
    extends ConsumerState<MentorshipCheckoutSheet> {
  /// Null until the user picks; the wallet is suggested when it is live.
  SessionPayMethod? _picked;

  Future<void> _topUp() async {
    await context.push('/wallet/add-money');
    // Fresh balance from the server after adding money.
    if (mounted) await ref.read(walletProvider.notifier).loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final expert = widget.expert;
    final price = expert.price;
    final wallet = ref.watch(walletProvider);
    final summary = wallet.summary;
    final checking = wallet.isLoading && summary == null;
    final walletLive = summary != null && !wallet.isComingSoon;
    final balance = summary?.mainBalance ?? 0;
    final shortBy = price - balance;
    final enough = walletLive && shortBy <= 0;

    final method =
        _picked ??
        (walletLive ? SessionPayMethod.wallet : SessionPayMethod.online);
    final walletSelected = method == SessionPayMethod.wallet;

    // The button always does what it says:
    // - wallet with enough balance: pay from the wallet (orange);
    // - wallet too low: "Pay via Razorpay Instead" switches the choice to
    //   Razorpay (nothing is paid yet);
    // - Razorpay chosen: "Proceed to Pay" (navy) opens Razorpay.
    final _PayButton button;
    if (walletSelected && enough) {
      button = _PayButton(
        label: 'Pay ${_money(price)} from Wallet',
        color: AppColors.accent,
        trailing: Icons.arrow_forward_rounded,
        onPressed: () => Navigator.pop(context, SessionPayMethod.wallet),
      );
    } else if (walletSelected) {
      button = _PayButton(
        label: 'Pay via Razorpay Instead',
        color: AppColors.accent,
        trailing: Icons.arrow_forward_rounded,
        onPressed: () => setState(() => _picked = SessionPayMethod.online),
      );
    } else {
      button = _PayButton(
        label: 'Proceed to Pay ${_money(price)}',
        color: AppColors.brandNavy,
        leading: Icons.lock_outline_rounded,
        onPressed: () => Navigator.pop(context, SessionPayMethod.online),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Header(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(expert: expert, scheduledAt: widget.scheduledAt),
                  const SizedBox(height: 20),
                  const Text(
                    'SELECT PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MethodCard(
                    selected: walletSelected,
                    enabled: walletLive,
                    icon: Icons.account_balance_wallet_outlined,
                    iconFilled: walletSelected,
                    title: 'KaamMilega Wallet',
                    tag: 'INSTANT',
                    tagColor: AppColors.success,
                    subtitle: checking
                        ? 'Checking your balance...'
                        : walletLive
                        ? 'Available main balance: ${_money(balance, paise: true)}'
                        : 'Wallet is not available right now',
                    onTap: () =>
                        setState(() => _picked = SessionPayMethod.wallet),
                    footer: walletSelected && walletLive && !enough
                        ? _ShortBy(amount: shortBy, onTopUp: _topUp)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _MethodCard(
                    selected: !walletSelected,
                    enabled: true,
                    icon: Icons.credit_card_rounded,
                    iconFilled: !walletSelected,
                    title: 'UPI, Cards & NetBanking',
                    tag: 'RAZORPAY',
                    tagColor: AppColors.blue,
                    subtitle:
                        'Google Pay, PhonePe, Paytm, cards and net banking',
                    onTap: () =>
                        setState(() => _picked = SessionPayMethod.online),
                  ),
                  const SizedBox(height: 16),
                  const _EscrowNote(),
                ],
              ),
            ),
          ),
          _Footer(button: button, enabled: !checking),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandNavy, AppColors.blue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm & Checkout',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '1-on-1 Mentorship Session',
                  style: TextStyle(fontSize: 12.5, color: AppColors.white),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.14),
            ),
            icon: const Icon(Icons.close_rounded, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.expert, required this.scheduledAt});

  final ExpertItem expert;
  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) {
    final category = expert.category.trim();
    final mentor = expert.expertName.trim();
    final minutes = expert.duration;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      expert.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (mentor.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Mentor: '),
                            TextSpan(
                              text: mentor,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
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
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL FEE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(expert.price),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.border),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Meta(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('EEE, d MMM, y').format(scheduledAt),
              ),
              _Meta(
                icon: Icons.schedule_rounded,
                iconColor: AppColors.accent,
                text: minutes > 0
                    ? '${DateFormat('h:mm a').format(scheduledAt)} ($minutes mins)'
                    : DateFormat('h:mm a').format(scheduledAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.iconColor = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One payment option: icon, name with a tag, a line of detail and a
/// round selector on the right.
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.subtitle,
    required this.onTap,
    this.iconFilled = false,
    this.footer,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final bool iconFilled;
  final String title;
  final String tag;
  final Color tagColor;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.brandNavy : AppColors.border;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: selected ? AppColors.background : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconFilled
                              ? AppColors.brandNavy
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: iconFilled
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 0.4,
                                      fontWeight: FontWeight.w800,
                                      color: tagColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? AppColors.brandNavy
                            : AppColors.textLight,
                      ),
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: 12), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Amber note when the wallet balance is lower than the fee.
class _ShortBy extends StatelessWidget {
  const _ShortBy({required this.amount, required this.onTopUp});

  final double amount;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      // Wraps: on narrow phones / large text "Top Up Wallet" goes under.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Short by ${_money(amount, paise: true)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onTopUp,
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandNavy,
              minimumSize: const Size(0, 40),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text(
              'Top Up Wallet',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowNote extends StatelessWidget {
  const _EscrowNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.success),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'KaamMilega Escrow Protection: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                        'Your payment is held safely in escrow. The mentor '
                        'receives the payout only after the session is '
                        'completed.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main button at the bottom: label, colour, optional icons.
class _PayButton {
  const _PayButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.leading,
    this.trailing,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? leading;
  final IconData? trailing;
}

class _Footer extends StatelessWidget {
  const _Footer({required this.button, required this.enabled});

  final _PayButton button;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: enabled ? button.onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: button.color,
                foregroundColor: AppColors.white,
                elevation: 0,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (button.leading != null) ...[
                    Icon(button.leading, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      button.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (button.trailing != null) ...[
                    const SizedBox(width: 6),
                    Icon(button.trailing, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
