import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/scan_report.dart';

/// The full security + ATS report (features 2–4). Used for a fresh scan
/// and for scans opened from history.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report});

  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScoreCard(score: report.atsScore, risk: report.riskLevel),
        const SizedBox(height: AppSpacing.xl),
        _Heading(
          'Threat report',
          trailing: report.threats.isEmpty
              ? null
              : '${report.threats.length} found',
        ),
        if (report.threats.isEmpty)
          const _NoThreats()
        else
          for (final threat in report.threats) ...[
            ThreatCard(threat: threat),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.lg),
        const _Heading('Score breakdown'),
        for (final part in report.breakdown) _BreakdownRow(part: part),
        if (report.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Heading('How to improve'),
          for (var i = 0; i < report.suggestions.length; i++)
            _Suggestion(number: i + 1, text: report.suggestions[i]),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'The ATS score is an estimate — every applicant tracking system '
          'works differently.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

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
            Text(trailing!,
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

/// Botanical green card with the score and the overall risk.
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.score, required this.risk});

  final int score;
  final RiskLevel risk;

  IconData get _icon => switch (risk) {
        RiskLevel.clean => Icons.verified_user_outlined,
        RiskLevel.low || RiskLevel.medium => Icons.gpp_maybe_outlined,
        RiskLevel.high => Icons.gpp_bad_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ivory.withValues(alpha: 0.8);
    final danger = risk == RiskLevel.high || risk == RiskLevel.medium;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATS SCORE · ESTIMATE',
              style: AppTypography.labelMedium.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score',
                  style: AppTypography.displayLarge
                      .copyWith(color: AppColors.ivory, fontSize: 56, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/ 100',
                    style: AppTypography.bodyLarge.copyWith(color: muted)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              color: AppColors.ivory,
              backgroundColor: AppColors.ivory.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Risk: charcoal for problems, ivory for clean — no new colours.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: danger ? AppColors.charcoal : AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon,
                    size: 18,
                    color: danger ? AppColors.ivory : AppColors.botanicalGreen),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  risk.label,
                  style: AppTypography.labelLarge.copyWith(
                    color: danger ? AppColors.ivory : AppColors.botanicalGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Severity tag: high = charcoal fill, medium = sage fill, low = outline.
class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (severity) {
      Severity.high => (AppColors.charcoal, AppColors.ivory, AppColors.charcoal),
      Severity.medium => (AppColors.softSage, AppColors.charcoal, AppColors.softSage),
      Severity.low => (AppColors.white, AppColors.mutedText, AppColors.stone),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Text('${severity.label} risk',
          style: AppTypography.labelMedium.copyWith(color: fg, fontSize: 11)),
    );
  }
}

/// One finding: what technique, why it matters, the evidence, and where.
class ThreatCard extends StatelessWidget {
  const ThreatCard({super.key, required this.threat});

  final Threat threat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: threat.severity == Severity.high
              ? AppColors.charcoal
              : AppColors.stone,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SeverityTag(threat.severity),
              Text(threat.techniqueName.toUpperCase(),
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.botanicalGreen)),
              if (threat.hidden)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off_outlined,
                        size: 14, color: AppColors.mutedText),
                    const SizedBox(width: 2),
                    Text('Hidden',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.mutedText)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(threat.title,
              style: AppTypography.labelLarge.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.xxs),
          Text(threat.description,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.mutedText)),
          if (threat.evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: const Border(
                  left: BorderSide(color: AppColors.botanicalGreen, width: 3),
                ),
              ),
              child: Text('“${threat.evidence}”',
                  style: AppTypography.bodyMedium
                      .copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          if (threat.locationLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColors.mutedText),
                const SizedBox(width: 4),
                Text(threat.locationLabel, style: AppTypography.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoThreats extends StatelessWidget {
  const _NoThreats();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: AppColors.botanicalGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No hidden text, prompt injection, keyword stuffing or '
              'invisible characters found.',
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.part});

  final AtsComponent part;

  @override
  Widget build(BuildContext context) {
    final full = part.score >= part.max;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(part.label, style: AppTypography.labelLarge)),
              Text('${part.score} / ${part.max}',
                  style: AppTypography.labelLarge.copyWith(
                      color: full ? AppColors.botanicalGreen : AppColors.charcoal)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: part.max == 0 ? 0 : part.score / part.max,
              minHeight: 6,
              color: AppColors.botanicalGreen,
              backgroundColor: AppColors.stone,
            ),
          ),
          if (part.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(part.notes.join(' '), style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.botanicalGreen,
              shape: BoxShape.circle,
            ),
            child: Text('$number',
                style: AppTypography.labelMedium.copyWith(color: AppColors.ivory)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
