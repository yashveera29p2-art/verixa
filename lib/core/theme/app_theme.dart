import 'package:flutter/material.dart';

import 'app_colors.dart';
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
      dividerTheme: const DividerThemeData(
        color: AppColors.stone,
        thickness: AppSizes.borderWidth,
      ),
    );
  }
}
