import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// Soft press / hover / focus highlight for buttons, tinted with [base].
  static WidgetStateProperty<Color?> _pressOverlay(Color base) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return base.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return base.withValues(alpha: 0.06);
      }
      return null;
    });
  }

  static bool _outlineActive(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused) ||
      states.contains(WidgetState.pressed);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    // Brand typography: Poppins, with Noto Sans Devanagari for Hindi text.
    fontFamily: AppFonts.primary,
    fontFamilyFallback: AppFonts.fallback,

    scaffoldBackgroundColor: AppColors.background,

    // Screen-to-screen navigation: subtle fade + slight upward slide on
    // Android; iOS keeps its native slide so swipe-back still works.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),

    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading2,
      headlineSmall: AppTextStyles.heading3,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.bodySecondary,
      labelLarge: AppTextStyles.button,
      bodySmall: AppTextStyles.caption,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),

      // Error, focused-error and disabled states (existing colour tokens).
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      // Hint / label / error text.
      // Form fields use the secondary font (Inter).
      hintStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        color: AppColors.textLight,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontFamily: AppFonts.secondary,
          color: states.contains(WidgetState.error)
              ? AppColors.error
              : states.contains(WidgetState.focused)
              ? AppColors.primary
              : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      helperStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        color: AppColors.textSecondary,
        fontSize: 12,
      ),
      errorStyle: const TextStyle(
        fontFamily: AppFonts.secondary,
        color: AppColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      // Long error messages wrap instead of being cut off.
      errorMaxLines: 2,

      // Prefix / suffix icons: grey normally, brand blue while focused.
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.error)
            ? AppColors.error
            : states.contains(WidgetState.focused)
            ? AppColors.primary
            : AppColors.textLight,
      ),
      suffixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? AppColors.primary
            : AppColors.textLight,
      ),
    ),

    // Cursor and text selection in the brand colour.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primary.withValues(alpha: 0.18),
      selectionHandleColor: AppColors.primary,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            // Disabled: faded brand blue instead of flat grey.
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
            disabledForegroundColor: AppColors.white.withValues(alpha: 0.9),
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ).copyWith(
            overlayColor: _pressOverlay(AppColors.white),
            // Primary CTA: navy, hover / pressed navy #0B1F52 with a soft shadow.
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.primary.withValues(alpha: 0.35);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return AppColors.primaryDark;
              }
              return AppColors.primary;
            }),
            elevation: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered) ? 4 : 0,
            ),
            shadowColor: WidgetStatePropertyAll(
              AppColors.brandNavy.withValues(alpha: 0.25),
            ),
          ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.textLight,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ).copyWith(
            overlayColor: _pressOverlay(AppColors.primary),
            // Outline: hover / focus / press -> light canvas, blue border + text.
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => _outlineActive(states) ? AppColors.background : null,
            ),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textLight;
              }
              return _outlineActive(states)
                  ? AppColors.blue
                  : AppColors.primary;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const BorderSide(color: AppColors.border, width: 1.5);
              }
              return BorderSide(
                color: _outlineActive(states)
                    ? AppColors.blue
                    : AppColors.primary,
                width: 1.5,
              );
            }),
          ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.textLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ).copyWith(overlayColor: _pressOverlay(AppColors.primary)),
    ),

    // Dialogs: one look for every popup (screens may still override).
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.45,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    ),

    // Bottom sheets: white, rounded top corners, slate drag handle.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      dragHandleColor: const Color(0xFFCBD5E1),
      dragHandleSize: const Size(40, 4),
    ),

    // Snackbars: floating, rounded, brand navy (screens that pass their own
    // colour, e.g. green success / red error, keep it).
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brandNavy,
      contentTextStyle: const TextStyle(
        color: AppColors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      actionTextColor: AppColors.accent,
      elevation: 4,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Cards: white, 1px border grey, radius 16, very soft navy shadow.
    cardTheme: CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: AppColors.brandNavy.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
