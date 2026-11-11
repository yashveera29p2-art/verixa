import '../../profile/domain/profile_data.dart';
import '../../profile/domain/profile_section.dart';

// JSON helpers.
Map<String, dynamic> _m(Object? v) => (v as Map<String, dynamic>?) ?? const {};
List<dynamic> _l(Object? v) => (v as List<dynamic>?) ?? const [];
String _s(Map<String, dynamic> m, String k) => (m[k] as String?) ?? '';
List<String> _ls(Map<String, dynamic> m, String k) => _l(m[k]).cast<String>();

/// Degree details found in the resume; these fill the Status section
/// (college, degree, branch, CGPA, graduation year).
class ParsedDegree {
  const ParsedDegree({
    this.college = '',
    this.degree = '',
    this.branch = '',
    this.cgpa = '',
    this.graduationYear = '',
  });

  final String college;
  final String degree;
  final String branch;
  final String cgpa;
  final String graduationYear;

  bool get isEmpty =>
      [college, degree, branch, cgpa, graduationYear].every((v) => v.isEmpty);
}

/// The backend's parse result (POST /v1/resumes/parse), already mapped onto
/// the app's profile classes so it can be reviewed and imported.
class ParsedResume {
  const ParsedResume({
    required this.contact,
    required this.email,
    required this.phone,
    required this.degree,
    required this.education,
    required this.careerGoal,
    required this.experience,
    required this.projects,
    required this.skills,
    required this.extras,
    required this.warnings,
    required this.confidence,
    required this.sectionsFound,
  });

  final ContactInfo contact;
  final String email; // shown for review; the account email isn't changed
  final String phone; // shown for review; the account phone is the login
  final ParsedDegree degree;
  final EducationHistory education;
  final CareerGoal careerGoal;
  final List<ExperienceEntry> experience;
  final List<ProjectEntry> projects;
  final SkillSet skills;
  final Extras extras;
  final List<String> warnings;
  final Map<String, double> confidence;
  final List<String> sectionsFound;

  factory ParsedResume.fromJson(Map<String, dynamic> json) {
    final c = _m(json['contact']);
    final edu = _m(json['education']);
    final deg = _m(edu['degree']);
    final skills = _m(json['skills']);
    final extras = _m(json['extras']);
    return ParsedResume(
      contact: ContactInfo(
        fullName: _s(c, 'fullName'),
        city: _s(c, 'city'),
        linkedin: _s(c, 'linkedin'),
        github: _s(c, 'github'),
        portfolio: _s(c, 'portfolio'),
      ),
      email: _s(c, 'email'),
      phone: _s(c, 'phone'),
      degree: ParsedDegree(
        college: _s(deg, 'college'),
        degree: _s(deg, 'degree'),
        branch: _s(deg, 'branch'),
        cgpa: _s(deg, 'cgpa'),
        graduationYear: _s(deg, 'graduationYear'),
      ),
      education: EducationHistory.fromMap(edu),
      careerGoal: CareerGoal(
        objective: _s(_m(json['careerGoal']), 'objective'),
      ),
      experience: _l(json['experience'])
          .map((e) => ExperienceEntry.fromMap(_m(e)))
          .toList(),
      projects: _l(json['projects'])
          .map((e) => ProjectEntry.fromMap(_m(e)))
          .toList(),
      skills: SkillSet.fromMap(skills),
      extras: Extras({
        for (final key in Extras.fields.keys) key: _ls(extras, key),
      }),
      warnings: _ls(json, 'warnings'),
      confidence: _m(json['confidence'])
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      sectionsFound: _ls(_m(json['meta']), 'sectionsFound'),
    );
  }

  /// Profile sections this resume has something for.
  List<ProfileSection> get availableSections => [
    if (contact.fullName.isNotEmpty ||
        contact.city.isNotEmpty ||
        contact.linkedin.isNotEmpty ||
        contact.github.isNotEmpty)
      ProfileSection.contact,
    if (!degree.isEmpty) ProfileSection.status,
    if (education.class10.year.isNotEmpty ||
        education.class12.year.isNotEmpty ||
        education.class10.score.isNotEmpty ||
        education.class12.score.isNotEmpty ||
        education.additional.isNotEmpty)
      ProfileSection.education,
    if (careerGoal.objective.isNotEmpty) ProfileSection.careerGoal,
    if (experience.isNotEmpty) ProfileSection.experience,
    if (projects.isNotEmpty) ProfileSection.projects,
    if (skills.technical.isNotEmpty ||
        skills.tools.isNotEmpty ||
        skills.soft.isNotEmpty ||
        skills.languages.isNotEmpty)
      ProfileSection.skills,
    if (extras.itemCount > 0) ProfileSection.extras,
  ];
}
