import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/offline_banner.dart';
import '../features/notifications/presentation/in_app_notification_host.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/mobile_design_spec.dart';

class KaamMilegaApp extends ConsumerWidget {
  const KaamMilegaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'KaamMilega',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.appTheme,
      routerConfig: router,
      builder: (context, child) {
        final app = OfflineBannerOverlay(
          // Live notifications: connection, unread badge and top banner.
          child: InAppNotificationHost(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        );
        if (!kMobileDesignSpec) return app;
        // Mobile spec 3.4: light screens have dark status bar icons and a
        // white Android navigation bar. Screens with their own app bar or
        // a navy header set their own style on top of this.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: app,
        );
      },
    );
  }
}
