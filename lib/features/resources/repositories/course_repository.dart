import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/response_list.dart';
import '../models/course.dart';

/// Learning videos for the Resources page (km-backend `course` feature,
/// public routes; same calls as the website's /resources page).
class CourseRepository {
  CourseRepository(this._client);

  final ApiClient _client;

  /// GET /courses?page&limit&search — published courses, newest first.
  /// Response: `{data: [Course], total, page, limit, total_pages}`.
  ///
  /// The backend uses [search] as a regular expression, so special
  /// characters (for example "C++") are escaped and matched literally.
  Future<CoursesPage> getCourses({
    required int page,
    required int limit,
    String search = '',
  }) async {
    final query = search.trim();
    return _page(
      ApiConstants.courses,
      page: page,
      limit: limit,
      extra: {if (query.isNotEmpty) 'search': RegExp.escape(query)},
    );
  }

  Future<CoursesPage> _page(
    String path, {
    required int page,
    required int limit,
    Map<String, dynamic> extra = const {},
  }) async {
    final response = await _client.get(
      path,
      queryParameters: {'page': page, 'limit': limit, ...extra},
    );
    final data = response.data;
    final courses = readListResponse(data)
        .map(Course.fromJson)
        .where((c) => c.id.isNotEmpty)
        .toList();
    final map = data is Map<String, dynamic> ? data : const {};
    final total = (map['total'] as num?)?.toInt() ?? courses.length;
    final totalPages =
        (map['total_pages'] as num?)?.toInt() ??
        (limit > 0 ? (total + limit - 1) ~/ limit : 1);
    return CoursesPage(
      courses: courses,
      total: total,
      page: (map['page'] as num?)?.toInt() ?? page,
      totalPages: totalPages,
    );
  }

  /// Expert Portal: GET /courses/my?page&limit — the signed-in Expert's
  /// own courses, newest first, same page shape as [getCourses].
  Future<CoursesPage> getMyCourses({required int page, required int limit}) =>
      _page(ApiConstants.myCourses, page: page, limit: limit);

  /// POST /courses {title, youtube_url, duration, category, description}.
  /// The server checks the link and word limits and returns the course.
  Future<Course> createCourse(CourseDraft draft) async {
    final response = await _client.post(
      ApiConstants.courses,
      data: {
        'title': draft.title.trim(),
        'youtube_url': draft.youtubeUrl.trim(),
        'duration': draft.duration.trim(),
        'category': draft.category.trim(),
        'description': draft.description.trim(),
      },
    );
    return _course(response.data);
  }

  /// PUT /courses/:id {title, duration, category, description} — only the
  /// uploader may edit. As on the website, the video link is not changed.
  /// The description is always sent (an empty one clears it).
  Future<Course> updateCourse(String id, CourseDraft draft) async {
    final response = await _client.put(
      ApiConstants.course(id),
      data: {
        'title': draft.title.trim(),
        'duration': draft.duration.trim(),
        'category': draft.category.trim(),
        'description': draft.description.trim(),
      },
    );
    return _course(response.data);
  }

  /// DELETE /courses/:id — only the uploader's own course is removed.
  Future<void> deleteCourse(String id) async {
    await _client.delete(ApiConstants.course(id));
  }

  Course _course(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const AppServerException('Unexpected course response.');
    }
    final course = Course.fromJson(data);
    if (course.id.isEmpty) {
      throw const AppServerException('Unexpected course response.');
    }
    return course;
  }

  /// POST /courses/:id/view — counts one view and returns the new total.
  /// The backend does not count the uploader's own views (it then returns
  /// the unchanged total). Works for guests too.
  Future<int> recordView(String courseId) async {
    final response = await _client.post(ApiConstants.courseView(courseId));
    final data = response.data;
    final views = data is Map ? data['views'] : null;
    if (views is num) return views.toInt();
    throw const AppValidationException('Unexpected response from server.');
  }
}

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(apiClientProvider)),
);

/// Opens a course video outside the app: the YouTube app when installed,
/// otherwise the browser (as the website does on phones). Replaced in tests.
typedef CourseVideoLauncher = Future<bool> Function(Uri url);

final courseVideoLauncherProvider = Provider<CourseVideoLauncher>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
