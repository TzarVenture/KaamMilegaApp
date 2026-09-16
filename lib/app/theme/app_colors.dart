import 'package:flutter/material.dart';

/// Single Source of Truth for KaamMilega™ UI/UX Design System Colors
/// Matches official Brand Identity guide (Brand Blue #1A2B8C & Accent Orange #F97316)
class AppColors {
  AppColors._();

  // -------------------------------------------------------------------
  // 1. PRIMARY BRAND COLORS
  // -------------------------------------------------------------------
  static const Color brandBlue = Color(0xFF1A2B8C); // Primary Brand Blue
  static const Color brandOrange = Color(0xFFF97316); // Accent Brand Orange
  static const Color deepNavy = Color(0xFF0D1B5E); // Dark Navy Backgrounds
  static const Color pureWhite = Color(0xFFFFFFFF);

  // -------------------------------------------------------------------
  // 2. SEMANTIC COLOR SYSTEM TOKENS (Easily Configurable)
  // -------------------------------------------------------------------
  static const Color primary = brandBlue; // All primary interactive elements
  static const Color primaryLight = Color(0xFFEFF6FF); // Blue-50 background
  static const Color primaryDark = deepNavy; // Deep Navy hover/header
  static const Color primaryGradientStart = Color(0xFF1A2B8C);
  static const Color primaryGradientEnd = Color(0xFF0D1B5E);

  static const Color accent = brandOrange; // Highlights, CTAs, InstantMilega
  static const Color accentDark = Color(0xFFEA580C);
  static const Color accentLight = Color(0xFFFFF7ED); // Orange-50

  // Header tokens
  static const Color deepPurpleHeader = deepNavy; // Deep Navy top navbar/header
  static const Color heroBg = deepNavy;
  static const Color heroAccent = brandOrange;
  static const Color heroButton = brandOrange;
  static const Color heroButtonHover = Color(0xFFEA580C);
  static const Color tickerBg = Color(0xFFEFF6FF);
  static const Color tickerBorder = Color(0xFFDBEAFE);
  static const Color cardLightBg = Color(0xFFF8FAFC);

  // -------------------------------------------------------------------
  // 3. PER-MODULE COLOR CODING VARIABLES
  // -------------------------------------------------------------------
  static const Color moduleJobs = Color(0xFF1A2B8C); // Brand Blue
  static const Color moduleInstantWork = Color(0xFFF97316); // Orange
  static const Color moduleSkills = Color(0xFF16A34A); // Green
  static const Color moduleExperts = Color(0xFF7C3AED); // Purple
  static const Color moduleServices = Color(0xFFEC4899); // Pink
  static const Color moduleP2P = Color(0xFF0D9488); // Teal
  static const Color moduleEvents = Color(0xFFEA580C); // Orange-Red

  // -------------------------------------------------------------------
  // 4. HIGHLIGHTS & BADGES
  // -------------------------------------------------------------------
  static const Color topMatchGold = Color(0xFFFBBF24);
  static const Color topMatchCardBg = Color(0xFFFFFDF2);
  static const Color topMatchBorder = Color(0xFFFDE68A);

  // -------------------------------------------------------------------
  // 5. BACKGROUND & SURFACES
  // -------------------------------------------------------------------
  static const Color background = Color(0xFFF8FAFC); // Page background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // -------------------------------------------------------------------
  // 6. TYPOGRAPHY & TEXT TOKENS
  // -------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF0F172A); // Main body text
  static const Color textSecondary = Color(0xFF64748B); // Subtext
  static const Color textLight = Color(0xFF94A3B8); // Placeholders & hints
  static const Color textMuted = Color(0xFF94A3B8);

  // -------------------------------------------------------------------
  // 7. BORDERS & DIVIDERS
  // -------------------------------------------------------------------
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // -------------------------------------------------------------------
  // 8. STATUS BADGES
  // -------------------------------------------------------------------
  static const Color verifiedBlue = Color(0xFF16A34A);
  static const Color verifiedBlueBg = Color(0xFFDCFCE7);
  static const Color verifiedBlueBorder = Color(0xFFBBF7D0);

  static const Color hotRose = Color(0xFFF97316);
  static const Color hotRoseBg = Color(0xFFFFF7ED);
  static const Color hotRoseBorder = Color(0xFFFFEDD5);

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFDC2626);
}
