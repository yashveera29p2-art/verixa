import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/links.dart';
import '../../companies/domain/company.dart';
import '../application/jobs_controller.dart';
import '../domain/job_models.dart';

/// Jobs tab: listings ranked by fit (matching v2), with filters for pay,
/// layoffs, work-life balance and job type.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(jobsControllerProvider.notifier).start();
      if (mounted) _query.text = ref.read(jobsControllerProvider).query;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    ref.read(jobsControllerProvider.notifier).search(_query.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsControllerProvider);
    final controller = ref.read(jobsControllerProvider.notifier);
    final jobs = state.visible;
    final navInset = AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.botanicalGreen,
          onRefresh: () => controller.search(state.query),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.pageGutter,
                    AppSpacing.lg, AppSpacing.pageGutter, 0),
                sliver: SliverList.list(children: [
                  Text('Jobs for you', style: AppTypography.displayMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ranked by how well your profile fits, by meaning, not '
                    'just keywords. Skills you’ve shown in projects count most.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Role or skill, e.g. Android developer',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final f in JobFilter.values)
                        FilterChip(
                          label: Text(f.label),
                          selected: state.filters.contains(f),
                          onSelected: (_) {
                            controller.toggleFilter(f);
                            // Internship searches ask the server for interns.
                            if (f == JobFilter.internship) controller.search(state.query);
                          },
                          showCheckmark: false,
                          selectedColor: AppColors.botanicalGreen,
                          labelStyle: AppTypography.labelMedium.copyWith(
                            color: state.filters.contains(f)
                                ? AppColors.ivory
                                : AppColors.charcoal,
                          ),
                          backgroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.stone),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SourceNote(source: state.source, ranked: state.ranked, loading: state.loading),
                  if (state.ranking)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.botanicalGreen),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Matching jobs to your profile…', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ]),
              ),
              if (state.loading && state.jobs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.botanicalGreen),
                  ),
                )
              else if (state.error != null && state.jobs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(text: state.error!, action: 'Try again', onAction: _search),
                )
              else if (jobs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Empty(
                    text: state.jobs.isEmpty
                        ? 'No jobs found for “${state.query}”. Try another role or skill.'
                        : 'No jobs match these filters. Remove a filter to see more.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.pageGutter, 0,
                      AppSpacing.pageGutter, navInset + AppSpacing.lg),
                  sliver: SliverList.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => StaggeredEntrance(
                      index: i,
                      child: JobCard(
                        ranked: jobs[i],
                        onTap: () => context.push(AppRoutes.jobDetail, extra: jobs[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source, required this.ranked, required this.loading});

  final String source;
  final bool ranked;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text('Finding and ranking jobs…', style: AppTypography.bodySmall);
    }
    if (source == 'adzuna') {
      return GestureDetector(
        onTap: () => openLink('https://www.adzuna.in'),
        child: Text.rich(
          TextSpan(style: AppTypography.bodySmall, children: [
            const TextSpan(text: 'Jobs by '),
            TextSpan(
              text: 'Adzuna',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.botanicalGreen,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w700,
              ),
            ),

          ]),
        ),
      );
    }
    if (source == 'sample') {
      return Text(
        'Sample listings for now. Live jobs appear automatically once the '
        'job feed is connected.',
        style: AppTypography.bodySmall,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText)),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

/// One job in the list: title, company, pay, tags and match %.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.ranked, required this.onTap});

  final RankedJob ranked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final j = ranked.job;
    final fit = ranked.fit;
    final insights = ranked.company?.insights;
    final tags = <String>[
      j.isInternship ? 'Internship' : 'Full-time',
      if (j.source == JobSource.verixa) 'On Verixa',
      if (insights?.layoffRisk == Level3.low) 'Low layoffs',
      if (insights?.workLife == WorkLife.good) 'Good work-life',
    ];
    return PressScale(
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.stone),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(j.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            [j.company, if (j.location.isNotEmpty) j.location].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (fit != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      MatchBadge(score: fit.score),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(j.payText,
                    style: AppTypography.labelMedium.copyWith(color: AppColors.botanicalGreen)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xxs,
                  runSpacing: AppSpacing.xxs,
                  children: [for (final t in tags) _Tag(t)],
                ),
                if (fit != null && fit.reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '✓ ${fit.reasons.first}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.stone),
        ),
        child: Text(text, style: AppTypography.bodySmall.copyWith(fontSize: 11.5)),
      );
}

/// Round match-% badge, greener for better fits.
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score, this.size = 50});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strong = score >= 55;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: strong ? AppColors.botanicalGreen : AppColors.white,
        border: Border.all(color: AppColors.botanicalGreen, width: 1.5),
      ),
      child: Text(
        '$score%',
        style: AppTypography.labelLarge.copyWith(
          fontSize: size * 0.28,
          color: strong ? AppColors.ivory : AppColors.botanicalGreen,
        ),
      ),
    );
  }
}
