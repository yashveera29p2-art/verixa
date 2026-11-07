import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles for the whole app.
///
/// Headings use DM Serif Display (fallback Lora). Body, buttons and labels use
/// DM Sans (fallback Inter).
abstract final class AppTypography {
  // Used only if DM fonts can't be loaded (named, not downloaded).
  static const _serifFallback = ['Lora', 'serif'];
  static const _sansFallback = ['Inter', 'sans-serif'];

  /// DM Sans cap height as a fraction of font size (700 / 1000 units).
  /// Used to size typed letters so they match the drawn V and Λ.
  static const double dmSansCapHeight = 0.70;

  static TextStyle _serif(double size, {double height = 1.15}) =>
      GoogleFonts.dmSerifDisplay(
        fontSize: size,
        height: height,
        color: AppColors.charcoal,
        fontWeight: FontWeight.w400,
      ).copyWith(fontFamilyFallback: _serifFallback);

  static TextStyle _sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.5,
    Color color = AppColors.charcoal,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
        letterSpacing: letterSpacing,
      ).copyWith(fontFamilyFallback: _sansFallback);

  // ── Headings (DM Serif Display) ──────────────────────────────────────────
  static TextStyle get displayLarge => _serif(40, height: 1.1);
  static TextStyle get displayMedium => _serif(34, height: 1.12);
  static TextStyle get headlineLarge => _serif(28);
  static TextStyle get headlineMedium => _serif(24);
  static TextStyle get titleLarge => _serif(20, height: 1.25);

  // ── Body (DM Sans) ───────────────────────────────────────────────────────
  static TextStyle get bodyLarge => _sans(16);
  static TextStyle get bodyMedium => _sans(14);
  static TextStyle get bodySmall => _sans(12, color: AppColors.mutedText);

  // ── Buttons & labels (DM Sans, medium) ───────────────────────────────────
  static TextStyle get button =>
      _sans(16, weight: FontWeight.w500, height: 1.2, letterSpacing: 0.2);
  static TextStyle get labelLarge => _sans(14, weight: FontWeight.w500);
  static TextStyle get labelMedium =>
      _sans(12, weight: FontWeight.w500, letterSpacing: 0.4);

  /// Letters typed into the splash wordmark (E R I X).
  static TextStyle splashWordmark(double fontSize) => _sans(
        fontSize,
        weight: FontWeight.w600,
        height: 1,
        color: AppColors.logoCream,
      );

  /// Waits (up to [timeout]) for the DM fonts to finish loading, so text
  /// doesn't flash in a fallback font. Safe to call repeatedly.
  static Future<void> ensureLoaded({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.dmSans(fontWeight: FontWeight.w400),
        GoogleFonts.dmSans(fontWeight: FontWeight.w500),
        GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        GoogleFonts.dmSerifDisplay(),
      ]).timeout(timeout);
    } catch (_) {
      // Offline or slow network: carry on with the fallback font.
    }
  }

  /// Material [TextTheme] built from the styles above.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: labelLarge.copyWith(fontSize: 16),
        titleSmall: labelLarge,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelMedium.copyWith(fontSize: 11),
      );
}
