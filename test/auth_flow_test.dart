import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/auth_guard.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Startup / login / logout / guest routing rules (AuthGuard.redirect).
void main() {
  const checking = AuthState(isChecking: true);
  const loggedOut = AuthState();
  const guest = AuthState(isGuest: true);
  const signedIn = AuthState(isAuthenticated: true);

  String? go(AuthState auth, String path) =>
      AuthGuard.redirect(auth, Uri.parse(path));

  Future<void> setToken(String? token) async {
    SharedPreferences.setMockInitialValues(
      token == null ? {} : {'km_auth_token': token},
    );
    LocalStorage.setMockInstance(await SharedPreferences.getInstance());
  }

  setUp(() async {
    await setToken(null);
    AuthGuard.takePendingPath(); // clear any remembered screen
  });

  group('While the session is being checked', () {
    test('stays on Splash', () {
      expect(go(checking, '/splash'), isNull);
    });

    test('never shows Home or any other screen (no Home flash)', () {
      expect(go(checking, '/home'), '/splash');
      expect(go(checking, '/jobs'), '/splash');
      expect(go(checking, '/login'), '/splash');
    });
  });

  group('Minimum Splash time', () {
    test('Splash stays until its minimum time has passed', () async {
      expect(go(loggedOut, '/splash'), '/login'); // time passed (default)
      expect(
        AuthGuard.redirect(
          loggedOut,
          Uri.parse('/splash'),
          splashTimeDone: false,
        ),
        isNull,
      );
      await setToken('valid-token');
      expect(
        AuthGuard.redirect(
          signedIn,
          Uri.parse('/splash'),
          splashTimeDone: false,
        ),
        isNull,
      );
    });
  });

  group('Logged out (not a guest)', () {
    test('Splash goes to Login', () {
      expect(go(loggedOut, '/splash'), '/login');
    });

    test('Home and other screens go to Login', () {
      expect(go(loggedOut, '/home'), '/login');
      expect(go(loggedOut, '/jobs'), '/login');
      expect(go(loggedOut, '/profile'), '/login');
      expect(go(loggedOut, '/wallet'), '/login');
    });

    test('sign-in screens stay open', () {
      expect(go(loggedOut, '/login'), isNull);
      expect(go(loggedOut, '/register'), isNull);
      expect(go(loggedOut, '/otp'), isNull);
      expect(go(loggedOut, '/forgot-password'), isNull);
    });
  });

  group('Signed in', () {
    setUp(() => setToken('valid-token'));

    test('Splash goes to Home', () {
      expect(go(signedIn, '/splash'), '/home');
    });

    test('Home and account screens are open', () {
      expect(go(signedIn, '/home'), isNull);
      expect(go(signedIn, '/wallet'), isNull);
      expect(go(signedIn, '/my-applications'), isNull);
    });

    test('expired token (cleared after HTTP 401) goes to Login', () async {
      await setToken(null);
      expect(go(signedIn, '/home'), '/login');
      expect(go(signedIn, '/splash'), '/login');
    });
  });

  group('Guest (Explore Jobs as Guest)', () {
    test('can browse Jobs and Job details', () {
      expect(go(guest, '/jobs'), isNull);
      expect(go(guest, '/jobs/abc123'), isNull);
      expect(go(guest, '/home'), isNull);
    });

    test('account-only screens go to Login', () {
      expect(go(guest, '/wallet'), '/login');
      expect(go(guest, '/wallet/add-money'), '/login');
      expect(go(guest, '/my-applications'), '/login');
      expect(go(guest, '/settings'), '/login');
    });

    test('is not treated as signed in', () {
      expect(AuthGuard.isSignedIn(guest), isFalse);
    });

    test('after login returns to the protected screen that was asked for', () {
      expect(go(guest, '/wallet'), '/login');
      expect(AuthGuard.takePendingPath(), '/wallet');
      expect(AuthGuard.takePendingPath(), '/home');
    });
  });

  test('a new AuthState is not in guest mode or checking by default', () {
    expect(loggedOut.isGuest, isFalse);
    expect(loggedOut.isChecking, isFalse);
  });
}
