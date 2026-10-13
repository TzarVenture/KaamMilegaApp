import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_guard.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/network/app_exception.dart';
import '../../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../auth/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../company/providers/company_provider.dart';
import '../../../home/presentation/widgets/connect_like_you_section.dart';
import '../../../home/presentation/widgets/home_section_header.dart';
import '../../../network/presentation/widgets/connect_button.dart';
import '../../../network/providers/network_provider.dart';
import '../../models/job.dart';

/// Job page: "Meet the recruiter". The real recruiter profile
/// (GET /user/:id, needs a login) with Message and Connect, and a link to
/// the company page. Guests are asked to log in; a private profile says
/// so (Message still works). Nothing about the recruiter is invented.
class JobRecruiterCard extends ConsumerWidget {
  const JobRecruiterCard({
    super.key,
    required this.job,
    required this.onMessage,
  });

  final Job job;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = AuthGuard.isSignedIn(ref.watch(authProvider));
    final verified =
        ref
            .watch(verifiedEmployerIdsProvider)
            .value
            ?.contains(job.recruiterId) ??
        false;
    final company = job.company.trim();

    Widget body;
    if (job.recruiterId.isEmpty) {
      body = _CompanyOnly(
        company: company,
        note: 'Recruiter details are not shared for this job.',
      );
    } else if (!signedIn) {
      body = _CompanyOnly(
        company: company,
        note: 'Log in to see who is hiring and connect with them.',
        action: FilledButton.icon(
          onPressed: () => showAuthPromptDialog(
            context,
            title: 'Login Required',
            message: 'Please log in to view the recruiter and connect.',
          ),
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: const Text('Log in to connect'),
        ),
      );
    } else {
      final async = ref.watch(memberProfileProvider(job.recruiterId));
      body = async.when(
        data: (user) => _RecruiterRow(
          user: user,
          company: company,
          verified: verified,
          onMessage: onMessage,
        ),
        loading: () => const _Loading(),
        error: (e, _) {
          final isPrivate = e is AppAuthException && e.statusCode == 403;
          if (isPrivate || e is AppNotFoundException) {
            return _CompanyOnly(
              company: company,
              note: isPrivate
                  ? "The recruiter's profile is private."
                  : 'Recruiter profile not found.',
              action: OutlinedButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Message recruiter'),
              ),
            );
          }
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load the recruiter right now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(memberProfileProvider(job.recruiterId)),
                child: const Text('Retry'),
              ),
            ],
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: HomeCard.decoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JobSectionTitle(
            icon: Icons.badge_outlined,
            title: 'Meet the recruiter',
            subtitle: 'The person hiring for this role',
          ),
          const SizedBox(height: 16),
          body,
          if (job.recruiterId.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.borderLight),
            TextButton(
              onPressed: () => context.push('/company/${job.recruiterId}'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apartment_rounded, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      company.isEmpty ? 'View company' : 'View $company',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RecruiterRow extends StatelessWidget {
  const _RecruiterRow({
    required this.user,
    required this.company,
    required this.verified,
    required this.onMessage,
  });

  final UserProfile user;
  final String company;
  final bool verified;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim().isNotEmpty ? user.name.trim() : 'Recruiter';
    final headline = user.headline.trim().isNotEmpty
        ? user.headline.trim()
        : (company.isNotEmpty ? 'Recruiter at $company' : 'Recruiter');
    final city = user.city.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/members/${user.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                PersonAvatar(user: user, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'KM Verified Employer',
                              child: Icon(
                                Icons.verified_rounded,
                                size: 17,
                                color: AppColors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text(
                    'Message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ConnectButton(
                userId: user.id,
                name: name,
                height: 42,
                fontSize: 13.5,
                showIcon: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Company name only (guest, private profile or no recruiter id).
class _CompanyOnly extends StatelessWidget {
  const _CompanyOnly({required this.company, required this.note, this.action});

  final String company;
  final String note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final initial = company.isNotEmpty ? company[0].toUpperCase() : '?';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.isEmpty ? 'Recruiter' : '$company recruiter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            ShimmerCircle(size: 58),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 150, height: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 200, height: 11),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 14),
        ShimmerBox(width: double.infinity, height: 42, borderRadius: 12),
        SizedBox(height: 8),
      ],
    );
  }
}

/// Icon + title + subtitle header for the job page's people sections.
class JobSectionTitle extends StatelessWidget {
  const JobSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
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
        ?trailing,
      ],
    );
  }
}
