import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../companies/application/company_providers.dart';
import '../companies/domain/company.dart';
import '../companies/presentation/widgets/company_avatar.dart';
import '../profile/application/profile_providers.dart';
import '../profile/domain/profile_data.dart';
import '../reviews/reviews.dart';

/// Prep tab: pick a company to prepare for.
class PrepScreen extends ConsumerStatefulWidget {
  const PrepScreen({super.key});

  @override
  ConsumerState<PrepScreen> createState() => _PrepScreenState();
}

class _PrepScreenState extends ConsumerState<PrepScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(allCompaniesProvider).value ?? const <Company>[];
    final shown = companies
        .where((c) => _filter.isEmpty || c.name.toLowerCase().contains(_filter))
        .toList();
    final navInset = AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.pageGutter, AppSpacing.lg,
              AppSpacing.pageGutter, navInset + AppSpacing.lg),
          children: [
            Text('Placement prep', style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Interview rounds, topics to study and common questions for '
              'each company, with a checklist from your own skill gaps.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search companies',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final c in shown) ...[
              PressScale(
                child: Material(
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: const BorderSide(color: AppColors.stone),
                  ),
                  child: ListTile(
                    onTap: () => context.push(AppRoutes.prepFor(c.id)),
                    leading: CompanyAvatar(initials: c.initials, domain: c.logoDomain, size: 40),
                    title: Text(c.name, style: AppTypography.labelLarge),
                    subtitle: Text(
                      '${c.category.title} · ${c.insights.prep.rounds.length} rounds',
                      style: AppTypography.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.softSage),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// Preparation for one company.
class PrepCompanyScreen extends ConsumerWidget {
  const PrepCompanyScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyByIdProvider(companyId)).value;
    final profile = ref.watch(profileDataProvider).value;
    if (company == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.botanicalGreen)),
      );
    }
    final prep = company.insights.prep;
    final gaps = skillGaps(company, profile);

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter, 0, AppSpacing.pageGutter, AppSpacing.xxl),
        children: staggered([
          Row(
            children: [
              CompanyAvatar(initials: company.initials, domain: company.logoDomain),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Prepare for ${company.name}',
                    style: AppTypography.headlineLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Your checklist',
            child: gaps.isEmpty
                ? Text(
                    profile == null
                        ? 'Fill your Skills in Profile to see what to work on.'
                        : 'Your profile already covers the skills they usually '
                            'ask for. Practise the topics below.',
                    style: AppTypography.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not in your profile yet:', style: AppTypography.bodySmall),
                      const SizedBox(height: AppSpacing.xxs),
                      for (final g in gaps) _Bullet(g, icon: Icons.radio_button_unchecked),
                    ],
                  ),
          ),
          _Section(
            title: 'Hiring process',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < prep.rounds.length; i++)
                  _Bullet(prep.rounds[i], number: i + 1),
              ],
            ),
          ),
          _Section(
            title: 'Topics to study',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final t in prep.topics) _Bullet(t)],
            ),
          ),
          _Section(
            title: 'Commonly asked',
            child: Column(
              children: [
                for (final q in prep.questions)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(q, style: AppTypography.bodyMedium),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            'Answer out loud in under 2 minutes, then refine. '
                            'Use an example from your own projects where you can.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'What they look for',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in company.expectations.skills) _Bullet(s),
                TextButton(
                  onPressed: () => context.push(
                      AppRoutes.companyDetail(company.category.id, company.id)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('See the resume pattern that suits them →'),
                ),
              ],
            ),
          ),
          CompanyReviewsSection(company: company),
          const SizedBox(height: AppSpacing.md),
          Text(
            'General preparation guidance from public hiring patterns, not '
            'an official statement from the company. Processes change; check '
            'the actual drive or posting.',
            style: AppTypography.bodySmall,
          ),
        ]),
      ),
    );
  }
}

/// Skills the company usually asks for that the profile doesn't mention.
List<String> skillGaps(Company company, ProfileData? profile) {
  if (profile == null) return const [];
  final have = [
    ...profile.skills.technical,
    ...profile.skills.tools,
    ...profile.skills.soft,
    for (final p in profile.projects) ...p.techStack,
  ].map((s) => s.toLowerCase()).toList();
  bool covered(String need) {
    final words = RegExp(r'[a-z+#]{2,}')
        .allMatches(need.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => !const {'and', 'or', 'the', 'of', 'in', 'basics', 'skills', 'with'}.contains(w));
    return words.any((w) => have.any((h) => h.contains(w) || w.contains(h) && h.length > 2));
  }
  return company.expectations.skills.where((s) => !covered(s)).toList();
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            child,
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.number, this.icon});

  final String text;
  final int? number;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: number != null
                  ? Text('$number.',
                      style: AppTypography.labelLarge.copyWith(color: AppColors.botanicalGreen))
                  : Icon(icon ?? Icons.circle, size: icon == null ? 6 : 16,
                      color: AppColors.botanicalGreen),
            ),
            Expanded(child: Text(text, style: AppTypography.bodyMedium)),
          ],
        ),
      );
}
