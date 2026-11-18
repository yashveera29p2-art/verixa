import '../../companies/domain/company.dart';
import '../../recruiter/domain/recruiter_models.dart';

/// One job in the student's Jobs tab: from Adzuna, a sample listing, or
/// posted by a recruiter on Verixa.
class JobListing {
  const JobListing({
    required this.id,
    required this.title,
    required this.company,
    this.location = '',
    this.description = '',
    this.url = '',
    this.salaryMin,
    this.salaryMax,
    this.contract = '',
    this.source = JobSource.adzuna,
    this.posted,
  });

  final String id;
  final String title;
  final String company;
  final String location;
  final String description;
  final String url;

  /// Yearly, in rupees. 0 = unpaid, null = not stated.
  final double? salaryMin;
  final double? salaryMax;

  /// "full_time" | "part_time" | "internship" | "".
  final String contract;
  final JobSource source;

  /// Set for jobs recruiters posted on Verixa.
  final PostedJob? posted;

  bool get isInternship => contract == 'internship';

  PayLevel get payLevel => PayLevel.fromYearly(salaryMax);

  String get payText {
    final max = salaryMax;
    if (max == null) return 'Pay not stated';
    if (max <= 0) return 'Unpaid';
    String lpa(double v) {
      final l = v / 100000;
      return l >= 10 || l == l.roundToDouble() ? l.toStringAsFixed(0) : l.toStringAsFixed(1);
    }
    final min = salaryMin;
    return min != null && min > 0 && (max - min).abs() > 1000
        ? '₹${lpa(min)}–${lpa(max)} LPA'
        : '₹${lpa(max)} LPA';
  }

  factory JobListing.fromJson(Map<String, dynamic> j) => JobListing(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        company: j['company'] as String? ?? '',
        location: j['location'] as String? ?? '',
        description: j['description'] as String? ?? '',
        url: j['url'] as String? ?? '',
        salaryMin: (j['salaryMin'] as num?)?.toDouble(),
        salaryMax: (j['salaryMax'] as num?)?.toDouble(),
        contract: j['contract'] as String? ?? '',
        source: j['source'] == 'sample' ? JobSource.sample : JobSource.adzuna,
      );

  factory JobListing.fromPosted(PostedJob p) => JobListing(
        id: 'vx-${p.id}',
        title: p.title,
        company: p.company,
        location: p.location,
        description: [p.description, if (p.skills.isNotEmpty) 'Skills: ${p.skills.join(', ')}.']
            .join('\n'),
        salaryMin: p.payMinLpa * 100000,
        salaryMax: p.payMaxLpa * 100000,
        contract: p.type.id,
        source: JobSource.verixa,
        posted: p,
      );
}

enum JobSource {
  adzuna('Jobs by Adzuna'),
  sample('Sample listing'),
  verixa('Posted on Verixa');

  const JobSource(this.label);
  final String label;
}

/// How well a job fits the student (from the backend's matching v2).
class JobFit {
  const JobFit({
    required this.score,
    required this.verdict,
    this.reasons = const [],
    this.gaps = const [],
    this.traitFit,
  });

  final int score;
  final String verdict;
  final List<String> reasons;
  final List<String> gaps;
  final int? traitFit;

  factory JobFit.fromJson(Map<String, dynamic> j) => JobFit(
        score: (j['score'] as num?)?.toInt() ?? 0,
        verdict: j['verdict'] as String? ?? 'low',
        reasons: (j['reasons'] as List?)?.cast<String>() ?? const [],
        gaps: (j['gaps'] as List?)?.cast<String>() ?? const [],
        traitFit: (j['traitFit'] as num?)?.toInt(),
      );
}

/// A listing with its fit and the matching company's insights (if the
/// company is one of Verixa's 30 researched companies).
class RankedJob {
  const RankedJob({required this.job, this.fit, this.company});

  final JobListing job;
  final JobFit? fit;
  final Company? company;
}

/// Filter chips on the Jobs tab.
enum JobFilter {
  highPackage('High package'),
  lowLayoffs('Low layoffs'),
  workLife('Work-life balance'),
  goodPay('Good pay'),
  lowerPay('Lower pay'),
  unpaid('No pay'),
  internship('Internships'),
  fullTime('Full-time');

  const JobFilter(this.label);
  final String label;

  bool test(RankedJob r) {
    final j = r.job;
    final pay = j.payLevel == PayLevel.unknown
        ? (r.company?.insights.payLevel ?? PayLevel.unknown)
        : j.payLevel;
    return switch (this) {
      highPackage => pay == PayLevel.high,
      goodPay => pay == PayLevel.good || pay == PayLevel.high,
      lowerPay => pay == PayLevel.lower,
      unpaid => pay == PayLevel.unpaid,
      lowLayoffs => r.company?.insights.layoffRisk == Level3.low,
      workLife => r.company?.insights.workLife == WorkLife.good,
      internship => j.isInternship,
      fullTime => !j.isInternship,
    };
  }
}
