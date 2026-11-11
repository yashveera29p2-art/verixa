import 'package:cloud_firestore/cloud_firestore.dart';

/// The sections a generated resume can have, in a user-chosen order.
enum ResumeSectionKind {
  summary('Summary'),
  education('Education'),
  experience('Experience'),
  projects('Projects'),
  skills('Skills'),
  certifications('Certifications'),
  achievements('Achievements'),
  activities('Positions & activities');

  const ResumeSectionKind(this.label);
  final String label;

  static ResumeSectionKind? fromId(String? id) {
    for (final k in values) {
      if (k.name == id) return k;
    }
    return null;
  }
}

/// Visual style of the exported resume. All templates are single-column
/// with real text, so they stay ATS-friendly.
enum ResumeTemplate {
  classic('Classic', 'Black and white, serif headings'),
  modern('Modern', 'Green accents, clean sans-serif'),
  compact('Compact', 'Tighter spacing to fit one page');

  const ResumeTemplate(this.label, this.description);
  final String label;
  final String description;

  static ResumeTemplate fromId(String? id) => values.firstWhere(
    (t) => t.name == id,
    orElse: () => ResumeTemplate.classic,
  );
}

/// What a resume version is tailored for.
enum ResumeTargetKind {
  general('General'),
  company('Company'),
  job('Job description');

  const ResumeTargetKind(this.label);
  final String label;

  static ResumeTargetKind fromId(String? id) => values.firstWhere(
    (t) => t.name == id,
    orElse: () => ResumeTargetKind.general,
  );
}

/// One saved resume version at `users/{uid}/resumes/{id}`.
///
/// It stores only choices (order, template, summary, focus skills) — the
/// content always comes from the live profile, so a resume can never
/// contain anything the user hasn't entered themselves.
class ResumeVersion {
  const ResumeVersion({
    this.id = '',
    required this.name,
    this.targetKind = ResumeTargetKind.general,
    this.targetLabel = '',
    this.companyId = '',
    this.jobTitle = '',
    this.template = ResumeTemplate.classic,
    required this.sectionOrder,
    this.hiddenSections = const {},
    this.summary = '',
    this.focusSkills = const [],
    this.alignmentScore,
    this.coverLetter = '',
    this.updatedAt,
  });

  final String id;
  final String name;
  final ResumeTargetKind targetKind;

  /// e.g. "Infosys (MNC)" or the job title.
  final String targetLabel;
  final String companyId;
  final String jobTitle;
  final ResumeTemplate template;
  final List<ResumeSectionKind> sectionOrder;
  final Set<ResumeSectionKind> hiddenSections;
  final String summary;

  /// Skills the target asks for that the profile genuinely has; listed
  /// first and used to order projects.
  final List<String> focusSkills;

  /// 0–100 fit with the target (JD match score, or company skill overlap).
  final int? alignmentScore;
  final String coverLetter;
  final DateTime? updatedAt;

  List<ResumeSectionKind> get visibleSections =>
      sectionOrder.where((s) => !hiddenSections.contains(s)).toList();

  ResumeVersion copyWith({
    String? name,
    ResumeTemplate? template,
    List<ResumeSectionKind>? sectionOrder,
    Set<ResumeSectionKind>? hiddenSections,
    String? summary,
    String? coverLetter,
  }) => ResumeVersion(
    id: id,
    name: name ?? this.name,
    targetKind: targetKind,
    targetLabel: targetLabel,
    companyId: companyId,
    jobTitle: jobTitle,
    template: template ?? this.template,
    sectionOrder: sectionOrder ?? this.sectionOrder,
    hiddenSections: hiddenSections ?? this.hiddenSections,
    summary: summary ?? this.summary,
    focusSkills: focusSkills,
    alignmentScore: alignmentScore,
    coverLetter: coverLetter ?? this.coverLetter,
    updatedAt: updatedAt,
  );

  factory ResumeVersion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data() ?? const {};
    List<String> list(String k) =>
        ((m[k] as List<dynamic>?) ?? const []).cast<String>();
    final order = list('sectionOrder')
        .map(ResumeSectionKind.fromId)
        .whereType<ResumeSectionKind>()
        .toList();
    // Sections added in later app versions go at the end.
    for (final k in ResumeSectionKind.values) {
      if (!order.contains(k)) order.add(k);
    }
    return ResumeVersion(
      id: d.id,
      name: (m['name'] as String?) ?? 'Resume',
      targetKind: ResumeTargetKind.fromId(m['targetKind'] as String?),
      targetLabel: (m['targetLabel'] as String?) ?? '',
      companyId: (m['companyId'] as String?) ?? '',
      jobTitle: (m['jobTitle'] as String?) ?? '',
      template: ResumeTemplate.fromId(m['template'] as String?),
      sectionOrder: order,
      hiddenSections: list('hiddenSections')
          .map(ResumeSectionKind.fromId)
          .whereType<ResumeSectionKind>()
          .toSet(),
      summary: (m['summary'] as String?) ?? '',
      focusSkills: list('focusSkills'),
      alignmentScore: (m['alignmentScore'] as num?)?.toInt(),
      coverLetter: (m['coverLetter'] as String?) ?? '',
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': _clip(name.trim(), 80),
    'targetKind': targetKind.name,
    'targetLabel': _clip(targetLabel, 160),
    'companyId': companyId,
    'jobTitle': _clip(jobTitle, 160),
    'template': template.name,
    'sectionOrder': sectionOrder.map((s) => s.name).toList(),
    'hiddenSections': hiddenSections.map((s) => s.name).toList(),
    'summary': summary.trim(),
    'focusSkills': focusSkills,
    'alignmentScore': alignmentScore,
    'coverLetter': coverLetter.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
