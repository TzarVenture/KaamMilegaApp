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
  final String profileImage;

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
    this.profileImage = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
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

    return UserProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      roles: parseStringList(json['roles']).isEmpty
          ? const ['user']
          : parseStringList(json['roles']),
      isRegistered: json['is_registered'] == true,
      name: json['name']?.toString() ??
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
      profileImage: json['profile_image']?.toString() ?? '',
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
        'profile_image': profileImage,
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
    bool? isRegistered,
    String? profileImage,
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
      profileImage: profileImage ?? this.profileImage,
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
