import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/glass_nav_bar.dart';
import '../../core/widgets/verixa_monogram.dart';
import 'splash_timings.dart';
import 'wordmark_layout.dart';

/// Tells the first screen after the splash to play the splash exit over
/// itself. The first page that claims it keeps it (rebuilds of the same
/// page get it again); it's cleared once the exit has finished.
abstract final class SplashExit {
  static bool _pending = false;
  static LocalKey? _owner;

  /// How long the exit takes.
  static const duration = Duration(milliseconds: 1250);

  /// When the nav pill should start popping out of the centre button:
  /// just as the V finishes turning into it.
  static const navIntroDelay = Duration(milliseconds: 1000);

  /// Set when the exit lands in the nav bar; the shell reads it once.
  static bool navIntro = false;

  static bool takeNavIntro() {
    final play = navIntro;
    navIntro = false;
    return play;
  }

  static void hold() {
    _pending = true;
    _owner = null;
  }

  static bool claim(LocalKey key) {
    if (!_pending) return false;
    _owner ??= key;
    return _owner == key;
  }

  static void clear() => _pending = false;
}

/// The splash's last frame coming apart over the next screen:
/// 1. the green background and E R I X fade away, revealing the page;
/// 2. Λ flies up off the screen;
/// 3. V drops to the bottom and morphs into the green centre button of the
///    nav bar ([withNav]); with no nav bar it just drops and fades.
class SplashExitOverlay extends StatelessWidget {
  const SplashExitOverlay({
    super.key,
    required this.animation,
    required this.withNav,
  });

  final Animation<double> animation;
  final bool withNav;

  static Animation<double> _part(Animation<double> a, double from, double to,
          [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: a, curve: Interval(from, to, curve: curve));

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final layout = WordmarkLayout(size);
    final h = layout.finalHeight;

    final background = _part(animation, 0.0, 0.42, Curves.easeInOut);
    final letters = _part(animation, 0.0, 0.26, Curves.easeOut);
    final lambda = _part(animation, 0.04, 0.50, Curves.easeInCubic);
    final drop = _part(animation, 0.10, 0.74, Curves.easeInOutCubic);
    final morph = _part(animation, 0.62, 0.92, Curves.easeOutCubic);
    final settle = _part(animation, 0.90, 1.0);

    // Where the V sits at the end of the splash, and where it lands.
    final monogramTop = layout.center.dy - h / 2;
    final monogramLeft = (size.width - MonogramGeometry.width * h) / 2;
    final vCentre = Offset(
      monogramLeft + MonogramGeometry.letterWidth / 2 * h - layout.finalSpread,
      layout.center.dy,
    );
    final target = Offset(
      size.width / 2,
      size.height - mq.padding.bottom - AppSizes.navPillGap - AppSizes.navPillHeight / 2,
    );
    const button = AppSizes.navCentreButton;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final drift = target - vCentre;
          final d = drop.value;
          final m = morph.value;
          // V shrinks a little as it lands, then fades as the circle appears.
          final vScale = lerpDouble(1, button * 0.62 / h, d)! * (1 - 0.25 * m);
          final vOpacity = (1 - m).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 1 - background.value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.1,
                      colors: [AppColors.splashBgTop, AppColors.splashBgBottom],
                    ),
                  ),
                ),
              ),
              // E R I X
              Positioned(
                left: layout.lettersLeft,
                top: monogramTop,
                child: Opacity(
                  opacity: 1 - letters.value,
                  child: Baseline(
                    baseline: h,
                    baselineType: TextBaseline.alphabetic,
                    child: Text(
                      SplashTimings.typedLetters,
                      style: layout.letterStyle,
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ),
              // Λ flies up.
              Positioned(
                left: 0,
                right: 0,
                top: monogramTop,
                height: h,
                child: Transform.translate(
                  offset: Offset(0, -(layout.center.dy + h) * lambda.value),
                  child: Opacity(
                    opacity: (1 - lambda.value * 0.6).clamp(0.0, 1.0),
                    child: CustomPaint(
                      painter: VerixaMonogramPainter(
                        palette: MonogramPalette.splash,
                        spread: layout.finalSpread,
                        showV: false,
                      ),
                    ),
                  ),
                ),
              ),
              // V drops and shrinks towards the centre button.
              Positioned(
                left: 0,
                right: 0,
                top: monogramTop,
                height: h,
                child: Transform.translate(
                  offset: drift * d,
                  child: Transform.scale(
                    scale: vScale,
                    origin: vCentre - Offset(size.width / 2, layout.center.dy),
                    child: Opacity(
                      opacity: withNav ? vOpacity : (1 - d * d).clamp(0.0, 1.0),
                      child: CustomPaint(
                        painter: VerixaMonogramPainter(
                          palette: MonogramPalette.splash,
                          spread: layout.finalSpread,
                          showLambda: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // …and becomes the button (the real one is underneath; this
              // copy fades out at the very end so the hand-off is invisible).
              if (withNav && m > 0)
                Positioned(
                  left: target.dx - button / 2,
                  top: target.dy - button / 2,
                  child: Opacity(
                    opacity: (m * (1 - settle.value)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.55 + 0.45 * m,
                      child: const CentreScanButton(
                        icon: Icons.document_scanner_outlined,
                        open: false,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
