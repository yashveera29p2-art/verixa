import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/links.dart';
import '../../auth/application/auth_providers.dart';
import '../../jobs/domain/job_models.dart';
import '../../jobs/presentation/jobs_screen.dart' show MatchBadge;
import '../../workstyle/workstyle.dart';
import '../application/recruiter_providers.dart';
import '../application/talent_controller.dart';
import '../domain/recruiter_models.dart';

/// Recruiters: students who opted in, ranked for one of the recruiter's
/// jobs (or typed requirements) by skills they've proven and work style.
class FindTalentScreen extends ConsumerStatefulWidget {
  const FindTalentScreen({super.key});

  @override
  ConsumerState<FindTalentScreen> createState() => _FindTalentScreenState();
}

class _FindTalentScreenState extends ConsumerState<FindTalentScreen> {
  String? _jobId; // null = custom requirements
  final _custom = TextEditingController();
  final _traits = <Trait>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(talentControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _rank(List<PostedJob> jobs) {
    FocusScope.of(context).unfocus();
    final job = jobs.where((j) => j.id == _jobId).firstOrNull;
    final text = job?.matchText ?? _custom.text.trim();
    if (text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick one of your jobs, or describe the skills you need.')));
      return;
    }
    final wanted = {for (final t in _traits) t.name: 1.0, ...?job?.wantedTraits};
    ref.read(talentControllerProvider.notifier).rank(
          title: job?.title ?? 'Custom requirements',
          description: text,
          wantedTraits: wanted,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(talentControllerProvider);
    final jobs = ref.watch(myPostedJobsProvider).value ?? const <PostedJob>[];
    final account = ref.watch(myRecruiterAccountProvider).value;
    final shortlisted = ref.watch(shortlistIdsProvider).value ?? const <String>{};
    final navInset = AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;
    final candidates = state.sorted;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.botanicalGreen,
          onRefresh: () => ref.read(talentControllerProvider.notifier).load(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.pageGutter, AppSpacing.md,
                AppSpacing.pageGutter, navInset + AppSpacing.lg),
            children: [
              // Charcoal "console" header.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account?.company.toUpperCase() ?? 'RECRUITER',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.softSage, letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text('Find talent',
                        style: AppTypography.displayMedium.copyWith(color: AppColors.ivory)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Students who chose to be visible, ranked by skills they’ve '
                      'shown in projects and internships, and by work style.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.ivory.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String?>(
                      initialValue: _jobId,
                      isExpanded: true,
                      dropdownColor: AppColors.ivory,
                      decoration: const InputDecoration(labelText: 'Rank for'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Custom requirements')),
                        for (final j in jobs)
                          DropdownMenuItem(value: j.id, child: Text(j.title, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _jobId = v),
                    ),
                    if (_jobId == null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _custom,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Backend intern: Python, REST APIs, SQL; Docker a plus',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text('Work style you value',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.ivory)),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final t in Trait.values)
                          FilterChip(
                            label: Text(t.label),
                            selected: _traits.contains(t),
                            onSelected: (on) =>
                                setState(() => on ? _traits.add(t) : _traits.remove(t)),
                            showCheckmark: false,
                            selectedColor: AppColors.botanicalGreen,
                            backgroundColor: AppColors.ivory,
                            labelStyle: AppTypography.labelMedium.copyWith(
                              color: _traits.contains(t) ? AppColors.ivory : AppColors.charcoal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.loading ? null : () => _rank(jobs),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.botanicalGreen,
                          foregroundColor: AppColors.ivory,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        child: Text(state.loading ? 'Ranking…' : 'Rank candidates'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.error != null)
                Text(state.error!, style: AppTypography.bodyMedium),
              Text(
                state.fits.isEmpty
                    ? '${state.candidates.length} visible candidates'
                    : 'Ranked for “${state.rankedFor}”',
                style: AppTypography.labelMedium.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!state.loading && state.candidates.isEmpty)
                Text(
                  'No students are visible yet. Students appear here when they '
                  'switch on “Visible to recruiters”.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
                ),
              for (final c in candidates) ...[
                _CandidateTile(
                  card: c,
                  fit: state.fits[c.uid],
                  starred: shortlisted.contains(c.uid),
                  jobTitle: state.rankedFor,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Scores are estimates to help shortlist, not a judgement of a '
                'person. Contact candidates respectfully.',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({
    required this.card,
    required this.fit,
    required this.starred,
    required this.jobTitle,
  });

  final CandidateCard card;
  final JobFit? fit;
  final bool starred;
  final String jobTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.stone),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showCandidate(context, card, fit),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (fit != null) ...[MatchBadge(score: fit!.score, size: 46), const SizedBox(width: AppSpacing.sm)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.fullName, style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                        Text(card.headline,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: starred ? 'Remove from shortlist' : 'Shortlist',
                    onPressed: uid == null
                        ? null
                        : () => ref
                            .read(recruiterRepositoryProvider)
                            .toggleShortlist(uid, card, !starred, jobTitle: jobTitle),
                    icon: Icon(starred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.botanicalGreen),
                  ),
                ],
              ),
              if (fit?.reasons.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('✓ ${fit!.reasons.first}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
              ],
              if (fit?.traitFit != null)
                Text('Work-style fit ${fit!.traitFit}%',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.botanicalGreen)),
              if (card.skills.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(card.skills.take(6).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showCandidate(BuildContext context, CandidateCard c, JobFit? fit) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        children: [
          Text(c.fullName, style: AppTypography.headlineLarge),
          Text(c.headline, style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
          if (c.city.isNotEmpty || c.targetRole.isNotEmpty)
            Text([c.targetRole, c.city].where((s) => s.isNotEmpty).join(' · '),
                style: AppTypography.bodySmall),
          if (fit != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Match ${fit.score}%', style: AppTypography.titleLarge),
            for (final r in fit.reasons)
              Text('✓ $r', style: AppTypography.bodyMedium),
            if (fit.gaps.isNotEmpty)
              Text('Missing: ${fit.gaps.join(', ')}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
          ],
          if (c.traits.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Work style', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            TraitBars(traits: c.traits),
          ],
          if (c.skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Skills', style: AppTypography.titleLarge),
            Text(c.skills.join(' · '), style: AppTypography.bodyMedium),
          ],
          if (c.projectTitles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Projects', style: AppTypography.titleLarge),
            for (final p in c.projectTitles) Text('• $p', style: AppTypography.bodyMedium),
          ],
          if (c.links.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Links', style: AppTypography.titleLarge),
            for (final l in c.links)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => openLink(l.startsWith('http') ? l : 'https://$l'),
                child: Text(l, overflow: TextOverflow.ellipsis),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'To contact this student, use their LinkedIn or portfolio link. '
            'Verixa doesn’t share phone numbers.',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    ),
  );
}
