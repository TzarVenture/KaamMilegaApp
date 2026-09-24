import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/offline_banner.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class KaamMilegaApp extends ConsumerWidget {
  const KaamMilegaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'KaamMilega',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return OfflineBannerOverlay(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
