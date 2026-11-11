import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/resume_import_controller.dart';
import 'widgets/import_section_card.dart';

/// Upload an existing resume, review what was found, and import the
/// chosen sections into the profile (feature 6).
class ResumeImportScreen extends ConsumerWidget {
  const ResumeImportScreen({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final ok =
        await ref.read(resumeImportControllerProvider.notifier).importSelected();
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Imported into your profile. Review each section.')));
    context.go(AppRoutes.profile);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeImportControllerProvider);
    final controller = ref.read(resumeImportControllerProvider.notifier);
    final result = state.result;
    final reviewing = result != null &&
        (state.phase == ImportPhase.review || state.phase == ImportPhase.importing);

    if (!reviewing) {
      final uploading = state.phase == ImportPhase.uploading;
      return AuthPage(
        title: 'Import your resume',
        subtitle: const Text(
            'Upload an existing resume and we’ll fill in your profile for you. '
            'You choose what gets imported.'),
        bottom: AppButton(
          label: 'Choose PDF or DOCX',
          isLoading: uploading,
          onPressed: controller.pickAndParse,
        ),
        children: [
          if (uploading)
            _UploadingCard(fileName: state.fileName)
          else
            const _HowItWorks(),
          InlineError(state.error),
        ],
      );
    }

    final available = result.availableSections;
    return AuthPage(
      title: 'Here’s what we found',
      subtitle: Text('From ${state.fileName ?? 'your resume'}. Untick anything '
          'you don’t want. Importing only fills empty fields — it never '
          'replaces what you’ve already entered.'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InlineError(state.error),
          if (state.error != null) const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: state.selected.isEmpty
                ? 'Select sections to import'
                : 'Import ${state.selected.length} '
                    '${state.selected.length == 1 ? 'section' : 'sections'}',
            isLoading: state.phase == ImportPhase.importing,
            onPressed: state.selected.isEmpty ? null : () => _import(context, ref),
          ),
          TextButton(
            onPressed: state.phase == ImportPhase.importing
                ? null
                : controller.pickAndParse,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.mutedText,
              textStyle: AppTypography.labelLarge,
            ),
            child: const Text('Choose a different file'),
          ),
        ],
      ),
      children: [
        if (result.warnings.isNotEmpty) ...[
          _Warnings(result.warnings),
          const SizedBox(height: AppSpacing.md),
        ],
        if (available.isEmpty)
          Text('We couldn’t find anything to import from this file.',
              style: AppTypography.bodyLarge),
        for (final section in available) ...[
          ImportSectionCard(
            section: section,
            result: result,
            selected: state.selected.contains(section),
            onToggle: () => controller.toggle(section),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const points = [
      (Icons.upload_file_outlined, 'PDF or DOCX, up to 5 MB.'),
      (Icons.auto_awesome_outlined,
          'We read your contact details, education, experience, projects '
              'and skills.'),
      (Icons.checklist_outlined, 'You review everything before it’s saved.'),
      (Icons.lock_outline,
          'Your file is processed and then discarded — we don’t store it.'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (final (icon, text) in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.ivory, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(text,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.ivory)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadingCard extends StatelessWidget {
  const _UploadingCard({this.fileName});

  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.botanicalGreen),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading your resume…', style: AppTypography.labelLarge),
                if (fileName != null)
                  Text(fileName!, style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings(this.warnings);

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.softSage.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Please double-check',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.botanicalGreen)),
          const SizedBox(height: AppSpacing.xxs),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $w', style: AppTypography.bodyMedium),
            ),
        ],
      ),
    );
  }
}
