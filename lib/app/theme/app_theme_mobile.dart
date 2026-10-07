import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// KaamMilega Mobile Design Specification v1.0 (Oct 2026) as a Flutter
/// theme. Same brand colours and fonts as the web; mobile sizes, touch
/// targets, contrast fixes and components. Used while kMobileDesignSpec
/// is true (see mobile_design_spec.dart).
class AppMobileTheme {
  AppMobileTheme._();

  // Colours used only here (spec section 3 and 7).
  static const Color _focus = AppColors.blue; // #0B5ED7 focus ring
  static const Color _disabledBg = AppColors.border; // #D9E0EA
  static const Color _disabledFg = AppColors.textSecondary; // #5B6472
  static const Color _ripple = Color(0x14071A4D); // navy 8%
  static const Color _rippleOnDark = Color(0x33FFFFFF); // white 20%

  /// Ripple tinted for the surface the button sits on (spec 6.2).
  static WidgetStateProperty<Color?> _press(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed) ? color : null,
      );

  // -------------------------------------------------------------------
  // Typography. Inter (clean, compact, easy to read on phones) for all
  // UI text; Poppins only for large headings, app bar and dialog titles
  // and the wordmark, where the brand shows.
  // -------------------------------------------------------------------
  static const TextTheme _text = TextTheme(
    // Display: splash, onboarding hero, home greeting
    displaySmall: TextStyle(
      fontFamily: AppFonts.primary,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.56,
      color: AppColors.brandNavy,
    ),
    // H1: screen titles
    headlineLarge: TextStyle(
      fontFamily: AppFonts.primary,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.36,
      color: AppColors.brandNavy,
    ),
    // H2: section headings
    headlineMedium: TextStyle(
      fontFamily: AppFonts.primary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    // H3: card titles, job titles
    headlineSmall: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.brandNavy,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    // Body Large: descriptions; also the text typed in form fields, which
    // must be 16px or larger.
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    // Body: default text (no line height here, so existing fixed-height
    // rows keep fitting)
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    // Caption: timestamps, meta, helper text
    bodySmall: TextStyle(
      fontFamily: AppFonts.secondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.13,
      color: AppColors.textSecondary,
    ),
    // Button
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
    ),
    // Label: form and list labels
    labelMedium: TextStyle(
      fontFamily: AppFonts.secondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    // Tab label / micro chip
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.11,
      color: AppColors.textSecondary,
    ),
  );

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.secondary,
    fontFamilyFallback: AppFonts.fallback,
    textTheme: _text,
    scaffoldBackgroundColor: AppColors.background, // Canvas #F4F7FB
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded, // 48px targets
    splashColor: _ripple,
    highlightColor: Colors.transparent,

    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          secondary: AppColors.accent,
          onSecondary: AppColors.onAccent,
          tertiary: AppColors.blue,
          error: AppColors.error,
          surface: AppColors.white,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          surfaceTint: Colors.transparent,
          scrim: AppColors.scrim,
        ),

    // Screen push: platform default timing (spec 6.4)
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // App bar 7.1: white, 56px, navy 18px title and 24px icons; a 1px
    // border colour shadow once content scrolls under it.
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.brandNavy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border,
      toolbarHeight: 56,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.brandNavy, size: 24),
      actionsIconTheme: IconThemeData(color: AppColors.brandNavy, size: 24),
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.primary,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.brandNavy,
      ),
      // Light screens: white status bar with dark icons (spec 3.4)
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.brandNavy, size: 24),

    // Forms 7.9: 52px fields, 12px radius, Inter 16px, 2px blue focus,
    // 2px red error, label above in Inter 500 14px.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      isDense: false,
      // About 52px tall with 16px text (no hard minimum, so search fields
      // inside fixed-height bars keep fitting).
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: _border(AppColors.border),
      enabledBorder: _border(AppColors.border),
      focusedBorder: _border(_focus, 2),
      errorBorder: _border(AppColors.error, 2),
      focusedErrorBorder: _border(AppColors.error, 2),
      disabledBorder: _border(AppColors.borderLight),
      hintStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontFamily: AppFonts.secondary,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.error)
              ? AppColors.error
              : states.contains(WidgetState.focused)
              ? _focus
              : AppColors.textPrimary,
        ),
      ),
      helperStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      errorStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
        height: 1.3,
      ),
      errorMaxLines: 3,
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.error)
            ? AppColors.error
            : states.contains(WidgetState.focused)
            ? _focus
            : AppColors.textSecondary,
      ),
      suffixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? _focus
            : AppColors.textSecondary,
      ),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: _focus,
      selectionColor: _focus.withValues(alpha: 0.2),
      selectionHandleColor: _focus,
    ),

    // Buttons 7.4: Poppins 600 16px, 12px radius, 48px minimum tap height.
    // Pressed instead of hover; disabled is grey (not faded colour).
    elevatedButtonTheme: ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: AppFonts.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return _disabledBg;
              if (states.contains(WidgetState.pressed)) {
                return AppColors.primaryDark;
              }
              return AppColors.primary;
            }),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? _disabledFg
                  : AppColors.white,
            ),
            overlayColor: _press(_rippleOnDark),
            elevation: const WidgetStatePropertyAll<double>(0),
          ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: _disabledBg,
        disabledForegroundColor: _disabledFg,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.secondary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ).copyWith(overlayColor: _press(_rippleOnDark)),
    ),

    // Outline 7.4: 1.5px navy; pressed: canvas fill with a blue border.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontFamily: AppFonts.secondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return _disabledFg;
              return states.contains(WidgetState.pressed)
                  ? AppColors.blue
                  : AppColors.primary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? AppColors.background
                  : null,
            ),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const BorderSide(color: _disabledBg, width: 1.5);
              }
              return BorderSide(
                color: states.contains(WidgetState.pressed)
                    ? AppColors.blue
                    : AppColors.primary,
                width: 1.5,
              );
            }),
            overlayColor: _press(_ripple),
          ),
    ),

    // Text button 7.4: brand blue, Poppins 600, 48px tap height.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        disabledForegroundColor: _disabledFg,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.secondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ).copyWith(overlayColor: _press(_ripple)),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48))
          .copyWith(overlayColor: _press(_ripple)),
    ),

    // FAB 7.16: orange with a navy icon
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      elevation: 3,
      shape: CircleBorder(),
    ),

    // Chips 7.7: 36px pills, 1px border; selected navy with a white tick.
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.borderLight,
      checkmarkColor: AppColors.white,
      deleteIconColor: AppColors.textSecondary,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontFamily: AppFonts.secondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.textPrimary,
        ),
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
      ),
      brightness: Brightness.light,
      showCheckmark: true,
    ),

    // Cards 7.6: white, 14px radius, 1px border, elevation 1
    cardTheme: CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: AppColors.brandNavy.withValues(alpha: 0.05),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // Bottom sheets 7.10: 20px top corners, 36x4 handle, navy scrim
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBarrierColor: AppColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      dragHandleColor: AppColors.border,
      dragHandleSize: Size(36, 4),
    ),

    // Dialogs 7.11: confirmations only; 20px radius, 24px from the edges
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      barrierColor: AppColors.scrim,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titleTextStyle: const TextStyle(
        fontFamily: AppFonts.primary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 15,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
    ),

    // Snackbars 7.12: navy, Inter 14px, 12px radius, light-orange action
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brandNavy,
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.white,
        height: 1.4,
      ),
      actionTextColor: AppColors.accentBright,
      elevation: 3,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // In-page tabs 7.13: 48px, Poppins 600 14px, 2px orange underline
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.brandNavy,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
      labelStyle: TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),

    // List rows 8.8: 56px, grey icons, pressed canvas
    listTileTheme: const ListTileThemeData(
      minTileHeight: 56,
      iconColor: AppColors.textSecondary,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    ),

    // Loading: navy spinners and pull-to-refresh, blue progress bars on
    // the border grey track (spec 6.3, 7.9).
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brandNavy,
      linearTrackColor: AppColors.border,
      circularTrackColor: Colors.transparent,
      refreshBackgroundColor: AppColors.white,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textSecondary,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        fontSize: 13,
        color: AppColors.white,
      ),
    ),
  );
}
