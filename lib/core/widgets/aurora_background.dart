import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The living background behind every screen: soft, slightly blurred green
/// leaves drifting down across the ivory in a light breeze, swaying and
/// slowly turning; as one leaves the screen another enters from the top.
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

/// One leaf. Positions and speeds are in logical pixels / seconds; the
/// starting point is a share of the screen so leaves are spread out.
class _Leaf {
  const _Leaf({
    required this.x0,
    required this.y0,
    required this.size,
    required this.fall,
    required this.drift,
    required this.sway,
    required this.swayPeriod,
    required this.spin,
    required this.color,
    required this.alpha,
    required this.phase,
  });

  final double x0, y0; // start, share of screen width / height
  final double size; // leaf length
  final double fall; // downward speed
  final double drift; // sideways speed (the breeze)
  final double sway; // side-to-side swing
  final double swayPeriod; // seconds per swing
  final double spin; // turns per second (negative = anticlockwise)
  final Color color;
  final double alpha;
  final double phase;
}

/// A fixed set, spread over the screen with varied sizes and speeds so the
/// motion looks natural but never repeats in an obvious way.
final List<_Leaf> _leaves = () {
  final rnd = math.Random(11);
  const colors = [
    AppColors.botanicalGreen,
    AppColors.softSage,
    AppColors.botanicalGreen,
    AppColors.splashBgTop,
  ];
  return [
    for (var i = 0; i < 14; i++)
      _Leaf(
        x0: rnd.nextDouble(),
        y0: rnd.nextDouble(),
        size: 26 + rnd.nextDouble() * 38,
        fall: 34 + rnd.nextDouble() * 38,
        drift: 10 + rnd.nextDouble() * 22,
        sway: 14 + rnd.nextDouble() * 26,
        swayPeriod: 3.2 + rnd.nextDouble() * 3.0,
        spin: (rnd.nextBool() ? 1 : -1) * (0.04 + rnd.nextDouble() * 0.10),
        color: colors[i % colors.length],
        alpha: colors[i % colors.length] == AppColors.splashBgTop
            ? 0.22
            : 0.38 + rnd.nextDouble() * 0.20,
        phase: rnd.nextDouble() * 2 * math.pi,
      ),
  ];
}();

/// Ivory with the drifting leaves behind [child].
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
            child: CustomPaint(painter: _LeafPainter(state)),
          ),
        ),
        child,
      ],
    );
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.state) : super(repaint: state);

  final AuroraState? state;

  /// A leaf of length 1 pointing up: an almond shape with a pointed tip and
  /// a short stem, built once and scaled per leaf.
  static final Path _shape = Path()
    ..moveTo(0, -0.5)
    ..quadraticBezierTo(0.34, -0.12, 0.0, 0.42)
    ..quadraticBezierTo(-0.34, -0.12, 0, -0.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ivory);
    final t = state?.time ?? 0;
    final w = size.width, h = size.height;
    for (final leaf in _leaves) {
      // Fall and drift, wrapping around so leaves keep coming from the top.
      final margin = leaf.size * 1.5;
      final travelY = h + 2 * margin;
      final travelX = w + 2 * margin;
      final y = (leaf.y0 * travelY + leaf.fall * t) % travelY - margin;
      final sway = leaf.sway * math.sin(2 * math.pi * t / leaf.swayPeriod + leaf.phase);
      final x = (leaf.x0 * travelX + leaf.drift * t + sway) % travelX - margin;
      // Turns slowly, and tilts with each swing like a falling leaf.
      final angle = 2 * math.pi * leaf.spin * t +
          0.5 * math.cos(2 * math.pi * t / leaf.swayPeriod + leaf.phase) +
          leaf.phase;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.scale(leaf.size);
      final paint = Paint()
        ..color = leaf.color.withValues(alpha: leaf.alpha)
        // Soft, slightly out-of-focus edges (blur is in leaf units here).
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 / leaf.size);
      canvas.drawPath(_shape, paint);
      // A faint midrib.
      canvas.drawLine(
        const Offset(0, -0.42),
        const Offset(0, 0.38),
        Paint()
          ..color = AppColors.ivory.withValues(alpha: 0.35)
          ..strokeWidth = 0.035
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.state != state;
}
