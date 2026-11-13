import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
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
  static const duration = Duration(milliseconds: 900);

  /// When the nav bar starts its entrance (glass bubble → button → pill):
  /// as the reveal opens past the bottom of the screen.
  static const navIntroDelay = Duration(milliseconds: 560);

  /// Set when the exit opens onto a page with the nav bar; the shell reads
  /// it once.
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

/// The splash leaving: a soft-edged circle opens from the centre of the
/// word and grows until the page underneath fills the screen, while the
/// word fades and shrinks slightly into the opening.
class SplashExitOverlay extends StatelessWidget {
  const SplashExitOverlay({
    super.key,
    required this.animation,
    required this.withNav,
  });

  final Animation<double> animation;

  /// Kept for the router; the nav bar runs its own entrance.
  final bool withNav;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = WordmarkLayout(size);
    final reveal = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    );
    final word = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    // Material gives the word a proper text style; without it Flutter
    // draws its yellow "missing text style" underline under the letters.
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final w = word.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _CircleRevealPainter(
                    progress: reveal.value,
                    centre: layout.center,
                  ),
                ),
                // The whole word, fading and easing back into the opening.
                Opacity(
                  opacity: (1 - w).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 - 0.12 * w,
                    origin: layout.center - size.center(Offset.zero),
                    child: _Word(layout: layout),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// VERIXA as it stands at the end of the splash.
class _Word extends StatelessWidget {
  const _Word({required this.layout});

  final WordmarkLayout layout;

  @override
  Widget build(BuildContext context) {
    final h = layout.finalHeight;
    final top = layout.center.dy - h / 2;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: h,
          child: CustomPaint(
            painter: VerixaMonogramPainter(
              palette: MonogramPalette.splash,
              spread: layout.finalSpread,
            ),
          ),
        ),
        Positioned(
          left: layout.lettersLeft,
          top: top,
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
      ],
    );
  }
}

/// The green splash with a growing soft-edged circular opening.
class _CircleRevealPainter extends CustomPainter {
  _CircleRevealPainter({required this.progress, required this.centre});

  final double progress;
  final Offset centre;

  /// Width of the soft edge, in pixels.
  static const _feather = 90.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final rect = Offset.zero & size;
    // Far enough to clear the furthest corner, edge included.
    final far = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((c) => (c - centre).distance).reduce(math.max);
    final radius = (far + _feather) * progress;
    final background = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.2),
        radius: 1.1,
        colors: [AppColors.splashBgTop, AppColors.splashBgBottom],
      ).createShader(rect);

    // Drawn with plain shapes (no layer blending, which some phones'
    // graphics engines don't support): solid green outside the circle…
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawPath(outside, background);

    // …and a soft edge just inside it, fading from green to clear.
    if (radius <= 0) return;
    final inner = math.max(0.0, radius - _feather);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.splashBgBottom.withValues(alpha: 0),
            AppColors.splashBgBottom.withValues(alpha: 0),
            AppColors.splashBgBottom,
          ],
          stops: [0, inner / radius, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_CircleRevealPainter old) => old.progress != progress;
}
