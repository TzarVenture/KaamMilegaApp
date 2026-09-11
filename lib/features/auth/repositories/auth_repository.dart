import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../cities/repositories/city_repository.dart';
import '../models/user_profile.dart';

/// Authentication repository connecting with km-backend auth endpoints
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
  Future<UserProfile?> verifyOtp(String mobile, String code) async {
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

    if (token != null && token.isNotEmpty) {
      await LocalStorage.saveToken(token);
    }

    if (data['user'] is Map<String, dynamic>) {
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await LocalStorage.saveUser(user.toJson());
      return user;
    }

    return null;
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
