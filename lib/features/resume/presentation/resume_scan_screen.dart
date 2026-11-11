import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/resume_scan_controller.dart';
import 'resume_import_screen.dart';
import 'widgets/report_view.dart';

/// Upload a resume → security scan + ATS report (features 1–4), saved to
/// scan history (feature 5). From the report, genuine (visible) details
/// can be imported into the profile.
class ResumeScanScreen extends ConsumerWidget {
  const ResumeScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeScanControllerProvider);
    final controller = ref.read(resumeScanControllerProvider.notifier);
    final report = state.report;
    final historyButton = IconButton(
      tooltip: 'Scan history',
      icon: const Icon(Icons.history),
      onPressed: () => context.push(AppRoutes.scanHistory),
    );

    if (report == null) {
      final scanning = state.phase == ScanPhase.scanning;
      return AuthPage(
        title: 'Scan your resume',
        subtitle: const Text(
            'We check for tricks that recruiters and ATS software flag, and '
            'estimate how well your resume will be read.'),
        actions: [historyButton],
        bottom: AppButton(
          label: 'Choose PDF or DOCX',
          isLoading: scanning,
          onPressed: controller.pickAndScan,
        ),
        children: [
          if (scanning)
            _ScanningCard(fileName: state.fileName)
          else
            const _WhatWeCheck(),
          InlineError(state.error),
        ],
      );
    }

    final parsed = report.parsed;
    final canImport = parsed != null && parsed.availableSections.isNotEmpty;
    return AuthPage(
      title: 'Scan report',
      subtitle: Text([
        state.fileName ?? 'Your resume',
        if (state.savedToHistory) 'Saved to history',
      ].join(' · ')),
      actions: [historyButton],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canImport)
            AppButton(
              label: report.threats.isEmpty
                  ? 'Import details into profile'
                  : 'Import genuine details',
              onPressed: () => context.push(
                AppRoutes.resumeImport,
                extra: ImportArgs(parsed, state.fileName ?? 'your resume'),
              ),
            ),
          TextButton(
            onPressed: controller.pickAndScan,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.mutedText,
              textStyle: AppTypography.labelLarge,
            ),
            child: const Text('Scan another file'),
          ),
        ],
      ),
      children: [
        ReportView(report: report),
        if (report.threats.isNotEmpty && canImport) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '“Import genuine details” uses only the text a reader can see — '
            'hidden content is left out.',
            style: AppTypography.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _WhatWeCheck extends StatelessWidget {
  const _WhatWeCheck();

  @override
  Widget build(BuildContext context) {
    const checks = [
      (Icons.visibility_off_outlined, 'Hidden text',
          'White, microscopic or off-page text.'),
      (Icons.smart_toy_outlined, 'Prompt injection',
          'Instructions aimed at AI screening tools.'),
      (Icons.repeat, 'Keyword stuffing',
          'Repeated keywords and hidden keyword lists.'),
      (Icons.text_fields, 'Invisible characters',
          'Zero-width and look-alike characters.'),
      (Icons.speed_outlined, 'ATS score',
          'An estimate of how well software reads your resume.'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (final (icon, title, text) in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.ivory, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '$title  ',
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.ivory)),
                      TextSpan(
                          text: text,
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.ivory.withValues(alpha: 0.8))),
                    ])),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.ivory, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your file is processed and discarded. Only the report is saved.',
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ivory.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanningCard extends StatelessWidget {
  const _ScanningCard({this.fileName});

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
                Text('Scanning your resume…', style: AppTypography.labelLarge),
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
