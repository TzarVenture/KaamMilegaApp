import '../../../core/constants/api_constants.dart';

/// An employer from GET /companies/top (km-backend `TopCompanyResponse`):
/// a recruiter account with a company name. [id] is the recruiter's user id,
/// which is also how their jobs are listed (GET /jobs?recruiter_id=).
class TopCompany {
  final String id;
  final String name;
  final String logo;
  final String website;

  /// Recruiter's headline; empty when the server only sent its default.
  final String category;

  /// Recruiter's city; empty when the server only sent its default.
  final String location;

  /// Set by the KaamMilega team after checking the employer.
  final bool verified;

  const TopCompany({
    required this.id,
    required this.name,
    this.logo = '',
    this.website = '',
    this.category = '',
    this.location = '',
    this.verified = false,
  });

  // Placeholders the backend fills in when the recruiter left them empty.
  // They are not facts about the company, so they are not shown.
  static const _defaultCategory = 'Enterprise Employer';
  static const _defaultLocation = 'India';

  factory TopCompany.fromJson(Map<String, dynamic> json) {
    String str(String key) => json[key]?.toString().trim() ?? '';
    final category = str('category');
    final location = str('location');
    return TopCompany(
      id: str('id'),
      name: str('name'),
      logo: ApiConstants.resolveImageUrl(str('logo')),
      website: str('website'),
      category: category == _defaultCategory ? '' : category,
      location: location == _defaultLocation ? '' : location,
      verified: json['verified'] == true,
    );
  }

  String get initials {
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
