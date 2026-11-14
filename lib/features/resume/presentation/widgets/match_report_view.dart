import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/match_report.dart';
import '../../../../core/widgets/disclaimer_note.dart';

/// JD match report: score, job summary, requirement checklist, skill gaps
/// and suggestions (feature 8).
class MatchReportView extends StatelessWidget {
  const MatchReportView({super.key, required this.report});

  final MatchReport report;

  @override
  Widget build(BuildContext context) {
    final required = report.requirements.where((r) => r.required).toList();
    final preferred = report.requirements.where((r) => !r.required).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(report: report),
        const SizedBox(height: AppSpacing.md),
        _JobChips(report: report),
        if (!report.semantic) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Matched by keywords only — the meaning-based model wasn’t '
            'available on the server.',
            style: AppTypography.bodySmall,
          ),
        ],
        if (required.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Heading('Requirements', _count(required)),
          for (final r in required) _RequirementRow(result: r),
        ],
        if (preferred.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Heading('Nice to have', _count(preferred)),
          for (final r in preferred) _RequirementRow(result: r),
        ],
        if (report.matchedSkills.isNotEmpty ||
            report.missingSkills.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Heading('Skills', null),
          _SkillChips(report: report),
        ],
        if (report.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Heading('What to do next', null),
          for (final s in report.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.arrow_right_alt,
                      size: 20,
                      color: AppColors.botanicalGreen,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(s, style: AppTypography.bodyMedium)),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        const DisclaimerNote(Disclaimers.match),
      ],
    );
  }

  static String _count(List<RequirementResult> list) =>
      '${list.where((r) => r.status == MatchStatus.met).length} of ${list.length} met';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.trailing);

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTypography.titleLarge)),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.mutedText,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});

  final MatchReport report;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ivory.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFILE MATCH',
            style: AppTypography.labelMedium.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${report.matchScore}',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.ivory,
                  fontSize: 56,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '%',
                  style: AppTypography.headlineMedium.copyWith(color: muted),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  report.verdict.label,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ivory,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: report.matchScore / 100,
              minHeight: 8,
              color: AppColors.ivory,
              backgroundColor: AppColors.ivory.withValues(alpha: 0.2),
            ),
          ),
          if (report.skillCoverage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${report.skillCoverage}% of the skills it names are in your profile',
              style: AppTypography.bodySmall.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobChips extends StatelessWidget {
  const _JobChips({required this.report});

  final MatchReport report;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (report.jobTitle.isNotEmpty) (Icons.work_outline, report.jobTitle),
      if (report.seniority.isNotEmpty)
        (Icons.stairs_outlined, report.seniority),
      if (report.yearsRequired != null)
        (Icons.schedule, '${report.yearsRequired}+ yrs experience'),
      if (report.education.isNotEmpty)
        (Icons.school_outlined, report.education),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (icon, text) in chips)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.stone),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.botanicalGreen),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// ✓ met (green), ◐ partly met (sage), ○ missing (charcoal outline).
class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.result});

  final RequirementResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (result.status) {
      MatchStatus.met => (Icons.check_circle, AppColors.botanicalGreen),
      MatchStatus.partial => (Icons.contrast, AppColors.softSage),
      MatchStatus.missing => (Icons.radio_button_unchecked, AppColors.charcoal),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.stone),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.text, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    result.evidence.isNotEmpty
                        ? '${result.status.label} · ${result.evidence}'
                        : result.status.label,
                    style: AppTypography.bodySmall.copyWith(
                      color: result.status == MatchStatus.met
                          ? AppColors.botanicalGreen
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChips extends StatelessWidget {
  const _SkillChips({required this.report});

  final MatchReport report;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, {required bool have, bool required = true}) =>
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs + 2,
          ),
          decoration: BoxDecoration(
            color: have ? AppColors.botanicalGreen : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: have ? AppColors.botanicalGreen : AppColors.charcoal,
              width: required ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                have ? Icons.check : Icons.add,
                size: 14,
                color: have ? AppColors.ivory : AppColors.charcoal,
              ),
              const SizedBox(width: 4),
              Text(
                required || have ? text : '$text (nice to have)',
                style: AppTypography.bodyMedium.copyWith(
                  color: have ? AppColors.ivory : AppColors.charcoal,
                ),
              ),
            ],
          ),
        );
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in report.matchedSkills) chip(s, have: true),
        for (final m in report.missingSkills)
          chip(m.skill, have: false, required: m.required),
      ],
    );
  }
}
