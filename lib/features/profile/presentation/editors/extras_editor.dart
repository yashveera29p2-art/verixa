import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Section 8 (optional): certifications, achievements and activities.
class ExtrasEditor extends ConsumerStatefulWidget {
  const ExtrasEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<ExtrasEditor> createState() => _ExtrasEditorState();
}

class _ExtrasEditorState extends ConsumerState<ExtrasEditor> {
  late final Map<String, List<String>> _lists = {
    for (final key in Extras.fields.keys) key: widget.data.extras[key],
  };

  static const _hints = {
    'certifications': 'AWS Cloud Practitioner (2025)…',
    'achievements': 'Smart India Hackathon finalist…',
    'publications': 'Paper title, venue, year',
    'positions': 'Class representative…',
    'clubs': 'Coding club, robotics club…',
    'nssNcc': 'NSS volunteer, NCC B certificate…',
    'volunteering': 'Teaching at an NGO…',
    'hobbies': 'Chess, photography…',
  };

  Future<bool> _save() => ref
      .read(profileSaveControllerProvider.notifier)
      .save((uid, repo) => repo.saveExtras(uid, Extras(_lists)));

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.extras,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Add whatever applies to you. Skip the rest.',
      onSave: _save,
      children: [
        for (final entry in Extras.fields.entries)
          ChipListField(
            label: entry.value,
            hint: _hints[entry.key],
            values: _lists[entry.key]!,
            onChanged: (v) => setState(() => _lists[entry.key] = v),
          ),
      ],
    );
  }
}
