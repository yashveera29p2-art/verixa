import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/form_fields.dart';
import '../../../auth/domain/user_profile.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile_data.dart';
import '../../domain/profile_section.dart';
import 'editor_page.dart';

/// Section 2: questions branch by status (CLAUDE.md §5):
/// Student → course details; Fresher → same + graduation and target role;
/// Working professional → company, designation, start date, experience.
class StatusEditor extends ConsumerStatefulWidget {
  const StatusEditor({super.key, required this.data, required this.guided});

  final ProfileData data;
  final bool guided;

  @override
  ConsumerState<StatusEditor> createState() => _StatusEditorState();
}

class _StatusEditorState extends ConsumerState<StatusEditor> {
  late final StatusDetails _d = widget.data.statusDetails;
  late UserStatus _status = _d.status;

  late final _college = TextEditingController(text: _d.college);
  late final _degree = TextEditingController(text: _d.degree);
  late final _branch = TextEditingController(text: _d.branch);
  late final _currentYear = TextEditingController(text: _d.currentYear);
  late final _gradYear = TextEditingController(text: _d.graduationYear);
  late final _cgpa = TextEditingController(text: _d.cgpa);
  late final _targetRole = TextEditingController(text: _d.targetRole);
  late final _company = TextEditingController(text: _d.company);
  late final _designation = TextEditingController(text: _d.designation);
  late final _startDate = TextEditingController(text: _d.startDate);
  late final _years = TextEditingController(text: _d.totalExperienceYears);
  String? _orgError;

  List<TextEditingController> get _all => [
        _college, _degree, _branch, _currentYear, _gradYear, _cgpa,
        _targetRole, _company, _designation, _startDate, _years,
      ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _save() async {
    final org = _status.asksForCompany ? _company.text : _college.text;
    final error = org.trim().isEmpty
        ? (_status.asksForCompany
            ? 'Please enter your company.'
            : 'Please enter your college.')
        : null;
    setState(() => _orgError = error);
    if (error != null) return false;

    final details = StatusDetails(
      status: _status,
      college: _college.text,
      degree: _degree.text,
      branch: _branch.text,
      currentYear: _currentYear.text,
      graduationYear: _gradYear.text,
      cgpa: _cgpa.text,
      targetRole: _targetRole.text,
      company: _company.text,
      designation: _designation.text,
      startDate: _startDate.text,
      totalExperienceYears: _years.text,
    );
    return ref
        .read(profileSaveControllerProvider.notifier)
        .save((uid, repo) => repo.saveStatus(uid, details));
  }

  static final _yearFormat = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];
  static final _decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    LengthLimitingTextInputFormatter(5),
  ];

  @override
  Widget build(BuildContext context) {
    return EditorPage(
      section: ProfileSection.status,
      data: widget.data,
      guided: widget.guided,
      subtitle: 'Tell us where you are right now.',
      onSave: _save,
      children: [
        const FormGroupLabel('I am a'),
        ChoiceChips<UserStatus>(
          options: UserStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          onSelected: (s) => setState(() {
            _status = s;
            _orgError = null;
          }),
        ),
        if (_status == UserStatus.workingProfessional)
          ..._workingFields()
        else
          ..._educationFields(isStudent: _status == UserStatus.student),
      ],
    );
  }

  List<Widget> _educationFields({required bool isStudent}) => [
        const FormGroupLabel('Your course'),
        LabeledTextField(
          controller: _college,
          label: 'College',
          capitalization: TextCapitalization.words,
          errorText: _orgError,
        ),
        FieldRow(
          left: LabeledTextField(
            controller: _degree,
            label: 'Degree',
            hint: 'B.Tech',
          ),
          right: LabeledTextField(
            controller: _branch,
            label: 'Branch',
            hint: 'CSE',
          ),
        ),
        if (isStudent)
          LabeledTextField(
            controller: _currentYear,
            label: 'Current year / semester',
            hint: '3rd year, 6th sem',
          ),
        FieldRow(
          left: LabeledTextField(
            controller: _gradYear,
            label: isStudent ? 'Expected graduation' : 'Graduation year',
            hint: '2027',
            keyboardType: TextInputType.number,
            inputFormatters: _yearFormat,
          ),
          right: LabeledTextField(
            controller: _cgpa,
            label: 'CGPA',
            hint: '8.2',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimal,
          ),
        ),
        if (!isStudent)
          LabeledTextField(
            controller: _targetRole,
            label: 'Target role',
            hint: 'Software Engineer',
            capitalization: TextCapitalization.words,
          ),
      ];

  List<Widget> _workingFields() => [
        const FormGroupLabel('Your job'),
        LabeledTextField(
          controller: _company,
          label: 'Company',
          capitalization: TextCapitalization.words,
          errorText: _orgError,
        ),
        LabeledTextField(
          controller: _designation,
          label: 'Designation',
          hint: 'Associate Software Engineer',
          capitalization: TextCapitalization.words,
        ),
        FieldRow(
          left: LabeledTextField(
            controller: _startDate,
            label: 'Start date',
            hint: 'Jun 2023',
          ),
          right: LabeledTextField(
            controller: _years,
            label: 'Experience (yrs)',
            hint: '2.5',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _decimal,
          ),
        ),
      ];
}
