import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/auth_guard.dart';
import 'package:kaam_milega/core/constants/api_constants.dart';
import 'package:kaam_milega/core/storage/local_storage.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile > More: share link format and who may open More Actions.
void main() {
  test('public profile link matches the website route /profile/<id>', () {
    expect(
      ApiConstants.publicProfileUrl('66f1a2b3c4d5e6f7a8b9c0d1'),
      'https://kaammilega.com/profile/66f1a2b3c4d5e6f7a8b9c0d1',
    );
  });

  group('More Actions access', () {
    Future<void> setToken(String? token) async {
      SharedPreferences.setMockInitialValues(
        token == null ? {} : {'km_auth_token': token},
      );
      LocalStorage.setMockInstance(await SharedPreferences.getInstance());
    }

    test('guest cannot open More Actions', () async {
      await setToken(null);
      expect(AuthGuard.isSignedIn(const AuthState(isGuest: true)), isFalse);
    });

    test('signed-in user can open More Actions', () async {
      await setToken('valid-token');
      expect(
        AuthGuard.isSignedIn(const AuthState(isAuthenticated: true)),
        isTrue,
      );
    });
  });
}
