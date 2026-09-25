import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
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

  /// Complete registration of the signed-in account (POST /user/register).
  ///
  /// Body = km-backend `RegisterRequest` (same fields the KaamMilega website
  /// sends). The backend replaces `email`, `is_email_verified` and `roles` on
  /// the account with these values, so callers pass the account's current
  /// email and verification status. Response: the updated `User`.
  Future<UserProfile> registerCandidate({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    required String experienceDetail,
    required String email,
    required bool isEmailVerified,
  }) async {
    final response = await _client.post(
      ApiConstants.userRegister,
      data: registerRequestBody(
        name: name,
        gender: gender,
        educationLevel: educationLevel,
        workExperience: workExperience,
        city: city,
        jobCategories: jobCategories,
        experienceDetail: experienceDetail,
        email: email,
        isEmailVerified: isEmailVerified,
      ),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    final user = UserProfile.fromJson(data);
    if (user.id.isEmpty) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// JSON body for POST /user/register (km-backend `RegisterRequest`).
  static Map<String, dynamic> registerRequestBody({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    required String experienceDetail,
    required String email,
    required bool isEmailVerified,
  }) {
    return {
      'roles': ['user'],
      'name': name.trim(),
      'gender': gender,
      'education_level': educationLevel,
      'work_experience': workExperience,
      'city': city.trim(),
      'job_categories': jobCategories,
      'experience_detail': experienceDetail,
      'email': email.trim(),
      'is_email_verified': isEmailVerified,
    };
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

  /// Updated profile from a profile-editing response. The backend answers
  /// with the whole `User`; anything else is an error (never an empty user).
  Future<UserProfile> _userFromResponse(dynamic data) async {
    if (data is! Map<String, dynamic>) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    final user = UserProfile.fromJson(data);
    if (user.id.isEmpty) {
      throw const AppValidationException(
        'Unexpected response from server. Please try again.',
      );
    }
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  static void _requireId(String id) {
    if (id.trim().isEmpty) {
      throw const AppValidationException(
        'This entry cannot be changed. Please refresh your profile.',
      );
    }
  }

  /// Update an education entry (PUT /user/education/:id). The backend
  /// replaces the whole entry and keeps its id. Returns the updated profile.
  Future<UserProfile> updateEducation({
    required String id,
    required String schoolName,
    required String degree,
    required String fieldOfStudy,
    required String startDate,
    required String endDate,
    String grade = '',
    String description = '',
  }) async {
    _requireId(id);
    final response = await _client.put(
      '${ApiConstants.userEducation}/$id',
      data: {
        'school_name': schoolName.trim(),
        'degree': degree.trim(),
        'field_of_study': fieldOfStudy.trim(),
        'start_date': startDate.trim(),
        'end_date': endDate.trim(),
        'grade': grade.trim(),
        'description': description.trim(),
      },
    );
    return _userFromResponse(response.data);
  }

  /// Delete an education entry (DELETE /user/education/:id).
  Future<UserProfile> deleteEducation(String id) async {
    _requireId(id);
    final response = await _client.delete('${ApiConstants.userEducation}/$id');
    return _userFromResponse(response.data);
  }

  /// Update an experience entry (PUT /user/experience/:id). The backend
  /// replaces the whole entry, so its existing [skills] are sent back too
  /// (they are not edited in the app but must not be lost).
  Future<UserProfile> updateExperience({
    required String id,
    required String title,
    required String companyName,
    required String employmentType,
    required String location,
    required String startDate,
    required String endDate,
    String description = '',
    List<String> skills = const [],
  }) async {
    _requireId(id);
    final response = await _client.put(
      '${ApiConstants.userExperience}/$id',
      data: {
        'title': title.trim(),
        'company_name': companyName.trim(),
        'employment_type': employmentType.trim(),
        'location': location.trim(),
        'start_date': startDate.trim(),
        'end_date': endDate.trim(),
        'description': description.trim(),
        'skills': skills,
      },
    );
    return _userFromResponse(response.data);
  }

  /// Delete an experience entry (DELETE /user/experience/:id).
  Future<UserProfile> deleteExperience(String id) async {
    _requireId(id);
    final response = await _client.delete('${ApiConstants.userExperience}/$id');
    return _userFromResponse(response.data);
  }

  /// Remove a skill (DELETE /user/skill/:skillName, name URL-encoded like
  /// the KaamMilega website does). Returns the updated profile.
  Future<UserProfile> deleteSkill(String skillName) async {
    final name = skillName.trim();
    if (name.isEmpty) {
      throw const AppValidationException('Please choose a skill to remove.');
    }
    final response = await _client.delete(
      '${ApiConstants.userSkill}/${Uri.encodeComponent(name)}',
    );
    return _userFromResponse(response.data);
  }

  /// Save Open To Work (PATCH /user/open-to-work). The backend replaces the
  /// whole object and answers with the updated profile under `user`.
  Future<UserProfile> updateOpenToWork(OpenToWorkPreferences prefs) async {
    final response = await _client.patch(
      ApiConstants.userOpenToWork,
      data: prefs.toJson(),
    );
    return _userFromResponse(response.data);
  }

  /// Save Providing Services (PATCH /user/providing-services). The backend
  /// replaces the whole object and answers with the updated profile.
  Future<UserProfile> updateProvidingServices(
    ProvidingServicesPreferences prefs,
  ) async {
    final response = await _client.patch(
      ApiConstants.userProvidingServices,
      data: prefs.toJson(),
    );
    return _userFromResponse(response.data);
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

  /// Add a new Project, or update an existing one when [id] is given.
  /// Backend: POST /user/project (add) and PUT /user/project/:id (update).
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
    // Field names must match the backend Project model exactly.
    final payload = <String, dynamic>{
      'title': title.trim(),
      'associated_with': associatedWith.trim(),
      'description': description.trim(),
      'project_url': link.trim(),
      'start_date': startDate.trim(),
      'end_date': endDate.trim(),
      // Backend expects a list of skills, the form collects comma-separated text
      'skills': skills
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'is_current': isCurrentlyWorking,
    };

    final isEdit = id != null && id.isNotEmpty;
    final response = isEdit
        ? await _client.put('${ApiConstants.userProject}/$id', data: payload)
        : await _client.post(ApiConstants.userProject, data: payload);

    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Apply to become an Expert (POST /user/apply-expert).
  /// Returns the updated profile with expert_approval_status = "pending".
  Future<UserProfile> applyForExpert({
    required String category,
    required String bio,
    required double pricing,
    List<Map<String, String>> documents = const [],
  }) async {
    final response = await _client.post(
      ApiConstants.userApplyExpert,
      data: {
        'expert_category': category,
        'expert_bio': bio.trim(),
        'expert_pricing': pricing,
        'expert_documents': documents,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final user = UserProfile.fromJson(data);
    await LocalStorage.saveUser(user.toJson());
    return user;
  }

  /// Change account password (PUT /user/password).
  /// [currentPassword] may be empty for accounts created with OTP only.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.put(
      ApiConstants.userPassword,
      data: {
        if (currentPassword.isNotEmpty) 'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// Fetch account settings.
  /// Read from GET /user/profile (field `settings`). GET /user/settings
  /// currently returns HTTP 500 because the backend matches it as
  /// GET /user/:id (route order issue on the server). Saving via
  /// PUT /user/settings is not affected.
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client.get(ApiConstants.userProfile);
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['settings'] is Map<String, dynamic>) {
      return data['settings'] as Map<String, dynamic>;
    }
    return {};
  }

  /// Save account settings (PUT /user/settings). Backend replaces the whole
  /// settings object, so always send every field.
  Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> settings,
  ) async {
    final response = await _client.put(
      ApiConstants.userSettings,
      data: settings,
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['settings'] is Map<String, dynamic>) {
      return data['settings'] as Map<String, dynamic>;
    }
    return settings;
  }

  /// Delete a Project from Candidate profile (DELETE /user/project/:id)
  Future<UserProfile> deleteProject(String id) async {
    final response = await _client.delete('${ApiConstants.userProject}/$id');
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
