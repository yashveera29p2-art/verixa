import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/verixa_monogram.dart';
import 'splash_timings.dart';

/// Sizes and positions for the monogram and the final word "VERIXA".
///
/// Final word, left to right: [V][gap][E R I X][gap][Λ]. The typed letters
/// are sized so their cap height equals the V/Λ height.
class WordmarkLayout {
  WordmarkLayout(Size screen) : center = screen.center(Offset.zero) {
    startHeight = math.min(110, screen.width * 0.26);

    // Measure "ERIX" at a reference size, then scale linearly.
    const refHeight = 100.0;
    final refStyle = _styleFor(refHeight);
    final painter = TextPainter(
      text: TextSpan(text: SplashTimings.typedLetters, style: refStyle),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Flutter adds letter spacing after the last letter too; ignore it.
    final lettersPerUnit =
        (painter.width - refStyle.letterSpacing!) / refHeight;
    painter.dispose();

    final wordUnits =
        2 * MonogramGeometry.letterWidth + 2 * _gap + lettersPerUnit;
    finalHeight = math.min(
      _maxFinalHeight,
      (screen.width - 2 * AppSpacing.xxl) / wordUnits,
    );

    final wordWidth = wordUnits * finalHeight;
    finalSpread = wordWidth / 2 - MonogramGeometry.width / 2 * finalHeight;
    lettersLeft = center.dx -
        wordWidth / 2 +
        (MonogramGeometry.letterWidth + _gap) * finalHeight;
    letterStyle = _styleFor(finalHeight);
  }

  static const double _maxFinalHeight = 56;
  static const double _gap = 0.2; // in glyph heights

  final Offset center;
  late final double startHeight;
  late final double finalHeight;
  late final double finalSpread;
  late final double lettersLeft;
  late final TextStyle letterStyle;

  static TextStyle _styleFor(double capHeight) {
    final fontSize = capHeight / AppTypography.dmSansCapHeight;
    return AppTypography.splashWordmark(fontSize)
        .copyWith(letterSpacing: fontSize * 0.14);
  }
}
