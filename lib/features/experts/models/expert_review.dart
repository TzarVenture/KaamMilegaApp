import '../../../core/constants/api_constants.dart';

/// One mentee's review of a completed session
/// (km-backend `ReviewItem`, from GET /mentorships/expert/:id/reviews).
class ExpertReview {
  final String id;
  final String menteeName;
  final String menteeAvatar;
  final String menteeHeadline;

  /// The session (offering) the review is for; may be empty.
  final String sessionTitle;

  /// 1 to 5 (the backend accepts whole and half values).
  final double rating;
  final String review;
  final DateTime? createdAt;

  const ExpertReview({
    required this.id,
    required this.rating,
    this.menteeName = '',
    this.menteeAvatar = '',
    this.menteeHeadline = '',
    this.sessionTitle = '',
    this.review = '',
    this.createdAt,
  });

  factory ExpertReview.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    final rating = json['rating'];
    return ExpertReview(
      id: str('id'),
      menteeName: str('mentee_name'),
      menteeAvatar: ApiConstants.resolveImageUrl(str('mentee_avatar')),
      menteeHeadline: str('mentee_headline'),
      sessionTitle: str('mentorship_title'),
      rating: rating is num ? rating.toDouble() : 0,
      review: str('review'),
      createdAt: DateTime.tryParse(str('created_at'))?.toLocal(),
    );
  }

  String get displayName =>
      menteeName.isNotEmpty ? menteeName : 'KaamMilega member';
}

/// An Expert's ratings: average, how many of each star, and the reviews
/// (newest first, as the server sends them).
class ExpertReviews {
  final double averageRating;
  final int totalReviews;

  /// Count per star: index 0 = 1 star ... index 4 = 5 stars.
  final List<int> starCounts;
  final List<ExpertReview> reviews;

  const ExpertReviews({
    required this.averageRating,
    required this.totalReviews,
    required this.starCounts,
    required this.reviews,
  });

  static const empty = ExpertReviews(
    averageRating: 0,
    totalReviews: 0,
    starCounts: [0, 0, 0, 0, 0],
    reviews: [],
  );

  factory ExpertReviews.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => v is num ? v.toInt() : 0;
    final rawDist = json['distribution'];
    final dist = rawDist is Map ? rawDist : const {};
    final rawReviews = json['reviews'];
    final reviews = rawReviews is List
        ? rawReviews
              .whereType<Map>()
              .map((e) => ExpertReview.fromJson(Map<String, dynamic>.from(e)))
              .where((r) => r.rating >= 1 && r.rating <= 5)
              .toList()
        : <ExpertReview>[];
    final average = json['average_rating'];
    return ExpertReviews(
      averageRating: average is num ? average.toDouble() : 0,
      totalReviews: n(json['total_reviews']),
      starCounts: [for (var s = 1; s <= 5; s++) n(dist['${s}_star'])],
      reviews: reviews,
    );
  }

  bool get isEmpty => totalReviews == 0;

  /// Share of reviews with [stars] stars, 0 to 1.
  double share(int stars) =>
      totalReviews == 0 ? 0 : starCounts[stars - 1] / totalReviews;
}
