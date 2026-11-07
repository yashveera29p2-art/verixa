import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Vector geometry of the VΛ monogram, in units where 1.0 = glyph height.
///
/// The monogram is a zigzag ribbon `\ / \` made of four parallelogram strokes.
/// Mirroring it horizontally gives `/ \ /` — a slanted **N**. That is what
/// lets the splash flip an N on the Y axis and land on VΛ seamlessly.
abstract final class MonogramGeometry {
  /// Total width of the monogram (V and Λ overlapping).
  static const double width = 1.95;

  /// Width of the V on its own (also the width of the Λ on its own).
  static const double letterWidth = 1.30;

  /// Where the Λ's right leg switches from the dark apex to the light base.
  static const double apexSplit = 0.48;

  /// Rounds the stroke corners slightly, like the ribbon in the logo.
  static const double cornerRounding = 0.035;

  // Each stroke: top-left, top-right, bottom-right, bottom-left (or the
  // equivalent going around the shape).
  static final Path vLeft = _quad(0.00, 0, 0.30, 0, 0.80, 1, 0.50, 1);
  static final Path vRight = _quad(0.50, 1, 0.80, 1, 1.30, 0, 1.00, 0);
  static final Path lambdaLeft = _quad(0.65, 1, 0.95, 1, 1.45, 0, 1.15, 0);
  static final Path lambdaRight = _quad(1.15, 0, 1.45, 0, 1.95, 1, 1.65, 1);

  static Path _quad(
    double x1, double y1, double x2, double y2,
    double x3, double y3, double x4, double y4,
  ) =>
      Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x3, y3)
        ..lineTo(x4, y4)
        ..close();
}

/// Colours for each part of the monogram.
class MonogramPalette {
  const MonogramPalette({
    required this.vLeft,
    required this.vRightTop,
    required this.vRightBottom,
    required this.lambdaLeft,
    required this.lambdaApex,
    required this.lambdaBase,
  });

  /// Every stroke the same colour (used for the splash N).
  const MonogramPalette.solid(Color color)
      : vLeft = color,
        vRightTop = color,
        vRightBottom = color,
        lambdaLeft = color,
        lambdaApex = color,
        lambdaBase = color;

  /// Logo colours — splash screen only.
  static const splash = MonogramPalette(
    vLeft: AppColors.logoGreen,
    vRightTop: AppColors.logoGreen,
    vRightBottom: AppColors.logoGreenDeep,
    lambdaLeft: AppColors.logoCream,
    lambdaApex: AppColors.logoCharcoal,
    lambdaBase: AppColors.logoCream,
  );

  /// App-palette version for ivory backgrounds.
  static const app = MonogramPalette(
    vLeft: AppColors.botanicalGreen,
    vRightTop: AppColors.botanicalGreen,
    vRightBottom: AppColors.botanicalGreen,
    lambdaLeft: AppColors.softSage,
    lambdaApex: AppColors.charcoal,
    lambdaBase: AppColors.softSage,
  );

  final Color vLeft;
  final Color vRightTop;
  final Color vRightBottom;
  final Color lambdaLeft;
  final Color lambdaApex;
  final Color lambdaBase;
}

/// Paints the monogram centred in its canvas, scaled to the canvas height.
///
/// [mirrored] draws the horizontal mirror image (the N).
/// [spread] pushes the V left and the Λ right by that many pixels each.
class VerixaMonogramPainter extends CustomPainter {
  const VerixaMonogramPainter({
    required this.palette,
    this.mirrored = false,
    this.spread = 0,
  });

  final MonogramPalette palette;
  final bool mirrored;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    if (h <= 0) return;
    final left = (size.width - MonogramGeometry.width * h) / 2;
    final unitSpread = spread / h;

    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas
      ..translate(left, 0)
      ..scale(h);

    // Λ first, so the V's right arm overlaps it like the logo's ribbon fold.
    canvas
      ..save()
      ..translate(unitSpread, 0);
    _drawStroke(canvas, MonogramGeometry.lambdaLeft, _solid(palette.lambdaLeft));
    _drawStroke(canvas, MonogramGeometry.lambdaRight, _solid(palette.lambdaBase));
    canvas
      ..save()
      ..clipRect(const Rect.fromLTRB(-1, -1, 3, MonogramGeometry.apexSplit));
    _drawStroke(canvas, MonogramGeometry.lambdaRight, _solid(palette.lambdaApex));
    canvas
      ..restore()
      ..restore();

    // V.
    canvas
      ..save()
      ..translate(-unitSpread, 0);
    final vRightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [palette.vRightBottom, palette.vRightTop],
        stops: const [0.0, 0.65],
      ).createShader(const Rect.fromLTWH(0, 0, 2, 1));
    _drawStroke(canvas, MonogramGeometry.vRight, vRightPaint);
    _drawStroke(canvas, MonogramGeometry.vLeft, _solid(palette.vLeft));
    canvas
      ..restore()
      ..restore();
  }

  Paint _solid(Color color) => Paint()..color = color;

  /// Fills the shape, then strokes it with a round join to soften corners.
  void _drawStroke(Canvas canvas, Path path, Paint paint) {
    paint
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = MonogramGeometry.cornerRounding
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(VerixaMonogramPainter old) =>
      old.palette != palette || old.mirrored != mirrored || old.spread != spread;
}

/// The VΛ monogram as a widget, sized by [height].
class VerixaMonogram extends StatelessWidget {
  const VerixaMonogram({
    super.key,
    required this.height,
    this.palette = MonogramPalette.app,
  });

  final double height;
  final MonogramPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(MonogramGeometry.width * height, height),
      painter: VerixaMonogramPainter(palette: palette),
    );
  }
}
