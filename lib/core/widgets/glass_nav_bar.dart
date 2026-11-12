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
/// translucent ivory + strong background blur + a thin light edge. No glow,
/// no heavy shadow (CLAUDE.md §2).
class GlassNavBar extends StatelessWidget {
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
  });

  final GlassNavItem left;
  final GlassNavItem right;

  /// 0 = left item active, 1 = right item active.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCentreTap;

  /// Whether the centre menu is open (the button turns into a close ×).
  final bool centreOpen;
  final IconData centreIcon;
  final String centreLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.navPillSide, 0, AppSizes.navPillSide,
          bottomInset + AppSizes.navPillGap),
      child: GlassPill(
        child: SizedBox(
          height: AppSizes.navPillHeight,
          child: LayoutBuilder(builder: (context, c) {
            final side = (c.maxWidth - AppSizes.navCentreButton - 2 * AppSpacing.md) / 2;
            return Stack(
              children: [
                // The sliding "selected" bubble.
                AnimatedPositioned(
                  duration: AppMotion.page,
                  curve: Curves.easeOutBack,
                  // Centred under the item (items are side + 6 wide).
                  left: currentIndex == 0 ? 3 : c.maxWidth - side - 3,
                  top: 6,
                  bottom: 6,
                  width: side,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.botanicalGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.navPillHeight),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: side + 6,
                      child: _SideItem(
                        item: left,
                        active: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    const Spacer(),
                    _CentreButton(
                      icon: centreIcon,
                      label: centreLabel,
                      open: centreOpen,
                      onTap: onCentreTap,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: side + 6,
                      child: _SideItem(
                        item: right,
                        active: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
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
              color: AppColors.ivory.withValues(alpha: AppSizes.glassOpacity),
              borderRadius: _radius,
              border: Border.all(color: AppColors.white.withValues(alpha: 0.65)),
            ),
            // A thin highlight across the top, as light catches glass.
            foregroundDecoration: BoxDecoration(
              borderRadius: _radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.white.withValues(alpha: 0.28),
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
          child: CentreScanButton(icon: widget.icon, open: widget.open),
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
