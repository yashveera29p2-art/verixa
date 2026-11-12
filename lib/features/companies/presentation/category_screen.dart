import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../application/company_providers.dart';
import '../domain/company_category.dart';
import '../../home/widgets/category_hero.dart';
import 'widgets/company_tile.dart';

/// List of companies in one category (MNC / SME / Startup).
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  final CompanyCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesByCategoryProvider(category));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CategoryHeader(
                category: category,
                onBack: () => context.pop(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            ...companies.when(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.botanicalGreen,
                    ),
                  ),
                ),
              ],
              error: (error, _) => [
                SliverToBoxAdapter(
                  child: _Message(
                    text: 'Couldn’t load companies. Please try again.',
                    actionLabel: 'Retry',
                    onAction: () =>
                        ref.invalidate(companiesByCategoryProvider(category)),
                  ),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      const SliverToBoxAdapter(
                        child: _Message(
                          text: 'No companies in this category yet.',
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageGutter,
                          0,
                          AppSpacing.pageGutter,
                          AppSpacing.xl,
                        ),
                        sliver: SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => StaggeredEntrance(
                            index: i,
                            initialDelay: const Duration(milliseconds: 320),
                            child: CompanyTile(
                              company: list[i],
                              onTap: () => context.push(
                                AppRoutes.companyDetail(
                                  category.id,
                                  list[i].id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.botanicalGreen,
                textStyle: AppTypography.labelLarge,
                padding: EdgeInsets.zero,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
