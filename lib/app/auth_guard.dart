import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/local_storage.dart';
import '../features/auth/providers/auth_provider.dart';
import '../shared/widgets/auth_prompt_dialog.dart';

/// Decides which screen a user may open, based on the existing [AuthState].
///
/// Used as the global `redirect` of [GoRouter]:
/// - Session still being checked at app start, or Splash not yet shown for
///   its minimum time: stay on Splash.
/// - Signed in but not registered yet (new phone number after OTP, new email
///   sign-up): only Complete Profile (`/complete-profile`) is open.
/// - Signed in: Splash goes to Home; every screen is open.
/// - Guest ("Explore Jobs as Guest"): public screens such as Jobs and Job
///   details are open; account-only screens go to Login.
/// - Logged out (not a guest): only Login, Register, OTP and Forgot
///   Password are open; everything else goes to Login.
///
/// "Signed in" means the auth state is authenticated AND a login token is
/// saved. When the server rejects an expired token (HTTP 401), ApiClient
/// clears it, so the next navigation goes to Login.
class AuthGuard {
  AuthGuard._();

  /// Screens (and everything under them) that require a login.
  static const List<String> _protectedRoots = [
    '/my-applications',
    '/applications',
    '/interviews',
    '/my-sessions', // booked mentorship sessions
    '/network',
    '/apply-expert',
    '/settings',
    '/wallet',
    '/peer-to-peer', // people search + connections (account-only APIs)
  ];

  /// Screens used to sign in. Always open.
  static const List<String> _authScreens = [
    '/login',
    '/register',
    '/otp',
    '/forgot-password',
  ];

  /// Registration step for a signed-in account that is not registered yet
  /// (see [AuthState.needsProfileCompletion]).
  static const String completeProfilePath = '/complete-profile';

  static String? _pendingPath;

  static bool isSignedIn(AuthState auth) {
    final token = LocalStorage.getToken();
    return auth.isAuthenticated && token != null && token.isNotEmpty;
  }

  static bool isProtected(String path) {
    if (path.startsWith('/chats/')) return true; // a single chat conversation
    return _protectedRoots.any(
      (root) => path == root || path.startsWith('$root/'),
    );
  }

  static bool _isAuthScreen(String path) => _authScreens.contains(path);

  /// Returns where to send the user for [uri], or null to allow it.
  ///
  /// [splashTimeDone] is false until Splash has been visible for its minimum
  /// time at app start; it never decides Home vs Login.
  static String? redirect(
    AuthState auth,
    Uri uri, {
    bool splashTimeDone = true,
  }) {
    final path = uri.path;

    // 1. Startup check still running: keep showing Splash (no Home flash).
    if (auth.isChecking) return path == '/splash' ? null : '/splash';

    // 1b. Check done but Splash not shown long enough yet: stay on Splash.
    if (!splashTimeDone && path == '/splash') return null;

    final signedIn = isSignedIn(auth);

    final needsProfile = signedIn && auth.needsProfileCompletion;

    // 2. Check finished: leave Splash for the final screen.
    if (path == '/splash') {
      if (!signedIn) return '/login';
      return needsProfile ? completeProfilePath : '/home';
    }

    // 2b. Signed in but registration not completed: only the Complete
    // Profile screen is open. Its Back / "Use a different account" actions
    // log out, so no half-registered session can use the app.
    if (needsProfile) {
      return path == completeProfilePath ? null : completeProfilePath;
    }

    // 2c. Complete Profile is only for unregistered, signed-in accounts.
    // Right after registration, continue to the screen the user wanted
    // (not cleared here; the Complete Profile screen takes it).
    if (path == completeProfilePath) {
      return signedIn ? (_pendingPath ?? '/home') : '/login';
    }

    if (signedIn || _isAuthScreen(path)) return null;

    // 3. Account-only screens: Login first, then back to the wanted screen.
    if (isProtected(path)) {
      // A chat screen needs extra data (who to chat with) that is lost on a
      // redirect, so after login those users go Home instead.
      _pendingPath = path.startsWith('/chats/') ? null : uri.toString();
      return '/login';
    }

    // 4. Guests may browse the public screens (Jobs, Job details, ...).
    if (auth.isGuest) return null;

    // 5. Logged out and not a guest: start at Login.
    return '/login';
  }

  /// Opens [path], a screen that needs an account. Guests and logged-out
  /// users get the Login Required popup instead, so the screen (and its API
  /// calls) never opens.
  static void openProtected(
    BuildContext context,
    String path, {
    String message = 'Please login to continue.',
  }) {
    final auth = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(authProvider);
    if (isSignedIn(auth)) {
      context.push(path);
      return;
    }
    showAuthPromptDialog(context, title: 'Login Required', message: message);
  }

  /// Where to go after a successful login: the screen the user originally
  /// wanted, or Home. Clears the remembered screen.
  static String takePendingPath() {
    final path = _pendingPath;
    _pendingPath = null;
    return path ?? '/home';
  }
}
