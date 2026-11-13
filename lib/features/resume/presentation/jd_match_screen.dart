import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/jd_match_controller.dart';
import 'widgets/match_report_view.dart';

/// Paste a job description and see how well the profile matches it
/// (feature 8).
class JdMatchScreen extends ConsumerStatefulWidget {
  const JdMatchScreen({super.key});

  @override
  ConsumerState<JdMatchScreen> createState() => _JdMatchScreenState();
}

class _JdMatchScreenState extends ConsumerState<JdMatchScreen> {
  final _jd = TextEditingController();

  @override
  void dispose() {
    _jd.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _jd.text = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jdMatchControllerProvider);
    final controller = ref.read(jdMatchControllerProvider.notifier);
    final report = state.report;
    final historyButton = IconButton(
      tooltip: 'Match history',
      icon: const Icon(Icons.history),
      onPressed: () => context.push(AppRoutes.matchHistory),
    );

    if (report != null) {
      return AuthPage(
        title: 'Match report',
        subtitle: Text(
          state.savedToHistory
              ? 'Compared with your profile · Saved to history'
              : 'Compared with your profile',
        ),
        actions: [historyButton],
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Create resume for this job',
              onPressed: () =>
                  context.push(AppRoutes.resumeNew, extra: _jd.text),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Update my profile',
              style: AppButtonStyle.outlined,
              onPressed: () => context.push(AppRoutes.profile),
            ),
            TextButton(
              onPressed: controller.reset,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedText,
                textStyle: AppTypography.labelLarge,
              ),
              child: const Text('Match another job'),
            ),
          ],
        ),
        children: [MatchReportView(report: report)],
      );
    }

    return AuthPage(
      title: 'Match a job',
      subtitle: const Text(
        'Paste a job description. We’ll pick out what it asks for and '
        'compare it with your profile by meaning, not just keywords.',
      ),
      actions: [historyButton],
      bottom: AppButton(
        label: 'Check my match',
        isLoading: state.matching,
        onPressed: () => controller.match(_jd.text),
      ),
      children: [
        TextField(
          controller: _jd,
          minLines: 10,
          maxLines: 18,
          maxLength: 20000,
          enabled: !state.matching,
          keyboardType: TextInputType.multiline,
          style: AppTypography.bodyMedium,
          decoration: const InputDecoration(
            hintText: 'Paste the job title, responsibilities and requirements…',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: state.matching ? null : _paste,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Paste from clipboard'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.botanicalGreen,
                textStyle: AppTypography.labelLarge,
                padding: EdgeInsets.zero,
              ),
            ),
            const Spacer(),
            if (_jd.text.isNotEmpty)
              TextButton(
                onPressed: state.matching ? null : () => setState(_jd.clear),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedText,
                ),
                child: const Text('Clear'),
              ),
          ],
        ),
        InlineError(state.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tip: the more complete your profile (skills, projects, experience), '
          'the more accurate the match.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}
