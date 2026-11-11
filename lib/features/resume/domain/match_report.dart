import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/profile_data.dart';

// JSON helpers.
Map<String, dynamic> _m(Object? v) => (v as Map<String, dynamic>?) ?? const {};
List<dynamic> _l(Object? v) => (v as List<dynamic>?) ?? const [];
String _s(Map<String, dynamic> m, String k) => (m[k] as String?) ?? '';

enum MatchStatus {
  met('Met'),
  partial('Partly met'),
  missing('Missing');

  const MatchStatus(this.label);
  final String label;

  static MatchStatus fromId(String? id) =>
      values.firstWhere((s) => s.name == id, orElse: () => MatchStatus.missing);
}

enum MatchVerdict {
  strong('Strong match'),
  good('Good match'),
  partial('Partial match'),
  low('Low match');

  const MatchVerdict(this.label);
  final String label;

  static MatchVerdict fromId(String? id) =>
      values.firstWhere((v) => v.name == id, orElse: () => MatchVerdict.low);
}

/// One requirement from the JD and how the profile covers it.
class RequirementResult {
  const RequirementResult({
    required this.text,
    required this.required,
    required this.kind,
    required this.status,
    this.evidence = '',
  });

  final String text;
  final bool required; // false = nice-to-have
  final String kind; // skill | experience | education | responsibility
  final MatchStatus status;

  /// The profile item that satisfies it, e.g. "Project: Verixa".
  final String evidence;

  factory RequirementResult.fromJson(Map<String, dynamic> j) =>
      RequirementResult(
        text: _s(j, 'text'),
        required: _s(j, 'importance') != 'preferred',
        kind: _s(j, 'kind'),
        status: MatchStatus.fromId(j['status'] as String?),
        evidence: _s(j, 'evidence'),
      );

  Map<String, dynamic> toFirestore() => {
    'text': text.length > 200 ? text.substring(0, 200) : text,
    'importance': required ? 'required' : 'preferred',
    'kind': kind,
    'status': status.name,
    'evidence': evidence,
  };
}

class MissingSkill {
  const MissingSkill(this.skill, {required this.required});
  final String skill;
  final bool required;

  factory MissingSkill.fromJson(Map<String, dynamic> j) => MissingSkill(
    _s(j, 'skill'),
    required: _s(j, 'importance') != 'preferred',
  );

  Map<String, dynamic> toFirestore() => {
    'skill': skill,
    'importance': required ? 'required' : 'preferred',
  };
}

/// The backend's /v1/jobs/match result (feature 8).
class MatchReport {
  const MatchReport({
    required this.matchScore,
    required this.verdict,
    required this.jobTitle,
    required this.seniority,
    required this.requirements,
    required this.matchedSkills,
    required this.missingSkills,
    required this.suggestions,
    this.skillCoverage,
    this.yearsRequired,
    this.education = '',
    this.semantic = true,
  });

  final int matchScore;
  final MatchVerdict verdict;
  final String jobTitle;
  final String seniority;
  final int? yearsRequired;
  final String education;
  final int? skillCoverage;
  final List<RequirementResult> requirements;
  final List<String> matchedSkills;
  final List<MissingSkill> missingSkills;
  final List<String> suggestions;

  /// False if the backend fell back to word matching.
  final bool semantic;

  factory MatchReport.fromJson(Map<String, dynamic> j) {
    final job = _m(j['job']);
    return MatchReport(
      matchScore: (j['matchScore'] as num?)?.toInt() ?? 0,
      verdict: MatchVerdict.fromId(j['verdict'] as String?),
      jobTitle: _s(job, 'title').isNotEmpty
          ? _s(job, 'title')
          : _s(j, 'jobTitle'),
      seniority: _s(job, 'seniority').isNotEmpty
          ? _s(job, 'seniority')
          : _s(j, 'seniority'),
      yearsRequired: ((job['yearsRequired'] ?? j['yearsRequired']) as num?)
          ?.toInt(),
      education: _s(job, 'education').isNotEmpty
          ? _s(job, 'education')
          : _s(j, 'education'),
      skillCoverage: (j['skillCoverage'] as num?)?.toInt(),
      requirements: _l(j['requirements'])
          .map((r) => RequirementResult.fromJson(_m(r)))
          .toList(),
      matchedSkills: _l(j['matchedSkills']).cast<String>(),
      missingSkills: _l(j['missingSkills'])
          .map((m) => MissingSkill.fromJson(_m(m)))
          .toList(),
      suggestions: _l(j['suggestions']).cast<String>(),
      semantic: (j['semantic'] as bool?) ?? true,
    );
  }
}

/// A saved match in `users/{uid}/matches`. Keeps a short JD snippet, not
/// the whole posting.
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.jdSnippet,
    required this.createdAt,
    required this.report,
  });

  final String id;
  final String jdSnippet;
  final DateTime? createdAt;
  final MatchReport report;

  static Map<String, dynamic> toFirestore(String jd, MatchReport r) {
    final snippet = jd.trim().replaceAll(RegExp(r'\s+'), ' ');
    return {
      'jdSnippet': snippet.length > 300 ? snippet.substring(0, 300) : snippet,
      'createdAt': FieldValue.serverTimestamp(),
      'matchScore': r.matchScore,
      'verdict': r.verdict.name,
      'jobTitle': r.jobTitle.length > 120
          ? r.jobTitle.substring(0, 120)
          : r.jobTitle,
      'seniority': r.seniority,
      'yearsRequired': r.yearsRequired,
      'education': r.education,
      'skillCoverage': r.skillCoverage,
      'requirements': r.requirements
          .take(40)
          .map((q) => q.toFirestore())
          .toList(),
      'matchedSkills': r.matchedSkills.take(40).toList(),
      'missingSkills': r.missingSkills
          .take(40)
          .map((m) => m.toFirestore())
          .toList(),
      'suggestions': r.suggestions.take(10).toList(),
    };
  }

  factory MatchRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return MatchRecord(
      id: doc.id,
      jdSnippet: _s(d, 'jdSnippet'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      report: MatchReport.fromJson(d),
    );
  }
}

/// The profile fields the backend matches against (its `ProfileIn`).
Map<String, dynamic> matchProfileJson(ProfileData p) {
  final status = p.statusDetails;
  return {
    'status': p.status.id,
    'targetRole': p.careerGoal.targetRole.isNotEmpty
        ? p.careerGoal.targetRole
        : status.targetRole,
    'degree': status.degree,
    'branch': status.branch,
    'cgpa': status.cgpa,
    'graduationYear': status.graduationYear,
    'totalExperienceYears': double.tryParse(status.totalExperienceYears),
    'skills': p.skills.technical,
    'tools': p.skills.tools,
    'softSkills': p.skills.soft,
    'projects': [
      for (final pr in p.projects)
        {
          'title': pr.title,
          'description': pr.description,
          'techStack': pr.techStack,
        },
    ],
    'experience': [
      for (final e in p.experience.entries)
        {
          'type': e.type,
          'company': e.company,
          'role': e.role,
          'description': e.description,
        },
    ],
    'certifications': p.extras['certifications'],
  };
}
