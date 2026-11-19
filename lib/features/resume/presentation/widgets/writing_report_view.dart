import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/writing_report.dart';

/// NLP writing review: a score, key numbers, and each issue with a fix.
class WritingReportView extends StatelessWidget {
  const WritingReportView({super.key, required this.report});

  final WritingReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: r.score >= 70 ? AppColors.botanicalGreen : AppColors.white,
                border: Border.all(color: AppColors.botanicalGreen, width: 1.5),
              ),
              child: Text(
                '${r.score}',
                style: AppTypography.headlineMedium.copyWith(
                  color: r.score >= 70 ? AppColors.ivory : AppColors.botanicalGreen,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(r.summary, style: AppTypography.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _Stat('Readability', r.readabilityLabel),
            _Stat('Bullets with numbers', '${r.quantifiedPercent}%'),
            _Stat('Weak phrases', '${r.weakCount}'),
            _Stat('Passive voice', '${r.passiveCount}'),
            if (r.buzzwordCount > 0) _Stat('Clichés', '${r.buzzwordCount}'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final issue in r.issues) _IssueTile(issue: issue),
        if (r.issues.isEmpty)
          Text('No writing problems found.', style: AppTypography.bodySmall),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.stone),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label  ', style: AppTypography.bodySmall),
          TextSpan(
              text: value,
              style: AppTypography.labelMedium.copyWith(color: AppColors.botanicalGreen)),
        ])),
      );
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});
  final WritingIssue issue;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.stone),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.title,
                style: AppTypography.labelMedium.copyWith(color: AppColors.botanicalGreen)),
            const SizedBox(height: 2),
            Text(issue.message, style: AppTypography.bodyMedium),
            if (issue.excerpt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('“${issue.excerpt}”',
                  style: AppTypography.bodySmall.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (issue.suggestion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('→ ${issue.suggestion}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal)),
            ],
          ],
        ),
      );
}
