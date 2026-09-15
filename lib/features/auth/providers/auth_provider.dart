import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => checkAuthStatus());
    return const AuthState();
  }

  /// Check if user has an active saved session & refresh profile data
  Future<void> checkAuthStatus() async {
    final token = LocalStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final cachedUser = LocalStorage.getUser();
      state = state.copyWith(
        isAuthenticated: true,
        user: cachedUser != null ? UserProfile.fromJson(cachedUser) : null,
      );
      await refreshProfile();
    }
  }

  /// Refresh latest candidate profile from backend API
  Future<void> refreshProfile() async {
    final profile = await _repository.getProfile();
    if (profile != null) {
      state = state.copyWith(isAuthenticated: true, user: profile);
    }
  }

  /// Send OTP to user's mobile number
  Future<bool> sendOtp(String mobile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.sendOtp(mobile);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Verify OTP and store token & user profile
  Future<AuthVerificationResult> verifyOtp(String mobile, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.verifyOtp(mobile, code);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result.user,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return const AuthVerificationResult();
    }
  }

  /// Register Candidate Profile
  Future<bool> registerCandidate({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    String experienceDetail = '',
    String email = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.registerCandidate(
        name: name,
        gender: gender,
        educationLevel: educationLevel,
        workExperience: workExperience,
        city: city,
        jobCategories: jobCategories,
        experienceDetail: experienceDetail,
        email: email,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Update Candidate Profile (headline, about, city, gender, experience, etc.)
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.updateProfile(updates);
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Add Education item to candidate profile
  Future<bool> addEducation({
    required String schoolName,
    required String degree,
    required String fieldOfStudy,
    required String startDate,
    required String endDate,
    String description = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.addEducation(
        schoolName: schoolName,
        degree: degree,
        fieldOfStudy: fieldOfStudy,
        startDate: startDate,
        endDate: endDate,
        description: description,
      );
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Add Experience item to candidate profile
  Future<bool> addExperience({
    required String title,
    required String companyName,
    required String employmentType,
    required String location,
    required String startDate,
    required String endDate,
    String description = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.addExperience(
        title: title,
        companyName: companyName,
        employmentType: employmentType,
        location: location,
        startDate: startDate,
        endDate: endDate,
        description: description,
      );
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Add skill tag
  Future<bool> addSkill(String skill) async {
    try {
      final updatedUser = await _repository.addSkill(skill);
      state = state.copyWith(user: updatedUser);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload Profile Photo and update profile
  Future<bool> uploadProfilePhoto(List<int> bytes, String filename) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = await _repository.uploadFile(bytes, filename);
      if (url != null && url.isNotEmpty) {
        final updatedUser = await _repository.updateProfile({
          'profile_image': url,
        });
        state = state.copyWith(isLoading: false, user: updatedUser);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to upload image.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout candidate session
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
