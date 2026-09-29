import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/open_chat.dart';
import '../../models/nearby_professional.dart';
import '../../models/spot_gig.dart';
import '../../providers/instant_candidate_provider.dart';
import '../../providers/spot_gigs_provider.dart';
import 'instant_availability_card.dart';

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

IconData _tradeIcon(String skill) {
  final s = skill.trim().toLowerCase();
  for (final c in InstantServiceCategory.values) {
    if (c.label.toLowerCase() == s || c.id == s) return c.icon;
  }
  return Icons.handyman_outlined;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------------------
// Claimed gig
// ---------------------------------------------------------------------------

/// The gig the user claimed, until the employer closes it: where to go,
/// the pay, call / chat / directions and "Mark as complete".
class ActiveGigCard extends ConsumerWidget {
  const ActiveGigCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AuthGuard.isSignedIn(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(spotGigsProvider);
    final gig = state.activeGig;
    if (gig == null) return const SizedBox.shrink();

    final waiting = gig.status == SpotGigStatus.completed;
    final location = gig.location;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandNavy, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ACTIVE GIG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      switch (gig.status) {
                        SpotGigStatus.completed => 'Waiting for employer',
                        SpotGigStatus.inProgress => 'In progress',
                        _ => 'Claimed',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              gig.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            if (gig.employer.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                gig.employer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
            if (gig.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.accentBright,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      gig.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  gig.payLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentBright,
                  ),
                ),
                if (gig.totalLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      gig.totalLabel!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (gig.recruiterMobile.isNotEmpty) ...[
                  Expanded(
                    child: _GigAction(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      onTap: () => _call(context, gig.recruiterMobile),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _GigAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    onTap: () => openChatWithUser(
                      context,
                      ref,
                      receiverId: gig.recruiterId,
                      title: gig.employer.isNotEmpty
                          ? gig.employer
                          : 'Employer',
                    ),
                  ),
                ),
                if (location != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GigAction(
                      icon: Icons.directions_rounded,
                      label: 'Directions',
                      onTap: () => _directions(context, location),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (waiting)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                      color: AppColors.accentBright,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for the employer to confirm. Your pay goes '
                        'straight to your KaamMilega Wallet once they do.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (gig.canComplete)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: state.completing
                      ? null
                      : () => _complete(context, ref),
                  icon: state.completing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.success.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _call(BuildContext context, String mobile) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: mobile));
    } catch (_) {}
    if (!opened && context.mounted) {
      _snack(context, 'Could not open the phone app.', isError: true);
    }
  }

  static Future<void> _directions(
    BuildContext context,
    ({double lat, double lng}) to,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${to.lat},${to.lng}',
    });
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      _snack(context, 'Could not open maps.', isError: true);
    }
  }

  static Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Mark this gig as complete?',
      message:
          'Only do this when the work is done. The employer will be asked '
          'to confirm, and then your pay is credited to your wallet.',
      action: 'Mark complete',
    );
    if (!ok || !context.mounted) return;
    final result = await ref.read(spotGigsProvider.notifier).completeActive();
    if (!context.mounted) return;
    _snack(
      context,
      result.message,
      isError: result.outcome != InstantActionOutcome.success,
    );
  }
}

class _GigAction extends StatelessWidget {
  const _GigAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Open gigs near the user
// ---------------------------------------------------------------------------

/// "Spot Gigs Near You": open gigs for the user's primary trade, updated
/// every 15 s while the screen is open.
class SpotGigsSection extends ConsumerWidget {
  const SpotGigsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AuthGuard.isSignedIn(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(spotGigsProvider);
    final skill = ref.watch(instantCandidateProvider.select((s) => s.skill));
    final notifier = ref.read(spotGigsProvider.notifier);
    final allTrades = skill.trim().isEmpty || skill.toLowerCase() == 'all';

    final Widget body;
    final feed = state.feed;
    if (!state.hasLocation) {
      body = const _Notice(
        icon: Icons.location_off_outlined,
        title: 'Location needed',
        message:
            'Allow location for KaamMilega (at the top of this page) to see '
            'gigs near you.',
      );
    } else if (feed == null && state.feedError != null) {
      body = _Notice(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load gigs',
        message: 'Please check your connection and try again.',
        actionLabel: 'Retry',
        onAction: notifier.loadFeed,
      );
    } else if (feed == null) {
      body = const Column(
        children: [
          ShimmerBox(width: double.infinity, height: 150, borderRadius: 18),
          SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 150, borderRadius: 18),
        ],
      );
    } else if (feed.isEmpty) {
      body = _Notice(
        icon: Icons.radar_rounded,
        title: 'No open gigs near you right now',
        message:
            'New gigs appear here by themselves and stay open for only a '
            'few minutes, so keep this page open while you are online.',
        actionLabel: allTrades ? null : 'Show all trades',
        onAction: allTrades
            ? null
            : () => ref.read(instantCandidateProvider.notifier).setSkill('All'),
      );
    } else {
      final now = DateTime.now();
      body = Column(
        children: [
          for (final gig in feed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SpotGigCard(
                gig: gig,
                now: now,
                claiming: state.claimingId == gig.id,
                blockedReason: state.activeGig != null
                    ? 'Finish your current gig first'
                    : null,
                enabled: state.claimingId == null && state.activeGig == null,
                onClaim: () => _claim(context, ref, gig),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Spot Gigs '),
                        TextSpan(
                          text: 'Near You',
                          style: TextStyle(color: AppColors.accent),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${allTrades ? 'All trades' : skill} · within 15 km',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasLocation) ...[
              const _LivePill(),
              IconButton(
                tooltip: 'Refresh gigs',
                onPressed: state.feedLoading ? null : notifier.loadFeed,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        body,
      ],
    );
  }

  static Future<void> _claim(
    BuildContext context,
    WidgetRef ref,
    SpotGig gig,
  ) async {
    final status = ref.read(instantCandidateProvider).status;
    if (status == null) {
      _snack(context, 'Checking your pass. Please try again in a moment.');
      return;
    }
    if (!status.canGoOnline) {
      await showInstantPassSheet(context);
      return;
    }
    final ok = await _confirm(
      context,
      title: 'Claim this gig?',
      message:
          'This uses 1 of your ${status.quotaRemaining} pass gigs. Claim only '
          'if you can reach the site soon.',
      action: 'Claim gig',
    );
    if (!ok || !context.mounted) return;
    final result = await ref.read(spotGigsProvider.notifier).claim(gig);
    if (!context.mounted) return;
    if (result.outcome == InstantActionOutcome.passRequired) {
      await showInstantPassSheet(context);
      return;
    }
    _snack(
      context,
      result.message,
      isError: result.outcome != InstantActionOutcome.success,
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: AppColors.success),
          SizedBox(width: 5),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotGigCard extends StatelessWidget {
  const _SpotGigCard({
    required this.gig,
    required this.now,
    required this.claiming,
    required this.enabled,
    required this.onClaim,
    this.blockedReason,
  });

  final SpotGig gig;
  final DateTime now;
  final bool claiming;
  final bool enabled;
  final String? blockedReason;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final minutes = gig.minutesLeft(now);
    final facts = <(IconData, String)>[
      if (gig.durationHours > 0)
        (
          Icons.schedule_rounded,
          '${gig.durationHours} ${gig.durationHours == 1 ? 'hr' : 'hrs'}',
        ),
      if (gig.distanceLabel != null)
        (Icons.near_me_outlined, gig.distanceLabel!),
      if (gig.requiredWorkers > 1)
        (Icons.groups_outlined, '${gig.requiredWorkers} needed'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _tradeIcon(gig.skill),
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gig.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (gig.employer.isNotEmpty)
                      Text(
                        gig.employer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (minutes != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.moduleEventsLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    minutes <= 1 ? 'Closing' : '$minutes min left',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309), // dark amber on light amber
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gig.payLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
              for (final (icon, label) in facts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (gig.address.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    gig.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
          if (gig.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              gig.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: enabled ? onClaim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: claiming
                    ? AppColors.accent.withValues(alpha: 0.7)
                    : AppColors.background,
                disabledForegroundColor: claiming
                    ? Colors.white
                    : AppColors.textLight,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: claiming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      blockedReason ?? 'Claim gig',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings
// ---------------------------------------------------------------------------

/// Gig pay credited to the wallet today and in the last 7 days (from the
/// wallet ledger), with a link to the wallet.
class GigEarningsCard extends ConsumerWidget {
  const GigEarningsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AuthGuard.isSignedIn(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(spotGigsProvider);
    final earnings = state.earnings;

    Widget content;
    if (earnings == null && state.earningsError != null) {
      content = Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load your gig earnings.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: ref.read(spotGigsProvider.notifier).loadEarnings,
            child: const Text('Retry'),
          ),
        ],
      );
    } else if (earnings == null) {
      content = const ShimmerBox(
        width: double.infinity,
        height: 76,
        borderRadius: 14,
      );
    } else {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _EarningTile(
                label: 'Today',
                amount: earnings.today,
                gigs: earnings.todayGigs,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EarningTile(
                label: 'Last 7 days',
                amount: earnings.week,
                gigs: earnings.weekGigs,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: AppColors.success,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your gig earnings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, size: 16, color: AppColors.success),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No commission: the full gig pay is credited to your '
                  'KaamMilega Wallet once the employer confirms.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/wallet'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              iconAlignment: IconAlignment.end,
              label: const Text('Open wallet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningTile extends StatelessWidget {
  const _EarningTile({
    required this.label,
    required this.amount,
    required this.gigs,
  });

  final String label;
  final double amount;
  final int gigs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatInr(amount),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$gigs ${gigs == 1 ? 'gig' : 'gigs'} paid',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft message with an optional action, used for list states.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
