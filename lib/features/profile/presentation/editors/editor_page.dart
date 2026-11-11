import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/auth_page.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';

/// Shared layout for every profile section editor.
///
/// [onSave] validates and writes the section; return false to stay on the
/// page (e.g. a validation error). In [guided] mode a successful save
/// opens the next unfinished section; otherwise it returns to Profile.
class EditorPage extends ConsumerWidget {
  const EditorPage({
    super.key,
    required this.section,
    required this.data,
    required this.guided,
    required this.subtitle,
    required this.onSave,
    required this.children,
  });

  final ProfileSection section;
  final ProfileData data;
  final bool guided;
  final String subtitle;
  final Future<bool> Function() onSave;
  final List<Widget> children;

  /// Next core section after [section] that isn't complete yet.
  ProfileSection? _nextSection() {
    final core = ProfileSection.core;
    final start = core.indexOf(section);
    for (var i = 1; i <= core.length; i++) {
      final s = core[(start + i) % core.length];
      if (s != section && !data.isComplete(s)) return s;
    }
    return null;
  }

  Future<void> _save(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final ok = await onSave();
    if (!ok || !context.mounted) return;

    final next = guided ? _nextSection() : null;
    if (next != null) {
      context.pushReplacement(AppRoutes.profileEdit(next.id, guided: true));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${section.title} saved.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = ref.watch(profileSaveControllerProvider);
    final core = ProfileSection.core;
    final step = core.indexOf(section) + 1;

    return AuthPage(
      eyebrow: section.isOptional
          ? 'Optional'
          : 'Step $step of ${core.length}',
      title: section.title,
      subtitle: Text(subtitle),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saving.hasError) ...[
            const InlineError(
                'Couldn’t save. Check your connection and try again.'),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: guided && _nextSection() != null ? 'Save & continue' : 'Save',
            isLoading: saving.isLoading,
            onPressed: () => _save(context),
          ),
        ],
      ),
      children: children,
    );
  }
}
