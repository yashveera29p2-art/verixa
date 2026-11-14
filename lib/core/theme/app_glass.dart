import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Glass settings. iPhones (the native app and the web app in Safari) get a
/// richer "liquid glass lite": stronger, more saturated blur, a clearer
/// fill and a light edge shine. Android keeps the calmer frosting.
abstract final class AppGlass {
  static bool get isApple =>
      _preview || defaultTargetPlatform == TargetPlatform.iOS;

  /// Web only: open the app with `?look=ios` to see the iPhone glass on
  /// any browser (for demos and testing).
  static final bool _preview =
      kIsWeb && Uri.base.queryParameters['look'] == 'ios';

  /// Backdrop filter for a glass surface with base blur [sigma].
  static ImageFilter filter(double sigma) {
    final blur = ImageFilter.blur(
      sigmaX: isApple ? sigma * 1.25 : sigma,
      sigmaY: isApple ? sigma * 1.25 : sigma,
    );
    if (!isApple) return blur;
    // Like iOS materials: colours behind the glass come through richer.
    return ImageFilter.compose(outer: _saturate, inner: blur);
  }

  /// Fill opacity: clearer glass on iPhone.
  static double fill(double base) => isApple ? base * 0.72 : base;

  static const _saturate = ColorFilter.matrix(<double>[
    1.2516, -0.2184, -0.0332, 0, 0, //
    -0.0484, 1.0816, -0.0332, 0, 0, //
    -0.0484, -0.2184, 1.2668, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// The light catching a glass edge: a thin bright line strongest at the top
/// left, fading round the sides, with a softer echo at the bottom right.
/// Only drawn on iPhone; elsewhere it's an empty box.
class SpecularRim extends StatelessWidget {
  const SpecularRim({super.key, required this.radius, this.strength = 1});

  final double radius;
  final double strength;

  @override
  Widget build(BuildContext context) {
    if (!AppGlass.isApple) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _SpecularPainter(radius, strength),
        size: Size.infinite,
      ),
    );
  }
}

class _SpecularPainter extends CustomPainter {
  _SpecularPainter(this.radius, this.strength);

  final double radius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.4);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius - 1.4));
    final white = AppColors.white;
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          white.withValues(alpha: 0.95 * strength),
          white.withValues(alpha: 0.15 * strength),
          white.withValues(alpha: 0.0),
          white.withValues(alpha: 0.45 * strength),
        ],
        stops: const [0, 0.35, 0.6, 1],
      ).createShader(rect);
    canvas.drawRRect(r, shine);
    // Soft inner glow under the top edge.
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          white.withValues(alpha: 0.28 * strength),
          white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(r, glow);
  }

  @override
  bool shouldRepaint(_SpecularPainter old) =>
      old.radius != radius || old.strength != strength;
}
