import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_guard.dart';
import '../features/auth/providers/auth_provider.dart';

import '../features/applications/presentation/application_detail_screen.dart';
import '../features/applications/presentation/my_applications_screen.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/chat/presentation/chat_detail_screen.dart';
import '../features/company/presentation/company_screen.dart';
import '../features/events/presentation/events_screen.dart';
import '../features/experts/presentation/apply_expert_screen.dart';
import '../features/experts/presentation/my_sessions_screen.dart';
import '../features/interviews/presentation/interviews_screen.dart';
import '../features/jobs/models/job.dart';
import '../features/jobs/presentation/job_detail_screen.dart';
import '../features/jobs/presentation/saved_jobs_screen.dart';
import '../features/navigation/presentation/main_navigation_shell.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';

import '../features/feed/presentation/feed_screen.dart';
import '../features/network/presentation/network_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/wallet/presentation/wallet_add_money_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../features/wallet/presentation/wallet_transactions_screen.dart';
import '../features/wallet/presentation/wallet_transfer_screen.dart';
import '../features/wallet/presentation/wallet_withdraw_screen.dart';

import '../features/explore/presentation/explore_screen.dart';
import '../features/instant_work/presentation/instant_work_screen.dart';
import '../features/skills_marketplace/presentation/skills_marketplace_screen.dart';
import '../features/experts/presentation/experts_screen.dart';
import '../features/services/presentation/services_marketplace_screen.dart';
import '../features/peer_to_peer/presentation/peer_to_peer_screen.dart';

/// Shortest time the Splash (brand) screen stays visible at app start.
/// It only delays leaving Splash; Home vs Login is still decided by the
/// session check in [authProvider].
const Duration kMinSplashDuration = Duration(milliseconds: 1500);

/// Central GoRouter for the KaamMilega app.
///
/// Starts on Splash. The redirect ([AuthGuard.redirect]) reads the existing
/// [authProvider] state and runs again whenever the startup check finishes,
/// the minimum Splash time has passed, the user logs in or out, or enters
/// guest mode.
final routerProvider = Provider<GoRouter>((ref) {
  // Only the fields that decide the screen trigger a router refresh.
  (bool, bool, bool, bool) routeKey(AuthState s) =>
      (s.isChecking, s.isAuthenticated, s.isGuest, s.needsProfileCompletion);

  final authChanges = ValueNotifier(routeKey(ref.read(authProvider)));
  ref.listen(
    authProvider.select(routeKey),
    (_, next) => authChanges.value = next,
  );

  // Keeps Splash on screen for at least kMinSplashDuration, even when the
  // session check finishes instantly (for example, no saved login).
  final splashTimeDone = ValueNotifier(false);
  final splashTimer = Timer(
    kMinSplashDuration,
    () => splashTimeDone.value = true,
  );

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([authChanges, splashTimeDone]),
    redirect: (context, state) => AuthGuard.redirect(
      ref.read(authProvider),
      state.uri,
      splashTimeDone: splashTimeDone.value,
    ),
    routes: AppRouter.routes,
  );

  ref.onDispose(() {
    splashTimer.cancel();
    router.dispose();
    authChanges.dispose();
    splashTimeDone.dispose();
  });
  return router;
});

/// Route table for the KaamMilega app
class AppRouter {
  AppRouter._();

  static final List<RouteBase> routes = [
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
      builder: (context, state) => const FeedScreen(),
    ),
    GoRoute(
      path: '/jobs',
      name: 'jobs',
      builder: (context, state) => const MainNavigationShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
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
      path: '/forgot-password',
      name: 'forgot_password',
      builder: (context, state) {
        final email = state.extra as String?;
        return ForgotPasswordScreen(initialEmail: email);
      },
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
      path: AuthGuard.completeProfilePath,
      name: 'complete_profile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: '/jobs/:id',
      name: 'job_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final job = state.extra is Job ? state.extra as Job : null;
        return JobDetailScreen(jobId: id, initialJob: job);
      },
    ),
    GoRoute(
      path: '/saved-jobs',
      name: 'saved_jobs',
      builder: (context, state) => const SavedJobsScreen(),
    ),
    GoRoute(
      path: '/my-applications',
      name: 'my_applications',
      builder: (context, state) => const MyApplicationsScreen(),
    ),
    GoRoute(
      path: '/applications/:id',
      name: 'application_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ApplicationDetailScreen(applicationId: id);
      },
    ),
    GoRoute(
      path: '/my-sessions',
      name: 'my_sessions',
      builder: (context, state) => const MySessionsScreen(),
    ),
    GoRoute(
      path: '/interviews',
      name: 'interviews',
      builder: (context, state) => const InterviewsScreen(),
    ),
    GoRoute(
      path: '/network',
      name: 'network',
      builder: (context, state) => const NetworkScreen(),
    ),
    GoRoute(
      path: '/chats',
      name: 'chats',
      builder: (context, state) => const MainNavigationShell(initialIndex: 3),
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
      path: '/apply-expert',
      name: 'apply_expert',
      builder: (context, state) => const ApplyExpertScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const MainNavigationShell(initialIndex: 4),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/wallet',
      name: 'wallet',
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/wallet/transactions',
      name: 'wallet_transactions',
      builder: (context, state) => const WalletTransactionsScreen(),
    ),
    GoRoute(
      path: '/wallet/add-money',
      name: 'wallet_add_money',
      builder: (context, state) => const WalletAddMoneyScreen(),
    ),
    GoRoute(
      path: '/wallet/withdraw',
      name: 'wallet_withdraw',
      builder: (context, state) => const WalletWithdrawScreen(),
    ),
    GoRoute(
      path: '/wallet/transfer',
      name: 'wallet_transfer',
      builder: (context, state) => const WalletTransferScreen(),
    ),
    GoRoute(
      path: '/explore',
      name: 'explore',
      builder: (context, state) => const ExploreScreen(),
    ),
    GoRoute(
      path: '/instant-work',
      name: 'instant_work',
      builder: (context, state) => const InstantWorkScreen(),
    ),
    GoRoute(
      path: '/skills-marketplace',
      name: 'skills_marketplace',
      builder: (context, state) => const SkillsMarketplaceScreen(),
    ),
    GoRoute(
      path: '/experts',
      name: 'experts',
      builder: (context, state) => const ExpertsScreen(),
    ),
    GoRoute(
      path: '/services',
      name: 'services_marketplace',
      builder: (context, state) => const ServicesMarketplaceScreen(),
    ),
    GoRoute(
      path: '/peer-to-peer',
      name: 'peer_to_peer',
      builder: (context, state) => const PeerToPeerScreen(),
    ),
  ];
}
