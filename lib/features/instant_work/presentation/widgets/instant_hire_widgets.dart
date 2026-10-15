import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../../shared/widgets/network_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/spot_gig.dart';
import '../../providers/instant_hire_provider.dart';
import '../../providers/instant_milega_provider.dart';
import '../hire_request_screen.dart';
import 'nearby_professionals_section.dart';

/// "Hire | Work" switch at the top of Instant Milega. Switching only
/// changes what is shown.
class InstantModeToggle extends ConsumerWidget {
  const InstantModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(instantModeProvider);
    final notifier = ref.read(instantModeProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Hire',
                  icon: Icons.person_search_rounded,
                  selected: mode == InstantMode.hire,
                  onTap: () => notifier.select(InstantMode.hire),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ModeButton(
                  label: 'Work',
                  icon: Icons.handyman_rounded,
                  selected: mode == InstantMode.work,
                  onTap: () => notifier.select(InstantMode.work),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            mode == InstantMode.hire
                ? 'Hire: get a worker near you for a quick job.'
                : 'Work: find quick paid gigs near you.',
            key: ValueKey(mode),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label mode',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleInstantWork : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: selected ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything shown in Hire mode: post a quick job, its live status, and
/// the workers who are free near you.
class InstantHireSection extends ConsumerWidget {
  const InstantHireSection({super.key});

  Future<void> _post(BuildContext context, WidgetRef ref) async {
    final location = ref.read(instantMilegaProvider).location;
    if (location == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Turn on location first so workers near you can see the job.',
            ),
          ),
        );
      return;
    }
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HireRequestScreen(location: location)),
    );
    if (posted == true) ref.invalidate(activeHireRequestProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = AuthGuard.isSignedIn(ref.watch(authProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (signedIn) ...[
          const HireActiveRequestCard(),
          _PostJobCard(onPost: () => _post(context, ref)),
        ] else
          _PostJobCard(
            onPost: () => showAuthPromptDialog(
              context,
              title: 'Login Required',
              message: 'Please log in to hire a worker.',
            ),
            signInFirst: true,
          ),
        const SizedBox(height: 18),
        const NearbyProfessionalsSection(),
      ],
    );
  }
}

/// Orange call to action: "Need a worker now?"
class _PostJobCard extends StatelessWidget {
  const _PostJobCard({required this.onPost, this.signInFirst = false});

  final VoidCallback onPost;
  final bool signInFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentBright],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a worker now?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Post a quick job. Workers who are free near you see '
                      'it, and the first to accept takes it.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.accentDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                signInFirst ? Icons.login_rounded : Icons.add_rounded,
                size: 20,
              ),
              label: Text(
                signInFirst ? 'Sign in to hire' : 'Post a quick job',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// My open quick job: waiting for a worker, taken by a worker, or marked
/// done by the worker. Nothing is shown when there is none.
class HireActiveRequestCard extends ConsumerWidget {
  const HireActiveRequestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeHireRequestProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: ShimmerBox(
          width: double.infinity,
          height: 120,
          borderRadius: 20,
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _StatusShell(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Could not load your request',
          message: NetworkStateView.errorMessageFor(e),
          actions: [
            OutlinedButton(
              onPressed: () => ref.invalidate(activeHireRequestProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (gig) => gig == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ActiveRequest(gig: gig),
            ),
    );
  }
}

class _ActiveRequest extends ConsumerWidget {
  const _ActiveRequest({required this.gig});

  final SpotGig gig;

  Future<void> _call(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: gig.candidateMobile));
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not start a call.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final details = [
      gig.title,
      gig.payLabel,
      if (gig.address.isNotEmpty) gig.address,
    ].join('  ·  ');
    final refresh = TextButton.icon(
      onPressed: () => ref.invalidate(activeHireRequestProvider),
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh status'),
    );

    if (gig.isExpiredAt(now)) {
      return _StatusShell(
        icon: Icons.timer_off_outlined,
        color: AppColors.textSecondary,
        title: 'No worker accepted in time',
        message:
            '$details\nThe request was open for 3 minutes. Post it again '
            'to reach workers who are free now.',
      );
    }
    switch (gig.status) {
      case SpotGigStatus.dispatching:
        final until = gig.expiresAt;
        return _StatusShell(
          icon: Icons.radar_rounded,
          color: AppColors.moduleInstantWork,
          title: 'Looking for a worker',
          message:
              '$details\n'
              '${until == null ? 'Open for 3 minutes.' : 'Open until ${DateFormat('h:mm a').format(until)}.'} '
              'The first worker to accept gets the job.',
          actions: [refresh],
        );
      case SpotGigStatus.accepted:
      case SpotGigStatus.inProgress:
        final name = gig.candidateName.isEmpty ? 'A worker' : gig.candidateName;
        return _StatusShell(
          icon: Icons.verified_rounded,
          color: AppColors.success,
          title: '$name accepted your job',
          message:
              '$details\nCall to share the exact place and timing. Pay the '
              'worker directly when the work is done.',
          actions: [
            if (gig.candidateMobile.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _call(context),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call worker'),
              ),
            refresh,
          ],
        );
      case SpotGigStatus.completed:
        return _StatusShell(
          icon: Icons.task_alt_rounded,
          color: AppColors.blue,
          title: 'The worker marked the job done',
          message:
              '$details\nPay the worker directly. Confirming and paying in '
              'the app is not available yet.',
          actions: [refresh],
        );
      case SpotGigStatus.closed:
      case SpotGigStatus.cancelled:
      case SpotGigStatus.expired:
      case SpotGigStatus.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _StatusShell extends StatelessWidget {
  const _StatusShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}
