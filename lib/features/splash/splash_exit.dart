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
/// 2. Λ flies up and grows, and its inside becomes a window onto the page:
///    the opening spreads until the whole page is revealed from above;
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

    final letters = _part(animation, 0.0, 0.26, Curves.easeOut);
    // Λ: lifts off, then accelerates upward as it spreads over the page.
    final lambda = _part(animation, 0.02, 0.66, Curves.easeInCubic);
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
              // Green splash with a Λ-shaped window onto the page.
              CustomPaint(
                painter: _LambdaRevealPainter(
                  progress: lambda.value,
                  layout: layout,
                  screen: size,
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


/// Paints the splash background with a growing Λ-shaped hole, plus the Λ
/// letter itself riding the edge of the hole until it fades.
///
/// The Λ's apex flies from its spot in the word to well above the screen
/// while the Λ grows; its outline (a triangle: apex at the top, legs
/// spreading down) ends up wider than the screen and taller than it, so
/// the hole covers everything and the page is fully revealed.
class _LambdaRevealPainter extends CustomPainter {
  _LambdaRevealPainter({
    required this.progress,
    required this.layout,
    required this.screen,
  });

  final double progress;
  final WordmarkLayout layout;
  final Size screen;

  /// Half the Λ's base width per unit of its height (its legs spread to
  /// 0.65 h either side of the apex).
  static const _spread = 0.65;

  @override
  void paint(Canvas canvas, Size size) {
    final h = layout.finalHeight;
    final top = layout.center.dy - h / 2;
    final left = (screen.width - MonogramGeometry.width * h) / 2;
    // Apex of the Λ at the end of the splash.
    final apex0 = Offset(left + 1.30 * h + layout.finalSpread, top);
    // Where it ends: centred, far enough above the screen that the legs
    // clear the top corners, and big enough to cover the bottom.
    final apex1 = Offset(screen.width / 2, -screen.width / (2 * _spread) - 48);
    final size1 = screen.height - apex1.dy + 96;

    final t = progress;
    final apex = Offset.lerp(apex0, apex1, t)!;
    final scale = lerpDouble(1, size1 / h, t)!; // letter size multiplier
    final letterHeight = h * scale;

    // The window starts as nothing and catches up with the letter's size.
    final windowShare = Curves.easeOutCubic.transform(((t - 0.06) / 0.30).clamp(0.0, 1.0));
    final windowHeight = letterHeight * windowShare;
    final window = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx + _spread * windowHeight, apex.dy + windowHeight)
      ..lineTo(apex.dx - _spread * windowHeight, apex.dy + windowHeight)
      ..close();

    final rect = Offset.zero & size;
    final background = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addPath(window, Offset.zero);
    canvas.drawPath(
      background,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [AppColors.splashBgTop, AppColors.splashBgBottom],
        ).createShader(rect),
    );

    // The Λ letter, flying and growing with the window, fading as it goes.
    final letterOpacity = (1 - ((t - 0.18) / 0.32)).clamp(0.0, 1.0);
    if (letterOpacity <= 0) return;
    canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, letterOpacity));
    canvas
      ..translate(apex.dx, apex.dy)
      ..scale(scale)
      ..translate(-apex0.dx, -apex0.dy)
      ..translate(0, top);
    VerixaMonogramPainter(
      palette: MonogramPalette.splash,
      spread: layout.finalSpread,
      showV: false,
    ).paint(canvas, Size(screen.width, h));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LambdaRevealPainter old) => old.progress != progress;
}
