import 'package:flutter/material.dart';

/// Single Source of Truth for KaamMilega™ UI/UX Design System Colors.
///
/// Master brand system (25 Sep 2026): Navy #071A4D (trust + platform) and
/// Orange #FF6B00 (action + opportunity). Wordmark: "Kaammi" navy, "lega"
/// orange, "™" navy. Gradients: navy #071A4D → blue #0B5ED7, and orange
/// #FF6B00 → #FF8A00 (app UI and banners only, never the wordmark).
class AppColors {
  AppColors._();

  // -------------------------------------------------------------------
  // 1. PRIMARY BRAND COLORS
  // -------------------------------------------------------------------
  static const Color brandNavy = Color(0xFF071A4D); // Dark Navy (logo)
  static const Color navy = Color(0xFF0B1F52); // Navy
  static const Color blue = Color(0xFF0B5ED7); // Blue (links, focus, Jobs)
  static const Color brandOrange = Color(0xFFFF6B00); // Brand Orange (logo)
  static const Color orangeLight = Color(0xFFFF8A00); // Light Orange
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF111827);

  /// Old name of the primary brand colour; same value as [brandNavy].
  static const Color brandBlue = brandNavy;
  static const Color deepNavy = brandNavy;

  // -------------------------------------------------------------------
  // 2. SEMANTIC COLOR SYSTEM TOKENS
  // -------------------------------------------------------------------
  static const Color primary = brandNavy; // Primary buttons, app chrome
  static const Color primaryLight = Color(0xFFEFF6FF); // Light blue tint
  static const Color primaryLightBorder = Color(0xFFDBEAFE); // Tint border
  static const Color primaryDark = navy; // Hover / active / deep banners
  static const Color primaryGradientStart = brandNavy;
  static const Color primaryGradientEnd = blue;

  static const Color accent = brandOrange; // Highlights, CTAs, InstantMilega
  static const Color accentBright = orangeLight; // Orange gradient end
  static const Color accentDark = brandOrange;
  static const Color accentLight = Color(0xFFFFF7ED); // Light orange tint

  // Header tokens
  static const Color deepPurpleHeader = brandNavy; // Navy top navbar/header
  static const Color heroBg = brandNavy;
  static const Color heroAccent = brandOrange;
  static const Color heroButton = brandOrange;
  static const Color heroButtonHover = orangeLight;
  static const Color tickerBg = primaryLight;
  static const Color tickerBorder = primaryLightBorder;
  static const Color cardLightBg = background;

  // -------------------------------------------------------------------
  // 3. SEVEN-SERVICE COLOR CODING (recognition colours per service)
  // -------------------------------------------------------------------
  static const Color moduleJobs = blue; // Jobs & Recruitment
  static const Color moduleInstantWork = brandOrange; // InstantMilega™
  static const Color moduleSkills = Color(0xFF16A34A); // Skills Marketplace
  static const Color moduleExperts = Color(0xFF7C3AED); // Experts & Mentors
  static const Color moduleServices = Color(0xFFEF4444); // Services
  static const Color moduleP2P = Color(0xFF0F9D8A); // Peer-to-Peer
  static const Color moduleEvents = Color(0xFFF59E0B); // Events & Community

  // Light tints (10 % of the service colour on white) for chips and icon
  // backgrounds.
  static const Color moduleJobsLight = primaryLight;
  static const Color moduleInstantWorkLight = accentLight;
  static const Color moduleSkillsLight = Color(0xFFDCFCE7);
  static const Color moduleExpertsLight = Color(0xFFF2EBFD);
  static const Color moduleServicesLight = Color(0xFFFDECEC);
  static const Color moduleP2PLight = Color(0xFFE7F5F3);
  static const Color moduleEventsLight = Color(0xFFFEF5E7);

  // -------------------------------------------------------------------
  // 4. HIGHLIGHTS & BADGES
  // -------------------------------------------------------------------
  static const Color topMatchGold = Color(0xFFFBBF24);
  static const Color topMatchCardBg = Color(0xFFFFFDF2);
  static const Color topMatchBorder = Color(0xFFFDE68A);

  // -------------------------------------------------------------------
  // 5. BACKGROUND & SURFACES
  // -------------------------------------------------------------------
  static const Color background = Color(0xFFF4F7FB); // Light Background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // -------------------------------------------------------------------
  // 6. TYPOGRAPHY & TEXT TOKENS
  // -------------------------------------------------------------------
  static const Color textPrimary = black; // Main body text
  static const Color textSecondary = Color(0xFF5B6472); // Text Grey
  static const Color textLight = Color(0xFF94A3B8); // Placeholders & hints
  static const Color textMuted = Color(0xFF94A3B8);

  // -------------------------------------------------------------------
  // 7. BORDERS & DIVIDERS
  // -------------------------------------------------------------------
  static const Color border = Color(0xFFD9E0EA); // Border Grey
  static const Color borderLight = Color(0xFFF1F5F9);

  // -------------------------------------------------------------------
  // 8. STATUS BADGES
  // -------------------------------------------------------------------
  static const Color verifiedBlue = Color(0xFF16A34A);
  static const Color verifiedBlueBg = Color(0xFFDCFCE7);
  static const Color verifiedBlueBorder = Color(0xFFBBF7D0);

  static const Color hotRose = brandOrange;
  static const Color hotRoseBg = accentLight;
  static const Color hotRoseBorder = Color(0xFFFFEDD5);

  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFDC2626);
}
