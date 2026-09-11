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

  /// Check if user has an active saved session
  Future<void> checkAuthStatus() async {
    final token = LocalStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final cachedUser = LocalStorage.getUser();
      state = state.copyWith(
        isAuthenticated: true,
        user: cachedUser != null ? UserProfile.fromJson(cachedUser) : null,
      );
      // Refresh profile in background
      _repository.getProfile().then((profile) {
        if (profile != null) {
          state = state.copyWith(user: profile);
        }
      });
    }
  }

  /// Send OTP
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

  /// Verify OTP
  Future<bool> verifyOtp(String mobile, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.verifyOtp(mobile, code);
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

  /// Logout
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
