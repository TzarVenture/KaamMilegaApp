import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/auth_prompt_dialog.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/open_chat.dart';
import '../../company/providers/company_provider.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../providers/related_jobs_provider.dart';
import 'job_links.dart';
import 'widgets/job_card.dart';

/// Jobs related to a tapped job-card chip: one job type ("Full-time jobs")
/// or jobs open to an experience level ("Jobs for 0-1 Yrs"). Real server
/// results with paging, pull to refresh, loading / empty / error states.
class RelatedJobsScreen extends ConsumerWidget {
  const RelatedJobsScreen({
    super.key,
    this.jobType = '',
    this.maxExperience,
    this.experienceLabel = '',
  });

  final String jobType;
  final int? maxExperience;
  final String experienceLabel;

  RelatedJobsQuery get _query =>
      (jobType: jobType, maxExperience: maxExperience);

  String get _title {
    if (jobType.isNotEmpty) return '$jobType jobs';
    final label = experienceLabel.isNotEmpty
        ? experienceLabel
        : '${maxExperience ?? 0} Yrs';
    return 'Jobs for $label';
  }

  String get _subtitle => jobType.isNotEmpty
      ? 'All open $jobType roles on KaamMilega'
      : 'Roles that accept your experience level';

  IconData get _icon =>
      jobType.isNotEmpty ? Icons.work_outline_rounded : Icons.schedule_rounded;

  void _chat(BuildContext context, WidgetRef ref, Job job) {
    if (!ref.read(authProvider).isAuthenticated) {
      showAuthPromptDialog(
        context,
        title: 'Sign In to Chat',
        message: 'Please sign in to your KaamMilega account to chat with the recruiter.',
      );
      return;
    }
    openChatWithUser(
      context,
      ref,
      receiverId: job.recruiterId,
      title: '${job.company} Recruiter',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = relatedJobsProvider(_query);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final saved = ref.watch(jobsProvider.select((s) => s.savedJobIds));
    final verified =
        ref.watch(verifiedEmployerIdsProvider).value ?? const <String>{};
    final firstError = state.jobs.isEmpty ? state.error : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.brandOrange,
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.brandNavy,
              // The app theme colours app bar icons navy; white on this navy bar.
              iconTheme: const IconThemeData(color: AppColors.white),
              actionsIconTheme: const IconThemeData(color: AppColors.white),
              surfaceTintColor: AppColors.brandNavy,
              foregroundColor: AppColors.white,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.white,
                ),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/jobs'),
              ),
              titleSpacing: 4,
              title: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Hero(
                icon: _icon,
                subtitle: _subtitle,
                count: state.isLoading && state.jobs.isEmpty
                    ? null
                    : state.total,
              ),
            ),
            if (state.isLoading && state.jobs.isEmpty)
              SliverList.builder(
                itemCount: 4,
                itemBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 150,
                    borderRadius: 18,
                  ),
                ),
              )
            else if (firstError != null || state.jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: NetworkStateView(
                  isOffline: firstError is AppNetworkException,
                  errorMessage: firstError == null
                      ? null
                      : (firstError is AppException
                            ? firstError.message
                            : 'Something went wrong. Please try again.'),
                  onRetry: notifier.refresh,
                  isEmpty: true,
                  emptyTitle: 'No jobs right now',
                  emptyMessage:
                      'There are no open roles here yet. Check again soon.',
                  child: const SizedBox.shrink(),
                ),
              )
            else ...[
              SliverList.builder(
                itemCount: state.jobs.length,
                itemBuilder: (context, i) {
                  final job = state.jobs[i];
                  return JobCard(
                    key: ValueKey(job.id),
                    job: job,
                    isSaved: saved.contains(job.id),
                    isVerifiedEmployer:
                        job.recruiterId.isNotEmpty &&
                        verified.contains(job.recruiterId),
                    onBookmarkToggle: () =>
                        ref.read(jobsProvider.notifier).toggleSaveJob(job.id),
                    onTap: () => context.push('/jobs/${job.id}', extra: job),
                    onApply: () => context.push('/jobs/${job.id}', extra: job),
                    onChat: () => _chat(context, ref, job),
                    onCall: () => showRecruiterCallSheet(
                      context,
                      onChat: () => _chat(context, ref, job),
                    ),
                    onLinkTap: (link) => openJobLink(context, job, link),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: _Footer(state: state, onLoadMore: notifier.loadMore),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.icon, required this.subtitle, this.count});

  final IconData icon;
  final String subtitle;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      decoration: const BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == null
                      ? 'Loading jobs...'
                      : count == 1
                      ? '1 open job'
                      : '$count open jobs',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final RelatedJobsState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Could not load more. Retry'),
          ),
        ),
      );
    }
    if (state.hasMore) {
      if (!state.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: ShimmerBox(
          width: double.infinity,
          height: 120,
          borderRadius: 18,
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: Text(
          "You've seen all jobs here",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
