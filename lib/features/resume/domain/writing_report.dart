/// NLP writing review of a resume (backend `WritingReport`).
class WritingReport {
  const WritingReport({
    required this.score,
    required this.readability,
    required this.readabilityLabel,
    required this.bullets,
    required this.quantifiedPercent,
    required this.passiveCount,
    required this.weakCount,
    required this.buzzwordCount,
    required this.issues,
    required this.summary,
  });

  final int score;
  final int readability;
  final String readabilityLabel;
  final int bullets;
  final int quantifiedPercent;
  final int passiveCount;
  final int weakCount;
  final int buzzwordCount;
  final List<WritingIssue> issues;
  final String summary;

  factory WritingReport.fromJson(Map<String, dynamic> j) => WritingReport(
        score: (j['score'] as num?)?.toInt() ?? 0,
        readability: (j['readability'] as num?)?.toInt() ?? 0,
        readabilityLabel: j['readabilityLabel'] as String? ?? '',
        bullets: (j['bullets'] as num?)?.toInt() ?? 0,
        quantifiedPercent: (j['quantifiedPercent'] as num?)?.toInt() ?? 0,
        passiveCount: (j['passiveCount'] as num?)?.toInt() ?? 0,
        weakCount: (j['weakCount'] as num?)?.toInt() ?? 0,
        buzzwordCount: (j['buzzwordCount'] as num?)?.toInt() ?? 0,
        issues: [
          for (final i in (j['issues'] as List? ?? const []))
            WritingIssue.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        summary: j['summary'] as String? ?? '',
      );
}

class WritingIssue {
  const WritingIssue({
    required this.kind,
    required this.excerpt,
    required this.message,
    required this.suggestion,
  });

  final String kind;
  final String excerpt;
  final String message;
  final String suggestion;

  String get title => switch (kind) {
        'weak_phrase' => 'Weak phrase',
        'passive' => 'Passive voice',
        'no_impact' => 'No result or number',
        'buzzword' => 'Cliché',
        'first_person' => 'First person',
        'long' => 'Long sentence',
        'repeated_start' => 'Repeated opening',
        _ => 'Writing',
      };

  factory WritingIssue.fromJson(Map<String, dynamic> j) => WritingIssue(
        kind: j['kind'] as String? ?? '',
        excerpt: j['excerpt'] as String? ?? '',
        message: j['message'] as String? ?? '',
        suggestion: j['suggestion'] as String? ?? '',
      );
}

/// Sentiment of a company's reviews (backend `ReviewAnalysis`).
class ReviewAnalysis {
  const ReviewAnalysis({
    required this.reviews,
    required this.positivePercent,
    required this.neutralPercent,
    required this.negativePercent,
    required this.overall,
    required this.aspects,
    required this.summary,
  });

  final int reviews;
  final int positivePercent;
  final int neutralPercent;
  final int negativePercent;
  final String overall;
  final List<AspectSentiment> aspects;
  final String summary;

  factory ReviewAnalysis.fromJson(Map<String, dynamic> j) => ReviewAnalysis(
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        positivePercent: (j['positivePercent'] as num?)?.toInt() ?? 0,
        neutralPercent: (j['neutralPercent'] as num?)?.toInt() ?? 0,
        negativePercent: (j['negativePercent'] as num?)?.toInt() ?? 0,
        overall: j['overall'] as String? ?? '',
        aspects: [
          for (final a in (j['aspects'] as List? ?? const []))
            AspectSentiment.fromJson(Map<String, dynamic>.from(a as Map)),
        ],
        summary: j['summary'] as String? ?? '',
      );
}

class AspectSentiment {
  const AspectSentiment({
    required this.aspect,
    required this.mentions,
    required this.label,
    required this.example,
  });

  final String aspect;
  final int mentions;
  final String label; // positive | mixed | negative
  final String example;

  factory AspectSentiment.fromJson(Map<String, dynamic> j) => AspectSentiment(
        aspect: j['aspect'] as String? ?? '',
        mentions: (j['mentions'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? 'mixed',
        example: j['example'] as String? ?? '',
      );
}
