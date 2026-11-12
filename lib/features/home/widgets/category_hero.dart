import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../companies/domain/company_category.dart';

/// Shared Hero for a company type: the green card on Home and the green
/// header on the category page. While flying, only the green shape moves
/// (growing and reshaping its corners); each end's text fades on its own,
/// which reads as the card expanding into the page.
class CategoryHero extends StatelessWidget {
  const CategoryHero({
    super.key,
    required this.category,
    required this.radius,
    required this.child,
  });

  final CompanyCategory category;

  /// Corner radii of this end (card: all corners; header: bottom only).
  final BorderRadius radius;
  final Widget child;

  static Object tag(CompanyCategory c) => 'category-hero-${c.id}';

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag(category),
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) {
            final from = (fromContext.widget as Hero).child as _HeroBody;
            final to = (toContext.widget as Hero).child as _HeroBody;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                final t = curved.value;
                // The page being left fades its content out fast; the arriving
                // page's content waits until the shape has mostly landed.
                final card = direction == HeroFlightDirection.push ? from : to;
                final header = direction == HeroFlightDirection.push
                    ? to
                    : from;
                final r = BorderRadius.lerp(card.radius, header.radius, t)!;
                return Material(
                  color: AppColors.botanicalGreen,
                  borderRadius: r,
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: (1 - t * 3).clamp(0.0, 1.0),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxHeight: double.infinity,
                      child: Transform.scale(
                        scale: lerpDouble(1, 1.04, t)!,
                        alignment: Alignment.topLeft,
                        child: card.child,
                      ),
                    ),
                  ),
                );
              },
            );
          },
      child: _HeroBody(radius: radius, child: child),
    );
  }
}

/// What the Hero carries: the corner shape (read by the flight) and the
/// visible content.
class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.radius, required this.child});

  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The green header of a category page; its content fades and lifts in
/// once the Hero has landed.
class CategoryHeader extends StatelessWidget {
  const CategoryHeader({
    super.key,
    required this.category,
    required this.onBack,
  });

  final CompanyCategory category;
  final VoidCallback onBack;

  static const radius = BorderRadius.only(
    bottomLeft: Radius.circular(28),
    bottomRight: Radius.circular(28),
  );

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ivory.withValues(alpha: 0.8);
    final top = MediaQuery.paddingOf(context).top;
    return CategoryHero(
      category: category,
      radius: radius,
      child: Material(
        color: AppColors.botanicalGreen,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            top + AppSpacing.xs,
            AppSpacing.pageGutter,
            AppSpacing.xl,
          ),
          child: StaggeredEntrance(
            index: 0,
            initialDelay: const Duration(milliseconds: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.ivory,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  tooltip: 'Back',
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.ivory.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(category.icon, color: AppColors.ivory, size: 26),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${category.title} companies',
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  category.description,
                  style: AppTypography.bodyLarge.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
