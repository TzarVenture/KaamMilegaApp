import 'package:dio/dio.dart';
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

  String _parseError(dynamic e, String defaultMessage) {
    if (e is DioException) {
      if (e.error != null && e.error.toString().isNotEmpty) {
        return e.error.toString();
      }
      if (e.response?.data is Map) {
        final data = e.response!.data as Map<String, dynamic>;
        final msg = data['error'] ?? data['message'];
        if (msg != null && msg.toString().isNotEmpty) {
          return msg.toString();
        }
      }
    }
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return str.isNotEmpty ? str : defaultMessage;
  }

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
      final errorMsg = _parseError(e, 'Failed to send OTP.');
      state = state.copyWith(isLoading: false, error: errorMsg);
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
      await refreshProfile();
      return result;
    } catch (e) {
      final errorMsg = _parseError(e, 'Invalid OTP code.');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return const AuthVerificationResult();
    }
  }

  /// Login with Password
  Future<bool> loginWithPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.loginWithPassword(email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result.user,
      );
      await refreshProfile();
      return true;
    } catch (e) {
      final errorMsg = _parseError(e, 'Invalid email or password');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    }
  }

  /// Register with Name, Email, and Password on km-backend
  Future<bool> registerWithPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.registerWithPassword(
        name: name,
        email: email,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result.user,
      );
      await refreshProfile();
      return true;
    } catch (e) {
      final errorMsg = _parseError(e, 'Registration failed. Please try again.');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
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
    String? id,
    required String schoolName,
    required String degree,
    required String fieldOfStudy,
    required String startDate,
    required String endDate,
    String grade = '',
    String description = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.addEducation(
        id: id,
        schoolName: schoolName,
        degree: degree,
        fieldOfStudy: fieldOfStudy,
        startDate: startDate,
        endDate: endDate,
        grade: grade,
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

  /// Delete / Remove Profile Photo
  Future<bool> deleteProfilePhoto() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.updateProfile({
        'profile_image': '',
        'profile_picture': '',
      });
      state = state.copyWith(
        isLoading: false,
        user: updatedUser.copyWith(profileImage: ''),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Upload Cover Photo and update profile
  Future<bool> uploadCoverPhoto(List<int> bytes, String filename) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = await _repository.uploadFile(bytes, filename);
      if (url != null && url.isNotEmpty) {
        final updatedUser = await _repository.updateProfile({
          'cover_image': url,
          'background_image': url,
        });
        state = state.copyWith(isLoading: false, user: updatedUser);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to upload cover image.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Delete / Remove Cover / Background Photo
  Future<bool> deleteCoverPhoto() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.updateProfile({
        'cover_image': '',
        'background_image': '',
      });
      state = state.copyWith(
        isLoading: false,
        user: updatedUser.copyWith(coverImage: ''),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Upload Resume PDF/DOC and update profile resume_url
  Future<bool> uploadResumePdf(List<int> bytes, String filename) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = await _repository.uploadFile(bytes, filename);
      if (url != null && url.isNotEmpty) {
        final updatedUser = await _repository.updateProfile({
          'resume_url': url,
          'resume': url,
        });
        state = state.copyWith(isLoading: false, user: updatedUser);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to upload resume document.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Send Email Verification OTP
  Future<bool> sendEmailOtp(String email) async {
    return _repository.sendEmailOtp(email);
  }

  /// Verify Email OTP and update profile status
  Future<bool> verifyEmailOtp(String email, String otp) async {
    final success = await _repository.verifyEmailOtp(email, otp);
    if (success) {
      if (state.user != null) {
        final updatedUser = state.user!.copyWith(isEmailVerified: true);
        state = state.copyWith(user: updatedUser);
        await LocalStorage.saveUser(updatedUser.toJson());
      } else {
        await refreshProfile();
      }
    }
    return success;
  }

  /// Add Project item to candidate profile
  Future<bool> addProject({
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.addProject(
        id: id,
        title: title,
        associatedWith: associatedWith,
        description: description,
        link: link,
        startDate: startDate,
        endDate: endDate,
        skills: skills,
        isCurrentlyWorking: isCurrentlyWorking,
      );
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      if (state.user != null) {
        final newProject = ProjectItem(
          id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          associatedWith: associatedWith,
          description: description,
          link: link,
          startDate: startDate,
          endDate: endDate,
          skills: skills,
          isCurrentlyWorking: isCurrentlyWorking,
        );
        final updatedList = List<ProjectItem>.from(state.user!.projects);
        final existingIdx = updatedList.indexWhere((p) => p.id == newProject.id);
        if (existingIdx >= 0) {
          updatedList[existingIdx] = newProject;
        } else {
          updatedList.add(newProject);
        }
        final updatedUser = state.user!.copyWith(projects: updatedList);
        state = state.copyWith(isLoading: false, user: updatedUser);
        await LocalStorage.saveUser(updatedUser.toJson());
        return true;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Request password reset OTP to email
  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.forgotPassword(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errorMsg = _parseError(e, 'Failed to send reset code');
      state = state.copyWith(isLoading: false, error: errorMsg);
      return false;
    }
  }

  /// Reset password using 4-digit code and new password
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      final errorMsg = _parseError(e, 'Failed to reset password');
      state = state.copyWith(isLoading: false, error: errorMsg);
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
