import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/app_exception.dart';
import '../../../shared/widgets/network_state_view.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../home/presentation/widgets/home_section_header.dart';
import '../../network/providers/network_provider.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import 'widgets/people_like_you_card.dart';

/// "People like you" for one job: real members (GET /community/users)
/// ordered by how closely they match the job (skills, role, city), each
/// with Chat and Connect. Who applied to a job is private, so it is never
/// shown here.
class JobPeopleScreen extends ConsumerWidget {
  const JobPeopleScreen({super.key, required this.jobId, this.initialJob});

  final String jobId;
  final Job? initialJob;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = initialJob ?? ref.watch(savedJobDetailProvider(jobId)).value;
    final jobAsync = initialJob == null
        ? ref.watch(savedJobDetailProvider(jobId))
        : AsyncData<Job?>(initialJob);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        surfaceTintColor: AppColors.brandNavy,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 4,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/jobs'),
        ),
        title: const Text(
          'People like you',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: switch (jobAsync) {
        AsyncError(:final error) => NetworkStateView(
          isOffline: error is AppNetworkException,
          errorMessage: error is AppException
              ? error.message
              : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(savedJobDetailProvider(jobId)),
          child: const SizedBox.shrink(),
        ),
        AsyncData(value: null) => const NetworkStateView(
          isEmpty: true,
          emptyTitle: 'Job not found',
          emptyMessage: 'This job is no longer available.',
          child: SizedBox.shrink(),
        ),
        _ when job == null => const _Skeleton(),
        _ => _PeopleList(job: job),
      },
    );
  }
}

class _PeopleList extends ConsumerWidget {
  const _PeopleList({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkSuggestionsProvider);
    return RefreshIndicator(
      color: AppColors.brandOrange,
      onRefresh: () => ref.refresh(networkSuggestionsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _JobBanner(job: job),
          ...async.when<List<Widget>>(
            data: (users) {
              final people = rankPeopleLikeYou(users, job, count: users.length);
              if (people.isEmpty) {
                return const [
                  SizedBox(
                    height: 360,
                    child: NetworkStateView(
                      isEmpty: true,
                      emptyTitle: 'No members to suggest yet',
                      emptyMessage:
                          'As more people join KaamMilega, members like you '
                          'will appear here.',
                      child: SizedBox.shrink(),
                    ),
                  ),
                ];
              }
              final matched = people.where((p) => p.match.isNotEmpty).length;
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Text(
                    matched > 0
                        ? '$matched with a similar profile'
                        : 'Members on KaamMilega',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (final p in people)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: HomeCard.decoration(),
                      child: PersonLikeYouRow(person: p),
                    ),
                  ),
              ];
            },
            loading: () => const [_Skeleton(shrinkWrap: true)],
            error: (e, _) => [
              SizedBox(
                height: 360,
                child: NetworkStateView(
                  isOffline: e is AppNetworkException,
                  errorMessage: 'Could not load people right now.',
                  onRetry: () => ref.invalidate(networkSuggestionsProvider),
                  child: const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The job these suggestions are for, with a short explanation.
class _JobBanner extends StatelessWidget {
  const _JobBanner({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final company = job.company.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      decoration: const BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect with people heading for roles like',
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Matched by skills, role and city. Applicants stay private.',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.shrinkWrap = false});

  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: 4,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: ShimmerBox(
          width: double.infinity,
          height: 128,
          borderRadius: 16,
        ),
      ),
    );
  }
}
