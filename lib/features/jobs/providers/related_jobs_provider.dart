import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job.dart';
import '../models/job_filter.dart';
import '../repositories/job_repository.dart';

/// What a "related jobs" page lists: one job type, or jobs open to someone
/// with up to [maxExperience] years.
typedef RelatedJobsQuery = ({String jobType, int? maxExperience});

class RelatedJobsState {
  const RelatedJobsState({
    this.jobs = const [],
    this.total = 0,
    this.page = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<Job> jobs;
  final int total;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasMore => jobs.length < total;
}

class RelatedJobsNotifier extends Notifier<RelatedJobsState> {
  RelatedJobsNotifier(this.query);

  final RelatedJobsQuery query;
  static const int pageSize = 10;
  int _generation = 0;

  @override
  RelatedJobsState build() {
    Future.microtask(refresh);
    return const RelatedJobsState(isLoading: true);
  }

  JobFilter _filter(int page) => JobFilter(
    jobTypes: query.jobType.isEmpty ? const [] : [query.jobType],
    experience: query.maxExperience == null ? 'all' : '${query.maxExperience}',
    page: page,
    limit: pageSize,
  );

  Future<void> refresh() async {
    final generation = ++_generation;
    state = RelatedJobsState(isLoading: true, jobs: state.jobs);
    try {
      final res = await ref.read(jobRepositoryProvider).getJobs(_filter(1));
      if (!ref.mounted || generation != _generation) return;
      state = RelatedJobsState(jobs: res.jobs, total: res.total, page: 1);
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = RelatedJobsState(jobs: state.jobs, error: e);
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.isLoading || s.isLoadingMore || !s.hasMore) return;
    final generation = _generation;
    state = RelatedJobsState(
      jobs: s.jobs,
      total: s.total,
      page: s.page,
      isLoadingMore: true,
    );
    try {
      final res = await ref
          .read(jobRepositoryProvider)
          .getJobs(_filter(s.page + 1));
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final j in s.jobs) j.id};
      final added = res.jobs.where((j) => !known.contains(j.id)).toList();
      state = RelatedJobsState(
        jobs: [...s.jobs, ...added],
        // An empty page means the server has nothing more.
        total: added.isEmpty ? s.jobs.length : res.total,
        page: s.page + 1,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = RelatedJobsState(
        jobs: s.jobs,
        total: s.total,
        page: s.page,
        loadMoreError: e,
      );
    }
  }
}

final relatedJobsProvider = NotifierProvider.autoDispose
    .family<RelatedJobsNotifier, RelatedJobsState, RelatedJobsQuery>(
      RelatedJobsNotifier.new,
    );
