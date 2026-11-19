import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../resume/data/resume_api.dart' show ResumeApiException;
import '../../resume/domain/writing_report.dart';
import '../domain/job_models.dart';

/// Backend calls for job search and matching v2 ranking.
class JobsApi {
  JobsApi({required this.baseUrl, required this.idToken, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() idToken;
  final http.Client _client;

  /// Returns (source, listings): source is "adzuna" or "sample".
  Future<(String, List<JobListing>)> search({
    String query = '',
    String location = '',
    bool internship = false,
  }) async {
    final body = await _post('/v1/jobs/search', {
      'query': query,
      'location': location,
      'internship': internship,
    });
    final jobs = [
      for (final j in body['jobs'] as List) JobListing.fromJson(j as Map<String, dynamic>),
    ];
    return (body['source'] as String? ?? 'sample', jobs);
  }

  /// Ranks [jobs] for [profile]; returns fit by job id.
  Future<Map<String, JobFit>> rankJobs({
    required Map<String, dynamic> profile,
    required List<JobListing> jobs,
  }) async {
    final body = await _post('/v1/jobs/rank', {
      'profile': profile,
      'jobs': [
        for (final j in jobs.take(25))
          {
            'id': j.id,
            'title': j.title,
            'description': j.description.length > 7900
                ? j.description.substring(0, 7900)
                : j.description,
          },
      ],
    });
    return _fits(body);
  }

  /// Ranks opted-in candidates for a recruiter's job.
  Future<Map<String, JobFit>> rankCandidates({
    required String title,
    required String description,
    required Map<String, double> wantedTraits,
    required List<(String id, Map<String, dynamic> profile, Map<String, double> traits)> candidates,
  }) async {
    final body = await _post('/v1/candidates/rank', {
      'job': {'id': 'job', 'title': title, 'description': description},
      'wantedTraits': wantedTraits,
      'candidates': [
        for (final c in candidates.take(60))
          {'id': c.$1, 'profile': c.$2, 'traits': c.$3},
      ],
    });
    return _fits(body);
  }

  /// Checks typed text: kind is "job", "requirements" or "review".
  /// Returns null if it's fine, otherwise the message to show.
  Future<String?> checkText(String kind, String text) async {
    final body = await _post('/v1/text/check', {'kind': kind, 'text': text});
    return body['ok'] == true ? null : body['message'] as String?;
  }

  /// NLP writing review of a resume's text.
  Future<WritingReport> checkWriting(String text) async =>
      WritingReport.fromJson(await _post('/v1/writing/check', {'text': text}));

  /// Sentiment and aspects of a company's reviews.
  Future<ReviewAnalysis> analyzeReviews(List<String> texts, List<int> ratings) async =>
      ReviewAnalysis.fromJson(
          await _post('/v1/reviews/analyze', {'texts': texts, 'ratings': ratings}));

  Map<String, JobFit> _fits(Map<String, dynamic> body) => {
        for (final r in body['results'] as List)
          (r as Map<String, dynamic>)['id'] as String: JobFit.fromJson(r),
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> json) async {
    final token = await idToken();
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(json),
          )
          .timeout(const Duration(seconds: 75));
    } on TimeoutException {
      throw const ResumeApiException(
          'The server is taking too long (it may be waking up). Please try again.');
    } on Exception {
      throw const ResumeApiException(
          'Can’t reach the Verixa server. Check your connection and try again.');
    }
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    }
    if (r.statusCode == 401) {
      throw const ResumeApiException('Your session has expired. Please sign in again.');
    }
    // 400: the server explains what's wrong (e.g. "This doesn't look like a
    // job description…").
    if (r.statusCode == 400) {
      try {
        final detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail'];
        if (detail is String) throw ResumeApiException(detail);
      } on FormatException {
        // fall through
      }
    }
    throw ResumeApiException('Something went wrong (${r.statusCode}). Please try again.');
  }
}
