import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The living background behind every screen: ivory with three very large,
/// very soft green glows drifting slowly and endlessly, like light through
/// leaves. Purely ambient (it doesn't react to touch).
///
/// [AuroraScope] at the top of the app owns the clock; [AuroraBackground]
/// paints it once, behind the whole app, so it never restarts or jumps
/// when pages change.
class AuroraScope extends StatefulWidget {
  const AuroraScope({super.key, required this.child});

  final Widget child;

  static AuroraState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AuroraInherited>()?.notifier;

  @override
  State<AuroraScope> createState() => _AuroraScopeState();
}

class _AuroraScopeState extends State<AuroraScope> with SingleTickerProviderStateMixin {
  final _state = AuroraState();
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_state._tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _AuroraInherited(notifier: _state, child: widget.child);
}

class _AuroraInherited extends InheritedNotifier<AuroraState> {
  const _AuroraInherited({required super.notifier, required super.child});
}

/// One glow. It wanders on two layered slow waves with unrelated periods
/// (so the path never visibly repeats) and gently breathes in size.
class _Glow {
  const _Glow({
    required this.cx,
    required this.cy,
    required this.ax,
    required this.ay,
    required this.px,
    required this.py,
    required this.phase,
    required this.radius,
  });

  final double cx, cy; // resting point (0–1 of the screen)
  final double ax, ay; // how far it wanders (0–1 of the screen)
  final double px, py; // main wave periods, seconds
  final double phase;
  final double radius; // share of the screen's long side

  Offset position(double t, Size s) {
    double wave(double period, double p) =>
        math.sin(2 * math.pi * t / period + p) +
        0.45 * math.sin(2 * math.pi * t / (period * 0.37) + p * 2.3);
    return Offset(
      s.width * (cx + ax * wave(px, phase) / 1.45),
      s.height * (cy + ay * wave(py, phase + 1.7) / 1.45),
    );
  }

  double size(double t, Size s) =>
      math.max(s.width, s.height) * radius * (1 + 0.10 * math.sin(t / 7.3 + phase));
}

class AuroraState extends ChangeNotifier {
  static const _glows = [
    _Glow(cx: 0.22, cy: 0.20, ax: 0.20, ay: 0.12, px: 23, py: 29, phase: 0.0, radius: 0.62),
    _Glow(cx: 0.80, cy: 0.50, ax: 0.16, ay: 0.18, px: 31, py: 19, phase: 2.1, radius: 0.55),
    _Glow(cx: 0.35, cy: 0.85, ax: 0.22, ay: 0.10, px: 27, py: 37, phase: 4.2, radius: 0.60),
  ];

  double _time = 0;
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    _time += ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    notifyListeners();
  }

  /// Where each glow is right now, and how big.
  List<(Offset, double)> glowsFor(Size size) => [
        for (final g in _glows) (g.position(_time, size), g.size(_time, size)),
      ];
}

/// Ivory with the drifting green glows behind [child].
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AuroraScope.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _AuroraPainter(state)),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.state) : super(repaint: state);

  final AuroraState? state;

  /// Peak strength of a glow's centre ("very subtle").
  static const _alpha = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.ivory);
    final s = state;
    if (s == null) return;
    for (final (centre, radius) in s.glowsFor(size)) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.botanicalGreen.withValues(alpha: _alpha),
              AppColors.botanicalGreen.withValues(alpha: _alpha * 0.45),
              AppColors.botanicalGreen.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.state != state;
}
