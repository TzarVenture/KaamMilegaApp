import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/network_status.dart';
import '../../../core/storage/local_storage.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  /// True while the saved session is being checked at app start. The router
  /// keeps the Splash screen visible until this is false.
  final bool isChecking;

  /// True after "Explore Jobs as Guest". Kept in memory only (a restart starts
  /// at Login again) and never counts as signed in.
  final bool isGuest;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.isChecking = false,
    this.isGuest = false,
  });

  /// True when the user is signed in but has not completed registration yet
  /// (for example a new phone number right after OTP, or a new email
  /// sign-up). Such a session may only use the Complete Profile screen.
  /// Unknown while the profile is not loaded ([user] is null).
  bool get needsProfileCompletion {
    final u = user;
    return isAuthenticated && u != null && !hasCompletedRegistration(u);
  }

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    bool? isChecking,
    bool? isGuest,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      isChecking: isChecking ?? this.isChecking,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

/// Whether [user] has completed registration (POST /user/register).
///
/// km-backend sets `is_registered` to true on registration. Older accounts
/// may not have that flag even though their profile is complete, so, like the
/// KaamMilega website (km-frontend register page), a profile with both an
/// education level and a city also counts as registered.
bool hasCompletedRegistration(UserProfile user) =>
    user.isRegistered ||
    (user.educationLevel.trim().isNotEmpty && user.city.trim().isNotEmpty);

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

    // Auto-refresh profile when internet returns
    ref.listen<NetworkStatus>(networkStatusProvider, (prev, next) {
      if (prev == NetworkStatus.offline && next == NetworkStatus.online) {
        if (state.isAuthenticated) {
          refreshProfile();
        }
      }
    });

    Future.microtask(() => checkAuthStatus());
    // Not signed in and not logged out yet: the session is still unknown.
    return const AuthState(isChecking: true);
  }

  /// Startup session check. Splash stays visible until it finishes, then the
  /// router opens Home (valid session) or Login (no or rejected session).
  Future<void> checkAuthStatus() async {
    final token = LocalStorage.getToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(isChecking: false, isAuthenticated: false);
      return;
    }

    final cachedUser = LocalStorage.getUser();
    if (cachedUser != null) {
      state = state.copyWith(user: UserProfile.fromJson(cachedUser));
    }

    // Validate the saved token with the server. If the server rejects it
    // (HTTP 401), ApiClient clears the saved session. When offline or the
    // server is down, the token stays and the cached profile is used.
    await refreshProfile();
    if (!ref.mounted) return;

    final tokenStillValid = (LocalStorage.getToken() ?? '').isNotEmpty;
    state = tokenStillValid
        ? state.copyWith(isChecking: false, isAuthenticated: true)
        : const AuthState();
  }

  /// "Explore Jobs as Guest": browse public screens without an account.
  /// No token is created; account-only actions still ask the user to log in.
  void enterGuestMode() {
    if (state.isAuthenticated) return;
    state = state.copyWith(isGuest: true);
  }

  /// Refresh latest candidate profile from backend API
  Future<void> refreshProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (profile != null) {
        state = state.copyWith(isAuthenticated: true, user: profile);
      }
    } catch (_) {
      // Preserve cached user profile without logging out when offline
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

  /// Verify OTP and store token & user profile.
  ///
  /// Returns the backend result on success; `is_registered` in it tells
  /// whether the number already has a completed account. Returns null when
  /// verification failed (wrong or expired OTP, network error, ...); the
  /// user-facing reason is then in [AuthState.error]. A failed verification
  /// never means "new user".
  Future<AuthVerificationResult?> verifyOtp(String mobile, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.verifyOtp(mobile, code);
      if ((result.token ?? '').isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not verify OTP. Please try again.',
        );
        return null;
      }
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: result.user,
      );
      await refreshProfile();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: otpErrorMessage(e));
      return null;
    }
  }

  /// User-facing message for a failed POST /auth/otp/verify.
  /// km-backend answers HTTP 400 with {"error": "Invalid OTP"} for a wrong
  /// code and {"error": "OTP not found or expired"} for an expired or
  /// already used code.
  static String otpErrorMessage(Object e) {
    if (e is AppValidationException) {
      final msg = e.message.trim();
      final lower = msg.toLowerCase();
      if (lower == 'invalid otp') return 'Incorrect OTP. Please try again.';
      if (lower.contains('not found or expired')) {
        return 'This OTP has expired or was already used. '
            'Tap Resend to get a new code.';
      }
      // Role mismatch, e.g. "this mobile number is already registered as a
      // recruiter" (safe, meaningful backend text).
      if (lower.contains('registered as')) return msg;
      return 'Could not verify OTP. Please try again.';
    }
    // Network / timeout / server errors already carry app-written messages.
    if (e is AppException) return e.message;
    return 'Could not verify OTP. Please try again.';
  }

  /// User-facing message for a failed POST /auth/login/password.
  /// km-backend answers HTTP 401 with {"error": "invalid email or password"}
  /// for both a wrong password and an unknown email (it does not say which).
  static String passwordLoginErrorMessage(Object e) {
    if (e is AppAuthException || e is AppValidationException) {
      final msg = (e as AppException).message.trim();
      final lower = msg.toLowerCase();
      if (lower == 'invalid email or password') {
        return 'Incorrect email or password. Please try again.';
      }
      if (lower == 'email and password are required') {
        return 'Please enter your email and password.';
      }
      // Meaningful backend texts: "No password has been set for this
      // account..." and "This account is registered as a Recruiter...".
      if (lower.startsWith('no password has been set') ||
          lower.contains('registered as')) {
        return msg;
      }
      return 'Login failed. Please try again.';
    }
    if (e is AppException) return e.message;
    return 'Login failed. Please try again.';
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
      state = state.copyWith(
        isLoading: false,
        error: passwordLoginErrorMessage(e),
      );
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

  /// Completes registration of the signed-in account (POST /user/register),
  /// the same account that was created by phone OTP or email sign-up. It
  /// never creates a second account.
  ///
  /// The backend overwrites `email` and `is_email_verified` with whatever is
  /// sent, so the values already on the account are sent back unchanged.
  Future<bool> completeRegistration({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    required String experienceDetail,
  }) async {
    final current = state.user;
    if (!state.isAuthenticated || current == null) {
      state = state.copyWith(
        error: 'Your session is not ready yet. Please try again.',
      );
      return false;
    }

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
        email: current.email,
        isEmailVerified: current.isEmailVerified,
      );
      if (!ref.mounted) return true;
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      final message = e is AppException
          ? e.message
          : 'Could not complete registration. Please try again.';
      // HTTP 401: ApiClient has already cleared the saved session. Reset the
      // state too, so the router returns to Login instead of keeping a
      // half-signed-in session.
      final tokenCleared = (LocalStorage.getToken() ?? '').isEmpty;
      state = tokenCleared
          ? AuthState(error: message)
          : state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  /// Profile fields the backend does not store yet. They are kept on the
  /// device instead of being sent (the server would silently drop them).
  static const Set<String> deviceOnlyProfileKeys = {
    'open_to_work',
    'providing_services',
    'is_available_for_gigs',
  };

  /// Update Candidate Profile (headline, about, city, gender, experience, etc.)
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deviceUpdates = Map<String, dynamic>.from(updates)
        ..removeWhere((k, _) => !deviceOnlyProfileKeys.contains(k));
      final serverUpdates = Map<String, dynamic>.from(updates)
        ..removeWhere((k, _) => deviceOnlyProfileKeys.contains(k));

      if (deviceUpdates.isNotEmpty) {
        await LocalStorage.saveDeviceProfilePrefs(deviceUpdates);
      }

      UserProfile? updatedUser = state.user;
      if (serverUpdates.isNotEmpty) {
        updatedUser = await _repository.updateProfile(serverUpdates);
      }

      if (updatedUser != null && deviceUpdates.isNotEmpty) {
        updatedUser = updatedUser.copyWith(
          openToWork: deviceUpdates['open_to_work']?.toString(),
          providingServices: deviceUpdates['providing_services']?.toString(),
          isAvailableForGigs: deviceUpdates['is_available_for_gigs'] as bool?,
        );
        await LocalStorage.saveUser(updatedUser.toJson());
      }

      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to update profile'),
      );
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
      // Backend can only add education; the existing id is not re-sent
      // (the server would store a duplicate entry with the same id).
      final updatedUser = await _repository.addEducation(
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
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to save education'),
      );
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
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to save experience'),
      );
      return false;
    }
  }

  /// Runs a profile edit that returns the updated profile from the server,
  /// and shows the server's result (never a local-only change).
  Future<bool> _applyProfileEdit(
    Future<UserProfile> Function() request,
    String fallbackError,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await request();
      if (!ref.mounted) return true;
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: e is AppException ? e.message : _parseError(e, fallbackError),
      );
      return false;
    }
  }

  /// Edit an existing education entry (PUT /user/education/:id).
  Future<bool> updateEducation({
    required String id,
    required String schoolName,
    required String degree,
    required String fieldOfStudy,
    required String startDate,
    required String endDate,
    String grade = '',
    String description = '',
  }) {
    return _applyProfileEdit(
      () => _repository.updateEducation(
        id: id,
        schoolName: schoolName,
        degree: degree,
        fieldOfStudy: fieldOfStudy,
        startDate: startDate,
        endDate: endDate,
        grade: grade,
        description: description,
      ),
      'Failed to update education',
    );
  }

  /// Delete an education entry (DELETE /user/education/:id).
  Future<bool> deleteEducation(String id) {
    return _applyProfileEdit(
      () => _repository.deleteEducation(id),
      'Failed to delete education',
    );
  }

  /// Edit an existing experience entry (PUT /user/experience/:id). Its
  /// [skills] are sent back unchanged.
  Future<bool> updateExperience({
    required String id,
    required String title,
    required String companyName,
    required String employmentType,
    required String location,
    required String startDate,
    required String endDate,
    String description = '',
    List<String> skills = const [],
  }) {
    return _applyProfileEdit(
      () => _repository.updateExperience(
        id: id,
        title: title,
        companyName: companyName,
        employmentType: employmentType,
        location: location,
        startDate: startDate,
        endDate: endDate,
        description: description,
        skills: skills,
      ),
      'Failed to update experience',
    );
  }

  /// Delete an experience entry (DELETE /user/experience/:id).
  Future<bool> deleteExperience(String id) {
    return _applyProfileEdit(
      () => _repository.deleteExperience(id),
      'Failed to delete experience',
    );
  }

  /// Save Open To Work (PATCH /user/open-to-work). The profile shown
  /// afterwards is the one returned by the server.
  Future<bool> saveOpenToWork(OpenToWorkPreferences prefs) => _applyProfileEdit(
    () => _repository.updateOpenToWork(prefs),
    'Failed to save Open To Work',
  );

  /// Save Providing Services (PATCH /user/providing-services).
  Future<bool> saveProvidingServices(ProvidingServicesPreferences prefs) =>
      _applyProfileEdit(
        () => _repository.updateProvidingServices(prefs),
        'Failed to save Providing Services',
      );

  /// Remove a skill (DELETE /user/skill/:skillName).
  ///
  /// Succeeds only if the profile returned by the server no longer has the
  /// skill (the backend answers 200 even when it did not match the name).
  Future<bool> removeSkill(String skill) async {
    final ok = await _applyProfileEdit(
      () => _repository.deleteSkill(skill),
      'Failed to remove skill',
    );
    if (!ok || !ref.mounted) return false;
    final target = skill.trim().toLowerCase();
    final stillThere = (state.user?.skills ?? const <String>[]).any(
      (s) => s.trim().toLowerCase() == target,
    );
    if (stillThere) {
      state = state.copyWith(
        error: 'Could not remove "$skill". Please try again later.',
      );
      return false;
    }
    return true;
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
        // Backend profile has no resume field yet, so keep the uploaded URL on
        // the device; it is attached to every job application (resume_url).
        await LocalStorage.saveResumeUrl(url);
        final current = state.user;
        if (current != null) {
          final updatedUser = current.copyWith(resumeUrl: url);
          await LocalStorage.saveUser(updatedUser.toJson());
          state = state.copyWith(isLoading: false, user: updatedUser);
        } else {
          state = state.copyWith(isLoading: false);
        }
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
      // Do not fake success locally: surface the real server error.
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to save project'),
      );
      return false;
    }
  }

  /// Submit Expert application to backend
  Future<bool> applyForExpert({
    required String category,
    required String bio,
    required double pricing,
    List<Map<String, String>> documents = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.applyForExpert(
        category: category,
        bio: bio,
        pricing: pricing,
        documents: documents,
      );
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to submit expert application'),
      );
      return false;
    }
  }

  /// Change account password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to update password'),
      );
      return false;
    }
  }

  /// Delete a Project from candidate profile
  Future<bool> deleteProject(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _repository.deleteProject(id);
      state = state.copyWith(isLoading: false, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _parseError(e, 'Failed to delete project'),
      );
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

/// ID of the signed-in account, or null for guests / logged-out users.
///
/// Providers that hold one user's data (applications, chats, connections,
/// ...) watch this, so Riverpod rebuilds or disposes them on logout, login
/// or an account switch and the previous user's data is never shown to the
/// next one. While it is null they must not call account-only APIs.
final sessionUserIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authProvider.select((s) {
      if (!s.isAuthenticated) return null;
      final id = s.user?.id ?? '';
      return id.isEmpty ? null : id;
    }),
  );
});
