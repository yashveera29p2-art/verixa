import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// One side item of the bar (Home, Profile).
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Floating frosted-glass pill (iOS style) at the bottom of the main tabs.
///
/// Layout: [left item] [centre scan button] [right item]. A soft green
/// bubble slides under the active item; icons bounce when tapped. Glass =
/// very translucent ivory + strong background blur + a thin green rim.
///
/// With [playIntro], the pill starts as a halo around the centre button
/// and springs outward to full width (overshoot, settle, slight squash),
/// then the icons rise in. Used right after the splash, where the V lands
/// in the centre button.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.currentIndex,
    required this.onTap,
    required this.onCentreTap,
    this.centreOpen = false,
    this.centreIcon = Icons.document_scanner_outlined,
    this.centreLabel = 'Resume actions',
    this.playIntro = false,
    this.introDelay = Duration.zero,
  });

  final GlassNavItem left;
  final GlassNavItem right;

  /// 0 = left item active, 1 = right item active.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCentreTap;

  /// Whether the centre menu is open (the button turns into a close x).
  final bool centreOpen;
  final IconData centreIcon;
  final String centreLabel;
  final bool playIntro;
  final Duration introDelay;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

/// A damped spring: rises fast, overshoots ~10%, wobbles once and settles
/// at 1.
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) =>
      1 - math.exp(-6.5 * t) * math.cos(10.5 * t);
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: widget.playIntro ? 0 : 1,
  );
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    if (widget.playIntro) {
      _waiting = true;
      Future.delayed(widget.introDelay, () {
        if (!mounted) return;
        setState(() => _waiting = false);
        _intro.forward();
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.navPillSide, 0, AppSizes.navPillSide,
          bottomInset + AppSizes.navPillGap),
      child: SizedBox(
        height: AppSizes.navPillHeight + 8, // room for the bounce
        child: LayoutBuilder(builder: (context, c) {
          final full = c.maxWidth;
          final content = _content(full);
          return AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              if (_waiting) return const SizedBox.shrink();
              final t = _intro.value;
              // 1. a green glass bubble appears and settles into the button;
              final bubble = (t / 0.34).clamp(0.0, 1.0);
              // 2. the glass pill springs out sideways from it;
              final grow = ((t - 0.30) / 0.70).clamp(0.0, 1.0);
              final spring = const _SpringCurve().transform(grow);
              const start = AppSizes.navCentreButton + 14;
              final width = start + (full - start) * spring;
              // Squash-and-stretch: a little flat as it stretches out,
              // a little tall as it snaps back.
              final scaleY = 1 + 0.07 * math.sin(math.pi * grow * 2) * (1 - grow);
              // 3. then Home and Profile rise in.
              final items = const Interval(0.38, 0.85, curve: Curves.easeOutCubic)
                  .transform(grow);
              final pillWidth = width.clamp(start, full * 1.06);
              return Align(
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scaleY: scaleY,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: pillWidth,
                    height: AppSizes.navPillHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (grow > 0)
                          Opacity(
                            opacity: (grow * 5).clamp(0.0, 1.0),
                            child: const GlassPill(child: SizedBox.expand()),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.navPillHeight),
                          child: OverflowBox(
                            minWidth: full,
                            maxWidth: full,
                            child: _IntroItems(
                              progress: items,
                              bubble: bubble,
                              child: content,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _content(double width) {
    final w = widget;
    final side = (width - AppSizes.navCentreButton - 2 * AppSpacing.md) / 2;
    return Stack(
      children: [
        // The sliding "selected" bubble.
        AnimatedPositioned(
          duration: AppMotion.page,
          curve: Curves.easeOutBack,
          // Centred under the item (items are side + 6 wide).
          left: w.currentIndex == 0 ? 3 : width - side - 3,
          top: 6,
          bottom: 6,
          width: side,
          child: _SideFade(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.botanicalGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.navPillHeight),
              ),
            ),
          ),
        ),
        Row(
          children: [
            SizedBox(
              width: side + 6,
              child: _SideFade(
                child: _SideItem(
                  item: w.left,
                  active: w.currentIndex == 0,
                  onTap: () => w.onTap(0),
                ),
              ),
            ),
            const Spacer(),
            _CentreButton(
              icon: w.centreIcon,
              label: w.centreLabel,
              open: w.centreOpen,
              onTap: w.onCentreTap,
            ),
            const Spacer(),
            SizedBox(
              width: side + 6,
              child: _SideFade(
                child: _SideItem(
                  item: w.right,
                  active: w.currentIndex == 1,
                  onTap: () => w.onTap(1),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Passes the intro's "items" progress down to the side items.
class _IntroItems extends InheritedWidget {
  const _IntroItems({required this.progress, this.bubble = 1, required super.child});

  final double progress;

  /// Centre button: 0 = not there yet, 1 = solid button.
  final double bubble;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IntroItems>()?.progress ?? 1;

  static double bubbleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IntroItems>()?.bubble ?? 1;

  @override
  bool updateShouldNotify(_IntroItems old) =>
      old.progress != progress || old.bubble != bubble;
}

/// Side items and the bubble fade and rise in during the intro.
class _SideFade extends StatelessWidget {
  const _SideFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = _IntroItems.of(context);
    if (p >= 1) return child;
    return Opacity(
      opacity: p,
      child: Transform.translate(offset: Offset(0, 10 * (1 - p)), child: child),
    );
  }
}

/// The frosted capsule: blur, translucent ivory, a thin light rim and a
/// faint top sheen, with a very soft lift shadow.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.child});

  final Widget child;

  static final _radius = BorderRadius.circular(AppSizes.navPillHeight);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppSizes.glassBlur, sigmaY: AppSizes.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              // Very light frosting: most of the colour comes from what's
              // blurred behind, which is what makes it read as glass.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withValues(alpha: AppSizes.glassOpacity + 0.12),
                  AppColors.ivory.withValues(alpha: AppSizes.glassOpacity),
                ],
              ),
              borderRadius: _radius,
              // The thin botanical-green line around the pill.
              border: Border.all(
                color: AppColors.botanicalGreen.withValues(alpha: 0.75),
                width: 1,
              ),
            ),
            // A thin highlight across the top, as light catches glass.
            foregroundDecoration: BoxDecoration(
              borderRadius: _radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.white.withValues(alpha: 0.45),
                  AppColors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bounces its child (shrink → overshoot → settle) each time [trigger] changes.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0.8).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.14).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween<double>(begin: 1.14, end: 1).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
  ]).animate(_c);

  @override
  void didUpdateWidget(_Bounce old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

class _SideItem extends StatefulWidget {
  const _SideItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  int _taps = 0;

  void _tap() {
    HapticFeedback.selectionClick();
    setState(() => _taps++);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color = active ? AppColors.botanicalGreen : AppColors.mutedText;
    return Semantics(
      selected: active,
      button: true,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: _Bounce(
          trigger: _taps,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.short,
                child: Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  key: ValueKey(active),
                  color: color,
                  size: AppSizes.navIcon,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppMotion.medium,
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green circle in the middle. Bounces when tapped; its icon turns into a
/// close × while the menu is open.
class _CentreButton extends StatefulWidget {
  const _CentreButton({
    required this.icon,
    required this.label,
    required this.open,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_CentreButton> createState() => _CentreButtonState();
}

class _CentreButtonState extends State<_CentreButton> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.open ? 'Close' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _taps++);
          widget.onTap();
        },
        child: _Bounce(
          trigger: _taps,
          child: _BubbleIn(
            child: CentreScanButton(icon: widget.icon, open: widget.open),
          ),
        ),
      ),
    );
  }
}

/// The visual of the centre button (also drawn by the branch menu, so the
/// button looks continuous while the menu is open).
class CentreScanButton extends StatelessWidget {
  const CentreScanButton({super.key, required this.icon, required this.open});

  final IconData icon;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.navCentreButton,
      height: AppSizes.navCentreButton,
      decoration: const BoxDecoration(
        color: AppColors.botanicalGreen,
        shape: BoxShape.circle,
      ),
      child: AnimatedRotation(
        turns: open ? 0.125 : 0,
        duration: AppMotion.page,
        curve: Curves.easeOutBack,
        child: AnimatedSwitcher(
          duration: AppMotion.short,
          child: Icon(
            open ? Icons.add : icon,
            key: ValueKey(open),
            color: AppColors.ivory,
            size: open ? 30 : 26,
          ),
        ),
      ),
    );
  }
}


/// The centre button's entrance: a translucent green glass bubble pops in
/// (with a small overshoot), then turns solid as the icon appears.
class _BubbleIn extends StatelessWidget {
  const _BubbleIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = _IntroItems.bubbleOf(context);
    if (b >= 1) return child;
    final pop = const _SpringCurve().transform((b / 0.7).clamp(0.0, 1.0));
    final solid = Curves.easeOutCubic.transform(((b - 0.55) / 0.45).clamp(0.0, 1.0));
    const size = AppSizes.navCentreButton;
    return SizedBox.square(
      dimension: size,
      child: Transform.scale(
        scale: pop,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Green glass.
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.botanicalGreen.withValues(alpha: 0.30),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
            // …turning into the solid button.
            Opacity(
              opacity: solid,
              child: Transform.scale(scale: 0.85 + 0.15 * solid, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
