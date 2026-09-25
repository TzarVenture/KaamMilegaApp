import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/auth_guard.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
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
      // People search + connections use account-only APIs
      expect(go(guest, '/peer-to-peer'), '/login');
      expect(go(loggedOut, '/peer-to-peer'), '/login');
      // Booked mentorship sessions are account-only
      expect(go(guest, '/my-sessions'), '/login');
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

  group('Signed in, registration not completed (new phone / email user)', () {
    final unregistered = AuthState(
      isAuthenticated: true,
      user: UserProfile(id: 'u1', mobile: '9876543210'),
    );
    final registered = AuthState(
      isAuthenticated: true,
      user: UserProfile(id: 'u2', mobile: '9876543211', isRegistered: true),
    );
    // Older accounts: no is_registered flag but a completed profile
    // (same rule as the KaamMilega website).
    final legacyComplete = AuthState(
      isAuthenticated: true,
      user: UserProfile(
        id: 'u3',
        mobile: '9876543212',
        educationLevel: 'Graduate',
        city: 'Pune',
      ),
    );

    setUp(() => setToken('valid-token'));

    test('needsProfileCompletion only for signed-in unregistered users', () {
      expect(unregistered.needsProfileCompletion, isTrue);
      expect(registered.needsProfileCompletion, isFalse);
      expect(legacyComplete.needsProfileCompletion, isFalse);
      // Profile not loaded yet: unknown, never forced.
      expect(signedIn.needsProfileCompletion, isFalse);
      expect(loggedOut.needsProfileCompletion, isFalse);
      expect(guest.needsProfileCompletion, isFalse);
    });

    test('Splash goes to Complete Profile', () {
      expect(go(unregistered, '/splash'), '/complete-profile');
    });

    test('every other screen goes to Complete Profile', () {
      expect(go(unregistered, '/home'), '/complete-profile');
      expect(go(unregistered, '/jobs'), '/complete-profile');
      expect(go(unregistered, '/wallet'), '/complete-profile');
      expect(go(unregistered, '/login'), '/complete-profile');
      expect(go(unregistered, '/register'), '/complete-profile');
      expect(go(unregistered, '/otp'), '/complete-profile');
    });

    test('Complete Profile itself stays open (no redirect loop)', () {
      expect(go(unregistered, '/complete-profile'), isNull);
    });

    test('registered users keep the normal signed-in behaviour', () {
      expect(go(registered, '/splash'), '/home');
      expect(go(registered, '/home'), isNull);
      expect(go(registered, '/otp'), isNull);
      expect(go(legacyComplete, '/splash'), '/home');
      expect(go(legacyComplete, '/home'), isNull);
    });

    test(
      'Complete Profile is closed once registered, and when signed out',
      () async {
        expect(go(registered, '/complete-profile'), '/home');
        await setToken(null);
        expect(go(unregistered, '/complete-profile'), '/login');
        expect(go(loggedOut, '/complete-profile'), '/login');
        expect(go(guest, '/complete-profile'), '/login');
      },
    );

    test(
      'after registration continues to the screen asked for before login',
      () {
        expect(go(guest, '/wallet'), '/login');
        expect(go(registered, '/complete-profile'), '/wallet');
        expect(AuthGuard.takePendingPath(), '/wallet');
      },
    );

    test('expired token (cleared after HTTP 401) goes to Login', () async {
      await setToken(null);
      expect(go(unregistered, '/home'), '/login');
      expect(go(unregistered, '/splash'), '/login');
    });
  });

  test('a new AuthState is not in guest mode or checking by default', () {
    expect(loggedOut.isGuest, isFalse);
    expect(loggedOut.isChecking, isFalse);
  });
}
