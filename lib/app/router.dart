import 'package:go_router/go_router.dart';

import '../features/applications/presentation/my_applications_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/chat/presentation/chat_detail_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/company/presentation/company_screen.dart';
import '../features/events/presentation/events_screen.dart';
import '../features/interviews/presentation/interviews_screen.dart';
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
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainNavigationShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/feed',
        name: 'feed',
        builder: (context, state) => const MainNavigationShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/jobs',
        name: 'jobs',
        builder: (context, state) => const MainNavigationShell(initialIndex: 4),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const MainNavigationShell(initialIndex: 3),
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/company/:id',
        name: 'company_detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CompanyScreen(companyId: id);
        },
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
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
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
        path: '/interviews',
        name: 'interviews',
        builder: (context, state) => const InterviewsScreen(),
      ),
      GoRoute(
        path: '/network',
        name: 'network',
        builder: (context, state) => const MainNavigationShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/chats',
        name: 'chats',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chats/:id',
        name: 'chat_detail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extraMap = state.extra as Map<String, String>?;
          final receiverId = extraMap?['receiverId'] ?? id;
          final title = extraMap?['title'] ?? 'Chat';
          return ChatDetailScreen(
            conversationId: id,
            receiverId: receiverId,
            title: title,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}
