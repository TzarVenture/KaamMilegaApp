import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/open_chat.dart';
import '../../home/presentation/widgets/featured_companies_section.dart';
import '../../jobs/models/job.dart';
import '../../jobs/presentation/widgets/job_card.dart';
import '../../jobs/providers/jobs_provider.dart';
import '../models/top_company.dart';
import '../providers/company_provider.dart';

/// Company page (`/company/:id`, id = the employer's recruiter id): the
/// employer's open jobs from GET /jobs?recruiter_id=. The header uses the
/// company passed from Home; opened without it, the name comes from the
/// jobs themselves. Nothing about the company is invented.
class CompanyScreen extends ConsumerWidget {
  final String companyId;
  final TopCompany? company;

  const CompanyScreen({super.key, required this.companyId, this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(companyJobsProvider(companyId));
    final jobs = jobsAsync.asData?.value ?? const <Job>[];
    final name =
        company?.name ??
        (jobs.isNotEmpty && jobs.first.company.trim().isNotEmpty
            ? jobs.first.company.trim()
            : 'Company');
    final header = company ?? TopCompany(id: companyId, name: name);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(companyJobsProvider(companyId).future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _CompanyHeader(company: header)),
            ...jobsAsync.when(
              data: (list) => list.isEmpty
                  ? [
                      const SliverFillRemaining(
                        hasScrollBody: true,
                        child: NetworkStateView(
                          isEmpty: true,
                          emptyTitle: 'No open jobs right now',
                          emptyMessage:
                              'This employer has no open jobs at the moment. '
                              'Please check again later.',
                          child: SizedBox.shrink(),
                        ),
                      ),
                    ]
                  : [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            '${list.length} open ${list.length == 1 ? 'job' : 'jobs'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) => FadeSlideIn(
                          index: index,
                          child: _CompanyJobCard(job: list[index]),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
              loading: () => [
                const SliverToBoxAdapter(
                  child: ShimmerLoadingList(count: 3, itemHeight: 150),
                ),
              ],
              error: (err, _) => [
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: NetworkStateView.fromError(
                    err,
                    onRetry: () =>
                        ref.invalidate(companyJobsProvider(companyId)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.company});

  final TopCompany company;

  Future<void> _openWebsite(BuildContext context) async {
    final raw = company.website.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the website: $raw')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      company.category,
      company.location,
    ].where((v) => v.isNotEmpty).join(' · ');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogo(company: company, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        company.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (company.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppColors.blue,
                        semanticLabel: 'Verified',
                      ),
                    ],
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (company.verified) ...[
                  const SizedBox(height: 8),
                  const VerifiedEmployerPill(),
                ],
                if (company.website.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openWebsite(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.language_rounded, size: 16),
                    label: const Text('Visit website'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Same job card and actions as the Jobs tab.
class _CompanyJobCard extends ConsumerWidget {
  const _CompanyJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      jobsProvider.select((s) => s.savedJobIds.contains(job.id)),
    );
    return JobCard(
      job: job,
      isSaved: saved,
      onBookmarkToggle: () =>
          ref.read(jobsProvider.notifier).toggleSaveJob(job.id),
      onTap: () => context.push('/jobs/${job.id}', extra: job),
      onApply: () => context.push('/jobs/${job.id}', extra: job),
      onChat: () {
        if (!ref.read(authProvider).isAuthenticated) {
          showAuthPromptDialog(
            context,
            title: 'Sign In to Chat',
            message:
                'Please sign in to your KaamMilega account to chat with '
                'the recruiter.',
          );
          return;
        }
        openChatWithUser(
          context,
          ref,
          receiverId: job.recruiterId,
          title: '${job.company} Recruiter',
        );
      },
      onCall: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calling recruiters is coming soon. Please use Chat to contact '
            'the recruiter.',
          ),
        ),
      ),
    );
  }
}
