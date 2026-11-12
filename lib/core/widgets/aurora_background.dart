import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The living background behind every ivory screen: three very large,
/// very soft green glows drifting slowly, like light through leaves.
///
/// - Touch: the nearest glow eases towards the finger and swells a little.
/// - Drag / scroll: the glows drift with the movement, then settle back.
///
/// One [AuroraScope] at the top of the app owns the clock and listens to
/// every touch, so the motion is continuous from screen to screen; each
/// screen draws it with an [AuroraBackground].
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
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _state._touch(e.position, down: true),
      onPointerMove: (e) => _state._drag(e.position, e.delta),
      onPointerUp: (_) => _state._release(),
      onPointerCancel: (_) => _state._release(),
      child: _AuroraInherited(notifier: _state, child: widget.child),
    );
  }
}

class _AuroraInherited extends InheritedNotifier<AuroraState> {
  const _AuroraInherited({required super.notifier, required super.child});
}

/// One glow: where it wanders (a slow Lissajous loop over the screen, in
/// 0–1 coordinates) and how big it is (share of the screen's long side).
class _Glow {
  _Glow(this.cx, this.cy, this.ax, this.ay, this.px, this.py, this.phase, this.radius);

  final double cx, cy, ax, ay; // centre and amplitude of the loop
  final double px, py; // loop periods in seconds
  final double phase;
  final double radius;

  // Touch reaction, eased every frame.
  Offset pull = Offset.zero; // towards the finger (pixels)
  Offset drift = Offset.zero; // from dragging (pixels)
  double swell = 0; // 0–1

  Offset base(double t, Size s) => Offset(
        s.width * (cx + ax * math.sin(2 * math.pi * t / px + phase)),
        s.height * (cy + ay * math.cos(2 * math.pi * t / py + phase * 1.3)),
      );
}

class AuroraState extends ChangeNotifier {
  final List<_Glow> _glows = [
    _Glow(0.20, 0.18, 0.18, 0.10, 23, 29, 0.0, 0.62),
    _Glow(0.82, 0.48, 0.14, 0.16, 31, 19, 2.1, 0.55),
    _Glow(0.35, 0.86, 0.20, 0.08, 27, 37, 4.2, 0.60),
  ];

  double _time = 0;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  Offset? _finger;
  int _target = -1;
  Offset _dragVelocity = Offset.zero;

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;
    for (var i = 0; i < _glows.length; i++) {
      final g = _glows[i];
      // Pull towards the finger for the touched glow, back to 0 otherwise.
      Offset pullTarget = Offset.zero;
      if (_finger != null && i == _target && _size != Size.zero) {
        pullTarget = (_finger! - g.base(_time, _size)) * 0.35;
      }
      g.pull = Offset.lerp(g.pull, pullTarget, (dt * 2.2).clamp(0.0, 1.0))!;
      g.swell += ((i == _target && _finger != null ? 1.0 : 0.0) - g.swell) *
          (dt * 3).clamp(0.0, 1.0);
      // Drag pushes every glow a little (nearer ones more), then it relaxes.
      g.drift = Offset.lerp(g.drift, Offset.zero, (dt * 1.2).clamp(0.0, 1.0))! +
          _dragVelocity * (0.18 + 0.1 * i);
    }
    _dragVelocity = Offset.zero;
    notifyListeners();
  }

  void _touch(Offset p, {required bool down}) {
    _finger = p;
    if (_size == Size.zero) return;
    var best = double.infinity;
    for (var i = 0; i < _glows.length; i++) {
      final d = (_glows[i].base(_time, _size) - p).distanceSquared;
      if (d < best) {
        best = d;
        _target = i;
      }
    }
  }

  void _drag(Offset p, Offset delta) {
    _finger = p;
    // Clamp so a fast fling can't throw the glows off screen.
    final limit = 40.0;
    _dragVelocity += Offset(delta.dx.clamp(-limit, limit), delta.dy.clamp(-limit, limit));
  }

  void _release() => _finger = null;

  /// Where each glow is right now (for the painter).
  List<(Offset, double)> glowsFor(Size size) {
    _size = size;
    final long = math.max(size.width, size.height);
    return [
      for (final g in _glows)
        (
          g.base(_time, size) + g.pull + Offset(g.drift.dx.clamp(-120, 120), g.drift.dy.clamp(-160, 160)),
          long * g.radius * (1 + 0.12 * g.swell),
        ),
    ];
  }
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
  static const _alpha = 0.075;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.ivory);
    final s = state;
    if (s == null) return;
    for (final (centre, radius) in s.glowsFor(size)) {
      final glow = Rect.fromCircle(center: centre, radius: radius);
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
          ).createShader(glow),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.state != state;
}
