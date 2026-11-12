import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../application/company_providers.dart';
import '../domain/company.dart';
import 'widgets/company_avatar.dart';
import 'widgets/detail_sections.dart';

/// What one company expects and the resume pattern that suits it.
class CompanyDetailScreen extends ConsumerWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyByIdProvider(companyId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(),
        body: company.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.botanicalGreen),
          ),
          error: (_, _) => const _NotFound(),
          data: (c) => c == null ? const _NotFound() : _Body(company: c),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.company});

  final Company company;

  void _buildResume(BuildContext context) =>
      context.push(AppRoutes.resumeNewFor(company.id));

  @override
  Widget build(BuildContext context) {
    final e = company.expectations;
    final p = company.resumePattern;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.xs,
                AppSpacing.pageGutter,
                AppSpacing.xl,
              ),
              children: [
                _Header(company: company),
                const SizedBox(height: AppSpacing.xl),

                const SectionTitle('What they look for'),
                const SizedBox(height: AppSpacing.md),
                const SubHeading('Skills'),
                ChipWrap(items: e.skills),
                const SizedBox(height: AppSpacing.lg),
                InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Academics',
                  text: e.academics,
                ),
                InfoRow(
                  icon: Icons.work_history_outlined,
                  label: 'Experience',
                  text: e.experience,
                ),
                const SizedBox(height: AppSpacing.sm),
                const SubHeading('Traits'),
                ChipWrap(items: e.traits),
                const SizedBox(height: AppSpacing.xl),

                ResumePatternCard(pattern: p),
                const SizedBox(height: AppSpacing.xl),

                GuidanceNote(
                  sources: company.sources,
                  lastReviewed: company.lastReviewed,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.sm,
              AppSpacing.pageGutter,
              AppSpacing.md,
            ),
            child: AppButton(
              label: 'Build a resume for this company type',
              onPressed: () => _buildResume(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CompanyAvatar(initials: company.initials, domain: company.logoDomain, size: 60),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company.name, style: AppTypography.headlineMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${company.category.title} · ${company.sector}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.botanicalGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          company.summary,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pageGutter),
      child: Text(
        'We couldn’t find this company.',
        style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
      ),
    );
  }
}
