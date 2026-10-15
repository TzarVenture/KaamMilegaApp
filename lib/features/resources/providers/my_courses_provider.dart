import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../models/course.dart';
import '../repositories/course_repository.dart';
import 'courses_provider.dart';

class MyCoursesState {
  const MyCoursesState({
    this.courses = const [],
    this.total = 0,
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<Course> courses;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasMore => page < totalPages && courses.length < total;

  /// Views of all my courses, known only once every page is loaded.
  int? get totalViews =>
      hasMore ? null : courses.fold<int>(0, (sum, c) => sum + c.views);

  MyCoursesState copyWith({
    List<Course>? courses,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    Object? loadMoreError,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) => MyCoursesState(
    courses: courses ?? this.courses,
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

/// Expert Portal "My Courses": the Expert's own courses (GET /courses/my)
/// and publishing, editing and deleting them. The list only changes with
/// what the server returns.
class MyCoursesNotifier extends Notifier<MyCoursesState> {
  static const int pageSize = 20;

  static const String unknownOutcome =
      'We could not confirm this change. Your courses have been refreshed; '
      'please check them before trying again.';

  int _generation = 0;

  @override
  MyCoursesState build() {
    Future.microtask(refresh);
    return const MyCoursesState(isLoading: true);
  }

  CourseRepository get _repo => ref.read(courseRepositoryProvider);

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final page = await _repo.getMyCourses(page: 1, limit: pageSize);
      if (!ref.mounted || generation != _generation) return;
      state = MyCoursesState(
        courses: page.courses,
        total: page.total,
        page: 1,
        totalPages: page.totalPages,
      );
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.isLoading || s.isLoadingMore || !s.hasMore) return;
    final generation = _generation;
    state = s.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final next = await _repo.getMyCourses(page: s.page + 1, limit: pageSize);
      if (!ref.mounted || generation != _generation) return;
      final known = {for (final c in state.courses) c.id};
      state = state.copyWith(
        courses: [
          ...state.courses,
          ...next.courses.where((c) => !known.contains(c.id)),
        ],
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

  /// Publishes a course. Returns null on success, else the message to show.
  Future<String?> publish(CourseDraft draft) => _run(() async {
    final created = await _repo.createCourse(draft);
    if (!ref.mounted) return;
    ++_generation; // a reload in flight must not drop the new course
    state = state.copyWith(
      courses: [created, ...state.courses.where((c) => c.id != created.id)],
      total: state.total + 1,
      isLoading: false,
    );
  });

  /// Saves edits to one of my courses.
  Future<String?> edit(Course course, CourseDraft draft) => _run(() async {
    final updated = await _repo.updateCourse(course.id, draft);
    if (!ref.mounted) return;
    state = state.copyWith(
      courses: [
        for (final c in state.courses) c.id == updated.id ? updated : c,
      ],
    );
  });

  /// Deletes one of my courses.
  Future<String?> remove(Course course) => _run(() async {
    await _repo.deleteCourse(course.id);
    if (!ref.mounted) return;
    final before = state.courses.length;
    final left = state.courses.where((c) => c.id != course.id).toList();
    state = state.copyWith(
      courses: left,
      total: left.length < before && state.total > 0 ? state.total - 1 : null,
    );
  });

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      // The public Resources list shows the change next time it loads.
      ref.invalidate(coursesProvider);
      return null;
    } on AppValidationException catch (e) {
      // Refused by the server (word limits, bad link, not my course).
      return _sentence(e.message);
    } on AppAuthException catch (e) {
      return e.message;
    } on AppNetworkException {
      return 'No internet connection. Nothing was changed.';
    } on AppException {
      // Timeout, not found or server error: it may have happened.
      if (ref.mounted) await refresh();
      return unknownOutcome;
    }
  }

  static String _sentence(String message) {
    final m = message.trim();
    if (m.isEmpty) return 'The change could not be saved.';
    return '${m[0].toUpperCase()}${m.substring(1)}';
  }
}

final myCoursesProvider =
    NotifierProvider.autoDispose<MyCoursesNotifier, MyCoursesState>(
      MyCoursesNotifier.new,
    );
