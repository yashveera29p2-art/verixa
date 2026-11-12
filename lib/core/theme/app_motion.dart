import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/aurora_background.dart';

/// Motion tokens: one timing and easing language for the whole app.
///
/// Calm and quick, never bouncy: pages settle in ~320 ms, small feedback
/// (taps, fades) in 120–200 ms.
abstract final class AppMotion {
  /// Taps and small state changes.
  static const short = Duration(milliseconds: 140);

  /// Fades between tabs and content states.
  static const medium = Duration(milliseconds: 220);

  /// Page pushes and bottom sheets.
  static const page = Duration(milliseconds: 320);
  static const pageReverse = Duration(milliseconds: 260);

  /// Decelerating ease for things arriving; gentle ease for leaving.
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  /// How far a pressed card or button shrinks.
  static const pressScale = 0.96;

  static const sheet = AnimationStyle(
    duration: page,
    reverseDuration: pageReverse,
    curve: enter,
    reverseCurve: exit,
  );
}

/// Page transition: the new page fades in while rising slightly; the page
/// underneath dims a touch and drifts back. Used for every route.
class VerixaPageTransitionsBuilder extends PageTransitionsBuilder {
  const VerixaPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    // Each page carries its own ivory + aurora background, so pages stay
    // opaque during transitions (the aurora shares one clock, so it looks
    // continuous from page to page).
    child = AuroraBackground(child: child);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.85).animate(outgoing),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.985).animate(outgoing),
        child: FadeTransition(
          opacity: incoming,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(incoming),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tactile press for cards, rows and buttons: the child dips to 96% with
/// a light haptic tick when touched, and springs back when released. A
/// quick tap still shows the full dip before springing back. Doesn't
/// consume the tap: the child's own InkWell / button still fires (and
/// draws the green ripple).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 380),
  );
  late final _scale = Tween<double>(begin: 1, end: AppMotion.pressScale).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.elasticOut),
  );
  bool _down = false;

  void _press() {
    if (!widget.enabled) return;
    _down = true;
    HapticFeedback.lightImpact();
    _c.forward();
  }

  Future<void> _release() async {
    if (!_down) return;
    _down = false;
    // Let a quick tap finish its dip so it's visible, then spring back.
    if (_c.status == AnimationStatus.forward) await _c.forward();
    if (mounted && !_down) _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Switch between tab pages: the new tab fades in while sliding a little
/// from the side you moved towards (Home → Profile comes from the right)
/// and settling from 98% scale. Keeps every tab alive (like IndexedStack).
class FadeThroughStack extends StatefulWidget {
  const FadeThroughStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: AppMotion.page, value: 1);
  late final _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);
  double _direction = 1;

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _direction = widget.index > old.index ? 1 : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(28 * _direction * (1 - t), 0),
            child: Transform.scale(scale: 0.98 + 0.02 * t, child: child),
          ),
        );
      },
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}

/// Fades and lifts its child into place when it first appears, starting
/// [index] steps after the first one, so lists and page sections arrive
/// one after another instead of all at once.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.initialDelay = Duration.zero,
  });

  final int index;
  final Widget child;

  /// Extra wait before the first item (e.g. to let a page transition land).
  final Duration initialDelay;

  static const step = Duration(milliseconds: 55);
  static const maxSteps = 8;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final _curve = CurvedAnimation(parent: _c, curve: AppMotion.enter);

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, StaggeredEntrance.maxSteps);
    Future.delayed(widget.initialDelay + StaggeredEntrance.step * steps, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps each widget in a [StaggeredEntrance], in order — for a page's
/// list of sections: `ListView(children: staggered([...]))`.
List<Widget> staggered(List<Widget> children) => [
      for (var i = 0; i < children.length; i++)
        StaggeredEntrance(index: i, child: children[i]),
    ];
