import 'package:cloud_firestore/cloud_firestore.dart';

import 'parsed_resume.dart';

// JSON helpers.
Map<String, dynamic> _m(Object? v) => (v as Map<String, dynamic>?) ?? const {};
List<dynamic> _l(Object? v) => (v as List<dynamic>?) ?? const [];
String _s(Map<String, dynamic> m, String k) => (m[k] as String?) ?? '';
int? _i(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt();

enum Severity {
  high('High'),
  medium('Medium'),
  low('Low');

  const Severity(this.label);
  final String label;

  static Severity fromId(String? id) =>
      values.firstWhere((s) => s.name == id, orElse: () => Severity.low);
}

enum RiskLevel {
  clean('No manipulation found'),
  low('Minor issues'),
  medium('Suspicious content'),
  high('Manipulation detected');

  const RiskLevel(this.label);
  final String label;

  static RiskLevel fromId(String? id) =>
      values.firstWhere((r) => r.name == id, orElse: () => RiskLevel.clean);
}

/// Human names for each manipulation technique (feature 2).
const techniqueNames = {
  'hidden_text': 'Hidden text',
  'prompt_injection': 'Prompt injection',
  'keyword_stuffing': 'Keyword stuffing',
  'metadata_stuffing': 'Hidden file keywords',
  'invisible_characters': 'Invisible characters',
  'homoglyphs': 'Look-alike letters',
};

/// One suspicious finding, with where it is and what it says.
class Threat {
  const Threat({
    required this.technique,
    required this.severity,
    required this.title,
    required this.description,
    this.evidence = '',
    this.page,
    this.section,
    this.line,
    this.hidden = false,
  });

  final String technique;
  final Severity severity;
  final String title;
  final String description;
  final String evidence;
  final int? page;
  final String? section;
  final int? line;
  final bool hidden;

  String get techniqueName => techniqueNames[technique] ?? technique;

  /// "Page 1 · Skills section · Line 12" (only the parts we know).
  String get locationLabel => [
    if (page != null) 'Page $page',
    if (section != null && section!.isNotEmpty)
      '${section![0].toUpperCase()}${section!.substring(1)} section',
    if (line != null) 'Line $line',
  ].join(' · ');

  factory Threat.fromJson(Map<String, dynamic> j) {
    final loc = _m(j['location']);
    return Threat(
      technique: _s(j, 'technique'),
      severity: Severity.fromId(j['severity'] as String?),
      title: _s(j, 'title'),
      description: _s(j, 'description'),
      evidence: _s(j, 'evidence'),
      page: _i(loc, 'page') ?? _i(j, 'page'),
      section: (loc['section'] ?? j['section']) as String?,
      line: _i(loc, 'line') ?? _i(j, 'line'),
      hidden: (j['hidden'] as bool?) ?? false,
    );
  }

  /// Flat shape stored in scan history.
  Map<String, dynamic> toFirestore() => {
    'technique': technique,
    'severity': severity.name,
    'title': title,
    'description': description,
    'evidence': evidence.length > 160 ? evidence.substring(0, 160) : evidence,
    'page': page,
    'section': section,
    'line': line,
    'hidden': hidden,
  };
}

/// One part of the ATS score, e.g. "Standard sections 17 / 25".
class AtsComponent {
  const AtsComponent({
    required this.key,
    required this.label,
    required this.score,
    required this.max,
    this.notes = const [],
  });

  final String key;
  final String label;
  final int score;
  final int max;
  final List<String> notes;

  factory AtsComponent.fromJson(Map<String, dynamic> j) => AtsComponent(
    key: _s(j, 'key'),
    label: _s(j, 'label'),
    score: _i(j, 'score') ?? 0,
    max: _i(j, 'max') ?? 0,
    notes: _l(j['notes']).cast<String>(),
  );

  Map<String, dynamic> toFirestore() => {
    'key': key,
    'label': label,
    'score': score,
    'max': max,
    'notes': notes,
  };
}

/// The security + ATS report (features 1–4).
class ScanReport {
  const ScanReport({
    required this.atsScore,
    required this.riskLevel,
    required this.threats,
    required this.breakdown,
    required this.suggestions,
    this.parsed,
  });

  final int atsScore;
  final RiskLevel riskLevel;
  final List<Threat> threats;
  final List<AtsComponent> breakdown;
  final List<String> suggestions;

  /// Visible-text parse, safe to import. Not kept in history.
  final ParsedResume? parsed;

  factory ScanReport.fromJson(Map<String, dynamic> j) => ScanReport(
    atsScore: _i(j, 'atsScore') ?? 0,
    riskLevel: RiskLevel.fromId(j['riskLevel'] as String?),
    threats: _l(j['threats']).map((t) => Threat.fromJson(_m(t))).toList(),
    breakdown: _l(j['atsBreakdown'] ?? j['breakdown'])
        .map((c) => AtsComponent.fromJson(_m(c)))
        .toList(),
    suggestions: _l(j['suggestions']).cast<String>(),
    parsed: j['parsed'] == null ? null : ParsedResume.fromJson(_m(j['parsed'])),
  );
}

/// A saved scan in `users/{uid}/scans` (feature 5). Stores the report and
/// short evidence quotes — never the resume file or its full text.
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.report,
  });

  final String id;
  final String fileName;
  final DateTime? createdAt;
  final ScanReport report;

  static Map<String, dynamic> toFirestore(String fileName, ScanReport r) => {
    'fileName': fileName.length > 200 ? fileName.substring(0, 200) : fileName,
    'createdAt': FieldValue.serverTimestamp(),
    'atsScore': r.atsScore,
    'riskLevel': r.riskLevel.name,
    'threatCount': r.threats.length,
    'threats': r.threats.take(50).map((t) => t.toFirestore()).toList(),
    'breakdown': r.breakdown.map((c) => c.toFirestore()).toList(),
    'suggestions': r.suggestions.take(20).toList(),
  };

  factory ScanRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ScanRecord(
      id: doc.id,
      fileName: _s(d, 'fileName'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      report: ScanReport.fromJson(d),
    );
  }
}
