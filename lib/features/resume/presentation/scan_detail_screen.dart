import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/date_format.dart';
import '../../auth/application/auth_providers.dart';
import '../application/resume_scan_controller.dart';
import 'widgets/report_view.dart';

/// A saved scan report from history.
class ScanDetailScreen extends ConsumerWidget {
  const ScanDetailScreen({super.key, required this.scanId});

  final String scanId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text('Delete this report?', style: AppTypography.titleLarge),
        content: Text(
          'It will be removed from your scan history.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.charcoal),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await ref.read(scanHistoryRepositoryProvider).delete(uid, scanId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(scanRecordProvider(scanId));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Delete report',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
        body: record.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.botanicalGreen),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (r) => r == null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageGutter),
                  child: Text(
                    'This report no longer exists.',
                    style: AppTypography.bodyLarge,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.xs,
                    AppSpacing.pageGutter,
                    AppSpacing.xl,
                  ),
                  children: [
                    Text('Scan report', style: AppTypography.headlineLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        r.fileName,
                        if (r.createdAt != null)
                          DateFormatting.dateTime(r.createdAt!),
                      ].join(' · '),
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ReportView(report: r.report),
                  ],
                ),
        ),
      ),
    );
  }
}
