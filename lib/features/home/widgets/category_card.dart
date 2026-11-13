import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../companies/domain/company_category.dart';
import 'category_hero.dart';

/// One company type on Home (MNC / SME / Startup) as a see-through glass
/// card: a light frosting and gentle blur, so the drifting leaves stay
/// visible behind it, with a thin botanical-green rim, green text and a
/// green outline icon. Compact: title, full name below it, one short line.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    this.square = false,
  });

  final CompanyCategory category;
  final VoidCallback onTap;

  /// Square bento tile (icon and arrow on top, text below) instead of the
  /// wide row.
  final bool square;

  static final _radius = BorderRadius.circular(AppRadius.lg);

  @override
  Widget build(BuildContext context) {
    const green = AppColors.botanicalGreen;
    final fullName = category.fullName;
    return Semantics(
      button: true,
      label: [category.title, ?fullName, category.description].join('. '),
      excludeSemantics: true,
      child: PressScale(
        child: CategoryHero(
          category: category,
          radius: _radius,
          child: ClipRRect(
            borderRadius: _radius,
            child: BackdropFilter(
              // Light blur: the leaves behind stay recognisable.
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Material(
                type: MaterialType.transparency,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white.withValues(alpha: 0.34),
                        AppColors.ivory.withValues(alpha: 0.18),
                      ],
                    ),
                    border: Border.all(color: green.withValues(alpha: 0.75)),
                  ),
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: _radius,
                    child: square ? _square(fullName) : _wide(fullName),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on CategoryCard {
  static const _green = AppColors.botanicalGreen;

  Widget _title() => Text(
        category.title,
        style: AppTypography.headlineMedium.copyWith(color: _green, height: 1.1),
      );

  Widget _fullName(String name) => Text(
        name,
        style: AppTypography.labelMedium
            .copyWith(color: _green, fontSize: 11.5, letterSpacing: 0.2),
      );

  Widget _description({int? maxLines}) => Text(
        category.description,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(
          color: _green.withValues(alpha: 0.85),
          fontSize: 12,
          height: 1.35,
        ),
      );

  /// Wide row: icon · text · arrow.
  Widget _wide(String? fullName) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            _IconFrame(icon: category.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _title(),
                  if (fullName != null) _fullName(fullName),
                  const SizedBox(height: 3),
                  _description(),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.arrow_forward, color: _green, size: 18),
          ],
        ),
      );

  /// Square tile: icon and arrow on top, text anchored to the bottom.
  Widget _square(String? fullName) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconFrame(icon: category.icon),
                const Spacer(),
                const Icon(Icons.arrow_forward, color: _green, size: 18),
              ],
            ),
            const Spacer(),
            _title(),
            if (fullName != null) _fullName(fullName),
            const SizedBox(height: 4),
            _description(maxLines: 4),
          ],
        ),
      );
}

/// Green line icon in a thin green outlined square.
class _IconFrame extends StatelessWidget {
  const _IconFrame({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.botanicalGreen, width: 1.2),
      ),
      child: Icon(icon, color: AppColors.botanicalGreen, size: 22),
    );
  }
}
