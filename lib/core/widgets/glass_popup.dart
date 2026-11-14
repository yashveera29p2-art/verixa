
import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Shows [builder] as a floating glass panel that grows out of the widget
/// at [origin] (e.g. the button that opened it) and shrinks back into it
/// when closed.
///
/// [size] picks the panel's size from the screen size; it is centred.
/// [frost] = 1 is the nav-bar glass; higher values are frostier (more like
/// iOS sheets).
Future<T?> showGlassPopup<T>({
  required BuildContext origin,
  required Size Function(Size screen) size,
  required WidgetBuilder builder,
  double radius = AppSizes.navPillHeight / 2,
  double frost = 1,
  double rimWidth = 1,
  bool dismissible = true,
}) {
  final box = origin.findRenderObject() as RenderBox?;
  final from = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  return showGeneralDialog<T>(
    context: origin,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: AppColors.charcoal.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) => const SizedBox.shrink(),
    transitionBuilder: (context, animation, _, _) {
      final screen = MediaQuery.sizeOf(context);
      final panel = size(screen);
      final target = Rect.fromCenter(
        center: screen.center(Offset.zero),
        width: panel.width,
        height: panel.height,
      );
      final start = from ?? target;
      final grow = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      );
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = grow.value;
          // Start the panel squeezed onto the button, then open it out.
          final sx =
              (start.width / target.width) +
              (1 - start.width / target.width) * t;
          final sy =
              (start.height / target.height) +
              (1 - start.height / target.height) * t;
          final shift = Offset.lerp(
            start.center - target.center,
            Offset.zero,
            t,
          )!;
          return Stack(
            children: [
              Positioned.fromRect(
                rect: target,
                child: Transform.translate(
                  offset: shift,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(sx, sy, 1),
                    child: Opacity(opacity: fade.value, child: child),
                  ),
                ),
              ),
            ],
          );
        },
        child: GlassPanel(
          radius: radius,
          frost: frost,
          rimWidth: rimWidth,
          child: Builder(builder: builder),
        ),
      );
    },
  );
}

/// Frosted glass surface with a green rim, as used by the nav pill.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppSizes.navPillHeight / 2,
    this.frost = 1,
    this.rimWidth = 1,
  });

  final Widget child;
  final double radius;
  final double frost;
  final double rimWidth;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final opacity = (AppSizes.glassOpacity * frost).clamp(0.0, 0.9);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: AppGlass.filter(AppSizes.glassBlur * frost),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withValues(
                    alpha: AppGlass.fill(opacity + 0.14),
                  ),
                  AppColors.ivory.withValues(alpha: AppGlass.fill(opacity)),
                ],
              ),
              border: Border.all(
                color: AppColors.botanicalGreen.withValues(
                  alpha: rimWidth > 1.5 ? 1 : 0.8,
                ),
                width: rimWidth,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.white.withValues(alpha: 0.30),
                  AppColors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
                Positioned.fill(child: SpecularRim(radius: radius)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
