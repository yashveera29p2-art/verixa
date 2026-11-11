import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Opens the sheet behind the centre document button (CLAUDE.md §3.3).
/// The three actions are built in later phases; for now each shows
/// a "Coming soon" state.
Future<void> showResumeActionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // Size to content (the default caps the sheet at ~56% of the screen).
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => const _ResumeActionsSheet(),
  );
}

class _ResumeAction {
  const _ResumeAction(this.icon, this.title, this.description, this.phase);
  final IconData icon;
  final String title;
  final String description;
  final String phase;
}

const _actions = [
  _ResumeAction(
    Icons.edit_note_outlined,
    'Create resume',
    'Build an ATS-friendly resume from your profile.',
    'Phase 9',
  ),
  _ResumeAction(
    Icons.document_scanner_outlined,
    'Upload & scan resume',
    'Check for hidden text, prompt injection and keyword stuffing.',
    'Phase 7',
  ),
  _ResumeAction(
    Icons.compare_arrows,
    'Match with a job description',
    'See how well your profile fits a specific role.',
    'Phase 8',
  ),
];

class _ResumeActionsSheet extends StatelessWidget {
  const _ResumeActionsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Scrolls only if the screen is too short (small phones, large text).
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.sm,
          AppSpacing.pageGutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stone,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your resume', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Choose what you’d like to do.',
              style:
                  AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final action in _actions) ...[
              _ActionRow(action: action),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// One action, shown disabled with a "Coming soon" tag until it's built.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _ResumeAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      label: '${action.title}. Coming soon.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.stone),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.softSage.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(action.icon, color: AppColors.botanicalGreen),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title,
                      style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(action.description, style: AppTypography.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const _ComingSoonTag(),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.softSage),
      ),
      child: Text(
        'Coming soon',
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.mutedText,
          fontSize: 11,
        ),
      ),
    );
  }
}
