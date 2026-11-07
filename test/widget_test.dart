import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/core/widgets/verixa_monogram.dart';
import 'package:verixa/features/splash/splash_timings.dart';

void main() {
  group('SplashTimings', () {
    test('total length stays within the 2–2.5 s target (incl. fade)', () {
      final totalMs =
          SplashTimings.total + SplashTimings.fadeOut.inMilliseconds;
      expect(totalMs, inInclusiveRange(2000, 2500));
    });

    test('steps run in order without overlapping', () {
      expect(SplashTimings.flipStart, greaterThanOrEqualTo(SplashTimings.nFadeInEnd));
      expect(SplashTimings.slideStart, greaterThanOrEqualTo(SplashTimings.flipEnd));
      expect(SplashTimings.firstLetter, greaterThanOrEqualTo(SplashTimings.slideEnd));
      final lastLetter = SplashTimings.firstLetter +
          (SplashTimings.typedLetters.length - 1) * SplashTimings.letterStep;
      expect(lastLetter, lessThan(SplashTimings.total));
    });

    test('letters appear one at a time', () {
      expect(SplashTimings.lettersVisibleAt(1299), 0);
      expect(SplashTimings.lettersVisibleAt(1300), 1);
      expect(SplashTimings.lettersVisibleAt(1450), 2);
      expect(SplashTimings.lettersVisibleAt(1600), 4);
      expect(SplashTimings.lettersVisibleAt(2000), 4);
    });
  });

  test('monogram strokes fit inside the declared width', () {
    for (final path in [
      MonogramGeometry.vLeft,
      MonogramGeometry.vRight,
      MonogramGeometry.lambdaLeft,
      MonogramGeometry.lambdaRight,
    ]) {
      final b = path.getBounds();
      // Paths are stored as float32, so allow a tiny rounding error.
      const eps = 1e-6;
      expect(b.left, greaterThanOrEqualTo(-eps));
      expect(b.right, lessThanOrEqualTo(MonogramGeometry.width + eps));
      expect(b.height, closeTo(1, eps));
    }
  });
}
