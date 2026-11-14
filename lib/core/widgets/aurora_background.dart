import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../platform/web_bridge.dart';
import '../theme/theme.dart';

/// The living background behind every screen: soft, slightly blurred green
/// leaves drifting down across the ivory in a light breeze, swaying and
/// slowly turning; as one leaves the screen another enters from the top.
/// Tilting the phone shifts the leaves the other way (bigger, nearer leaves
/// more), giving a 3D "looking through a window" depth. No touch reaction.
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

/// The clock that drives the leaves (seconds since the app opened), plus
/// the phone's smoothed tilt for the parallax.
class AuroraState extends ChangeNotifier {
  AuroraState() {
    if (kIsWeb) {
      // Browser (iPhone web app): Safari gives tilt angles instead.
      _webSensor = orientationStream().listen((o) {
        _targetTilt = Offset(
          -math.sin(o.gamma * math.pi / 180).clamp(-1.0, 1.0),
          (math.sin(o.beta * math.pi / 180) - 6.5 / 9.81).clamp(-1.0, 1.0),
        );
      });
      return;
    }
    try {
      _sensor = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(
        (e) {
          // Gravity along the screen's x/y axes, as a share of g (−1…1).
          _targetTilt = Offset(
            (e.x / 9.81).clamp(-1.0, 1.0),
            ((e.y - 6.5) / 9.81).clamp(-1.0, 1.0), // relative to holding it upright-ish
          );
        },
        onError: (_) {}, // no sensor: leaves just don't tilt
        cancelOnError: true,
      );
    } catch (_) {}
  }

  double time = 0;
  Duration _last = Duration.zero;
  StreamSubscription<AccelerometerEvent>? _sensor;
  StreamSubscription<Object?>? _webSensor;
  Offset _targetTilt = Offset.zero;

  /// Smoothed tilt (−1…1 on each axis).
  Offset tilt = Offset.zero;

  /// Lite mode: switched on automatically when the phone can't keep up
  /// (half the leaves, no soft-focus blur), so slow phones stay smooth.
  bool lite = false;
  double _avgFrame = 1 / 60;
  int _slowFrames = 0;

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    final dt = raw.clamp(0.0, 0.05);
    _last = elapsed;
    _watchSpeed(raw);
    time += dt;
    // Ease towards the latest reading so the motion is fluid, not jittery.
    tilt = Offset.lerp(tilt, _targetTilt, (dt * 5).clamp(0.0, 1.0))!;
    notifyListeners();
  }

  void _watchSpeed(double raw) {
    if (lite || raw <= 0 || raw > 0.5) return; // ignore pauses (app hidden)
    _avgFrame = _avgFrame * 0.95 + raw * 0.05;
    // Averaging under ~40 fps for about 3 seconds: go lite for good.
    _slowFrames = _avgFrame > 1 / 40 ? _slowFrames + 1 : 0;
    if (_slowFrames > 120) lite = true;
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _webSensor?.cancel();
    super.dispose();
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
    final tilt = state?.tilt ?? Offset.zero;
    final w = size.width, h = size.height;
    final lite = state?.lite ?? false;
    for (var i = 0; i < _leaves.length; i++) {
      if (lite && i.isOdd) continue;
      final leaf = _leaves[i];
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

      // Parallax: nearer (bigger) leaves shift more against the tilt.
      final depth = ((leaf.size - 26) / 38).clamp(0.0, 1.0) * 0.7 + 0.3;
      final shift = Offset(-tilt.dx * 40 * depth, tilt.dy * 40 * depth);

      canvas.save();
      canvas.translate(x + shift.dx, y + shift.dy);
      canvas.rotate(angle);
      // The soft-edged leaf is drawn once into an image and reused every
      // frame: much cheaper than blurring 14 shapes 60 times a second.
      final sprite = _sprite(i, leaf);
      final side = leaf.size + _pad;
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        _spritePaint,
      );
      canvas.restore();
    }
  }

  static const _pad = 16.0; // room for the blurred edge
  static const _spriteScale = 2.5; // sharp on high-density screens
  static final _sprites = <int, ui.Image>{};
  static final _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  static ui.Image _sprite(int i, _Leaf leaf) => _sprites[i] ??= () {
        final side = leaf.size + _pad;
        final recorder = ui.PictureRecorder();
        final c = Canvas(recorder)
          ..scale(_spriteScale)
          ..translate(side / 2, side / 2)
          ..scale(leaf.size);
        c.drawPath(
          _shape,
          Paint()
            ..color = leaf.color.withValues(alpha: leaf.alpha)
            // Soft, slightly out-of-focus edges (blur is in leaf units).
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 / leaf.size),
        );
        // A faint midrib.
        c.drawLine(
          const Offset(0, -0.42),
          const Offset(0, 0.38),
          Paint()
            ..color = AppColors.ivory.withValues(alpha: 0.35)
            ..strokeWidth = 0.035
            ..strokeCap = StrokeCap.round,
        );
        final px = (side * _spriteScale).ceil();
        return recorder.endRecording().toImageSync(px, px);
      }();

  @override
  bool shouldRepaint(_LeafPainter old) => old.state != state;
}
