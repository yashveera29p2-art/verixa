import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The single Material theme for the app UI.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.botanicalGreen,
      onPrimary: AppColors.ivory,
      secondary: AppColors.softSage,
      onSecondary: AppColors.charcoal,
      surface: AppColors.ivory,
      onSurface: AppColors.charcoal,
      onSurfaceVariant: AppColors.mutedText,
      outline: AppColors.stone,
      outlineVariant: AppColors.stone,
      error: AppColors.charcoal,
      onError: AppColors.ivory,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ivory,
      textTheme: AppTypography.textTheme,
      // One calm page transition on every platform (see app_motion.dart).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: VerixaPageTransitionsBuilder(),
          TargetPlatform.iOS: VerixaPageTransitionsBuilder(),
        },
      ),
      // Soft, brand-tinted tap feedback instead of the default grey splash.
      splashFactory: InkRipple.splashFactory,
      splashColor: AppColors.botanicalGreen.withValues(alpha: 0.10),
      highlightColor: AppColors.botanicalGreen.withValues(alpha: 0.04),
      dividerTheme: const DividerThemeData(
        color: AppColors.stone,
        thickness: AppSizes.borderWidth,
      ),
      inputDecorationTheme: _inputTheme,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.botanicalGreen,
        selectionColor: AppColors.softSage,
        selectionHandleColor: AppColors.botanicalGreen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColors.ivory,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.ivory,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static InputDecorationTheme get _inputTheme {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
      floatingLabelStyle: AppTypography.labelLarge.copyWith(
        color: AppColors.botanicalGreen,
      ),
      hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.softSage),
      errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.charcoal),
      border: _border(AppColors.stone),
      enabledBorder: _border(AppColors.stone),
      focusedBorder: _border(AppColors.botanicalGreen, 1.5),
      errorBorder: _border(AppColors.charcoal),
      focusedErrorBorder: _border(AppColors.charcoal, 1.5),
    );
  }
}
