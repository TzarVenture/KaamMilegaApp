import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaam_milega/app/theme/app_theme.dart';
import 'package:kaam_milega/features/auth/models/user_profile.dart';
import 'package:kaam_milega/features/auth/presentation/complete_profile_screen.dart';
import 'package:kaam_milega/features/auth/providers/auth_provider.dart';
import 'package:kaam_milega/features/auth/repositories/auth_repository.dart';
import 'package:kaam_milega/features/cities/models/city.dart';
import 'package:kaam_milega/features/cities/repositories/city_repository.dart';

/// Signed-in account that is not registered yet. Never touches the network.
class _UnregisteredAuth extends AuthNotifier {
  _UnregisteredAuth({this.email = '', this.emailVerified = false});

  final String email;
  final bool emailVerified;
  int completeCalls = 0;
  int logoutCalls = 0;
  Map<String, Object?>? lastArgs;

  @override
  AuthState build() => AuthState(
    isAuthenticated: true,
    user: UserProfile(
      id: 'u1',
      mobile: '9876543210',
      email: email,
      isEmailVerified: emailVerified,
    ),
  );

  @override
  Future<bool> completeRegistration({
    required String name,
    required String gender,
    required String educationLevel,
    required String workExperience,
    required String city,
    required List<String> jobCategories,
    required String experienceDetail,
  }) async {
    completeCalls++;
    lastArgs = {
      'name': name,
      'gender': gender,
      'education_level': educationLevel,
      'work_experience': workExperience,
      'city': city,
      'job_categories': jobCategories,
      'experience_detail': experienceDetail,
    };
    state = state.copyWith(
      user: state.user!.copyWith(isRegistered: true, name: name),
    );
    return true;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthState();
  }
}

void main() {
  Widget app(_UnregisteredAuth auth) {
    final router = GoRouter(
      initialLocation: '/complete-profile',
      routes: [
        GoRoute(
          path: '/complete-profile',
          builder: (_, _) => const CompleteProfileScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN SCREEN')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME SCREEN')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => auth),
        citiesFutureProvider.overrideWith(
          (ref) async => const [City(id: 'c1', name: 'Pune')],
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('POST /user/register body uses exactly the backend RegisterRequest '
      'fields and keeps the account email', () {
    final body = AuthRepository.registerRequestBody(
      name: '  Ravi Kumar ',
      gender: 'Male',
      educationLevel: 'Graduate',
      workExperience: 'I am a Fresher',
      city: 'Pune',
      jobCategories: const ['Security Guard'],
      experienceDetail: 'Fresher',
      email: 'ravi@example.com',
      isEmailVerified: true,
    );
    expect(body.keys.toSet(), {
      'roles',
      'name',
      'gender',
      'education_level',
      'work_experience',
      'city',
      'job_categories',
      'experience_detail',
      'email',
      'is_email_verified',
    });
    expect(body['roles'], ['user']);
    expect(body['name'], 'Ravi Kumar');
    expect(body['email'], 'ravi@example.com');
    expect(body['is_email_verified'], isTrue);
  });

  testWidgets('empty form is not submitted', (tester) async {
    await useTallScreen(tester);
    final auth = _UnregisteredAuth();
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    await tapText(tester, 'Complete registration');
    expect(auth.completeCalls, 0);
    expect(find.text('Please enter your full name.'), findsOneWidget);
  });

  testWidgets('filled form completes the same account and leaves the screen', (
    tester,
  ) async {
    await useTallScreen(tester);
    final auth = _UnregisteredAuth();
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ravi Kumar');
    await tapText(tester, 'Male');
    await tapText(tester, 'Graduate');
    await tapText(tester, 'I am a Fresher');
    await tapText(tester, 'Select your city');
    await tapText(tester, 'Pune');
    await tapText(tester, 'Security Guard');
    await tapText(tester, '1 Year');
    await tapText(tester, 'Complete registration');

    expect(auth.completeCalls, 1);
    expect(auth.lastArgs, {
      'name': 'Ravi Kumar',
      'gender': 'Male',
      'education_level': 'Graduate',
      'work_experience': 'I am a Fresher',
      'city': 'Pune',
      'job_categories': ['Security Guard'],
      'experience_detail': '1 Year',
    });
    expect(find.text('HOME SCREEN'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar finish
  });

  testWidgets('Back asks first, then signs out and returns to Login', (
    tester,
  ) async {
    await useTallScreen(tester);
    final auth = _UnregisteredAuth();
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel registration?'), findsOneWidget);

    // "Stay" keeps the user on the screen, still signed in.
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 0);
    expect(find.byType(CompleteProfileScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel registration').last);
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 1);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });

  testWidgets('"Use a different account" signs out and returns to Login', (
    tester,
  ) async {
    await useTallScreen(tester);
    final auth = _UnregisteredAuth();
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();

    await tapText(tester, 'Use a different account');
    expect(find.text('Use a different account?'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 1);
    expect(find.text('LOGIN SCREEN'), findsOneWidget);
  });

  testWidgets('shows the account email read-only', (tester) async {
    await useTallScreen(tester);
    final auth = _UnregisteredAuth(
      email: 'ravi@example.com',
      emailVerified: true,
    );
    await tester.pumpWidget(app(auth));
    await tester.pumpAndSettle();
    expect(find.text('ravi@example.com (verified)'), findsOneWidget);
  });
}
