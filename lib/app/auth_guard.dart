import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/local_storage.dart';

/// Keeps logged-out users away from screens that only work when signed in.
///
/// Used as the global `redirect` of [GoRouter]. If a logged-out user opens a
/// protected screen (by a link, a deep link or a leftover button), they are
/// sent to /login. The screen they wanted is remembered, and after a
/// successful login [takePendingPath] sends them back to it.
///
/// "Signed in" means a login token is saved on the device. When the server
/// rejects an expired token (HTTP 401), ApiClient clears it, so the next
/// navigation to a protected screen goes to login.
class AuthGuard {
  AuthGuard._();

  /// Screens (and everything under them) that require a login.
  static const List<String> _protectedRoots = [
    '/my-applications',
    '/applications',
    '/interviews',
    '/network',
    '/apply-expert',
    '/settings',
    '/wallet',
  ];

  static String? _pendingPath;

  static bool get isSignedIn {
    final token = LocalStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  static bool isProtected(String path) {
    if (path.startsWith('/chats/')) return true; // a single chat conversation
    return _protectedRoots.any(
      (root) => path == root || path.startsWith('$root/'),
    );
  }

  /// GoRouter redirect: returns '/login' for protected screens when logged
  /// out, otherwise null (no redirect).
  static String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    if (isSignedIn || !isProtected(path)) return null;

    // A chat screen needs extra data (who to chat with) that is lost on a
    // redirect, so after login those users go Home instead.
    _pendingPath = path.startsWith('/chats/') ? null : state.uri.toString();
    return '/login';
  }

  /// Where to go after a successful login: the screen the user originally
  /// wanted, or Home. Clears the remembered screen.
  static String takePendingPath() {
    final path = _pendingPath;
    _pendingPath = null;
    return path ?? '/home';
  }
}
