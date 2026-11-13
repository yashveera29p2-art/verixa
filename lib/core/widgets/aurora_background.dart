import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The living background behind every screen: soft, faded ribbons of brand
/// green drifting across the ivory, each one slowly stretching and
/// shrinking in length and swelling and thinning in width, like an aurora.
/// Purely ambient (it doesn't react to touch).
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

/// The clock that drives the ribbons (seconds since the app opened).
class AuroraState extends ChangeNotifier {
  double time = 0;
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    time += ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    notifyListeners();
  }
}

/// One ribbon: where it lies, how it waves, and how its length and width
/// breathe over time. Distances are shares of the screen.
class _Ribbon {
  const _Ribbon({
    required this.y,
    required this.tilt,
    required this.thickness,
    required this.color,
    required this.alpha,
    required this.phase,
    required this.speed,
  });

  final double y; // resting height of the centre line (0 top – 1 bottom)
  final double tilt; // how much it slopes across the screen
  final double thickness; // average width (share of screen height)
  final Color color;
  final double alpha; // strength at its brightest (0–1)
  final double phase;
  final double speed; // 1 = base pace; slow and calm overall
}

const _ribbons = [
  _Ribbon(y: 0.16, tilt: 0.10, thickness: 0.22, color: AppColors.botanicalGreen,
      alpha: 0.58, phase: 0.0, speed: 1.00),
  _Ribbon(y: 0.46, tilt: -0.14, thickness: 0.26, color: AppColors.softSage,
      alpha: 0.62, phase: 2.2, speed: 0.80),
  _Ribbon(y: 0.78, tilt: 0.12, thickness: 0.22, color: AppColors.botanicalGreen,
      alpha: 0.50, phase: 4.1, speed: 0.90),
  // A thin, faint deep-green ribbon for depth.
  _Ribbon(y: 0.62, tilt: 0.06, thickness: 0.09, color: AppColors.splashBgTop,
      alpha: 0.22, phase: 1.1, speed: 1.15),
];

/// Ivory with the drifting ribbons behind [child].
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
            child: CustomPaint(painter: _RibbonPainter(state)),
          ),
        ),
        child,
      ],
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.state) : super(repaint: state);

  final AuroraState? state;

  static const _samples = 36;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ivory);
    final t = state?.time ?? 0;
    for (final r in _ribbons) {
      _paintRibbon(canvas, size, r, t * r.speed);
    }
  }

  void _paintRibbon(Canvas canvas, Size size, _Ribbon r, double t) {
    final w = size.width, h = size.height;
    final p = r.phase;

    // Length: the ribbon spans 90–150% of the width (so it reads as one
    // long band that runs off the edges) and its middle drifts left and
    // right, so it visibly stretches and shrinks.
    final span = w * (1.2 + 0.3 * math.sin(t / 17 + p));
    final mid = w * (0.5 + 0.22 * math.sin(t / 23 + p * 1.7));
    final x0 = mid - span / 2, x1 = mid + span / 2;

    // Width: swells and thins over time, and varies along the ribbon.
    final baseThickness = h * r.thickness * (0.65 + 0.35 * math.sin(t / 13 + p * 2.3));

    final top = <Offset>[], bottom = <Offset>[];
    for (var i = 0; i <= _samples; i++) {
      final u = i / _samples; // 0 → 1 along the ribbon
      final x = x0 + span * u;
      final nx = x / w;
      // Centre line: a slow wave plus a slower counter-wave, sloped.
      final y = h *
          (r.y +
              r.tilt * (nx - 0.5) +
              0.045 * math.sin(2 * math.pi * nx * 1.1 + t / 9 + p) +
              0.025 * math.sin(2 * math.pi * nx * 2.3 - t / 14 + p * 0.7));
      // Thicker in the middle, tapering to points at the ends, with a
      // gentle ripple along its length.
      final taper = math.pow(math.sin(math.pi * u), 0.45).toDouble();
      final ripple = 0.75 + 0.25 * math.sin(2 * math.pi * u * 1.6 + t / 7 + p);
      final half = baseThickness * taper * ripple / 2;
      top.add(Offset(x, y - half));
      bottom.add(Offset(x, y + half));
    }
    final path = Path()..addPolygon([...top, ...bottom.reversed], true);

    final paint = Paint()
      // Fade along its length: clear at both ends.
      ..shader = ui.Gradient.linear(
        Offset(x0, 0),
        Offset(x1, 0),
        [
          r.color.withValues(alpha: 0),
          r.color.withValues(alpha: r.alpha),
          r.color.withValues(alpha: r.alpha),
          r.color.withValues(alpha: 0),
        ],
        const [0, 0.18, 0.82, 1],
      )
      // Fade across its width: very soft edges.
      ..maskFilter = MaskFilter.blur(
          BlurStyle.normal, (baseThickness * 0.28).clamp(10.0, 52.0));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.state != state;
}
