import 'package:flutter/painting.dart';

/// Every colour used in the Verixa app. This file is the ONLY place hex values
/// may appear — widgets must reference these tokens instead.
abstract final class AppColors {
  // ── Core palette (see CLAUDE.md §2) ──────────────────────────────────────
  /// ~40% — main backgrounds, page surfaces, large sections.
  static const ivory = Color(0xFFF5F1E8);

  /// ~40% — brand, primary buttons, active/selected states, filled sections.
  static const botanicalGreen = Color(0xFF365C47);

  /// ~20% — headings, important text, icons, dark contrast sections.
  static const charcoal = Color(0xFF292D2B);

  /// Max ~4% — small cards/highlights only, never a dominant background.
  static const white = Color(0xFFFFFFFF);

  /// Borders, dividers, separators.
  static const stone = Color(0xFFD9D4C9);

  /// Secondary backgrounds, subtle highlights, inactive states.
  static const softSage = Color(0xFFA8B8AA);

  /// Secondary / supporting text.
  static const mutedText = Color(0xFF626A63);

  // ── Splash-only brand tokens (sampled from the logo) ─────────────────────
  // Use these ONLY on the splash screen and the app icon.
  static const splashBgTop = Color(0xFF002C28);
  static const splashBgBottom = Color(0xFF001F1E);
  static const logoGreen = Color(0xFF11D258);
  static const logoGreenDeep = Color(0xFF029932);
  static const logoCream = Color(0xFFFCEFDF);
  static const logoCharcoal = Color(0xFF3D3A3A);
}
