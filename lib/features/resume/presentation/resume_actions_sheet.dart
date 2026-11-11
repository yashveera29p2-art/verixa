import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';

/// Opens the sheet behind the centre document button (CLAUDE.md §3.3).
/// Actions that aren't built yet show a "Coming soon" state.
Future<void> showResumeActionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // Size to content (the default caps the sheet at ~56% of the screen).
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheet,
    backgroundColor: AppColors.ivory,
    barrierColor: AppColors.charcoal.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => const _ResumeActionsSheet(),
  );
}

class _ResumeAction {
  const _ResumeAction(this.icon, this.title, this.description, {this.route});
  final IconData icon;
  final String title;
  final String description;

  /// Where tapping goes; null means "Coming soon".
  final String? route;
}

const _actions = [
  _ResumeAction(
    Icons.edit_note_outlined,
    'Create resume',
    'Build an ATS-friendly resume from your profile — general, for a company, or for a job.',
    route: AppRoutes.resumes,
  ),
  _ResumeAction(
    Icons.document_scanner_outlined,
    'Upload & scan resume',
    'Check for hidden text, prompt injection and keyword stuffing, and get an ATS score.',
    route: AppRoutes.resumeScan,
  ),
  _ResumeAction(
    Icons.compare_arrows,
    'Match with a job description',
    'See how well your profile fits a specific role.',
    route: AppRoutes.jdMatch,
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
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
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

/// One action. Built actions are tappable; the rest show "Coming soon".
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _ResumeAction action;

  void _open(BuildContext context) {
    final router = GoRouter.of(context); // grab before the sheet closes
    Navigator.of(context).pop();
    router.push(action.route!);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = action.route != null;
    return Semantics(
      enabled: enabled,
      button: enabled,
      label: enabled ? action.title : '${action.title}. Coming soon.',
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: enabled ? AppColors.botanicalGreen : AppColors.stone,
            ),
          ),
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.botanicalGreen
                          : AppColors.softSage.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      action.icon,
                      color: enabled
                          ? AppColors.ivory
                          : AppColors.botanicalGreen,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: AppTypography.labelLarge.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.description,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (enabled)
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.botanicalGreen,
                    )
                  else
                    const _ComingSoonTag(),
                ],
              ),
            ),
          ),
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
