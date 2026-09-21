import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/models/job.dart';
import '../../jobs/models/job_filter.dart';
import '../../jobs/repositories/job_repository.dart';

class InstantWorkState {
  final List<Job> gigs;
  final bool isLoading;
  final String? error;
  final String activeFilter; // 'All', 'Today', 'Hourly', 'Urgent', 'Nearby'
  final String searchQuery;

  const InstantWorkState({
    this.gigs = const [],
    this.isLoading = false,
    this.error,
    this.activeFilter = 'All',
    this.searchQuery = '',
  });

  InstantWorkState copyWith({
    List<Job>? gigs,
    bool? isLoading,
    String? error,
    String? activeFilter,
    String? searchQuery,
  }) {
    return InstantWorkState(
      gigs: gigs ?? this.gigs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class InstantWorkNotifier extends Notifier<InstantWorkState> {
  late final JobRepository _repository;

  @override
  InstantWorkState build() {
    _repository = ref.watch(jobRepositoryProvider);
    Future.microtask(() => loadGigs());
    return const InstantWorkState();
  }

  Future<void> loadGigs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Query backend jobs engine with gig / hourly / instant job types
      final filter = JobFilter(
        searchQuery: state.searchQuery,
        jobTypes: const ['Instant', 'Hourly', 'Gig', 'Part-time'],
        limit: 30,
      );
      final response = await _repository.getJobs(filter);
      state = state.copyWith(isLoading: false, gigs: response.jobs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadGigs();

  void setFilter(String filter) {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);
    loadGigs();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadGigs();
  }
}

final instantWorkProvider =
    NotifierProvider<InstantWorkNotifier, InstantWorkState>(() {
      return InstantWorkNotifier();
    });
