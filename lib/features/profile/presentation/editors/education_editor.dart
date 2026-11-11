import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_fields.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Controllers for one 10th/12th record.
class _SchoolFields {
  _SchoolFields(SchoolRecord r)
      : board = TextEditingController(text: r.board),
        school = TextEditingController(text: r.school),
        score = TextEditingController(text: r.score),
        year = TextEditingController(text: r.year);

  final TextEditingController board, school, score, year;

  SchoolRecord toRecord() => SchoolRecord(
      board: board.text, school: school.text, score: score.text, year: year.text);

  void dispose() {
    for (final c in [board, school, score, year]) {
      c.dispose();
    }
  }
}

/// Controllers for one diploma / PG entry.
class _HigherFields {
  _HigherFields(HigherQualification q)
      : qualification = TextEditingController(text: q.qualification),
        institution = TextEditingController(text: q.institution),
        score = TextEditingController(text: q.score),
        year = TextEditingController(text: q.year);

  final TextEditingController qualification, institution, score, year;

  bool get isEmpty => [qualification, institution, score, year]
      .every((c) => c.text.trim().isEmpty);

  HigherQualification toEntry() => HigherQualification(
      qualification: qualification.text,
      institution: institution.text,
      score: score.text,
      year: year.text);

  void dispose() {
    for (final c in [qualification, institution, score, year]) {
      c.dispose();
    }
  }
}

/// Section 3: 10th, 12th, and any diploma / postgraduate.
class EducationEditor extends ConsumerStatefulWidget {
  const EducationEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<EducationEditor> createState() => _EducationEditorState();
}

class _EducationEditorState extends ConsumerState<EducationEditor> {
  late final _class10 = _SchoolFields(widget.data.education.class10);
  late final _class12 = _SchoolFields(widget.data.education.class12);
  late final List<_HigherFields> _higher = widget.data.education.additional
      .map(_HigherFields.new)
      .toList();

  @override
  void dispose() {
    _class10.dispose();
    _class12.dispose();
    for (final h in _higher) {
      h.dispose();
    }
    super.dispose();
  }

  Future<bool> _save() {
    final education = EducationHistory(
      class10: _class10.toRecord(),
      class12: _class12.toRecord(),
      additional: _higher
          .where((h) => !h.isEmpty)
          .map((h) => h.toEntry())
          .toList(),
    );
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveEducation(uid, education));
  }

  static final _yearFormat = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  List<Widget> _schoolFields(_SchoolFields f) => [
        FieldRow(
          left: LabeledTextField(
              controller: f.board, label: 'Board', hint: 'CBSE / State'),
          right: LabeledTextField(
              controller: f.year,
              label: 'Year',
              hint: '2021',
              keyboardType: TextInputType.number,
              inputFormatters: _yearFormat),
        ),
        FieldRow(
          left: LabeledTextField(
              controller: f.school,
              label: 'School / college',
              capitalization: TextCapitalization.words),
          right: LabeledTextField(
              controller: f.score, label: '% or CGPA', hint: '92%'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.education,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Many companies check marks from 10th onwards.',
      onSave: _save,
      children: [
        const FormGroupLabel('10th'),
        ..._schoolFields(_class10),
        const FormGroupLabel('12th / Intermediate'),
        ..._schoolFields(_class12),
        for (var i = 0; i < _higher.length; i++) ...[
          FormGroupLabel(
            'Diploma / PG ${i + 1}',
            trailing: RemoveButton(onPressed: () => setState(() {
              _higher.removeAt(i).dispose();
            })),
          ),
          LabeledTextField(
            controller: _higher[i].qualification,
            label: 'Qualification',
            hint: 'Diploma in ECE / M.Tech CSE',
          ),
          LabeledTextField(
            controller: _higher[i].institution,
            label: 'Institution',
            capitalization: TextCapitalization.words,
          ),
          FieldRow(
            left: LabeledTextField(
                controller: _higher[i].score, label: '% or CGPA'),
            right: LabeledTextField(
                controller: _higher[i].year,
                label: 'Year',
                keyboardType: TextInputType.number,
                inputFormatters: _yearFormat),
          ),
        ],
        AddEntryButton(
          label: 'Add diploma or postgraduate',
          onTap: () => setState(() =>
              _higher.add(_HigherFields(const HigherQualification()))),
        ),
      ],
    );
  }
}
