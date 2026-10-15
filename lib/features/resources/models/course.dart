import 'package:intl/intl.dart';

/// A learning video on the Resources page (km-backend `course.Course`).
class Course {
  const Course({
    required this.id,
    required this.title,
    this.description = '',
    this.youtubeUrl = '',
    this.youtubeVideoId = '',
    this.thumbnailUrl = '',
    this.duration = '',
    this.category = '',
    this.expertId = '',
    this.expertName = '',
    this.expertAvatar = '',
    this.views = 0,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String thumbnailUrl;
  final String duration;
  final String category;
  final String expertId;
  final String expertName;
  final String expertAvatar;

  /// Server view count (`POST /courses/:id/view` returns the new value).
  final int views;
  final DateTime? createdAt;

  factory Course.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    return Course(
      id: str('id').isNotEmpty ? str('id') : str('_id'),
      title: str('title'),
      description: str('description'),
      youtubeUrl: str('youtube_url'),
      youtubeVideoId: str('youtube_video_id'),
      thumbnailUrl: str('thumbnail_url'),
      duration: str('duration'),
      category: str('category'),
      expertId: str('expert_id'),
      expertName: str('expert_name'),
      expertAvatar: str('expert_avatar'),
      views: (json['views'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(str('created_at')),
    );
  }

  Course withViews(int value) => Course(
    id: id,
    title: title,
    description: description,
    youtubeUrl: youtubeUrl,
    youtubeVideoId: youtubeVideoId,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    category: category,
    expertId: expertId,
    expertName: expertName,
    expertAvatar: expertAvatar,
    views: value,
    createdAt: createdAt,
  );

  /// YouTube's standard thumbnail, used when the stored one fails.
  String get fallbackThumbnail => youtubeVideoId.isEmpty
      ? ''
      : 'https://img.youtube.com/vi/$youtubeVideoId/hqdefault.jpg';

  String get thumbnail =>
      thumbnailUrl.isNotEmpty ? thumbnailUrl : fallbackThumbnail;

  /// Where the video is opened (YouTube app when installed, else browser).
  String get watchUrl => youtubeUrl.isNotEmpty
      ? youtubeUrl
      : (youtubeVideoId.isEmpty
            ? ''
            : 'https://www.youtube.com/watch?v=$youtubeVideoId');

  /// As on the website: the server's duration text, "30 Min" if missing.
  String get durationLabel => duration.isEmpty ? '30 Min' : duration;

  String get expertLabel => expertName.isEmpty ? 'Expert' : expertName;

  /// "2 Viewers", "1 Viewer", "1.2K Viewers", "3.4M Viewers".
  String get viewersLabel => formatViewers(views);

  static String formatViewers(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M Viewers';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K Viewers';
    return v == 1 ? '1 Viewer' : '$v Viewers';
  }

  /// "Released 12 Oct 2026" (website wording); "Released recently" when the
  /// server sends no date.
  String get releasedLabel {
    final d = createdAt;
    if (d == null) return 'Released recently';
    return 'Released ${DateFormat('d MMM yyyy').format(d.toLocal())}';
  }

  /// The 11-character YouTube video id in [url] (watch, youtu.be, shorts,
  /// embed links), or null. Same pattern as the server and the website.
  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final match = _youtubeId.firstMatch(trimmed);
    final id = match?.group(1);
    if (id != null && id.length == 11) return id;
    final v = Uri.tryParse(trimmed)?.queryParameters['v'];
    return (v != null && v.length == 11) ? v : null;
  }

  static final RegExp _youtubeId = RegExp(
    r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)'
    r'|youtu\.be\/)([^"&?\/\s]{11})',
  );
}

/// Course categories offered by the website's course form; "Others" lets
/// the Expert type their own.
const List<String> kCourseCategories = [
  'Vocational Skills',
  'Technology',
  'Electrician & Electrical',
  'Plumbing & Sanitation',
  'Construction & Carpentry',
  'Hospitality & Culinary',
  'Automotive & Mechanics',
  'Business & Sales',
  'Others',
];

/// What the Expert enters to publish or edit a course. The server allows
/// up to 10 words in the title and 50 in the description.
class CourseDraft {
  const CourseDraft({
    required this.title,
    required this.duration,
    required this.category,
    this.description = '',
    this.youtubeUrl = '',
  });

  static const int maxTitleWords = 10;
  static const int maxDescriptionWords = 50;

  final String title;
  final String duration;
  final String category;
  final String description;

  /// Only sent when publishing (the website's edit form keeps the video).
  final String youtubeUrl;
}

/// One page of `GET /courses`.
class CoursesPage {
  const CoursesPage({
    required this.courses,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<Course> courses;
  final int total;
  final int page;
  final int totalPages;
}
