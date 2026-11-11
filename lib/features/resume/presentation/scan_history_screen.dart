import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/date_format.dart';
import '../application/resume_scan_controller.dart';
import '../domain/scan_report.dart';

/// Past scans: file, date, score and risk (feature 5).
class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(scanHistoryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.xs,
            AppSpacing.pageGutter,
            AppSpacing.xl,
          ),
          children: [
            Text('Scan history', style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reports from resumes you’ve scanned. Files themselves are '
              'never stored.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...history.when(
              loading: () => const [
                Center(
                  child: CircularProgressIndicator(
                    color: AppColors.botanicalGreen,
                  ),
                ),
              ],
              error: (_, _) => [
                Text(
                  'Couldn’t load your history. Check your connection.',
                  style: AppTypography.bodyLarge,
                ),
              ],
              data: (records) => records.isEmpty
                  ? [
                      Text(
                        'No scans yet. Use the centre button → Upload & '
                        'scan resume.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ]
                  : [
                      for (final r in records) ...[
                        _HistoryTile(record: r),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record.report;
    final threats = r.threats.length;
    return PressScale(
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: r.riskLevel == RiskLevel.high
                ? AppColors.charcoal
                : AppColors.stone,
          ),
        ),
        child: InkWell(
          onTap: () => context.push(AppRoutes.scanDetail(record.id)),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.botanicalGreen,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    '${r.atsScore}',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge.copyWith(fontSize: 16),
                      ),
                      Text(
                        [
                          r.riskLevel.label,
                          if (threats > 0)
                            '$threats ${threats == 1 ? 'threat' : 'threats'}',
                        ].join(' · '),
                        style: AppTypography.bodySmall.copyWith(
                          color: r.riskLevel == RiskLevel.clean
                              ? AppColors.botanicalGreen
                              : AppColors.charcoal,
                        ),
                      ),
                      if (record.createdAt != null)
                        Text(
                          DateFormatting.dateTime(record.createdAt!),
                          style: AppTypography.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.softSage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
