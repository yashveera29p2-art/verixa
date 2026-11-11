import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/company.dart';

/// Serif section heading, e.g. "What they look for".
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.color = AppColors.charcoal});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.titleLarge.copyWith(color: color));
}

/// Small uppercase label above a group, e.g. "SKILLS".
class SubHeading extends StatelessWidget {
  const SubHeading(this.text, {super.key, this.color = AppColors.mutedText});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(color: color),
    ),
  );
}

/// Outlined chips for skills and traits.
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs - 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.stone),
            ),
            child: Text(item, style: AppTypography.bodyMedium),
          ),
      ],
    );
  }
}

/// Icon + label + paragraph, used for academics and experience.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.botanicalGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelLarge),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.mutedText,
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

/// The recommended resume shape, in a botanical green filled section.
class ResumePatternCard extends StatelessWidget {
  const ResumePatternCard({super.key, required this.pattern});

  final ResumePattern pattern;

  static final _muted = AppColors.ivory.withValues(alpha: 0.8);

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodyMedium.copyWith(color: AppColors.ivory);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Resume pattern that suits them',
            color: AppColors.ivory,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.ivory,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(pattern.length, style: body)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SubHeading('Section order', color: _muted),
          for (var i = 0; i < pattern.sectionOrder.length; i++)
            _NumberedLine(number: i + 1, text: pattern.sectionOrder[i]),
          const SizedBox(height: AppSpacing.lg),
          SubHeading('Emphasise', color: _muted),
          for (final item in pattern.emphasise)
            _MarkedLine(icon: Icons.check, text: item),
          const SizedBox(height: AppSpacing.lg),
          SubHeading('Avoid', color: _muted),
          for (final item in pattern.avoid)
            _MarkedLine(icon: Icons.close, text: item),
          if (pattern.atsNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.ivory.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubHeading('ATS tip', color: _muted),
                  Text(pattern.atsNotes, style: body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$number.',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.ivory.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ivory),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkedLine extends StatelessWidget {
  const _MarkedLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: AppColors.ivory),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ivory),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small note: guidance is general, plus sources and review date.
class GuidanceNote extends StatelessWidget {
  const GuidanceNote({
    super.key,
    required this.sources,
    required this.lastReviewed,
  });

  final List<String> sources;
  final DateTime lastReviewed;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _reviewed =>
      '${lastReviewed.day} ${_months[lastReviewed.month - 1]} ${lastReviewed.year}';

  @override
  Widget build(BuildContext context) {
    final small = AppTypography.bodySmall;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'About this guidance',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'General guidance based on public hiring patterns — not an '
            'official statement from the company. Always check the actual '
            'job posting.',
            style: small,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Last reviewed: $_reviewed', style: small),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            for (final url in sources)
              SelectableText('Source: $url', style: small),
          ],
        ],
      ),
    );
  }
}
