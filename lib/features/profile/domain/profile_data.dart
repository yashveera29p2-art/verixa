import '../../auth/domain/user_profile.dart';
import 'profile_section.dart';

// Helpers for reading loosely-typed Firestore maps.
String _s(Map<String, dynamic>? m, String key) => (m?[key] as String?) ?? '';
List<String> _list(Map<String, dynamic>? m, String key) =>
    ((m?[key] as List<dynamic>?) ?? const []).cast<String>();
Map<String, dynamic>? _map(Object? v) => v as Map<String, dynamic>?;
bool _filled(String v) => v.trim().isNotEmpty;

/// Section 1 — account & contact.
class ContactInfo {
  const ContactInfo({
    this.fullName = '',
    this.city = '',
    this.state = '',
    this.linkedin = '',
    this.github = '',
    this.portfolio = '',
    this.dateOfBirth,
  });

  final String fullName;
  final String city;
  final String state;
  final String linkedin;
  final String github;
  final String portfolio;
  final DateTime? dateOfBirth;

  bool get isComplete => _filled(fullName) && _filled(city) && _filled(state);

  factory ContactInfo.fromMap(Map<String, dynamic>? m, {String fallbackName = ''}) =>
      ContactInfo(
        fullName: _filled(_s(m, 'fullName')) ? _s(m, 'fullName') : fallbackName,
        city: _s(m, 'city'),
        state: _s(m, 'state'),
        linkedin: _s(m, 'linkedin'),
        github: _s(m, 'github'),
        portfolio: _s(m, 'portfolio'),
        dateOfBirth: DateTime.tryParse(_s(m, 'dateOfBirth')),
      );

  Map<String, dynamic> toMap() => {
        'fullName': fullName.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'linkedin': linkedin.trim(),
        'github': github.trim(),
        'portfolio': portfolio.trim(),
        'dateOfBirth': dateOfBirth?.toIso8601String().substring(0, 10) ?? '',
      };
}

/// Section 2 — status details. Which fields matter depends on [status].
class StatusDetails {
  const StatusDetails({
    required this.status,
    this.college = '',
    this.degree = '',
    this.branch = '',
    this.currentYear = '',
    this.graduationYear = '',
    this.cgpa = '',
    this.targetRole = '',
    this.company = '',
    this.designation = '',
    this.startDate = '',
    this.totalExperienceYears = '',
  });

  final UserStatus status;

  // Student / fresher
  final String college;
  final String degree;
  final String branch;
  final String currentYear; // students only, e.g. "3rd year, 6th sem"
  final String graduationYear; // expected (student) or actual (fresher)
  final String cgpa;
  final String targetRole; // freshers only

  // Working professional
  final String company;
  final String designation;
  final String startDate; // e.g. "Jun 2023"
  final String totalExperienceYears;

  /// College or company, mirrored to the top-level `organisation` field.
  String get organisation => status.asksForCompany ? company : college;

  bool get isComplete => switch (status) {
        UserStatus.student => [college, degree, branch, currentYear,
            graduationYear, cgpa].every(_filled),
        UserStatus.fresher => [college, degree, branch, graduationYear, cgpa,
            targetRole].every(_filled),
        UserStatus.workingProfessional => [company, designation, startDate,
            totalExperienceYears].every(_filled),
      };

  factory StatusDetails.fromMap(Map<String, dynamic>? m,
      {required UserStatus status, String organisation = ''}) {
    final details = StatusDetails(
      status: status,
      college: _s(m, 'college'),
      degree: _s(m, 'degree'),
      branch: _s(m, 'branch'),
      currentYear: _s(m, 'currentYear'),
      graduationYear: _s(m, 'graduationYear'),
      cgpa: _s(m, 'cgpa'),
      targetRole: _s(m, 'targetRole'),
      company: _s(m, 'company'),
      designation: _s(m, 'designation'),
      startDate: _s(m, 'startDate'),
      totalExperienceYears: _s(m, 'totalExperienceYears'),
    );
    // Prefill from onboarding the first time.
    if (m == null && organisation.isNotEmpty) {
      return status.asksForCompany
          ? details.copyWithOrg(company: organisation)
          : details.copyWithOrg(college: organisation);
    }
    return details;
  }

  StatusDetails copyWithOrg({String? college, String? company}) =>
      StatusDetails(
        status: status,
        college: college ?? this.college,
        degree: degree,
        branch: branch,
        currentYear: currentYear,
        graduationYear: graduationYear,
        cgpa: cgpa,
        targetRole: targetRole,
        company: company ?? this.company,
        designation: designation,
        startDate: startDate,
        totalExperienceYears: totalExperienceYears,
      );

  /// Only the fields relevant to [status] are saved.
  Map<String, dynamic> toMap() => switch (status) {
        UserStatus.student => {
            'college': college.trim(),
            'degree': degree.trim(),
            'branch': branch.trim(),
            'currentYear': currentYear.trim(),
            'graduationYear': graduationYear.trim(),
            'cgpa': cgpa.trim(),
          },
        UserStatus.fresher => {
            'college': college.trim(),
            'degree': degree.trim(),
            'branch': branch.trim(),
            'graduationYear': graduationYear.trim(),
            'cgpa': cgpa.trim(),
            'targetRole': targetRole.trim(),
          },
        UserStatus.workingProfessional => {
            'company': company.trim(),
            'designation': designation.trim(),
            'startDate': startDate.trim(),
            'totalExperienceYears': totalExperienceYears.trim(),
          },
      };
}

/// One school-level record (10th or 12th).
class SchoolRecord {
  const SchoolRecord({
    this.board = '',
    this.school = '',
    this.score = '',
    this.year = '',
  });

  final String board;
  final String school;
  final String score; // percentage or CGPA, as typed
  final String year;

  bool get isComplete => [board, school, score, year].every(_filled);

  factory SchoolRecord.fromMap(Map<String, dynamic>? m) => SchoolRecord(
        board: _s(m, 'board'),
        school: _s(m, 'school'),
        score: _s(m, 'score'),
        year: _s(m, 'year'),
      );

  Map<String, dynamic> toMap() => {
        'board': board.trim(),
        'school': school.trim(),
        'score': score.trim(),
        'year': year.trim(),
      };
}

/// A diploma or postgraduate qualification.
class HigherQualification {
  const HigherQualification({
    this.qualification = '',
    this.institution = '',
    this.score = '',
    this.year = '',
  });

  final String qualification; // e.g. "Diploma in ECE", "M.Tech CSE"
  final String institution;
  final String score;
  final String year;

  factory HigherQualification.fromMap(Map<String, dynamic>? m) =>
      HigherQualification(
        qualification: _s(m, 'qualification'),
        institution: _s(m, 'institution'),
        score: _s(m, 'score'),
        year: _s(m, 'year'),
      );

  Map<String, dynamic> toMap() => {
        'qualification': qualification.trim(),
        'institution': institution.trim(),
        'score': score.trim(),
        'year': year.trim(),
      };
}

/// Section 3 — education history.
class EducationHistory {
  const EducationHistory({
    this.class10 = const SchoolRecord(),
    this.class12 = const SchoolRecord(),
    this.additional = const [],
  });

  final SchoolRecord class10;
  final SchoolRecord class12;
  final List<HigherQualification> additional;

  /// 10th is required; 12th or a diploma (lateral entry) is required.
  bool get isComplete =>
      class10.isComplete && (class12.isComplete || additional.isNotEmpty);

  factory EducationHistory.fromMap(Map<String, dynamic>? m) => EducationHistory(
        class10: SchoolRecord.fromMap(_map(m?['class10'])),
        class12: SchoolRecord.fromMap(_map(m?['class12'])),
        additional: ((m?['additional'] as List<dynamic>?) ?? const [])
            .map((e) => HigherQualification.fromMap(_map(e)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'class10': class10.toMap(),
        'class12': class12.toMap(),
        'additional': additional.map((e) => e.toMap()).toList(),
      };
}

/// Section 4 — career goal.
class CareerGoal {
  const CareerGoal({this.targetRole = '', this.domain = '', this.objective = ''});

  final String targetRole;
  final String domain;
  final String objective;

  bool get isComplete => _filled(targetRole) && _filled(objective);

  factory CareerGoal.fromMap(Map<String, dynamic>? m) => CareerGoal(
        targetRole: _s(m, 'targetRole'),
        domain: _s(m, 'domain'),
        objective: _s(m, 'objective'),
      );

  Map<String, dynamic> toMap() => {
        'targetRole': targetRole.trim(),
        'domain': domain.trim(),
        'objective': objective.trim(),
      };
}

/// One internship or job.
class ExperienceEntry {
  const ExperienceEntry({
    this.type = 'internship',
    this.company = '',
    this.role = '',
    this.start = '',
    this.end = '',
    this.description = '',
  });

  /// "internship" or "job".
  final String type;
  final String company;
  final String role;
  final String start; // e.g. "Jun 2024"
  final String end; // e.g. "Aug 2024" or "Present"
  final String description;

  String get duration =>
      [start, end].where(_filled).join(' – ');

  factory ExperienceEntry.fromMap(Map<String, dynamic>? m) => ExperienceEntry(
        type: _filled(_s(m, 'type')) ? _s(m, 'type') : 'internship',
        company: _s(m, 'company'),
        role: _s(m, 'role'),
        start: _s(m, 'start'),
        end: _s(m, 'end'),
        description: _s(m, 'description'),
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'company': company.trim(),
        'role': role.trim(),
        'start': start.trim(),
        'end': end.trim(),
        'description': description.trim(),
      };
}

/// Section 5 — experience. Students often have none yet, which is fine.
class ExperienceHistory {
  const ExperienceHistory({this.entries = const [], this.noneYet = false});

  final List<ExperienceEntry> entries;

  /// The user said "I don't have any experience yet".
  final bool noneYet;

  bool get isComplete => entries.isNotEmpty || noneYet;

  factory ExperienceHistory.fromMap(Map<String, dynamic>? m) =>
      ExperienceHistory(
        entries: ((m?['entries'] as List<dynamic>?) ?? const [])
            .map((e) => ExperienceEntry.fromMap(_map(e)))
            .toList(),
        noneYet: (m?['noneYet'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'entries': entries.map((e) => e.toMap()).toList(),
        'noneYet': entries.isEmpty && noneYet,
      };
}

/// One project.
class ProjectEntry {
  const ProjectEntry({
    this.title = '',
    this.description = '',
    this.techStack = const [],
    this.link = '',
    this.duration = '',
  });

  final String title;
  final String description;
  final List<String> techStack;
  final String link;
  final String duration;

  factory ProjectEntry.fromMap(Map<String, dynamic>? m) => ProjectEntry(
        title: _s(m, 'title'),
        description: _s(m, 'description'),
        techStack: _list(m, 'techStack'),
        link: _s(m, 'link'),
        duration: _s(m, 'duration'),
      );

  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'description': description.trim(),
        'techStack': techStack,
        'link': link.trim(),
        'duration': duration.trim(),
      };
}

/// Section 7 — skills.
class SkillSet {
  const SkillSet({
    this.technical = const [],
    this.tools = const [],
    this.soft = const [],
    this.languages = const [],
  });

  final List<String> technical;
  final List<String> tools;
  final List<String> soft;

  /// Spoken languages.
  final List<String> languages;

  bool get isComplete => technical.isNotEmpty;

  factory SkillSet.fromMap(Map<String, dynamic>? m) => SkillSet(
        technical: _list(m, 'technical'),
        tools: _list(m, 'tools'),
        soft: _list(m, 'soft'),
        languages: _list(m, 'languages'),
      );

  Map<String, dynamic> toMap() => {
        'technical': technical,
        'tools': tools,
        'soft': soft,
        'languages': languages,
      };
}

/// Section 8 — optional extras, each a simple list of lines.
class Extras {
  const Extras(this.lists);

  /// Keys and labels, in display order.
  static const fields = {
    'certifications': 'Certifications',
    'achievements': 'Hackathons & coding ranks',
    'publications': 'Publications',
    'positions': 'Positions of responsibility',
    'clubs': 'Clubs',
    'nssNcc': 'NSS / NCC',
    'volunteering': 'Volunteering',
    'hobbies': 'Hobbies',
  };

  final Map<String, List<String>> lists;

  List<String> operator [](String key) => lists[key] ?? const [];

  int get itemCount => lists.values.fold(0, (sum, l) => sum + l.length);

  factory Extras.fromMap(Map<String, dynamic>? m) =>
      Extras({for (final key in fields.keys) key: _list(m, key)});

  Map<String, dynamic> toMap() =>
      {for (final key in fields.keys) key: this[key]};
}

/// Everything collected in Profile, read from `users/{uid}`.
class ProfileData {
  const ProfileData({
    required this.status,
    required this.contact,
    required this.statusDetails,
    required this.education,
    required this.careerGoal,
    required this.experience,
    required this.projects,
    required this.skills,
    required this.extras,
  });

  final UserStatus status;
  final ContactInfo contact;
  final StatusDetails statusDetails;
  final EducationHistory education;
  final CareerGoal careerGoal;
  final ExperienceHistory experience;
  final List<ProjectEntry> projects;
  final SkillSet skills;
  final Extras extras;

  factory ProfileData.fromFirestore(Map<String, dynamic> data) {
    final status =
        UserStatus.fromId(data['status'] as String?) ?? UserStatus.student;
    return ProfileData(
      status: status,
      contact: ContactInfo.fromMap(_map(data['contact']),
          fallbackName: (data['fullName'] as String?) ?? ''),
      statusDetails: StatusDetails.fromMap(_map(data['statusDetails']),
          status: status,
          organisation: (data['organisation'] as String?) ?? ''),
      education: EducationHistory.fromMap(_map(data['education'])),
      careerGoal: CareerGoal.fromMap(_map(data['careerGoal'])),
      experience: ExperienceHistory.fromMap(_map(data['experience'])),
      projects: ((data['projects'] as List<dynamic>?) ?? const [])
          .map((e) => ProjectEntry.fromMap(_map(e)))
          .toList(),
      skills: SkillSet.fromMap(_map(data['skills'])),
      extras: Extras.fromMap(_map(data['extras'])),
    );
  }

  bool isComplete(ProfileSection section) => switch (section) {
        ProfileSection.contact => contact.isComplete,
        ProfileSection.status => statusDetails.isComplete,
        ProfileSection.education => education.isComplete,
        ProfileSection.careerGoal => careerGoal.isComplete,
        ProfileSection.experience => experience.isComplete,
        ProfileSection.projects => projects.isNotEmpty,
        ProfileSection.skills => skills.isComplete,
        ProfileSection.extras => extras.itemCount > 0,
      };

  /// Share of core sections (not Extras) that are complete, 0.0–1.0.
  double get completion {
    final core = ProfileSection.core;
    return core.where(isComplete).length / core.length;
  }

  int get completedCoreCount => ProfileSection.core.where(isComplete).length;

  /// The next section to fill in, or null when all core sections are done.
  ProfileSection? get nextIncomplete {
    for (final s in ProfileSection.core) {
      if (!isComplete(s)) return s;
    }
    return null;
  }

  /// Short status text for a section row, e.g. "2 projects".
  String summaryFor(ProfileSection section) => switch (section) {
        ProfileSection.experience => experience.entries.isNotEmpty
            ? _count(experience.entries.length, 'entry', 'entries')
            : experience.noneYet
                ? 'No experience yet'
                : 'Not added',
        ProfileSection.projects => projects.isEmpty
            ? 'Not added'
            : _count(projects.length, 'project', 'projects'),
        ProfileSection.extras => extras.itemCount == 0
            ? 'Optional'
            : _count(extras.itemCount, 'item', 'items'),
        _ => isComplete(section) ? 'Complete' : 'To do',
      };

  static String _count(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';
}
