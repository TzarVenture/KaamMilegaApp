import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../cities/repositories/city_repository.dart';
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

/// Authentication repository connecting with km-backend auth endpoints (Candidate-only)
class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  /// Send OTP to user's mobile number
  Future<void> sendOtp(String mobile) async {
    await _client.post(
      ApiConstants.sendOtp,
      data: {
        'mobile': mobile,
        'role': 'user',
      },
    );
  }

  /// Verify OTP and store JWT auth token
  Future<AuthVerificationResult> verifyOtp(String mobile, String code) async {
    final response = await _client.post(
      ApiConstants.verifyOtp,
      data: {
        'mobile': mobile,
        'code': code,
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

  /// Update Candidate Profile
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

  /// Fetch user profile
  Future<UserProfile?> getProfile() async {
    try {
      final response = await _client.get(ApiConstants.userProfile);
      if (response.data is Map<String, dynamic>) {
        final user = UserProfile.fromJson(response.data as Map<String, dynamic>);
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

  /// Logout
  Future<void> logout() async {
    await LocalStorage.clearSession();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
