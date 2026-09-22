import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../models/job.dart';
import '../models/job_filter.dart';
import '../repositories/job_repository.dart';

/// State of the Jobs Feed screen
class JobsState {
  final List<Job> jobs;
  final int totalJobs;
  final bool isLoading;
  final bool isOffline;
  final String? errorMessage;
  final JobFilter filter;
  final Set<String> savedJobIds;
  final DateTime? cachedTimestamp;

  const JobsState({
    this.jobs = const [],
    this.totalJobs = 0,
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.filter = const JobFilter(),
    this.savedJobIds = const {},
    this.cachedTimestamp,
  });

  JobsState copyWith({
    List<Job>? jobs,
    int? totalJobs,
    bool? isLoading,
    bool? isOffline,
    String? errorMessage,
    JobFilter? filter,
    Set<String>? savedJobIds,
    DateTime? cachedTimestamp,
  }) {
    return JobsState(
      jobs: jobs ?? this.jobs,
      totalJobs: totalJobs ?? this.totalJobs,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      errorMessage: errorMessage,
      filter: filter ?? this.filter,
      savedJobIds: savedJobIds ?? this.savedJobIds,
      cachedTimestamp: cachedTimestamp,
    );
  }

  int get totalPages => (totalJobs / filter.limit).ceil();
}

/// Riverpod Notifier for managing Jobs State smoothly with offline caching & recovery
class JobsNotifier extends Notifier<JobsState> {
  late final JobRepository _repository;
  int _currentRequestId = 0;

  @override
  JobsState build() {
    _repository = ref.watch(jobRepositoryProvider);
    final cachedSaved = LocalStorage.getSavedJobIds();

    // Listen to network status for smart recovery on reconnect
    ref.listen<NetworkStatus>(networkStatusProvider, (prev, next) {
      if (prev == NetworkStatus.offline && next == NetworkStatus.online) {
        // Auto-refresh when internet returns
        if (state.isOffline ||
            state.cachedTimestamp != null ||
            state.errorMessage != null) {
          fetchJobs();
        }
      }
    });

    // Check cached jobs initially
    final cachedData = LocalStorage.getCachedJobs();
    List<Job> initialJobs = [];
    DateTime? initialTimestamp;
    if (cachedData.jobs.isNotEmpty) {
      try {
        initialJobs = cachedData.jobs.map((m) => Job.fromJson(m)).toList();
        initialTimestamp = cachedData.timestamp;
      } catch (_) {}
    }

    Future.microtask(() => fetchJobs());

    return JobsState(
      jobs: initialJobs,
      totalJobs: initialJobs.length,
      savedJobIds: cachedSaved,
      cachedTimestamp: initialTimestamp,
    );
  }

  /// Toggle saving / bookmarking a job
  void toggleSaveJob(String jobId) {
    final current = Set<String>.from(state.savedJobIds);
    if (current.contains(jobId)) {
      current.remove(jobId);
    } else {
      current.add(jobId);
    }
    state = state.copyWith(savedJobIds: current);
    LocalStorage.saveSavedJobIds(current);
  }

  /// Fetch jobs with current filter
  Future<void> fetchJobs() async {
    final requestId = ++_currentRequestId;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _repository.getJobs(state.filter);
      if (requestId != _currentRequestId) return;

      // Save to local cache
      try {
        final jobMaps = response.jobs
            .map(
              (j) => {
                'id': j.id,
                'recruiter_id': j.recruiterId,
                'title': j.title,
                'description': j.description,
                'company': j.company,
                'city_id': j.cityId,
                'city_name': j.cityName,
                'location': j.location,
                'salary_min': j.salaryMin,
                'salary_max': j.salaryMax,
                'job_type': j.jobType,
                'status': j.status,
                'requirements': j.requirements,
                'we_offer': j.weOffer,
                'gender': j.gender,
                'education': j.education,
                'experience_min': j.experienceMin,
                'experience_max': j.experienceMax,
                'vacancies': j.vacancies,
                'applicant_count': j.applicantCount,
                'created_at': j.createdAt?.toIso8601String(),
              },
            )
            .toList();
        LocalStorage.saveCachedJobs(jobMaps);
      } catch (_) {}

      state = state.copyWith(
        jobs: response.jobs,
        totalJobs: response.total,
        isLoading: false,
        isOffline: false,
        errorMessage: null,
        cachedTimestamp: null,
      );
    } catch (e) {
      if (requestId != _currentRequestId) return;

      // Check if we have cached jobs to display gracefully
      final cached = LocalStorage.getCachedJobs();
      if (cached.jobs.isNotEmpty) {
        try {
          final cachedList = cached.jobs.map((m) => Job.fromJson(m)).toList();
          state = state.copyWith(
            jobs: cachedList,
            totalJobs: cachedList.length,
            isLoading: false,
            isOffline: false,
            errorMessage: null,
            cachedTimestamp: cached.timestamp ?? DateTime.now(),
          );
          return;
        } catch (_) {}
      }

      // If no cache, display clean offline / error state
      final isOffline =
          ref.read(isOnlineProvider) == false ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('offline') ||
          e.toString().toLowerCase().contains('socket');

      state = state.copyWith(
        isLoading: false,
        isOffline: isOffline,
        errorMessage: isOffline ? null : e.toString(),
      );
    }
  }

  /// Update search query
  void setSearchQuery(String query) {
    if (state.filter.searchQuery == query) return;
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query, page: 1),
    );
    fetchJobs();
  }

  /// Update selected city
  void setCity(String city) {
    if (state.filter.city == city) return;
    state = state.copyWith(filter: state.filter.copyWith(city: city, page: 1));
    fetchJobs();
  }

  /// Toggle job type filter (e.g. Full-time, Part-time)
  void toggleJobType(String type) {
    final current = List<String>.from(state.filter.jobTypes);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(
      filter: state.filter.copyWith(jobTypes: current, page: 1),
    );
    fetchJobs();
  }

  /// Update salary range
  void setSalaryRange(String range) {
    state = state.copyWith(
      filter: state.filter.copyWith(salaryRange: range, page: 1),
    );
    fetchJobs();
  }

  /// Update experience filter
  void setExperience(String exp) {
    state = state.copyWith(
      filter: state.filter.copyWith(experience: exp, page: 1),
    );
    fetchJobs();
  }

  /// Toggle gender filter
  void toggleGender(String gender) {
    final current = List<String>.from(state.filter.genders);
    if (current.contains(gender)) {
      current.remove(gender);
    } else {
      current.add(gender);
    }
    state = state.copyWith(
      filter: state.filter.copyWith(genders: current, page: 1),
    );
    fetchJobs();
  }

  /// Toggle qualification filter
  void toggleQualification(String qual) {
    final current = List<String>.from(state.filter.qualification);
    if (current.contains(qual)) {
      current.remove(qual);
    } else {
      current.add(qual);
    }
    state = state.copyWith(
      filter: state.filter.copyWith(qualification: current, page: 1),
    );
    fetchJobs();
  }

  /// Change page
  void setPage(int newPage) {
    if (newPage < 1 || newPage > state.totalPages) return;
    state = state.copyWith(filter: state.filter.copyWith(page: newPage));
    fetchJobs();
  }

  /// Apply custom filter object
  void applyFilter(JobFilter newFilter) {
    state = state.copyWith(filter: newFilter.copyWith(page: 1));
    fetchJobs();
  }

  /// Clear all active filters
  void clearAllFilters() {
    state = state.copyWith(filter: JobFilter(city: state.filter.city));
    fetchJobs();
  }
}

final jobsProvider = NotifierProvider<JobsNotifier, JobsState>(
  JobsNotifier.new,
);
