import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/application/auth_providers.dart';
import '../application/resume_builder_controller.dart';
import '../data/resume_api.dart';
import '../data/resume_repository.dart';
import '../domain/resume_version.dart';
import 'resumes_screen.dart';
import '../../jobs/application/jobs_controller.dart' show jobsApiProvider;
import 'widgets/writing_report_view.dart';
import '../../profile/application/profile_providers.dart';

/// Edit one resume version: template, summary, section order (feature 9–10).
/// Changes save automatically.
class ResumeEditorScreen extends ConsumerWidget {
  const ResumeEditorScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(resumeVersionProvider(id));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Delete this version',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        body: version.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.botanicalGreen),
          ),
          error: (_, _) => const _Message('Couldn’t load this resume.'),
          data: (v) => v == null
              ? const _Message('This resume was deleted.')
              : _Editor(initial: v),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this resume version?'),
        content: const Text('Your profile isn’t affected.'),
        actions: [
          TextButton(
            onPressed: () => c.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(onPressed: () => c.pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _deletedIds.add(id); // stops the editor re-saving it as it closes
    context.pop();
    await deleteResumeVersion(ref, id);
  }
}

/// Versions deleted in this session; the editor never re-saves these.
final _deletedIds = <String>{};

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.pageGutter),
    child: Text(text, style: AppTypography.bodyLarge),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.initial});
  final ResumeVersion initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late ResumeVersion _v = widget.initial;
  late final _name = TextEditingController(text: _v.name);
  late final _summary = TextEditingController(text: _v.summary);
  late final ResumeRepository _repo = ref.read(resumeRepositoryProvider);
  late final String? _uid = ref.read(authServiceProvider).currentUser?.uid;
  bool _exporting = false;

  @override
  void dispose() {
    _save(); // keep text edits made just before leaving
    _name.dispose();
    _summary.dispose();
    super.dispose();
  }

  /// Saves the draft (Firestore queues it when offline).
  void _save() {
    if (_deletedIds.contains(_v.id)) return;
    final v = _v.copyWith(name: _name.text, summary: _summary.text);
    if (_uid == null || v.name.trim().isEmpty) return;
    _v = v;
    _repo.save(_uid, v).ignore();
  }

  void _update(ResumeVersion v) {
    setState(() => _v = v);
    _save();
  }

  void _move(int i, int delta) {
    final order = [..._v.sectionOrder];
    final item = order.removeAt(i);
    order.insert(i + delta, item);
    _update(_v.copyWith(sectionOrder: order));
  }

  void _toggle(ResumeSectionKind k, bool show) {
    final hidden = {..._v.hiddenSections};
    show ? hidden.remove(k) : hidden.add(k);
    _update(_v.copyWith(hiddenSections: hidden));
  }

  Future<void> _shareDocx() async {
    _save();
    final content = readResumeContent(ref, _v);
    if (content == null) {
      _snack('Your profile is still loading.');
      return;
    }
    setState(() => _exporting = true);
    try {
      await ref.read(resumeExporterProvider).shareDocx(content, _v);
    } on ResumeApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Couldn’t create the Word file. Please try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  bool _checking = false;

  /// NLP writing review of this resume version's text.
  Future<void> _checkWriting() async {
    _save();
    setState(() => _checking = true);
    final content = readResumeContent(ref, _v);
    if (content == null) {
      setState(() => _checking = false);
      _snack('Your profile is still loading.');
      return;
    }
    try {
      final report = await ref.read(jobsApiProvider).checkWriting(content.plainText);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.ivory,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            children: [
              Text('Writing check', style: AppTypography.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'How your bullets read to a recruiter: action verbs, results, '
                'clarity. Fix them in Profile → Projects / Experience.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              WritingReportView(report: report),
            ],
          ),
        ),
      );
    } on ResumeApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Couldn’t check the writing. Please try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _open(String route) {
    _save();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the profile loaded so the writing check and exports have it.
    ref.watch(profileDataProvider);
    final v = _v;
    return SafeArea(
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
              children: staggered([
                Text('Edit resume', style: AppTypography.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.targetKind == ResumeTargetKind.general
                            ? 'General resume'
                            : 'Tailored for ${v.targetLabel}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                    if (v.alignmentScore != null)
                      AlignmentBadge(score: v.alignmentScore!),
                  ],
                ),
                if (v.focusSkills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Highlighted skills: ${v.focusSkills.join(', ')}',
                    style: AppTypography.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(controller: _name, label: 'Version name'),
                const FormGroupLabel('Template'),
                ChoiceChips<ResumeTemplate>(
                  options: ResumeTemplate.values,
                  selected: v.template,
                  labelOf: (t) => t.label,
                  onSelected: (t) => _update(v.copyWith(template: t)),
                ),
                LabeledTextField(
                  controller: _summary,
                  label: 'Summary',
                  helper:
                      'Written from your profile. Keep it true and specific.',
                  maxLines: 5,
                  maxLength: 600,
                ),
                const FormGroupLabel('Sections — order and visibility'),
                for (var i = 0; i < v.sectionOrder.length; i++)
                  _SectionRow(
                    kind: v.sectionOrder[i],
                    visible: !v.hiddenSections.contains(v.sectionOrder[i]),
                    onUp: i == 0 ? null : () => _move(i, -1),
                    onDown: i == v.sectionOrder.length - 1
                        ? null
                        : () => _move(i, 1),
                    onToggle: (show) => _toggle(v.sectionOrder[i], show),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Empty sections are left out automatically. To change what a '
                  'section says, edit your Profile.',
                  style: AppTypography.bodySmall,
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.sm,
              AppSpacing.pageGutter,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  label: 'Preview & share PDF',
                  onPressed: () => _open(AppRoutes.resumePreview(v.id)),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Check writing',
                  style: AppButtonStyle.outlined,
                  isLoading: _checking,
                  onPressed: _checkWriting,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Word file',
                        style: AppButtonStyle.outlined,
                        isLoading: _exporting,
                        onPressed: _shareDocx,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Cover letter',
                        style: AppButtonStyle.outlined,
                        onPressed: () => _open(AppRoutes.coverLetter(v.id)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.kind,
    required this.visible,
    required this.onUp,
    required this.onDown,
    required this.onToggle,
  });

  final ResumeSectionKind kind;
  final bool visible;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.stone),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kind.label,
              style: AppTypography.labelLarge.copyWith(
                color: visible ? AppColors.charcoal : AppColors.mutedText,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Move up',
            icon: const Icon(Icons.arrow_upward, size: 20),
            color: AppColors.botanicalGreen,
            onPressed: onUp,
          ),
          IconButton(
            tooltip: 'Move down',
            icon: const Icon(Icons.arrow_downward, size: 20),
            color: AppColors.botanicalGreen,
            onPressed: onDown,
          ),
          Switch(
            value: visible,
            activeTrackColor: AppColors.botanicalGreen,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
