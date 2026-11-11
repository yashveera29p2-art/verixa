import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/auth_page.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Controllers for one project.
class _ProjectFields {
  _ProjectFields(ProjectEntry p)
      : title = TextEditingController(text: p.title),
        description = TextEditingController(text: p.description),
        link = TextEditingController(text: p.link),
        duration = TextEditingController(text: p.duration),
        techStack = [...p.techStack];

  final TextEditingController title, description, link, duration;
  List<String> techStack;

  bool get isEmpty =>
      [title, description, link, duration].every((c) => c.text.trim().isEmpty) &&
      techStack.isEmpty;

  ProjectEntry toEntry() => ProjectEntry(
        title: title.text,
        description: description.text,
        techStack: techStack,
        link: link.text,
        duration: duration.text,
      );

  void dispose() {
    for (final c in [title, description, link, duration]) {
      c.dispose();
    }
  }
}

/// Section 6: projects with tech stack and links.
class ProjectsEditor extends ConsumerStatefulWidget {
  const ProjectsEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<ProjectsEditor> createState() => _ProjectsEditorState();
}

class _ProjectsEditorState extends ConsumerState<ProjectsEditor> {
  late final List<_ProjectFields> _projects = widget.data.projects.isEmpty
      ? [_ProjectFields(const ProjectEntry())] // start with one blank
      : widget.data.projects.map(_ProjectFields.new).toList();
  String? _error;

  @override
  void dispose() {
    for (final p in _projects) {
      p.dispose();
    }
    super.dispose();
  }

  Future<bool> _save() async {
    final filled = _projects.where((p) => !p.isEmpty).toList();
    final error = filled.any((p) => p.title.text.trim().isEmpty)
        ? 'Each project needs a title.'
        : null;
    setState(() => _error = error);
    if (error != null) return false;

    final projects = filled.map((p) => p.toEntry()).toList();
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveProjects(uid, projects));
  }

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.projects,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Academic, personal or hackathon projects all count.',
      onSave: _save,
      children: [
        for (var i = 0; i < _projects.length; i++) ...[
          FormGroupLabel(
            'Project ${i + 1}',
            trailing: RemoveButton(
              onPressed: () =>
                  setState(() => _projects.removeAt(i).dispose()),
            ),
          ),
          LabeledTextField(
            controller: _projects[i].title,
            label: 'Title',
            capitalization: TextCapitalization.words,
          ),
          LabeledTextField(
            controller: _projects[i].description,
            label: 'Description',
            helper: 'The problem, what you built, and the result.',
            maxLines: 4,
            maxLength: 600,
          ),
          ChipListField(
            label: 'Tech stack',
            hint: 'Flutter, Firebase…',
            values: _projects[i].techStack,
            onChanged: (v) => setState(() => _projects[i].techStack = v),
          ),
          FieldRow(
            left: LabeledTextField(
              controller: _projects[i].link,
              label: 'Link',
              hint: 'github.com/…',
              keyboardType: TextInputType.url,
              capitalization: TextCapitalization.none,
            ),
            right: LabeledTextField(
              controller: _projects[i].duration,
              label: 'Duration',
              hint: '2 months',
            ),
          ),
        ],
        InlineError(_error),
        AddEntryButton(
          label: 'Add project',
          onTap: () =>
              setState(() => _projects.add(_ProjectFields(const ProjectEntry()))),
        ),
      ],
    );
  }
}
