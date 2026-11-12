import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../companies/domain/company_category.dart';
import 'category_hero.dart';

/// A prominent botanical green card for one company type (MNC / SME /
/// Startup): line icon, ivory serif title, one-line description.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final CompanyCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ivory.withValues(alpha: 0.8);
    return Semantics(
      button: true,
      label: '${category.title}. ${category.description}',
      excludeSemantics: true,
      child: PressScale(
        child: CategoryHero(
          category: category,
          radius: BorderRadius.circular(AppRadius.lg),
          child: Material(
            color: AppColors.botanicalGreen,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              splashColor: AppColors.ivory.withValues(alpha: 0.12),
              highlightColor: AppColors.ivory.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    _IconFrame(icon: category.icon),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.ivory,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            category.description,
                            style: AppTypography.bodyMedium.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward, color: muted, size: 20),
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

/// Thin ivory outline around the category's line icon.
class _IconFrame extends StatelessWidget {
  const _IconFrame({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.ivory.withValues(alpha: 0.4),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Icon(icon, color: AppColors.ivory, size: 26),
    );
  }
}
