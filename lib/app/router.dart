import 'package:go_router/go_router.dart';

import '../features/applications/presentation/my_applications_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/navigation/presentation/main_navigation_shell.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

/// Central GoRouter configuration for the KaamMilega app
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra as String?;
          return OtpScreen(phone: phone ?? '');
        },
      ),
      GoRoute(
        path: '/jobs',
        name: 'jobs',
        builder: (context, state) => const MainNavigationShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/jobs/:id',
        name: 'job_detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return JobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '/my-applications',
        name: 'my_applications',
        builder: (context, state) => const MyApplicationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/jobs',
      ),
    ],
  );
}
