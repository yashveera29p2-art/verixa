import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A picture of a screen, broken into a grid of coloured cells.
/// Each cell becomes one particle in [ParticleDissolve].
class ParticleGrid {
  const ParticleGrid({
    required this.columns,
    required this.rows,
    required this.cell,
    required this.colors,
  });

  final int columns;
  final int rows;

  /// Cell size in logical pixels.
  final double cell;

  /// ARGB colour of each cell, row by row.
  final Int32List colors;

  /// Captures [boundary] at one pixel per [cell] logical pixels.
  static Future<ParticleGrid?> capture(
    RenderRepaintBoundary boundary, {
    double cell = 7,
  }) async {
    try {
      final image = await boundary.toImage(pixelRatio: 1 / cell);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width, h = image.height;
      image.dispose();
      if (data == null || w == 0 || h == 0) return null;
      final rgba = data.buffer.asUint8List();
      final colors = Int32List(w * h);
      for (var i = 0; i < w * h; i++) {
        final r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
        colors[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
      }
      return ParticleGrid(columns: w, rows: h, cell: cell, colors: colors);
    } catch (_) {
      return null; // effect is decorative; callers fall back to a fade
    }
  }
}

/// Paints [grid] as tiny squares that, as [progress] goes 0 → 1, break
/// apart from the centre, drift outward, shrink and fade — revealing
/// whatever is underneath.
class ParticleDissolve extends StatefulWidget {
  const ParticleDissolve({
    super.key,
    required this.grid,
    required this.progress,
  });

  final ParticleGrid grid;
  final Animation<double> progress;

  @override
  State<ParticleDissolve> createState() => _ParticleDissolveState();
}

class _ParticleDissolveState extends State<ParticleDissolve> {
  late _Particles _particles;

  @override
  void initState() {
    super.initState();
    _particles = _Particles(widget.grid);
  }

  @override
  void didUpdateWidget(ParticleDissolve old) {
    super.didUpdateWidget(old);
    if (old.grid != widget.grid) _particles = _Particles(widget.grid);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DissolvePainter(_particles, widget.progress),
        ),
      ),
    );
  }
}

/// Per-particle constants, computed once.
class _Particles {
  _Particles(this.grid) {
    final n = grid.columns * grid.rows;
    originX = Float32List(n);
    originY = Float32List(n);
    dx = Float32List(n);
    dy = Float32List(n);
    delay = Float32List(n);
    final rnd = math.Random(7);
    final cx = grid.columns * grid.cell / 2, cy = grid.rows * grid.cell / 2;
    final maxDist = math.sqrt(cx * cx + cy * cy);
    for (var r = 0; r < grid.rows; r++) {
      for (var c = 0; c < grid.columns; c++) {
        final i = r * grid.columns + c;
        final x = (c + 0.5) * grid.cell, y = (r + 0.5) * grid.cell;
        originX[i] = x;
        originY[i] = y;
        final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        // Outward from the centre, with some scatter.
        final angle = math.atan2(y - cy, x - cx) + (rnd.nextDouble() - 0.5) * 1.1;
        final travel = 30 + rnd.nextDouble() * 120 + dist * 0.18;
        dx[i] = math.cos(angle) * travel;
        dy[i] = math.sin(angle) * travel - rnd.nextDouble() * 18;
        // The centre breaks first, the edges a moment later.
        delay[i] = (dist / maxDist) * 0.28 + rnd.nextDouble() * 0.14;
      }
    }
    positions = Float32List(n * 12);
    colors = Int32List(n * 6);
  }

  final ParticleGrid grid;
  late final Float32List originX, originY, dx, dy, delay;
  late final Float32List positions; // 2 triangles × 3 vertices × (x, y)
  late final Int32List colors; // 6 vertices per particle
}

class _DissolvePainter extends CustomPainter {
  _DissolvePainter(this.p, this.progress) : super(repaint: progress);

  final _Particles p;
  final Animation<double> progress;
  final _paint = Paint();

  static const _life = 0.58; // share of the animation each particle lives

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t >= 1) return;
    final grid = p.grid;
    // Scale the captured grid to this canvas (should already match).
    final sx = size.width / (grid.columns * grid.cell);
    final sy = size.height / (grid.rows * grid.cell);
    final n = grid.columns * grid.rows;
    final pos = p.positions, col = p.colors;
    final base = grid.cell * 0.5 + 0.35; // slight overlap → solid at t = 0

    for (var i = 0; i < n; i++) {
      final local = ((t - p.delay[i]) / _life).clamp(0.0, 1.0);
      final move = Curves.easeOutCubic.transform(local);
      final half = base * (1 - 0.65 * local);
      final alpha = ((1 - Curves.easeIn.transform(local)) * 255).round();
      final x = (p.originX[i] + p.dx[i] * move) * sx;
      final y = (p.originY[i] + p.dy[i] * move) * sy;
      final l = x - half, r = x + half, top = y - half, b = y + half;
      final o = i * 12;
      pos[o] = l; pos[o + 1] = top; pos[o + 2] = r; pos[o + 3] = top;
      pos[o + 4] = l; pos[o + 5] = b; pos[o + 6] = r; pos[o + 7] = top;
      pos[o + 8] = r; pos[o + 9] = b; pos[o + 10] = l; pos[o + 11] = b;
      final c = (alpha << 24) | (grid.colors[i] & 0x00FFFFFF);
      final k = i * 6;
      col[k] = c; col[k + 1] = c; col[k + 2] = c;
      col[k + 3] = c; col[k + 4] = c; col[k + 5] = c;
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, pos, colors: col);
    canvas.drawVertices(vertices, BlendMode.dst, _paint);
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_DissolvePainter old) => old.p != p;
}
