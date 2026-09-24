import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/network/app_exception.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';

/// Login error handling: maps the real km-backend auth errors
/// (see controller.go / service.go in km-backend) to user messages.
void main() {
  group('OTP verify errors (POST /auth/otp/verify)', () {
    test('wrong code (400 "Invalid OTP") -> incorrect OTP message', () {
      expect(
        AuthNotifier.otpErrorMessage(
          const AppValidationException('Invalid OTP'),
        ),
        'Incorrect OTP. Please try again.',
      );
    });

    test('expired or used code (400) -> expired message with resend hint', () {
      final msg = AuthNotifier.otpErrorMessage(
        const AppValidationException('OTP not found or expired'),
      );
      expect(msg, contains('expired'));
      expect(msg, contains('Resend'));
    });

    test('role mismatch keeps the backend explanation', () {
      expect(
        AuthNotifier.otpErrorMessage(
          const AppValidationException(
            'this mobile number is already registered as a recruiter',
          ),
        ),
        'this mobile number is already registered as a recruiter',
      );
    });

    test('unknown 400 text is not shown raw', () {
      expect(
        AuthNotifier.otpErrorMessage(
          const AppValidationException('mongo: connection pool closed'),
        ),
        'Could not verify OTP. Please try again.',
      );
    });

    test('no internet -> network message (not a registration case)', () {
      expect(
        AuthNotifier.otpErrorMessage(const AppNetworkException()),
        const AppNetworkException().message,
      );
    });
  });

  group('Password login errors (POST /auth/login/password)', () {
    test('wrong password or unknown email (401) -> incorrect message', () {
      expect(
        AuthNotifier.passwordLoginErrorMessage(
          const AppAuthException('invalid email or password', 401),
        ),
        'Incorrect email or password. Please try again.',
      );
    });

    test('account without password keeps the backend hint to use OTP', () {
      const text =
          "No password has been set for this account. Please use the "
          "'Login with OTP' tab above to sign in.";
      expect(
        AuthNotifier.passwordLoginErrorMessage(
          const AppAuthException(text, 401),
        ),
        text,
      );
    });

    test('unknown auth text is not shown raw', () {
      expect(
        AuthNotifier.passwordLoginErrorMessage(
          const AppAuthException('crypto/bcrypt: hashedSecret too short', 401),
        ),
        'Login failed. Please try again.',
      );
    });

    test('server down -> app server message', () {
      expect(
        AuthNotifier.passwordLoginErrorMessage(const AppServerException()),
        const AppServerException().message,
      );
    });
  });
}
