import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Section 4: target role/domain and a short objective.
class CareerGoalEditor extends ConsumerStatefulWidget {
  const CareerGoalEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<CareerGoalEditor> createState() => _CareerGoalEditorState();
}

class _CareerGoalEditorState extends ConsumerState<CareerGoalEditor> {
  late final _role =
      TextEditingController(text: widget.data.careerGoal.targetRole);
  late final _domain = TextEditingController(text: widget.data.careerGoal.domain);
  late final _objective =
      TextEditingController(text: widget.data.careerGoal.objective);

  @override
  void dispose() {
    _role.dispose();
    _domain.dispose();
    _objective.dispose();
    super.dispose();
  }

  Future<bool> _save() {
    final goal = CareerGoal(
      targetRole: _role.text,
      domain: _domain.text,
      objective: _objective.text,
    );
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveCareerGoal(uid, goal));
  }

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.careerGoal,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'What are you aiming for next?',
      onSave: _save,
      children: [
        LabeledTextField(
          controller: _role,
          label: 'Target role',
          hint: 'Backend Developer',
          capitalization: TextCapitalization.words,
        ),
        LabeledTextField(
          controller: _domain,
          label: 'Domain (optional)',
          hint: 'Fintech, healthcare, embedded…',
        ),
        LabeledTextField(
          controller: _objective,
          label: 'Short objective',
          helper: 'Two or three sentences, in your own words.',
          maxLines: 4,
          maxLength: 300,
        ),
      ],
    );
  }
}
