import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/profile_section.dart';

/// Botanical green card showing how much of the profile is filled in,
/// with a button that opens the next unfinished step.
class CompletionCard extends StatelessWidget {
  const CompletionCard({
    super.key,
    required this.completion,
    required this.completedCount,
    required this.next,
    required this.onContinue,
  });

  /// 0.0–1.0 across the core sections.
  final double completion;
  final int completedCount;

  /// Next section to fill in; null when everything core is done.
  final ProfileSection? next;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final percent = (completion * 100).round();
    final total = ProfileSection.core.length;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$percent%',
                  style: AppTypography.displayMedium
                      .copyWith(color: AppColors.ivory, height: 1)),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('profile complete',
                    style: AppTypography.bodyMedium.copyWith(color: muted)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              color: AppColors.ivory,
              backgroundColor: AppColors.ivory.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            next == null
                ? 'All $total core sections done. A complete profile makes '
                    'better resumes.'
                : '$completedCount of $total sections done · Next: ${next!.title}',
            style: AppTypography.bodySmall.copyWith(color: muted),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Continue'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ivory,
                foregroundColor: AppColors.botanicalGreen,
                textStyle: AppTypography.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
