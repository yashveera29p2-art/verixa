import 'package:flutter/animation.dart';

/// All splash timings in one place (milliseconds from launch).
/// Change these to tune the animation — nothing else needs editing.
abstract final class SplashTimings {
  /// N fades in at the very start.
  static const int nFadeInEnd = 150;

  /// N flips on the Y axis and becomes VΛ.
  static const int flipStart = 500;
  static const int flipEnd = 900;

  /// V slides left, Λ slides right, both shrink to word size.
  static const int slideStart = 900;
  static const int slideEnd = 1300;

  /// E R I X are typed one at a time.
  static const String typedLetters = 'ERIX';
  static const int firstLetter = 1300;
  static const int letterStep = 100;

  /// Hold on the full word "VERIXA" (from the last letter until [total]).
  static const int total = 2000;

  /// Fade into the next screen (handled by the route transition).
  static const Duration fadeOut = Duration(milliseconds: 300);

  static const Duration controllerDuration = Duration(milliseconds: total);

  /// An [Interval] for the controller, built from millisecond bounds.
  static Interval interval(int startMs, int endMs, [Curve curve = Curves.linear]) =>
      Interval(startMs / total, endMs / total, curve: curve);

  /// How many of [typedLetters] are visible at [elapsedMs].
  static int lettersVisibleAt(double elapsedMs) {
    if (elapsedMs < firstLetter) return 0;
    final count = ((elapsedMs - firstLetter) ~/ letterStep) + 1;
    return count.clamp(0, typedLetters.length);
  }
}
