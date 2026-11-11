import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Section 7: technical skills, tools, soft skills and spoken languages.
class SkillsEditor extends ConsumerStatefulWidget {
  const SkillsEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<SkillsEditor> createState() => _SkillsEditorState();
}

class _SkillsEditorState extends ConsumerState<SkillsEditor> {
  late SkillSet _skills = widget.data.skills;

  Future<bool> _save() => ref
      .read(profileSaveControllerProvider.notifier)
      .save((uid, repo) => repo.saveSkills(uid, _skills));

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.skills,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Only add skills you can answer interview questions on.',
      onSave: _save,
      children: [
        ChipListField(
          label: 'Technical skills',
          hint: 'Java, SQL, Data structures…',
          values: _skills.technical,
          onChanged: (v) => setState(() => _skills = SkillSet(
              technical: v,
              tools: _skills.tools,
              soft: _skills.soft,
              languages: _skills.languages)),
        ),
        ChipListField(
          label: 'Tools',
          hint: 'Git, VS Code, Figma…',
          values: _skills.tools,
          onChanged: (v) => setState(() => _skills = SkillSet(
              technical: _skills.technical,
              tools: v,
              soft: _skills.soft,
              languages: _skills.languages)),
        ),
        ChipListField(
          label: 'Soft skills',
          hint: 'Teamwork, public speaking…',
          values: _skills.soft,
          onChanged: (v) => setState(() => _skills = SkillSet(
              technical: _skills.technical,
              tools: _skills.tools,
              soft: v,
              languages: _skills.languages)),
        ),
        ChipListField(
          label: 'Languages you speak',
          hint: 'English, Telugu, Hindi…',
          values: _skills.languages,
          onChanged: (v) => setState(() => _skills = SkillSet(
              technical: _skills.technical,
              tools: _skills.tools,
              soft: _skills.soft,
              languages: v)),
        ),
      ],
    );
  }
}
