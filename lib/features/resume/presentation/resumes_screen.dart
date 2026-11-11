import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_button.dart';
import '../application/resume_builder_controller.dart';
import '../domain/resume_version.dart';

/// All saved resume versions (feature 10), with "New resume".
class ResumesScreen extends ConsumerWidget {
  const ResumesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(resumeVersionsProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.xs,
                    AppSpacing.pageGutter,
                    AppSpacing.lg,
                  ),
                  children: [
                    Text('My resumes', style: AppTypography.headlineLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Each version is built from your profile, so edits to '
                      'your profile show up everywhere.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...versions.when(
                      loading: () => const [
                        Center(
                          child: CircularProgressIndicator(
                            color: AppColors.botanicalGreen,
                          ),
                        ),
                      ],
                      error: (_, _) => [
                        Text(
                          'Couldn’t load your resumes. Check your connection.',
                          style: AppTypography.bodyLarge,
                        ),
                      ],
                      data: (list) => list.isEmpty
                          ? [
                              Text(
                                'No resumes yet. Create your first one below.',
                                style: AppTypography.bodyLarge,
                              ),
                            ]
                          : [
                              for (final v in list) ...[
                                _VersionTile(version: v),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                            ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  0,
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                ),
                child: AppButton(
                  label: 'New resume',
                  onPressed: () => context.push(AppRoutes.resumeNew),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version});

  final ResumeVersion version;

  @override
  Widget build(BuildContext context) {
    final v = version;
    final details = [
      v.targetKind == ResumeTargetKind.general ? 'General' : v.targetLabel,
      v.template.label,
      if (v.updatedAt != null) DateFormatting.date(v.updatedAt!),
    ].where((s) => s.isNotEmpty).join(' · ');
    return PressScale(
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.stone),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => context.push(AppRoutes.resumeEdit(v.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppColors.botanicalGreen,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: AppTypography.labelLarge.copyWith(fontSize: 16),
                      ),
                      Text(details, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                if (v.alignmentScore != null)
                  AlignmentBadge(score: v.alignmentScore!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "82% fit" pill used on version rows and in the editor.
class AlignmentBadge extends StatelessWidget {
  const AlignmentBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strong = score >= 60;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: strong ? AppColors.botanicalGreen : AppColors.ivory,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: strong ? AppColors.botanicalGreen : AppColors.softSage,
        ),
      ),
      child: Text(
        '$score% fit',
        style: AppTypography.labelMedium.copyWith(
          color: strong ? AppColors.ivory : AppColors.charcoal,
        ),
      ),
    );
  }
}
