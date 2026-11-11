import 'company_category.dart';

/// What a company typically expects from candidates.
class CompanyExpectations {
  const CompanyExpectations({
    required this.skills,
    required this.academics,
    required this.experience,
    required this.traits,
  });

  final List<String> skills;
  final String academics;
  final String experience;
  final List<String> traits;

  factory CompanyExpectations.fromJson(Map<String, dynamic> json) =>
      CompanyExpectations(
        skills: _stringList(json['skills']),
        academics: json['academics'] as String? ?? '',
        experience: json['experience'] as String? ?? '',
        traits: _stringList(json['traits']),
      );
}

/// The resume shape that suits a company.
class ResumePattern {
  const ResumePattern({
    required this.length,
    required this.sectionOrder,
    required this.emphasise,
    required this.avoid,
    required this.atsNotes,
  });

  final String length;
  final List<String> sectionOrder;
  final List<String> emphasise;
  final List<String> avoid;
  final String atsNotes;

  factory ResumePattern.fromJson(Map<String, dynamic> json) => ResumePattern(
    length: json['length'] as String? ?? '',
    sectionOrder: _stringList(json['sectionOrder']),
    emphasise: _stringList(json['emphasise']),
    avoid: _stringList(json['avoid']),
    atsNotes: json['atsNotes'] as String? ?? '',
  );
}

/// One company from `assets/data/companies.json`.
///
/// Content is general guidance from public hiring patterns, not an
/// official statement by the company (CLAUDE.md §4.1).
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.category,
    required this.sector,
    required this.summary,
    required this.expectations,
    required this.resumePattern,
    required this.sources,
    required this.lastReviewed,
  });

  final String id;
  final String name;
  final CompanyCategory category;
  final String sector;
  final String summary;
  final CompanyExpectations expectations;
  final ResumePattern resumePattern;

  /// Careers page URLs the guidance was checked against.
  final List<String> sources;
  final DateTime lastReviewed;

  /// Up to two initials for the logo placeholder ("Tata Consultancy
  /// Services" → "TC", "Infosys" → "IN", "IBM India" → "IB").
  String get initials {
    final words = name
        .split(RegExp(r'[\s\-]+'))
        .where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase())
        .where((w) => w != 'India') // "Deloitte India" → "DE", not "DI"
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Throws [FormatException] if a required field is missing or invalid,
  /// so a broken seed file fails loudly in tests instead of silently.
  factory Company.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final category = CompanyCategory.fromLabel(json['category'] as String?);
    final reviewed = DateTime.tryParse(json['lastReviewed'] as String? ?? '');
    if (id == null || name == null || category == null || reviewed == null) {
      throw FormatException('Invalid company entry: ${json['id'] ?? json}');
    }
    return Company(
      id: id,
      name: name,
      category: category,
      sector: json['sector'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      expectations: CompanyExpectations.fromJson(
        json['expectations'] as Map<String, dynamic>? ?? const {},
      ),
      resumePattern: ResumePattern.fromJson(
        json['resumePattern'] as Map<String, dynamic>? ?? const {},
      ),
      sources: _stringList(json['sources']),
      lastReviewed: reviewed,
    );
  }
}

List<String> _stringList(Object? value) =>
    (value as List<dynamic>? ?? const []).cast<String>();
