import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/date_format.dart';
import '../../auth/application/auth_providers.dart';
import '../application/jd_match_controller.dart';
import '../domain/match_report.dart';
import 'widgets/match_report_view.dart';

/// Past JD matches, newest first.
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);
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
            Text('Match history', style: AppTypography.headlineLarge),
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
                        'No matches yet. Use the centre button → Match with a '
                        'job description.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ]
                  : [
                      for (final r in records) ...[
                        _MatchTile(record: r),
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

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record.report;
    final title = r.jobTitle.isNotEmpty ? r.jobTitle : record.jdSnippet;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.stone),
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.matchDetail(record.id)),
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
                  '${r.matchScore}%',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.ivory,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(fontSize: 16),
                    ),
                    Text(
                      r.verdict.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.botanicalGreen,
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
    );
  }
}

/// One saved match.
class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text('Delete this match?', style: AppTypography.titleLarge),
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
    await ref.read(matchHistoryRepositoryProvider).delete(uid, matchId);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(matchRecordProvider(matchId));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Delete match',
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
                    'This match no longer exists.',
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
                    Text('Match report', style: AppTypography.headlineLarge),
                    if (r.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DateFormatting.dateTime(r.createdAt!),
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '“${r.jdSnippet}${r.jdSnippet.length >= 300 ? '…' : ''}”',
                      style: AppTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    MatchReportView(report: r.report),
                  ],
                ),
        ),
      ),
    );
  }
}
