import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/verixa_monogram.dart';
import '../../core/utils/server_warmup.dart';
import 'splash_exit.dart';
import 'splash_timings.dart';
import 'wordmark_layout.dart';
import 'startup_provider.dart';

/// Plays the N → VΛ → VERIXA animation, then moves to the next screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<String> _destination;

  @override
  void initState() {
    super.initState();
    // Wake the backend now so OTP / scans are fast later.
    warmUpServer();
    // Start the session check now so it runs while the animation plays.
    _destination = ref.read(startupDestinationProvider.future);
    _controller = AnimationController(
      vsync: this,
      duration: SplashTimings.controllerDuration,
    )..addStatusListener(_onStatus);
    _start();
  }

  /// Starts the animation only once the first frame is on screen and the
  /// fonts are ready. Otherwise a slow cold start can make the controller
  /// jump straight to the end and skip the animation.
  Future<void> _start() async {
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    await AppTypography.ensureLoaded();
    if (mounted) _controller.forward();
  }

  Future<void> _onStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    final route = await _destination;
    if (!mounted) return;
    // The next screen plays the exit: letters fade, Λ flies up, V drops
    // into the centre button.
    SplashExit.hold();
    context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.1,
              colors: [AppColors.splashBgTop, AppColors.splashBgBottom],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _SplashScene(t: _controller.value),
          ),
        ),
      ),
    );
  }
}

/// One frame of the splash, drawn from the controller value [t] (0 → 1).
class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.t});

  final double t;

  static final _fadeIn = SplashTimings.interval(0, SplashTimings.nFadeInEnd);
  static final _flip = SplashTimings.interval(
      SplashTimings.flipStart, SplashTimings.flipEnd, Curves.easeInOut);
  static final _slide = SplashTimings.interval(
      SplashTimings.slideStart, SplashTimings.slideEnd, Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final layout = WordmarkLayout(constraints.biggest);
      final slide = _slide.transform(t);
      final flipAngle = _flip.transform(t) * math.pi;

      final h = lerpDouble(layout.startHeight, layout.finalHeight, slide)!;
      final spread = layout.finalSpread * slide;
      final monogramTop = layout.center.dy - h / 2;

      return Opacity(
        opacity: _fadeIn.transform(t),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: monogramTop,
              height: h,
              child: _FlippingMonogram(angle: flipAngle, spread: spread),
            ),
            Positioned(
              left: layout.lettersLeft,
              top: layout.center.dy - layout.finalHeight / 2,
              child: Baseline(
                baseline: layout.finalHeight,
                baselineType: TextBaseline.alphabetic,
                child: _TypedLetters(
                  style: layout.letterStyle,
                  visible: SplashTimings.lettersVisibleAt(
                      t * SplashTimings.total),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Green N for the first half of the flip, coloured VΛ for the second half.
/// At 90° the glyph is edge-on, so the swap is invisible.
class _FlippingMonogram extends StatelessWidget {
  const _FlippingMonogram({required this.angle, required this.spread});

  final double angle;
  final double spread;

  @override
  Widget build(BuildContext context) {
    final showN = angle < math.pi / 2;
    final rotation = showN ? angle : angle - math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015) // perspective
        ..rotateY(rotation),
      child: CustomPaint(
        size: Size.infinite,
        painter: VerixaMonogramPainter(
          palette: showN
              ? const MonogramPalette.solid(AppColors.logoGreen)
              : MonogramPalette.splash,
          mirrored: showN,
          spread: spread,
        ),
      ),
    );
  }
}

/// E R I X, with untyped letters kept in place but transparent so the
/// layout never shifts while typing.
class _TypedLetters extends StatelessWidget {
  const _TypedLetters({required this.style, required this.visible});

  final TextStyle style;
  final int visible;

  @override
  Widget build(BuildContext context) {
    const letters = SplashTimings.typedLetters;
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < letters.length; i++)
          TextSpan(
            text: letters[i],
            style: i < visible
                ? style
                : style.copyWith(color: AppColors.logoCream.withValues(alpha: 0)),
          ),
      ]),
      textScaler: TextScaler.noScaling,
      semanticsLabel: 'Verixa',
    );
  }
}
