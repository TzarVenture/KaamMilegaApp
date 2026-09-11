/// User Profile model mapped from km-backend MongoDB schema
class UserProfile {
  final String id;
  final String mobile;
  final List<String> roles;
  final bool isRegistered;
  final String name;
  final String email;
  final String city;
  final String educationLevel;
  final String workExperience;

  const UserProfile({
    required this.id,
    required this.mobile,
    this.roles = const ['user'],
    this.isRegistered = false,
    this.name = '',
    this.email = '',
    this.city = '',
    this.educationLevel = '',
    this.workExperience = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> parseRoles(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return ['user'];
    }

    return UserProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      roles: parseRoles(json['roles']),
      isRegistered: json['is_registered'] == true,
      name: json['name']?.toString() ?? json['first_name']?.toString() ?? 'Job Seeker',
      email: json['email']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      educationLevel: json['education_level']?.toString() ?? '',
      workExperience: json['work_experience']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mobile': mobile,
        'roles': roles,
        'is_registered': isRegistered,
        'name': name,
        'email': email,
        'city': city,
        'education_level': educationLevel,
        'work_experience': workExperience,
      };
}
