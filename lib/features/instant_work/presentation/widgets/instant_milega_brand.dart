import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

/// The Instant Milega logo on its orange header, laid out like the
/// KaamMilega logo on the other pages: the full-colour "IM" runner mark on
/// a white tile, then the wordmark in white with "milega" in warm cream so
/// it reads clearly on orange. Tap: Home.
class InstantMilegaBrand extends StatelessWidget {
  const InstantMilegaBrand({super.key});

  static const String markAsset = 'assets/images/instant_milega_mark.webp';
  static const String wordmarkAsset =
      'assets/images/instant_milega_text_light.webp';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Instant Milega. Go to Home',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.go('/home'),
        child: Align(
          alignment: Alignment.centerLeft,
          // Shrinks on very narrow phones instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    markAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 10),
                Image.asset(
                  wordmarkAsset,
                  height: 21,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
