import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    await LocalStorage.init();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        final token = LocalStorage.getToken();
        if (token != null && token.isNotEmpty) {
          context.go('/jobs');
        } else {
          context.go('/jobs'); // Allow guest browsing jobs directly, just like website
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 100),
            const SizedBox(height: 24),
            const Text(
              'KaamMilega',
              style: AppTextStyles.heading1,
            ),
            const SizedBox(height: 8),
            Text(
              'Kaam Bhi, Kamai Bhi',
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
