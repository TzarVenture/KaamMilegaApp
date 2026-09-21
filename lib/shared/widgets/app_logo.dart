import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Official KaamMilega™ Logo Widget
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 80, this.showText = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(
            'assets/images/logo_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(size * 0.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'KM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: size * 0.4,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Image.asset(
            'assets/images/logo_text.png',
            height: size * 0.3,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Kaammi',
                    style: TextStyle(color: AppColors.brandBlue),
                  ),
                  TextSpan(
                    text: 'lega™',
                    style: TextStyle(color: AppColors.brandOrange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Combined Brand Logo widget displaying the icon and the Kaammilega™ wordmark side-by-side
class AppBrandBarLogo extends StatelessWidget {
  final double iconHeight;
  final double textHeight;
  final double spacing;
  final VoidCallback? onTap;

  const AppBrandBarLogo({
    super.key,
    this.iconHeight = 28,
    this.textHeight = 17,
    this.spacing = 8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          height: iconHeight,
          fit: BoxFit.contain,
        ),
        SizedBox(width: spacing),
        Image.asset(
          'assets/images/logo_text.png',
          height: textHeight,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: 'Kaammi',
                  style: TextStyle(color: AppColors.brandBlue),
                ),
                TextSpan(
                  text: 'lega™',
                  style: TextStyle(color: AppColors.brandOrange),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}
