import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/course.dart';
import '../repositories/course_repository.dart';

class CoursesState {
  const CoursesState({
    this.courses = const [],
    this.query = '',
    this.total = 0,
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<Course> courses;
  final String query;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasMore => page < totalPages && courses.length < total;

  CoursesState copyWith({
    List<Course>? courses,
    String? query,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    Object? loadMoreError,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) => CoursesState(
    courses: courses ?? this.courses,
    query: query ?? this.query,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : (error ?? this.error),
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

/// Resources page: published courses from the server with search, paging
/// and view counting (same rules as the website's /resources page).
class CoursesNotifier extends Notifier<CoursesState> {
  static const int pageSize = 10;

  int _generation = 0;
  final Set<String> _countingViews = {};

  @override
  CoursesState build() {
    Future.microtask(refresh);
    return const CoursesState(isLoading: true);
  }

  CourseRepository get _repo => ref.read(courseRepositoryProvider);

  /// New search text (the screen debounces typing). Reloads page 1.
  Future<void> search(String query) {
    final q = query.trim();
    if (q == state.query && !state.isLoading && state.error == null) {
      return Future.value();
    }
    state = state.copyWith(query: q);
    return refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final page = await _repo.getCourses(
        page: 1,
        limit: pageSize,
        search: state.query,
      );
      if (!ref.mounted || generation != _generation) return;
      state = CoursesState(
        courses: page.courses,
        query: state.query,
        total: page.total,
        page: 1,
        totalPages: page.totalPages,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      // Keep anything already shown; the error is still reported.
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.isLoading || s.isLoadingMore || !s.hasMore) return;
    final generation = _generation;
    state = s.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final next = await _repo.getCourses(
        page: s.page + 1,
        limit: pageSize,
        search: s.query,
      );
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final c in state.courses) c.id};
      final added = next.courses.where((c) => !known.contains(c.id));
      state = state.copyWith(
        courses: [...state.courses, ...added],
        total: next.total,
        page: s.page + 1,
        totalPages: next.totalPages,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e);
    }
  }

  /// True when the signed-in member uploaded [course]; the backend does not
  /// count their own views.
  bool isOwner(Course course) {
    final me = ref.read(sessionUserIdProvider);
    return me != null && course.expertId.isNotEmpty && me == course.expertId;
  }

  /// Counts one view (POST /courses/:id/view), as the website does when a
  /// video is opened. Shown at once (+1, except for the uploader), then
  /// replaced by the server's number; put back if the request fails.
  /// A second tap while the first request is running is not counted again.
  Future<void> recordView(Course course) async {
    if (!_countingViews.add(course.id)) return;
    final before = course.views;
    final optimistic = !isOwner(course);
    if (optimistic) _setViews(course.id, before + 1);
    try {
      final views = await _repo.recordView(course.id);
      if (ref.mounted) _setViews(course.id, views);
    } catch (_) {
      if (ref.mounted && optimistic) _setViews(course.id, before);
    } finally {
      _countingViews.remove(course.id);
    }
  }

  void _setViews(String id, int views) {
    final i = state.courses.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final next = [...state.courses]..[i] = state.courses[i].withViews(views);
    state = state.copyWith(courses: next);
  }
}

final coursesProvider =
    NotifierProvider.autoDispose<CoursesNotifier, CoursesState>(
      CoursesNotifier.new,
    );
