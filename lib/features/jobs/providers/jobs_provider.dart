import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/providers/auth_provider.dart';
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

    // Sync bookmarks with the server when a user signs in; forget them on
    // logout (they belong to that account, not to the next user or guest).
    ref.listen<AuthState>(authProvider, (prev, next) {
      final wasSignedIn = prev?.isAuthenticated ?? false;
      if (!wasSignedIn && next.isAuthenticated) {
        syncSavedJobs();
      } else if (wasSignedIn && !next.isAuthenticated) {
        state = state.copyWith(
          savedJobIds: const <String>{},
          cachedTimestamp: state.cachedTimestamp,
        );
        LocalStorage.saveSavedJobIds(const <String>{});
      }
    });

    Future.microtask(() => fetchJobs());
    Future.microtask(() => syncSavedJobs());

    return JobsState(
      jobs: initialJobs,
      totalJobs: initialJobs.length,
      savedJobIds: cachedSaved,
      cachedTimestamp: initialTimestamp,
    );
  }

  bool get _isSignedIn {
    final token = LocalStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  bool _isSyncingSaved = false;

  /// Load bookmarked job IDs from the server (signed-in users only)
  Future<void> syncSavedJobs() async {
    if (!_isSignedIn || _isSyncingSaved) return;
    _isSyncingSaved = true;
    try {
      final serverIds = await _repository.getBookmarkedJobIds();
      state = state.copyWith(
        savedJobIds: serverIds,
        cachedTimestamp: state.cachedTimestamp,
      );
      LocalStorage.saveSavedJobIds(serverIds);
    } catch (_) {
      // Offline or unavailable: keep the locally cached bookmarks
    } finally {
      _isSyncingSaved = false;
    }
  }

  /// Toggle saving / bookmarking a job.
  /// Updates instantly on the phone, then syncs with the server when signed in.
  Future<void> toggleSaveJob(String jobId) async {
    final previous = Set<String>.from(state.savedJobIds);
    final current = Set<String>.from(previous);
    if (current.contains(jobId)) {
      current.remove(jobId);
    } else {
      current.add(jobId);
    }
    state = state.copyWith(
      savedJobIds: current,
      cachedTimestamp: state.cachedTimestamp,
    );
    LocalStorage.saveSavedJobIds(current);

    if (!_isSignedIn) return; // Guests keep bookmarks on this device only

    try {
      final serverIds = await _repository.toggleBookmark(jobId);
      state = state.copyWith(
        savedJobIds: serverIds,
        cachedTimestamp: state.cachedTimestamp,
      );
      LocalStorage.saveSavedJobIds(serverIds);
    } catch (_) {
      // Server rejected or unreachable: undo so the phone matches the server
      state = state.copyWith(
        savedJobIds: previous,
        cachedTimestamp: state.cachedTimestamp,
      );
      LocalStorage.saveSavedJobIds(previous);
    }
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

/// Latest jobs for the Home screen (Recommended for You, Top Picks).
///
/// Only the selected city is applied. The Jobs tab's search and filters
/// (e.g. a Popular Categories tap) never change what Home shows, so going
/// back to Home does not leave it empty. GET /jobs, first page.
final homeJobsProvider = FutureProvider<List<Job>>((ref) async {
  final city = ref.watch(jobsProvider.select((s) => s.filter.city));
  // Reload when the connection comes back (like the Jobs tab does).
  ref.listen<bool>(isOnlineProvider, (previous, next) {
    if (previous == false && next) ref.invalidateSelf();
  });
  final response = await ref
      .watch(jobRepositoryProvider)
      .getJobs(JobFilter(city: city));
  return response.jobs;
});

/// One saved (bookmarked) job for the Saved Jobs screen.
class SavedJobEntry {
  final String id;

  /// The job from the server, or null when it no longer exists (the
  /// backend answered HTTP 404 "Job not found", e.g. the job was deleted).
  final Job? job;

  const SavedJobEntry({required this.id, this.job});

  bool get isUnavailable => job == null;
}

/// Details of one saved job: GET /jobs/:id (public endpoint).
///
/// A job already loaded on the Jobs tab is reused (same server data, no
/// extra request). HTTP 404 means the job is gone -> null. Any other failure
/// is an error (never shown as "no saved jobs").
final savedJobDetailProvider = FutureProvider.autoDispose.family<Job?, String>((
  ref,
  jobId,
) async {
  final loaded = ref
      .read(jobsProvider)
      .jobs
      .where((job) => job.id == jobId)
      .firstOrNull;
  if (loaded != null) return loaded;
  try {
    return await ref.watch(jobRepositoryProvider).getJobById(jobId);
  } on AppNotFoundException {
    return null;
  }
});

/// All saved jobs, loaded by their saved IDs (not taken from the current
/// Jobs page, which only holds one page of results).
///
/// The dedicated GET /user/bookmarks endpoint currently answers HTTP 500
/// (km-backend registers GET /user/:id before it), so each saved job is
/// loaded with GET /jobs/:id instead. Each job is cached separately, so
/// removing a bookmark does not reload the others.
final savedJobsProvider = FutureProvider.autoDispose<List<SavedJobEntry>>((
  ref,
) async {
  final ids = ref.watch(jobsProvider.select((s) => s.savedJobIds)).toList();
  final jobs = await Future.wait([
    for (final id in ids) ref.watch(savedJobDetailProvider(id).future),
  ]);
  return [
    for (var i = 0; i < ids.length; i++)
      SavedJobEntry(id: ids[i], job: jobs[i]),
  ];
});
