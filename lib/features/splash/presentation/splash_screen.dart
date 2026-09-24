import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_logo.dart';

/// Shown while the saved login session is checked at app start. It does not
/// navigate by itself: the router (AuthGuard.redirect) leaves Splash for Home
/// or Login as soon as the check in authProvider finishes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppBrandBarLogo(iconHeight: 64, textHeight: 36, spacing: 14),
            const SizedBox(height: 8),
            Text(
              'Kaam Bhi. Skill Bhi. Kamaai Bhi.',
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
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
