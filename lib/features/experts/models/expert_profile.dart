import '../../../core/constants/api_constants.dart';

class ExpertItem {
  final String id;
  final String expertId;
  final String title;
  final String description;
  final String category;
  final int duration;
  final double price;
  final double rating;
  final int reviews;
  final String status;
  final String expertName;
  final String expertHeadline;
  final String expertImage;
  final String expertBio;

  const ExpertItem({
    required this.id,
    required this.expertId,
    required this.title,
    this.description = '',
    this.category = 'Career',
    this.duration = 45,
    this.price = 0.0,
    this.rating = 5.0,
    this.reviews = 0,
    this.status = 'active',
    this.expertName = 'Industry Expert',
    this.expertHeadline = 'Career Advisor',
    this.expertImage = '',
    this.expertBio = '',
  });

  factory ExpertItem.fromJson(Map<String, dynamic> json) {
    // Handle both direct mentorship model or nested MentorshipDetail
    final rawM = json['mentorship'];
    final Map<String, dynamic> m = (rawM is Map)
        ? Map<String, dynamic>.from(rawM)
        : json;
    final rawExp = json['expert'];
    final Map<String, dynamic> exp = (rawExp is Map)
        ? Map<String, dynamic>.from(rawExp)
        : <String, dynamic>{};

    return ExpertItem(
      id: m['id']?.toString() ?? m['_id']?.toString() ?? '',
      expertId: m['expert_id']?.toString() ?? exp['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '1-on-1 Mentorship Session',
      description: m['description']?.toString() ?? exp['bio']?.toString() ?? '',
      category: m['category']?.toString() ?? 'Mentorship',
      duration: (m['duration'] as num?)?.toInt() ?? 45,
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      rating:
          (m['rating'] as num?)?.toDouble() ??
          (exp['rating'] as num?)?.toDouble() ??
          5.0,
      reviews: (m['reviews'] as num?)?.toInt() ?? 0,
      status: m['status']?.toString() ?? 'active',
      expertName:
          (exp['name'] != null && exp['name'].toString().trim().isNotEmpty)
          ? exp['name'].toString().trim()
          : (m['expert_name']?.toString() ?? 'Verified Expert'),
      expertHeadline:
          (exp['headline'] != null &&
              exp['headline'].toString().trim().isNotEmpty)
          ? exp['headline'].toString().trim()
          : (m['expert_headline']?.toString() ?? 'Senior Professional'),
      expertImage: ApiConstants.resolveImageUrl(
        exp['profile_image']?.toString() ?? m['expert_image']?.toString(),
      ),
      expertBio: exp['bio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert_id': expertId,
      'title': title,
      'description': description,
      'category': category,
      'duration': duration,
      'price': price,
      'rating': rating,
      'reviews': reviews,
      'status': status,
      'expert_name': expertName,
      'expert_headline': expertHeadline,
      'expert_image': expertImage,
      'expert_bio': expertBio,
    };
  }
}
