import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

/// Candidate / Jobseeker Profile model mapped from km-backend MongoDB schema
class UserProfile {
  final String id;
  final String mobile;
  final List<String> roles;
  final bool isRegistered;
  final String name;
  final String email;
  final String gender;
  final String city;
  final String state;
  final String headline;
  final String about;
  final String educationLevel;
  final String workExperience;
  final List<String> jobCategories;
  final String experienceDetail;
  final List<String> skills;
  final List<EducationItem> education;
  final List<ExperienceItem> experience;
  final List<ProjectItem> projects;
  final String profileImage;
  final String coverImage;
  final bool isEmailVerified;
  final String resumeUrl;

  /// Text typed in the app's Open To sheet (kept on this device only).
  final String openToWork;

  /// Text typed in the app's Open To sheet (kept on this device only).
  final String providingServices;

  /// Open To Work status stored by the backend (`open_to_work` object).
  /// Null when the backend has not stored one for this user.
  final OpenToWorkPreferences? openToWorkPreferences;

  /// Providing Services status stored by the backend (`providing_services`
  /// object). Null when the backend has not stored one for this user.
  final ProvidingServicesPreferences? providingServicesPreferences;
  final bool isAvailableForGigs;
  final int walletBalance;
  final int profileViewsCount;
  final int postImpressionsCount;
  final int searchAppearancesCount;
  final String portfolioUrl;
  final String portfolioText;

  const UserProfile({
    required this.id,
    required this.mobile,
    this.roles = const ['user'],
    this.isRegistered = false,
    this.name = '',
    this.email = '',
    this.gender = '',
    this.city = '',
    this.state = '',
    this.headline = '',
    this.about = '',
    this.educationLevel = '',
    this.workExperience = '',
    this.jobCategories = const [],
    this.experienceDetail = '',
    this.skills = const [],
    this.education = const [],
    this.experience = const [],
    this.projects = const [],
    this.profileImage = '',
    this.coverImage = '',
    this.isEmailVerified = false,
    this.resumeUrl = '',
    this.openToWork = '',
    this.providingServices = '',
    this.openToWorkPreferences,
    this.providingServicesPreferences,
    this.isAvailableForGigs = true,
    this.walletBalance = 0,
    this.profileViewsCount = 0,
    this.postImpressionsCount = 0,
    this.searchAppearancesCount = 0,
    this.portfolioUrl = '',
    this.portfolioText = '',
  });

  /// Public Profile URL alloted to user from MongoDB backend
  String get publicProfileUrl =>
      id.isNotEmpty ? 'www.kaammilega.com/in/$id' : 'www.kaammilega.com/in/...';

  /// Full Web URL to candidate public profile
  String get fullPublicProfileUrl => id.isNotEmpty
      ? 'https://www.kaammilega.com/in/$id'
      : 'https://www.kaammilega.com';

  /// Whether the user is open to work. The backend value is used when the
  /// backend has one; otherwise the text saved on this device decides.
  bool get isOpenToWork => openToWorkPreferences != null
      ? openToWorkPreferences!.isOpen
      : openToWork.trim().isNotEmpty;

  /// Readable Open To Work text for the Profile screen (never raw JSON).
  String get openToWorkSummary {
    final prefs = openToWorkPreferences;
    if (prefs != null) return prefs.isOpen ? prefs.summary : '';
    return openToWork.trim();
  }

  /// Whether the user is providing services. The backend value is used when
  /// the backend has one; otherwise the text saved on this device decides.
  bool get isProvidingServices => providingServicesPreferences != null
      ? providingServicesPreferences!.isProviding
      : providingServices.trim().isNotEmpty;

  /// Readable Providing Services text for the Profile screen (never raw JSON).
  String get providingServicesSummary {
    final prefs = providingServicesPreferences;
    if (prefs != null) return prefs.isProviding ? prefs.summary : '';
    return providingServices.trim();
  }

  factory UserProfile.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['user'] is Map<String, dynamic>)
        ? rawJson['user'] as Map<String, dynamic>
        : (rawJson['data'] is Map<String, dynamic>
              ? rawJson['data'] as Map<String, dynamic>
              : rawJson);

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<EducationItem> parseEducation(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map(EducationItem.fromJson)
            .toList();
      }
      return [];
    }

    List<ExperienceItem> parseExperience(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map(ExperienceItem.fromJson)
            .toList();
      }
      return [];
    }

    List<ProjectItem> parseProjects(dynamic val) {
      if (val is List) {
        return val
            .whereType<Map<String, dynamic>>()
            .map(ProjectItem.fromJson)
            .toList();
      }
      return [];
    }

    // Backend object fields (`open_to_work`, `providing_services`)
    Map<String, dynamic>? parseObject(dynamic val) =>
        val is Map ? Map<String, dynamic>.from(val) : null;

    // Text typed in the app's Open To sheet. It is saved on this device;
    // profiles cached before this change kept it as a string under [key].
    String deviceText(String key) {
      final cached = json[key];
      if (cached is String) return cached;
      final saved = LocalStorage.getDeviceProfilePrefs()[key];
      return saved is String ? saved : '';
    }

    int parseCount(dynamic val) => val is num ? val.toInt() : 0;

    final openToWorkJson = parseObject(json['open_to_work']);
    final providingServicesJson = parseObject(json['providing_services']);

    return UserProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      roles: parseStringList(json['roles']).isEmpty
          ? const ['user']
          : parseStringList(json['roles']),
      isRegistered: json['is_registered'] == true,
      name:
          json['name']?.toString() ??
          json['first_name']?.toString() ??
          'Candidate',
      email: json['email']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
      educationLevel: json['education_level']?.toString() ?? '',
      workExperience: json['work_experience']?.toString() ?? '',
      jobCategories: parseStringList(json['job_categories']),
      experienceDetail: json['experience_detail']?.toString() ?? '',
      skills: parseStringList(json['skills']),
      education: parseEducation(json['education']),
      experience: parseExperience(json['experience']),
      projects: parseProjects(json['projects']),
      profileImage: ApiConstants.resolveImageUrl(
        json['profile_image']?.toString(),
      ),
      coverImage: ApiConstants.resolveImageUrl(
        json['cover_image']?.toString() ?? json['background_image']?.toString(),
      ),
      isEmailVerified:
          json['is_email_verified'] == true || json['email_verified'] == true,
      resumeUrl: ApiConstants.resolveImageUrl(
        json['resume_url']?.toString() ??
            json['resume']?.toString() ??
            json['cv_url']?.toString() ??
            // Server profile has no resume field yet: use the device copy
            LocalStorage.getResumeUrl(),
      ),
      openToWork: deviceText('open_to_work'),
      providingServices: deviceText('providing_services'),
      openToWorkPreferences: openToWorkJson == null
          ? null
          : OpenToWorkPreferences.fromJson(openToWorkJson),
      providingServicesPreferences: providingServicesJson == null
          ? null
          : ProvidingServicesPreferences.fromJson(providingServicesJson),
      isAvailableForGigs:
          (json['is_available_for_gigs'] ??
              LocalStorage.getDeviceProfilePrefs()['is_available_for_gigs']) !=
          false,
      walletBalance: (json['wallet_balance'] as num?)?.toInt() ?? 0,
      profileViewsCount: parseCount(json['profile_views']),
      postImpressionsCount: parseCount(json['post_impressions']),
      searchAppearancesCount: parseCount(json['search_appearances']),
      portfolioUrl:
          json['portfolio_url']?.toString() ??
          json['portfolioUrl']?.toString() ??
          json['portfolio_link']?.toString() ??
          json['website']?.toString() ??
          '',
      portfolioText:
          json['portfolio_label']?.toString() ??
          json['portfolio_text']?.toString() ??
          json['portfolioText']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mobile': mobile,
    'roles': roles,
    'is_registered': isRegistered,
    'name': name,
    'email': email,
    'gender': gender,
    'city': city,
    'state': state,
    'headline': headline,
    'about': about,
    'education_level': educationLevel,
    'work_experience': workExperience,
    'job_categories': jobCategories,
    'experience_detail': experienceDetail,
    'skills': skills,
    'education': education.map((e) => e.toJson()).toList(),
    'experience': experience.map((e) => e.toJson()).toList(),
    'projects': projects.map((e) => e.toJson()).toList(),
    'profile_image': profileImage,
    'cover_image': coverImage,
    'is_email_verified': isEmailVerified,
    'resume_url': resumeUrl,
    // Same shapes as the backend. Device-typed Open To text is not written
    // here: it stays in the device prefs (see UserProfile.fromJson).
    if (openToWorkPreferences != null)
      'open_to_work': openToWorkPreferences!.toJson(),
    if (providingServicesPreferences != null)
      'providing_services': providingServicesPreferences!.toJson(),
    'is_available_for_gigs': isAvailableForGigs,
    'wallet_balance': walletBalance,
    'profile_views': profileViewsCount,
    'post_impressions': postImpressionsCount,
    'search_appearances': searchAppearancesCount,
    'portfolio_url': portfolioUrl,
    'portfolio_text': portfolioText,
  };

  UserProfile copyWith({
    String? name,
    String? email,
    String? gender,
    String? city,
    String? state,
    String? headline,
    String? about,
    String? educationLevel,
    String? workExperience,
    List<String>? jobCategories,
    String? experienceDetail,
    List<String>? skills,
    List<EducationItem>? education,
    List<ExperienceItem>? experience,
    List<ProjectItem>? projects,
    bool? isRegistered,
    String? profileImage,
    String? coverImage,
    bool? isEmailVerified,
    String? resumeUrl,
    String? openToWork,
    String? providingServices,
    OpenToWorkPreferences? openToWorkPreferences,
    ProvidingServicesPreferences? providingServicesPreferences,
    bool? isAvailableForGigs,
    int? walletBalance,
    int? profileViewsCount,
    int? postImpressionsCount,
    int? searchAppearancesCount,
    String? portfolioUrl,
    String? portfolioText,
  }) {
    return UserProfile(
      id: id,
      mobile: mobile,
      roles: roles,
      isRegistered: isRegistered ?? this.isRegistered,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      state: state ?? this.state,
      headline: headline ?? this.headline,
      about: about ?? this.about,
      educationLevel: educationLevel ?? this.educationLevel,
      workExperience: workExperience ?? this.workExperience,
      jobCategories: jobCategories ?? this.jobCategories,
      experienceDetail: experienceDetail ?? this.experienceDetail,
      skills: skills ?? this.skills,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      projects: projects ?? this.projects,
      profileImage: profileImage ?? this.profileImage,
      coverImage: coverImage ?? this.coverImage,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      openToWork: openToWork ?? this.openToWork,
      providingServices: providingServices ?? this.providingServices,
      openToWorkPreferences:
          openToWorkPreferences ?? this.openToWorkPreferences,
      providingServicesPreferences:
          providingServicesPreferences ?? this.providingServicesPreferences,
      isAvailableForGigs: isAvailableForGigs ?? this.isAvailableForGigs,
      walletBalance: walletBalance ?? this.walletBalance,
      profileViewsCount: profileViewsCount ?? this.profileViewsCount,
      postImpressionsCount: postImpressionsCount ?? this.postImpressionsCount,
      searchAppearancesCount:
          searchAppearancesCount ?? this.searchAppearancesCount,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      portfolioText: portfolioText ?? this.portfolioText,
    );
  }
}

class EducationItem {
  final String id;
  final String schoolName;
  final String degree;
  final String fieldOfStudy;
  final String startDate;
  final String endDate;
  final String grade;
  final String description;

  const EducationItem({
    this.id = '',
    required this.schoolName,
    this.degree = '',
    this.fieldOfStudy = '',
    this.startDate = '',
    this.endDate = '',
    this.grade = '',
    this.description = '',
  });

  factory EducationItem.fromJson(Map<String, dynamic> json) => EducationItem(
    id: json['id']?.toString() ?? '',
    schoolName: json['school_name']?.toString() ?? '',
    degree: json['degree']?.toString() ?? '',
    fieldOfStudy: json['field_of_study']?.toString() ?? '',
    startDate: json['start_date']?.toString() ?? '',
    endDate: json['end_date']?.toString() ?? '',
    grade: json['grade']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'school_name': schoolName,
    'degree': degree,
    'field_of_study': fieldOfStudy,
    'start_date': startDate,
    'end_date': endDate,
    'grade': grade,
    'description': description,
  };
}

class ExperienceItem {
  final String id;
  final String title;
  final String employmentType;
  final String companyName;
  final String location;
  final String startDate;
  final String endDate;
  final String description;
  final List<String> skills;

  const ExperienceItem({
    this.id = '',
    required this.title,
    this.employmentType = '',
    required this.companyName,
    this.location = '',
    this.startDate = '',
    this.endDate = '',
    this.description = '',
    this.skills = const [],
  });

  factory ExperienceItem.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return ExperienceItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      employmentType: json['employment_type']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      skills: parseList(json['skills']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'employment_type': employmentType,
    'company_name': companyName,
    'location': location,
    'start_date': startDate,
    'end_date': endDate,
    'description': description,
    'skills': skills,
  };
}

class ProjectItem {
  final String id;
  final String title;
  final String associatedWith;
  final String description;
  final String link;
  final String startDate;
  final String endDate;
  final String skills;
  final bool isCurrentlyWorking;

  const ProjectItem({
    this.id = '',
    required this.title,
    this.associatedWith = '',
    this.description = '',
    this.link = '',
    this.startDate = '',
    this.endDate = '',
    this.skills = '',
    this.isCurrentlyWorking = false,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    title: json['title']?.toString() ?? json['name']?.toString() ?? '',
    associatedWith:
        json['associated_with']?.toString() ??
        json['associatedWith']?.toString() ??
        '',
    description: json['description']?.toString() ?? '',
    link:
        json['project_url']?.toString() ??
        json['link']?.toString() ??
        json['url']?.toString() ??
        '',
    startDate: json['start_date']?.toString() ?? '',
    endDate: json['end_date']?.toString() ?? '',
    // Backend sends skills as a list; UI works with comma-separated text
    skills: _skillsToText(json['skills'] ?? json['skills_used']),
    isCurrentlyWorking:
        json['is_current'] == true ||
        json['is_currently_working'] == true ||
        json['isCurrentlyWorking'] == true,
  );

  static String _skillsToText(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'associated_with': associatedWith,
    'description': description,
    'project_url': link,
    'start_date': startDate,
    'end_date': endDate,
    'skills': skills
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    'is_current': isCurrentlyWorking,
  };
}

/// Open To Work status stored by the backend (`open_to_work` on the user).
class OpenToWorkPreferences {
  final bool isOpen;
  final List<String> jobTitles;
  final List<String> jobTypes;
  final List<String> locations;

  /// Who can see it: "all" or "recruiters" (empty when not set).
  final String visibility;

  /// Job types offered on the KaamMilega website's Open To Work form. The
  /// backend stores any text; these are the values the website sends.
  static const List<String> jobTypeOptions = [
    'Full-time',
    'Part-time',
    'Contract',
    'Freelance',
    'Hourly',
  ];

  /// Backend visibility values (`OpenToWorkPreferences.Visibility`); the
  /// backend saves "all" when none is sent.
  static const String visibilityAll = 'all';
  static const String visibilityRecruiters = 'recruiters';

  const OpenToWorkPreferences({
    this.isOpen = false,
    this.jobTitles = const [],
    this.jobTypes = const [],
    this.locations = const [],
    this.visibility = '',
  });

  factory OpenToWorkPreferences.fromJson(Map<String, dynamic> json) =>
      OpenToWorkPreferences(
        isOpen: json['is_open'] == true,
        jobTitles: _stringList(json['job_titles']),
        jobTypes: _stringList(json['job_types']),
        locations: _stringList(json['locations']),
        visibility: json['visibility']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'is_open': isOpen,
    'job_titles': jobTitles,
    'job_types': jobTypes,
    'locations': locations,
    'visibility': visibility,
  };

  /// e.g. "Flutter Developer, Backend Developer · Full-time · Pune"
  String get summary => _joinGroups([jobTitles, jobTypes, locations]);
}

/// Providing Services status stored by the backend (`providing_services`).
class ProvidingServicesPreferences {
  final bool isProviding;
  final List<String> services;

  /// 0 when the backend has no hourly rate.
  final double hourlyRate;
  final String currency;
  final String description;

  /// Currency the backend saves when none is sent (the website always
  /// sends it).
  static const String defaultCurrency = 'INR';

  const ProvidingServicesPreferences({
    this.isProviding = false,
    this.services = const [],
    this.hourlyRate = 0,
    this.currency = '',
    this.description = '',
  });

  factory ProvidingServicesPreferences.fromJson(Map<String, dynamic> json) {
    final rate = json['hourly_rate'];
    return ProvidingServicesPreferences(
      isProviding: json['is_providing'] == true,
      services: _stringList(json['services']),
      hourlyRate: rate is num ? rate.toDouble() : 0.0,
      currency: json['currency']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'is_providing': isProviding,
    'services': services,
    'hourly_rate': hourlyRate,
    'currency': currency,
    'description': description,
  };

  /// e.g. "Web Development, AC Repair · INR 500/hr". Uses the description
  /// when no services are listed.
  String get summary {
    final main = services.isNotEmpty ? services.join(', ') : description.trim();
    if (hourlyRate <= 0) return main;
    final amount = hourlyRate == hourlyRate.roundToDouble()
        ? hourlyRate.toInt().toString()
        : hourlyRate.toStringAsFixed(2);
    final rate = '${currency.trim()} $amount/hr'.trim();
    return main.isEmpty ? rate : '$main · $rate';
  }
}

List<String> _stringList(dynamic val) {
  if (val is! List) return const [];
  return val
      .where((e) => e != null)
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _joinGroups(List<List<String>> groups) =>
    groups.where((g) => g.isNotEmpty).map((g) => g.join(', ')).join(' · ');
