import 'package:flutter/material.dart';

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
  static const pressScale = 0.97;

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

/// Shrinks its child slightly while pressed, for tactile buttons and cards.
/// Doesn't consume the tap: the child's own InkWell / button still fires.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (widget.enabled && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? AppMotion.pressScale : 1,
        duration: AppMotion.short,
        curve: _down ? AppMotion.enter : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Fade-through between tab pages: the new tab fades in while scaling up
/// from 98%. Keeps every tab alive (like IndexedStack).
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
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(_curve),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
