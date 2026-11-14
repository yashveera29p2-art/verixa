import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/resume_builder_controller.dart';
import '../data/resume_api.dart';
import '../domain/resume_builder.dart';
import '../domain/resume_version.dart';
import '../../../core/widgets/disclaimer_note.dart';

/// A cover letter written from profile facts, editable, saved with the
/// resume version, and shareable as PDF or Word (feature 10).
class CoverLetterScreen extends ConsumerWidget {
  const CoverLetterScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(resumeVersionProvider(id)).value;
    final profile = ref.watch(profileDataProvider).value;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(),
        body: version == null || profile == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.botanicalGreen,
                ),
              )
            : _LetterEditor(
                version: version,
                generated: () => writeCoverLetter(profile, version),
              ),
      ),
    );
  }
}

class _LetterEditor extends ConsumerStatefulWidget {
  const _LetterEditor({required this.version, required this.generated});

  final ResumeVersion version;
  final String Function() generated;

  @override
  ConsumerState<_LetterEditor> createState() => _LetterEditorState();
}

class _LetterEditorState extends ConsumerState<_LetterEditor> {
  late final _text = TextEditingController(
    text: widget.version.coverLetter.isNotEmpty
        ? widget.version.coverLetter
        : widget.generated(),
  );
  late final _repo = ref.read(resumeRepositoryProvider);
  late final _uid = ref.read(authServiceProvider).currentUser?.uid;
  bool _busy = false;

  @override
  void dispose() {
    _save();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_uid == null) return;
    _repo.save(_uid, widget.version.copyWith(coverLetter: _text.text)).ignore();
  }

  Future<void> _run(Future<void> Function(ResumeContent c) action) async {
    _save();
    final content = readResumeContent(ref, widget.version);
    if (content == null) return;
    setState(() => _busy = true);
    try {
      await action(content);
    } on ResumeApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Couldn’t create the file. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final exporter = ref.read(resumeExporterProvider);
    final v = widget.version;
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
              children: [
                Text('Cover letter', style: AppTypography.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Drafted from your profile for ${v.targetLabel.isNotEmpty ? v.targetLabel : 'this resume'}. '
                  'Read it through and make it yours — it saves automatically. '
                  '${Disclaimers.coverLetter}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _text,
                  minLines: 14,
                  maxLines: null,
                  maxLength: 8000,
                  keyboardType: TextInputType.multiline,
                  style: AppTypography.bodyMedium.copyWith(height: 1.5),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _text.text = widget.generated()),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Rewrite from profile'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.botanicalGreen,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _text.text));
                        _snack('Copied');
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.botanicalGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.sm,
              AppSpacing.pageGutter,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Share PDF',
                    isLoading: _busy,
                    onPressed: () => _run((c) async {
                      final bytes = await exporter.coverLetterPdf(
                        _text.text,
                        c,
                      );
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename:
                            '${ResumeExporter.fileBase(c, v)}_Cover_Letter.pdf',
                      );
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Word file',
                    style: AppButtonStyle.outlined,
                    onPressed: _busy
                        ? null
                        : () => _run(
                            (c) =>
                                exporter.shareCoverLetterDocx(_text.text, c, v),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
