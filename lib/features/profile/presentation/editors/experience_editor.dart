import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/auth_page.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Controllers for one internship or job.
class _ExperienceFields {
  _ExperienceFields(ExperienceEntry e)
      : type = e.type,
        company = TextEditingController(text: e.company),
        role = TextEditingController(text: e.role),
        start = TextEditingController(text: e.start),
        end = TextEditingController(text: e.end),
        description = TextEditingController(text: e.description);

  String type;
  final TextEditingController company, role, start, end, description;

  List<TextEditingController> get _all =>
      [company, role, start, end, description];

  bool get isEmpty => _all.every((c) => c.text.trim().isEmpty);
  bool get hasRequired =>
      company.text.trim().isNotEmpty && role.text.trim().isNotEmpty;

  ExperienceEntry toEntry() => ExperienceEntry(
        type: type,
        company: company.text,
        role: role.text,
        start: start.text,
        end: end.text,
        description: description.text,
      );

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

/// Section 5: internships and jobs.
class ExperienceEditor extends ConsumerStatefulWidget {
  const ExperienceEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<ExperienceEditor> createState() => _ExperienceEditorState();
}

class _ExperienceEditorState extends ConsumerState<ExperienceEditor> {
  late final List<_ExperienceFields> _entries = widget.data.experience.entries
      .map(_ExperienceFields.new)
      .toList();
  late bool _noneYet = widget.data.experience.noneYet;
  String? _error;

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<bool> _save() async {
    final filled = _entries.where((e) => !e.isEmpty).toList();
    final error = filled.any((e) => !e.hasRequired)
        ? 'Each entry needs a company and a role.'
        : null;
    setState(() => _error = error);
    if (error != null) return false;

    final history = ExperienceHistory(
      entries: filled.map((e) => e.toEntry()).toList(),
      noneYet: _noneYet,
    );
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveExperience(uid, history));
  }

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.experience,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Internships count. Describe what you did, not just the title.',
      onSave: _save,
      children: [
        for (var i = 0; i < _entries.length; i++)
          ..._entryFields(i, _entries[i]),
        InlineError(_error),
        AddEntryButton(
          label: 'Add internship or job',
          onTap: () => setState(() {
            _entries.add(_ExperienceFields(const ExperienceEntry()));
            _noneYet = false;
          }),
        ),
        if (_entries.isEmpty)
          CheckboxListTile(
            value: _noneYet,
            onChanged: (v) => setState(() => _noneYet = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.botanicalGreen,
            title: Text('I don’t have any experience yet',
                style: AppTypography.bodyLarge),
            subtitle: Text('That’s fine — projects matter more for now.',
                style: AppTypography.bodySmall),
          ),
      ],
    );
  }

  List<Widget> _entryFields(int i, _ExperienceFields e) => [
        FormGroupLabel(
          '${e.type == 'job' ? 'Job' : 'Internship'} ${i + 1}',
          trailing: RemoveButton(
            onPressed: () => setState(() => _entries.removeAt(i).dispose()),
          ),
        ),
        ChoiceChips<String>(
          options: const ['internship', 'job'],
          selected: e.type,
          labelOf: (t) => t == 'job' ? 'Job' : 'Internship',
          onSelected: (t) => setState(() => e.type = t),
        ),
        LabeledTextField(
          controller: e.company,
          label: 'Company',
          capitalization: TextCapitalization.words,
        ),
        LabeledTextField(
          controller: e.role,
          label: 'Role',
          hint: 'Software Engineering Intern',
          capitalization: TextCapitalization.words,
        ),
        FieldRow(
          left: LabeledTextField(
              controller: e.start, label: 'Start', hint: 'Jun 2024'),
          right: LabeledTextField(
              controller: e.end, label: 'End', hint: 'Aug 2024 / Present'),
        ),
        LabeledTextField(
          controller: e.description,
          label: 'What you did',
          helper: 'Start with an action verb; include results if you can.',
          maxLines: 4,
          maxLength: 600,
        ),
      ];
}
