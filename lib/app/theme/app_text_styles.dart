import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand font families (bundled in `assets/fonts`, see pubspec.yaml).
///
/// - Poppins: primary consumer font (400 body, 500 labels, 600 buttons and
///   H3, 700 headings, 800 hero).
/// - Inter: secondary font for form fields, captions / meta text,
///   transaction ledgers and analytics.
/// - Noto Sans Devanagari: Hindi text (fallback everywhere) and the Hindi
///   brand tagline.
class AppFonts {
  AppFonts._();

  static const String primary = 'Poppins';
  static const String secondary = 'Inter';
  static const String hindi = 'NotoSansDevanagari';
  static const List<String> fallback = [hindi];
}

/// KaamMilega™ type scale (brand specification, 26 Sep 2026).
/// Letter spacing is the spec's em value times the font size.
class AppTextStyles {
  AppTextStyles._();

  /// Display Hero: Poppins 800, line height 1.15, -0.025em.
  static const TextStyle displayXl = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -1.2,
  );

  /// Heading 1: Poppins 700, line height 1.25, -0.02em.
  static const TextStyle displayLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.64,
  );

  /// Heading 2 (large): Poppins 700, line height 1.3, -0.015em.
  static const TextStyle headingXl = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.42,
  );

  /// Heading 2: Poppins 700, line height 1.3, -0.015em.
  static const TextStyle headingLg = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.36,
  );

  /// Heading 3: Poppins 600, line height 1.35, -0.01em.
  static const TextStyle headingMd = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: -0.18,
  );

  /// Body Regular (16): Poppins 400, line height 1.5.
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Body Regular (14): Poppins 400, line height 1.5.
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Body Bold: Poppins 600, line height 1.5.
  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Caption / Meta: Inter 500, line height 1.4, +0.01em.
  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.secondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.12,
  );

  /// Micro Chip: Poppins 700, line height 1.2, +0.05em (use with CAPS).
  static const TextStyle micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    height: 1.2,
    letterSpacing: 0.5,
  );

  /// Hindi tagline ("हर काम, हर मौका"): Noto Sans Devanagari 600, line
  /// height 1.4, +0.01em.
  static const TextStyle taglineHindi = TextStyle(
    fontFamily: AppFonts.hindi,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.brandNavy,
    height: 1.4,
    letterSpacing: 0.16,
  );

  /// Form field input text: Inter 400.
  static const TextStyle input = TextStyle(
    fontFamily: AppFonts.secondary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // -------------------------------------------------------------------
  // Backward-Compatible Aliases
  // -------------------------------------------------------------------
  static const TextStyle heading1 = headingXl;
  static const TextStyle heading2 = headingLg;
  static const TextStyle heading3 = headingMd;
  static const TextStyle body = bodyLg;
  static const TextStyle bodySecondary = bodyMd;
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
  static const TextStyle caption = label;
}
