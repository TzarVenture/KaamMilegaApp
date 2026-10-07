import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../applications/repositories/application_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../interviews/models/interview.dart';
import '../../../interviews/repositories/interview_repository.dart';
import '../../../jobs/providers/jobs_provider.dart';
import '../../../profile/models/profile_strength.dart';

/// The time used for the greeting (replaced in tests).
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// "Good morning" until noon, "Good afternoon" until 5 pm, then
/// "Good evening".
String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Good evening, Dev" (first name) for a signed-in user, "Good evening"
/// for guests, with one line under it. White text: sits on the navy Home
/// header.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final signedIn = AuthGuard.isSignedIn(auth);
    final first = signedIn
        ? (auth.user?.name.trim().split(RegExp(r'\s+')).first ?? '')
        : '';
    final hello = greetingFor(ref.watch(homeClockProvider)());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          first.isEmpty ? hello : '$hello, $first',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          signedIn
              ? 'Find your next job today.'
              : 'Jobs, gigs and mentors near you.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Upcoming interviews (time still ahead and not cancelled or done).
int upcomingInterviews(List<InterviewItem> items, DateTime now) {
  const closed = {'cancelled', 'canceled', 'completed', 'done', 'rejected'};
  return items.where((i) {
    final at = i.scheduledAt;
    return at != null &&
        at.toLocal().isAfter(now) &&
        !closed.contains(i.status.toLowerCase());
  }).length;
}

/// One card for a signed-in user: their real numbers (applications,
/// upcoming interviews, saved jobs; each opens its list) and, until the
/// profile is complete, a progress bar with the next step (opens Profile).
/// A number that could not be loaded shows "–" (never a made-up 0).
class HomeDashboardCard extends ConsumerWidget {
  const HomeDashboardCard({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (!AuthGuard.isSignedIn(auth) || user == null) {
      return const SizedBox.shrink();
    }
    final now = ref.watch(homeClockProvider)();
    final applied = ref.watch(myApplicationsProvider).whenData((a) => a.length);
    final interviews = ref
        .watch(myInterviewsProvider)
        .whenData((i) => upcomingInterviews(i, now));
    final saved = ref.watch(jobsProvider.select((s) => s.savedJobIds.length));
    final strength = ProfileStrength.of(user);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Stat(
                      value: applied,
                      label: 'Applied',
                      icon: Icons.send_rounded,
                      color: AppColors.blue,
                      onTap: () => context.push('/my-applications'),
                    ),
                  ),
                  const _Divider(),
                  Expanded(
                    child: _Stat(
                      value: interviews,
                      label: 'Interviews',
                      semanticLabel: 'Upcoming interviews',
                      icon: Icons.event_available_rounded,
                      color: AppColors.success,
                      onTap: () => context.push('/interviews'),
                    ),
                  ),
                  const _Divider(),
                  Expanded(
                    child: _Stat(
                      value: AsyncValue.data(saved),
                      label: 'Saved',
                      semanticLabel: 'Saved jobs',
                      icon: Icons.bookmark_rounded,
                      color: AppColors.accent,
                      onTap: () => context.push('/saved-jobs'),
                    ),
                  ),
                ],
              ),
            ),
            if (!strength.isComplete) ...[
              const Divider(height: 1, color: AppColors.borderLight),
              _ProfileProgress(strength: strength, onTap: onOpenProfile),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: AppColors.borderLight,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final AsyncValue<int> value;
  final String label;
  final String? semanticLabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = value.value;
    final failed = number == null && value.hasError;
    final name = semanticLabel ?? label;
    return Semantics(
      button: true,
      label: failed
          ? '$name: could not load. Opens the list.'
          : number == null
          ? '$name: loading'
          : '$name: $number',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 24,
                child: Center(
                  child: number == null && !failed
                      ? const ShimmerBox(width: 24, height: 18, borderRadius: 6)
                      : Text(
                          number?.toString() ?? '–',
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
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
      ),
    );
  }
}

/// "Profile 25% complete" with a bar and the next step.
class _ProfileProgress extends StatelessWidget {
  const _ProfileProgress({required this.strength, required this.onTap});

  final ProfileStrength strength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = strength.next!;
    return Semantics(
      button: true,
      label:
          'Your profile is ${strength.percent}% complete. Next: '
          '${next.action}. Opens your profile.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: AppColors.accentLight,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile ${strength.percent}% complete',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: strength.percent / 100),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: AppColors.white,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Next: ${next.action}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.accentText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
