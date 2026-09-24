import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_logo.dart';

/// Shown while the saved login session is checked at app start. It does not
/// navigate by itself: the router (AuthGuard.redirect) leaves Splash for Home
/// or Login as soon as the check in authProvider finishes.
///
/// The entrance animation is purely visual. It runs once, needs no
/// AnimationController and never delays or controls leaving Splash.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Length of the one-time entrance (shorter than the minimum Splash time,
  /// so it always finishes before the app moves on).
  static const Duration _entranceDuration = Duration(milliseconds: 900);

  /// Progress of one part of the entrance: 0 before [begin], 1 after [end].
  static double _stage(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    // Respect the phone's "remove animations" accessibility setting.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // Only scrolls if the content is taller than the screen (very
            // small phones or very large font settings); otherwise centred.
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: reduceMotion ? Duration.zero : _entranceDuration,
                    builder: (context, t, _) {
                      // Logo first, then tagline, then the loader.
                      final logo = Curves.easeOutCubic.transform(
                        _stage(t, 0.0, 0.7),
                      );
                      final tagline = Curves.easeOutCubic.transform(
                        _stage(t, 0.3, 0.9),
                      );
                      final loader = Curves.easeOut.transform(
                        _stage(t, 0.55, 1.0),
                      );

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo: fade in with a subtle scale-up (0.92 -> 1).
                          Opacity(
                            opacity: logo,
                            child: Transform.scale(
                              scale: 0.92 + 0.08 * logo,
                              // Shrinks only if the phone is too narrow.
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AppBrandBarLogo(
                                  iconHeight: 64,
                                  textHeight: 36,
                                  spacing: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Tagline: fade in while rising 8 px.
                          Opacity(
                            opacity: tagline,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - tagline)),
                              child: Text(
                                'Kaam Bhi. Skill Bhi. Kamaai Bhi.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Loader: fades in last.
                          Opacity(
                            opacity: loader,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
