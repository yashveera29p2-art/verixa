/// Spacing scale (logical pixels). Use these instead of magic numbers.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Horizontal padding for full-width page content.
  static const double pageGutter = 24;
}

/// Corner radii. Kept modest on purpose — no "bubbly" cards.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}

/// Fixed component sizes shared across screens.
abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double borderWidth = 1;
}
