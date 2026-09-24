import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/features/auth/presentation/login_screen.dart';
import 'package:kaam_milega/features/auth/presentation/otp_screen.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';

/// Fake auth that never touches the network: every OTP is "wrong".
class _WrongOtpAuth extends AuthNotifier {
  int verifyCalls = 0;

  @override
  AuthState build() => const AuthState();

  @override
  Future<AuthVerificationResult?> verifyOtp(String mobile, String code) async {
    verifyCalls++;
    state = state.copyWith(error: 'Incorrect OTP. Please try again.');
    return null;
  }
}

/// Batch 5 (Login / OTP / Register UI): new look, same auth behaviour.
void main() {
  Widget app(Widget screen, AuthNotifier Function() createAuth) =>
      ProviderScope(
        overrides: [authProvider.overrideWith(createAuth)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
      );

  testWidgets('wrong OTP: stays on OTP screen, shows inline error, clears '
      'boxes', (tester) async {
    final fake = _WrongOtpAuth();
    await tester.pumpWidget(
      app(const OtpScreen(phone: '9876543210'), () => fake),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 600));

    expect(fake.verifyCalls, 1);
    expect(find.byType(OtpScreen), findsOneWidget); // no navigation
    expect(
      find.text('Incorrect OTP. Please try again.'),
      findsAtLeastNWidgets(1),
    );
    for (var i = 0; i < 4; i++) {
      expect(tester.widget<TextField>(boxes.at(i)).controller!.text, isEmpty);
    }

    // Let the error snackbar finish so no timers are left running.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('OTP screen fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(const OtpScreen(phone: '9876543210'), _WrongOtpAuth.new),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login tabs switch between password and OTP forms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const LoginScreen(), _WrongOtpAuth.new));
    await tester.pumpAndSettle();
    expect(find.text('Sign In With Password'), findsOneWidget);
    expect(find.text('Explore Jobs as Guest ↗'), findsOneWidget);

    await tester.tap(find.text('Login with OTP').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign In With OTP'), findsOneWidget);
    expect(find.text('Send OTP & Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
