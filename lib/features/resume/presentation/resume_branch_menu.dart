import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathMetric;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/glass_nav_bar.dart';

/// The centre button's menu: a stem grows up from the button like a
/// seedling, splits into three branches, and an option card opens at the
/// tip of each one. Tap outside (or the ×) and it folds back down.
Future<void> showResumeBranchMenu(BuildContext context) async {
  final router = GoRouter.of(context);
  final route = await Navigator.of(context, rootNavigator: true).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 680),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, _) => _BranchMenu(animation: animation),
    ),
  );
  if (route != null) router.push(route);
}

class _Option {
  const _Option(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

const _options = [
  _Option(Icons.edit_note_outlined, 'Create resume', 'From your profile',
      AppRoutes.resumes),
  _Option(Icons.document_scanner_outlined, 'Upload & scan', 'Security + ATS check',
      AppRoutes.resumeScan),
  _Option(Icons.compare_arrows, 'Match a job', 'Compare with a JD',
      AppRoutes.jdMatch),
];

/// Where everything sits, from the screen size.
class _Geometry {
  _Geometry(Size size, EdgeInsets padding) {
    final cx = size.width / 2;
    button = Offset(cx, size.height - padding.bottom - AppSizes.navPillGap - AppSizes.navPillHeight / 2);
    stemBase = button.translate(0, -AppSizes.navCentreButton / 2 - 2);
    joint = button.translate(0, -84);
    final spread = math.min(size.width * 0.29, 130.0);
    tips = [
      Offset(cx - spread, button.dy - 196),
      Offset(cx, button.dy - 332),
      Offset(cx + spread, button.dy - 196),
    ];
    cardWidth = math.min(124, size.width * 0.31);
  }

  late final Offset button, stemBase, joint;
  late final List<Offset> tips;
  late final double cardWidth;

  Path stem() => Path()
    ..moveTo(stemBase.dx, stemBase.dy)
    ..lineTo(joint.dx, joint.dy);

  Path branch(int i) {
    final tip = tips[i];
    final p = Path()..moveTo(joint.dx, joint.dy);
    if (i == 1) return p..lineTo(tip.dx, tip.dy + 4);
    return p
      ..cubicTo(joint.dx, joint.dy - 46, tip.dx, tip.dy + 62, tip.dx, tip.dy + 4);
  }
}

class _BranchMenu extends StatelessWidget {
  const _BranchMenu({required this.animation});

  final Animation<double> animation;

  static Animation<double> _part(Animation<double> a, double from, double to,
          [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(
        parent: a,
        curve: Interval(from, to, curve: curve),
        reverseCurve: Interval(from, to, curve: Curves.easeInCubic),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final g = _Geometry(mq.size, mq.padding);
    final backdrop = _part(animation, 0, 0.4);
    final stem = _part(animation, 0, 0.32);
    final branches = _part(animation, 0.26, 0.62);
    final leaves = _part(animation, 0.5, 0.78, Curves.easeOutBack);
    final cards = [
      _part(animation, 0.46, 0.86, Curves.easeOutBack),
      _part(animation, 0.52, 0.93, Curves.easeOutBack),
      _part(animation, 0.58, 1.0, Curves.easeOutBack),
    ];
    void close() => Navigator.of(context).pop();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Frosted, dimmed backdrop; tap anywhere to close.
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              child: AnimatedBuilder(
                animation: backdrop,
                builder: (context, _) => BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 7 * backdrop.value, sigmaY: 7 * backdrop.value),
                  child: ColoredBox(
                    color: AppColors.ivory.withValues(alpha: 0.55 * backdrop.value),
                  ),
                ),
              ),
            ),
          ),
          // Stem, branches and leaves.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TreePainter(g, stem, branches, leaves),
              ),
            ),
          ),
          for (var i = 0; i < 3; i++)
            _OptionCard(
              option: _options[i],
              tip: g.tips[i],
              width: g.cardWidth,
              animation: cards[i],
              onTap: () => Navigator.of(context).pop(_options[i].route),
            ),
          // The centre button, now a close ×, sitting exactly over the bar's.
          Positioned(
            left: g.button.dx - AppSizes.navCentreButton / 2,
            top: g.button.dy - AppSizes.navCentreButton / 2,
            child: GestureDetector(
              onTap: close,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => CentreScanButton(
                  icon: Icons.document_scanner_outlined,
                  open: animation.status != AnimationStatus.reverse &&
                      animation.value > 0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter(this.g, this.stem, this.branches, this.leaves)
      : super(repaint: Listenable.merge([stem, branches, leaves]));

  final _Geometry g;
  final Animation<double> stem, branches, leaves;

  static final _line = Paint()
    ..color = AppColors.botanicalGreen
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round;
  static final _leaf = Paint()..color = AppColors.botanicalGreen;

  /// The first [t] share of [path], so it looks like it's growing.
  static Path _grow(Path path, double t) {
    final out = Path();
    for (final PathMetric m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (stem.value <= 0) return;
    canvas.drawPath(_grow(g.stem(), stem.value.clamp(0, 1)), _line);
    final b = branches.value.clamp(0.0, 1.0);
    if (b > 0) {
      for (var i = 0; i < 3; i++) {
        canvas.drawPath(_grow(g.branch(i), b), _line);
      }
    }
    // Two small leaves on each side branch, one on the stem.
    final l = leaves.value;
    if (l <= 0) return;
    void leaf(Path path, double at, double side) {
      final m = path.computeMetrics().first;
      final tan = m.getTangentForOffset(m.length * at);
      if (tan == null) return;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(-tan.angle + side * 0.9);
      canvas.scale(l.clamp(0, 1.2));
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -side * 7), width: 7, height: 15), _leaf);
      canvas.restore();
    }

    leaf(g.stem(), 0.55, 1);
    leaf(g.branch(0), 0.45, -1);
    leaf(g.branch(2), 0.45, 1);
    leaf(g.branch(1), 0.5, -1);
  }

  @override
  bool shouldRepaint(_TreePainter old) => false;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.tip,
    required this.width,
    required this.animation,
    required this.onTap,
  });

  final _Option option;
  final Offset tip;
  final double width;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: tip.dx - width / 2,
      width: width,
      bottom: MediaQuery.sizeOf(context).height - tip.dy - 4,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)),
              child: Transform.scale(
                scale: 0.4 + 0.6 * t,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
        child: PressScale(
          child: Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: const BorderSide(color: AppColors.stone),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.botanicalGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(option.icon, color: AppColors.ivory, size: 22),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(option.title,
                        textAlign: TextAlign.center,
                        style: AppTypography.labelLarge.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(option.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
