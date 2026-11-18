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

/// Pay, job security and work-life summary plus placement prep.
/// The team's indicative summary of public information (campus offer
/// announcements, layoff news, public review trends): approximate.
class CompanyInsights {
  const CompanyInsights({
    this.payBand = '',
    this.payMaxLpa = 0,
    this.payLevel = PayLevel.unknown,
    this.layoffRisk = Level3.unknown,
    this.workLife = WorkLife.unknown,
    this.prep = const CompanyPrep(),
  });

  final String payBand;
  final double payMaxLpa;
  final PayLevel payLevel;
  final Level3 layoffRisk;
  final WorkLife workLife;
  final CompanyPrep prep;

  factory CompanyInsights.fromJson(Map<String, dynamic> json) => CompanyInsights(
    payBand: json['payBand'] as String? ?? '',
    payMaxLpa: (json['payMaxLpa'] as num?)?.toDouble() ?? 0,
    payLevel: PayLevel.fromId(json['payLevel'] as String?),
    layoffRisk: Level3.fromId(json['layoffRisk'] as String?),
    workLife: WorkLife.fromId(json['workLife'] as String?),
    prep: CompanyPrep.fromJson(json['prep'] as Map<String, dynamic>? ?? const {}),
  );
}

/// Interview rounds, topics to study and commonly asked questions.
class CompanyPrep {
  const CompanyPrep({
    this.rounds = const [],
    this.topics = const [],
    this.questions = const [],
  });

  final List<String> rounds;
  final List<String> topics;
  final List<String> questions;

  bool get isEmpty => rounds.isEmpty && topics.isEmpty && questions.isEmpty;

  factory CompanyPrep.fromJson(Map<String, dynamic> json) => CompanyPrep(
    rounds: _stringList(json['rounds']),
    topics: _stringList(json['topics']),
    questions: _stringList(json['questions']),
  );
}

enum PayLevel {
  high('High package'),
  good('Good pay'),
  lower('Lower pay'),
  unpaid('No pay'),
  unknown('Pay not known');

  const PayLevel(this.label);
  final String label;

  static PayLevel fromId(String? id) =>
      values.firstWhere((v) => v.name == id, orElse: () => PayLevel.unknown);

  /// From a yearly salary in rupees (0 = unpaid).
  static PayLevel fromYearly(double? max) {
    if (max == null) return PayLevel.unknown;
    if (max <= 0) return PayLevel.unpaid;
    final lpa = max / 100000;
    return lpa >= 10 ? high : lpa >= 6 ? good : lower;
  }
}

/// Low / medium / high (used for layoff risk).
enum Level3 {
  low('Low'),
  medium('Medium'),
  high('High'),
  unknown('Not known');

  const Level3(this.label);
  final String label;

  static Level3 fromId(String? id) =>
      values.firstWhere((v) => v.name == id, orElse: () => Level3.unknown);
}

enum WorkLife {
  good('Good work-life balance'),
  average('Average work-life balance'),
  demanding('Demanding hours'),
  unknown('Work-life not known');

  const WorkLife(this.label);
  final String label;

  static WorkLife fromId(String? id) =>
      values.firstWhere((v) => v.name == id, orElse: () => WorkLife.unknown);
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
    this.insights = const CompanyInsights(),
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
  final CompanyInsights insights;

  /// The website to load the company's logo from, from its careers page
  /// URL: "www." hosts are kept as they are ("www.tcs.com" has an icon
  /// where "tcs.com" doesn't); other subdomains are trimmed to the main
  /// domain ("careers.wipro.com" → "wipro.com").
  String? get logoDomain {
    if (sources.isEmpty) return null;
    final host = Uri.tryParse(sources.first)?.host ?? '';
    if (host.startsWith('www.')) return host;
    final labels = host.split('.').where((l) => l.isNotEmpty).toList();
    if (labels.length < 2) return null;
    return labels.sublist(labels.length - 2).join('.');
  }

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
      insights: CompanyInsights.fromJson(
        json['insights'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

List<String> _stringList(Object? value) =>
    (value as List<dynamic>? ?? const []).cast<String>();
