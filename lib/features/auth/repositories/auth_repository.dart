import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../models/user_profile.dart';

class AuthVerificationResult {
  final UserProfile? user;
  final bool isRegistered;
  final String? token;

  const AuthVerificationResult({
    this.user,
    this.isRegistered = false,
    this.token,
  });
}

/// Authentication & Candidate Profile repository connecting with km-backend auth endpoints
class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// Send OTP to user's mobile number
  Future<void> sendOtp(String mobile) async {
    await _client.post(
      ApiConstants.sendOtp,
      data: {'mobile': mobile, 'role': 'user'},
    );
  }

  /// Verify OTP and store JWT auth token
  Future<AuthVerificationResult> verifyOtp(String mobile, String code) async {
    final response = await _client.post(
      ApiConstants.verifyOtp,
      data: {'mobile': mobile, 'code': code, 'role': 'user'},
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final token = data['token']?.toString();
    final isRegistered = data['is_registered'] == true;

    if (token != null && token.isNotEmpty) {
      await LocalStorage.saveToken(token);
    }

    UserProfile? user;
    if (data['user'] is Map<String, dynamic>) {
      user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await LocalStorage.saveUser(user.toJson());
    }

    return AuthVerificationResult(
      user: user,
      isRegistered: isRegistered,
      token: token,
    );
  }

  /// Login with Email and Password
  Future<AuthVerificationResult> loginWithPassword(
    String email,
    String password,
  ) async {
    final response = await _client.post(
      ApiConstants.loginPassword,
      data: {'email': email.trim(), 'password': password, 'role': 'user'},
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final token = data['token']?.toString();
    final isRegistered = data['is_registered'] == true || data['user'] != null;

    if (token != null && token.isNotEmpty) {
      await LocalStorage.saveToken(token);
    }

    UserProfile? user;
    if (data['user'] is Map<String, dynamic>) {
      user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await LocalStorage.saveUser(user.toJson());
    }

    return AuthVerificationResult(
      user: user,
      isRegistered: isRegistered,
      token: token,
    );
  }

  /// Register with Name, Email and Password on km-backend
  Future<AuthVerificationResult> registerWithPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.registerPassword,
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': 'user',
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final token = data['token']?.toString();
    final isRegistered = data['is_registered'] == true;

    if (token != null && token.isNotEmpty) {
      await LocalStorage.saveToken(token);
    }

    UserProfile? user;
    if (data['user'] is Map<String, dynamic>) {
      user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await LocalStorage.saveUser(user.toJson());
    }

    return AuthVerificationResult(
      user: user,
      isRegistered: isRegistered,
      token: token,
    );
  }

  /// Register Candidate Profile on km-backend
  Future<UserProfile> registerCandidate({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    String experienceDetail = '',
    String email = '',
  }) async {
    final response = await _client.post(
      ApiConstants.userRegister,
      data: {
        'roles': ['user'],
        'name': name.trim(),
        'gender': gender,
        'education_level': educationLevel,
        'work_experience': workExperience,
        'city': city,
        'job_categories': jobCategories,
        'experience_detail': experienceDetail.trim(),
        'email': email.trim(),
        'is_email_verified': false,
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Update Candidate Profile (headline, about, city, gender, profile photo, etc.)
  Future<UserProfile> updateProfile(Map<String, dynamic> updates) async {
    final response = await _client.patch(
      ApiConstants.userProfile,
      data: updates,
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Add Education record to Candidate profile
  Future<UserProfile> addEducation({
    String? id,
    required String schoolName,
    required String degree,
    required String fieldOfStudy,
    required String startDate,
    required String endDate,
    String grade = '',
    String description = '',
  }) async {
    final payload = {
      'school_name': schoolName.trim(),
      'degree': degree.trim(),
      'field_of_study': fieldOfStudy.trim(),
      'start_date': startDate.trim(),
      'end_date': endDate.trim(),
      'grade': grade.trim(),
      'description': description.trim(),
    };
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }

    final response = await _client.post('/user/education', data: payload);

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Add Work Experience record to Candidate profile
  Future<UserProfile> addExperience({
    required String title,
    required String companyName,
    required String employmentType,
    required String location,
    required String startDate,
    required String endDate,
    String description = '',
  }) async {
    final response = await _client.post(
      '/user/experience',
      data: {
        'title': title.trim(),
        'company_name': companyName.trim(),
        'employment_type': employmentType.trim(),
        'location': location.trim(),
        'start_date': startDate.trim(),
        'end_date': endDate.trim(),
        'description': description.trim(),
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Add a Skill tag to Candidate profile
  Future<UserProfile> addSkill(String skillName) async {
    final response = await _client.post(
      '/user/skill',
      data: {'skill_name': skillName.trim()},
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Upload file to backend file service (Profile photo, Resume document)
  Future<String?> uploadFile(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _client.post('/files/upload', data: formData);

    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final url = data['url']?.toString() ?? data['file_url']?.toString();
      if (url != null && url.isNotEmpty) {
        if (!url.startsWith('http')) {
          final base = ApiConstants.baseUrl;
          final host = base.endsWith('/api')
              ? base.substring(0, base.length - 4)
              : base;
          final formattedUrl = url.startsWith('/') ? url : '/$url';
          return '$host$formattedUrl';
        }
        return url;
      }
    }
    return null;
  }

  /// Fetch user profile from km-backend
  Future<UserProfile?> getProfile() async {
    try {
      final response = await _client.get(ApiConstants.userProfile);
      if (response.data is Map<String, dynamic>) {
        final user = UserProfile.fromJson(
          response.data as Map<String, dynamic>,
        );
        await LocalStorage.saveUser(user.toJson());
        return user;
      }
    } catch (_) {
      // Fallback to local storage if offline
      final cached = LocalStorage.getUser();
      if (cached != null) return UserProfile.fromJson(cached);
    }
    return null;
  }

  /// Send OTP to candidate's email address
  Future<bool> sendEmailOtp(String email) async {
    try {
      await _client.post(
        ApiConstants.otpEmailSend,
        data: {'email': email.trim()},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verify Email OTP
  Future<bool> verifyEmailOtp(String email, String otp) async {
    try {
      await _client.post(
        ApiConstants.otpEmailVerify,
        data: {'email': email.trim(), 'code': otp.trim()},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Request password reset OTP code via km-backend
  Future<void> forgotPassword(String email) async {
    await _client.post(
      ApiConstants.forgotPassword,
      data: {'email': email.trim(), 'role': 'user'},
    );
  }

  /// Reset password using 4-digit code on km-backend
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.post(
      ApiConstants.resetPassword,
      data: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
        'role': 'user',
      },
    );
  }

  /// Add Project record to Candidate profile
  Future<UserProfile> addProject({
    String? id,
    required String title,
    String associatedWith = '',
    String description = '',
    String link = '',
    String startDate = '',
    String endDate = '',
    String skills = '',
    bool isCurrentlyWorking = false,
  }) async {
    final payload = {
      'title': title.trim(),
      'associated_with': associatedWith.trim(),
      'description': description.trim(),
      'link': link.trim(),
      'start_date': startDate.trim(),
      'end_date': endDate.trim(),
      'skills': skills.trim(),
      'is_currently_working': isCurrentlyWorking,
    };
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }

    final response = await _client.post('/user/project', data: payload);

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Logout
  Future<void> logout() async {
    await LocalStorage.clearSession();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
