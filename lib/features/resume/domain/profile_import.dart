import '../../profile/domain/profile_data.dart';
import '../../profile/domain/profile_section.dart';
import 'parsed_resume.dart';

/// Merge rules for importing a parsed resume into the profile.
///
/// Importing never replaces what the user typed: it only fills empty
/// fields and adds entries (projects, skills, …) that aren't there yet.
abstract final class ProfileImport {
  static String _fill(String current, String incoming) =>
      current.trim().isEmpty ? incoming : current;

  static List<String> _union(List<String> current, List<String> incoming) {
    final seen = current.map((s) => s.toLowerCase()).toSet();
    return [
      ...current,
      for (final s in incoming)
        if (seen.add(s.toLowerCase())) s,
    ];
  }

  static ContactInfo contact(ContactInfo cur, ContactInfo inc) => ContactInfo(
    fullName: _fill(cur.fullName, inc.fullName),
    city: _fill(cur.city, inc.city),
    state: _fill(cur.state, inc.state),
    linkedin: _fill(cur.linkedin, inc.linkedin),
    github: _fill(cur.github, inc.github),
    portfolio: _fill(cur.portfolio, inc.portfolio),
    dateOfBirth: cur.dateOfBirth,
  );

  /// Only students and freshers have course details to fill.
  static StatusDetails status(StatusDetails cur, ParsedDegree deg) {
    if (cur.status.asksForCompany) return cur;
    return StatusDetails(
      status: cur.status,
      college: _fill(cur.college, deg.college),
      degree: _fill(cur.degree, deg.degree),
      branch: _fill(cur.branch, deg.branch),
      currentYear: _fill(cur.currentYear, deg.currentYear),
      graduationYear: _fill(cur.graduationYear, deg.graduationYear),
      cgpa: _fill(cur.cgpa, deg.cgpa),
      targetRole: cur.targetRole,
      company: cur.company,
      designation: cur.designation,
      startDate: cur.startDate,
      totalExperienceYears: cur.totalExperienceYears,
    );
  }

  static SchoolRecord _school(SchoolRecord cur, SchoolRecord inc) =>
      SchoolRecord(
        board: _fill(cur.board, inc.board),
        school: _fill(cur.school, inc.school),
        score: _fill(cur.score, inc.score),
        year: _fill(cur.year, inc.year),
      );

  static EducationHistory education(
    EducationHistory cur,
    EducationHistory inc,
  ) {
    final existing = cur.additional
        .map((q) => q.qualification.toLowerCase())
        .toSet();
    return EducationHistory(
      class10: _school(cur.class10, inc.class10),
      class12: _school(cur.class12, inc.class12),
      additional: [
        ...cur.additional,
        for (final q in inc.additional)
          if (existing.add(q.qualification.toLowerCase())) q,
      ],
    );
  }

  static CareerGoal careerGoal(CareerGoal cur, CareerGoal inc) => CareerGoal(
    targetRole: _fill(cur.targetRole, inc.targetRole),
    domain: cur.domain,
    objective: _fill(cur.objective, inc.objective),
  );

  static ExperienceHistory experience(
    ExperienceHistory cur,
    List<ExperienceEntry> inc,
  ) {
    String key(ExperienceEntry e) =>
        '${e.company.toLowerCase()}|${e.role.toLowerCase()}';
    final seen = cur.entries.map(key).toSet();
    final entries = [
      ...cur.entries,
      for (final e in inc)
        if (seen.add(key(e))) e,
    ];
    return ExperienceHistory(
      entries: entries,
      noneYet: entries.isEmpty && cur.noneYet,
    );
  }

  static List<ProjectEntry> projects(
    List<ProjectEntry> cur,
    List<ProjectEntry> inc,
  ) {
    final seen = cur.map((p) => p.title.toLowerCase()).toSet();
    return [
      ...cur,
      for (final p in inc)
        if (seen.add(p.title.toLowerCase())) p,
    ];
  }

  static SkillSet skills(SkillSet cur, SkillSet inc) => SkillSet(
    technical: _union(cur.technical, inc.technical),
    tools: _union(cur.tools, inc.tools),
    soft: _union(cur.soft, inc.soft),
    languages: _union(cur.languages, inc.languages),
  );

  static Extras extras(Extras cur, Extras inc) => Extras({
    for (final key in Extras.fields.keys) key: _union(cur[key], inc[key]),
  });

  /// Builds the merged value for each selected section, ready to save.
  static ImportPlan plan(
    ProfileData current,
    ParsedResume parsed,
    Set<ProfileSection> sections,
  ) {
    bool pick(ProfileSection s) => sections.contains(s);
    return ImportPlan(
      contact: pick(ProfileSection.contact)
          ? contact(current.contact, parsed.contact)
          : null,
      status: pick(ProfileSection.status)
          ? status(current.statusDetails, parsed.degree)
          : null,
      education: pick(ProfileSection.education)
          ? education(current.education, parsed.education)
          : null,
      careerGoal: pick(ProfileSection.careerGoal)
          ? careerGoal(current.careerGoal, parsed.careerGoal)
          : null,
      experience: pick(ProfileSection.experience)
          ? experience(current.experience, parsed.experience)
          : null,
      projects: pick(ProfileSection.projects)
          ? projects(current.projects, parsed.projects)
          : null,
      skills: pick(ProfileSection.skills)
          ? skills(current.skills, parsed.skills)
          : null,
      extras: pick(ProfileSection.extras)
          ? extras(current.extras, parsed.extras)
          : null,
    );
  }
}

/// Merged section values to write; null means "leave this section alone".
class ImportPlan {
  const ImportPlan({
    this.contact,
    this.status,
    this.education,
    this.careerGoal,
    this.experience,
    this.projects,
    this.skills,
    this.extras,
  });

  final ContactInfo? contact;
  final StatusDetails? status;
  final EducationHistory? education;
  final CareerGoal? careerGoal;
  final ExperienceHistory? experience;
  final List<ProjectEntry>? projects;
  final SkillSet? skills;
  final Extras? extras;
}
