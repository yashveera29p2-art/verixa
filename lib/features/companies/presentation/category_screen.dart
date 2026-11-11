import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme.dart';
import '../domain/company_category.dart';

/// Company list for one category. Phase 3 shows a placeholder; Phase 4
/// fills it from assets/data/companies.json.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final CompanyCategory category;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.xs,
            AppSpacing.pageGutter,
            AppSpacing.xl,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(category.icon,
                  color: AppColors.botanicalGreen, size: 32),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('${category.title} companies',
                style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              category.description,
              style:
                  AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.stone),
              ),
              child: Text(
                'Company list and resume patterns are coming in the next update.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
