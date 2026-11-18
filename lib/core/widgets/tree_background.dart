import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Recruiter side: switched on while the recruiter screens are open.
final recruiterBackground = ValueNotifier<bool>(false);

/// A large, softly blurred tree on ivory that sways in a light breeze:
/// branches bend more towards the top. Recruiters see the tree the falling
/// leaves (student side) come from.
///
/// The tree is drawn once into two images (wood, foliage); each frame only
/// bends them with a skew, so it's very cheap to animate.
class TreePainter extends CustomPainter {
  TreePainter(this.time) : super(repaint: time);

  /// Seconds, from the shared aurora clock.
  final ValueNotifier<double> time;

  static ui.Image? _wood, _foliage;
  static Size _builtFor = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ivory);
    if (size.isEmpty) return;
    if (_builtFor != size) _build(size);
    final t = time.value;
    final base = Offset(size.width * 0.62, size.height * 1.02);

    void layer(ui.Image img, double amount, double phase) {
      // Gentle, slightly irregular breeze.
      final sway = math.sin(t * 0.55 + phase) * 0.8 + math.sin(t * 1.3 + phase) * 0.2;
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.skew(sway * amount, 0);
      canvas.translate(-base.dx, -base.dy);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
      canvas.restore();
    }

    layer(_wood!, 0.018, 0);
    layer(_foliage!, 0.030, 0.6);
  }

  static void _build(Size size) {
    const scale = 0.5; // half resolution: it's blurred anyway
    final w = (size.width * scale).ceil(), h = (size.height * scale).ceil();
    final rnd = math.Random(7);
    final segments = <(Offset, Offset, double)>[];
    final tips = <Offset>[];

    void branch(Offset from, double angle, double length, double width, int depth) {
      final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
      segments.add((from, to, width));
      if (depth == 0 || length < 12) {
        tips.add(to);
        return;
      }
      final spread = 0.32 + rnd.nextDouble() * 0.22;
      final shrink = 0.70 + rnd.nextDouble() * 0.08;
      branch(to, angle - spread, length * shrink, width * 0.68, depth - 1);
      branch(to, angle + spread * 0.9, length * shrink * 0.94, width * 0.66, depth - 1);
      if (depth > 3 && rnd.nextDouble() < 0.45) {
        branch(to, angle + (rnd.nextDouble() - 0.5) * 0.3, length * 0.6, width * 0.5, depth - 2);
      }
    }

    final root = Offset(w * 0.62, h * 1.02);
    branch(root, -math.pi / 2 - 0.05, h * 0.30, w * 0.07, 7);

    ui.Image draw(void Function(Canvas c) paint) {
      final rec = ui.PictureRecorder();
      paint(Canvas(rec));
      return rec.endRecording().toImageSync(w, h);
    }

    _wood = draw((c) {
      final p = Paint()
        ..color = AppColors.charcoal.withValues(alpha: 0.16)
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      for (final (a, b, width) in segments) {
        c.drawLine(a, b, p..strokeWidth = width);
      }
    });
    _foliage = draw((c) {
      const colors = [AppColors.botanicalGreen, AppColors.softSage, AppColors.botanicalGreen];
      final blur = MaskFilter.blur(BlurStyle.normal, w * 0.022);
      for (final tip in tips) {
        for (var k = 0; k < 3; k++) {
          final o = tip + Offset((rnd.nextDouble() - 0.5) * w * 0.07, (rnd.nextDouble() - 0.6) * w * 0.07);
          c.drawCircle(
            o,
            w * (0.028 + rnd.nextDouble() * 0.03),
            Paint()
              ..color = colors[(k + tip.dx.round()) % colors.length].withValues(alpha: 0.16)
              ..maskFilter = blur,
          );
        }
      }
    });
    _builtFor = size;
  }

  @override
  bool shouldRepaint(TreePainter old) => false;
}
