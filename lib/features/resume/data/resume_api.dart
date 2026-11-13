import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/match_report.dart';
import '../domain/parsed_resume.dart';
import '../domain/scan_report.dart';

/// A failure the user can understand (shown as-is in the UI).
class ResumeApiException implements Exception {
  const ResumeApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the Verixa backend's resume endpoints.
class ResumeApi {
  ResumeApi({required this.baseUrl, required this.idToken, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;

  /// Returns the signed-in user's Firebase ID token.
  final Future<String?> Function() idToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 60);

  /// Uploads a PDF/DOCX and returns the extracted profile data.
  /// The backend processes the file in memory and doesn't store it.
  Future<ParsedResume> parse({
    required Uint8List bytes,
    required String fileName,
  }) async => ParsedResume.fromJson(await _upload('parse', bytes, fileName));

  /// Uploads a PDF/DOCX for a security scan and ATS report.
  Future<ScanReport> scan({
    required Uint8List bytes,
    required String fileName,
  }) async => ScanReport.fromJson(await _upload('scan', bytes, fileName));

  /// Matches the profile against a job description (feature 8).
  Future<MatchReport> matchJob({
    required String jobDescription,
    required Map<String, dynamic> profile,
  }) async {
    final token = await _token();
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/v1/jobs/match'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'jobDescription': jobDescription,
              'profile': profile,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ResumeApiException(
        'The server took too long to respond. Please try again.',
      );
    } on Exception {
      throw const ResumeApiException(
        'Can’t reach the Verixa server. Check your connection — or, '
        'during development, that the backend is running.',
      );
    }
    if (response.statusCode == 200) {
      return MatchReport.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    if (response.statusCode == 422) {
      throw const ResumeApiException(
        'Please paste the full job description (at least a few lines).',
      );
    }
    throw ResumeApiException(_messageFor(response));
  }

  /// Lays out a generated resume as DOCX on the backend (feature 10).
  Future<Uint8List> resumeDocx(Map<String, dynamic> resume) =>
      _postForBytes('/v1/export/resume.docx', resume);

  Future<Uint8List> coverLetterDocx({
    required String name,
    required List<String> contact,
    required String text,
  }) => _postForBytes('/v1/export/cover-letter.docx', {
    'name': name,
    'contact': contact,
    'text': text,
  });

  Future<Uint8List> _postForBytes(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _token();
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ResumeApiException(
        'The server took too long to respond. Please try again.',
      );
    } on Exception {
      throw const ResumeApiException(
        'Can’t reach the Verixa server. Check your connection — or, '
        'during development, that the backend is running.',
      );
    }
    if (response.statusCode == 200) return response.bodyBytes;
    throw ResumeApiException(_messageFor(response));
  }

  Future<String> _token() async {
    final String? token;
    try {
      token = await idToken().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ResumeApiException(
        'Couldn’t confirm your sign-in. Check your internet connection.',
      );
    }
    if (token == null) throw const ResumeApiException('Please sign in again.');
    return token;
  }

  /// POSTs the file to /v1/resumes/[endpoint] and returns the JSON body.
  Future<Map<String, dynamic>> _upload(
    String endpoint,
    Uint8List bytes,
    String fileName,
  ) async {
    final token = await _token();
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/v1/resumes/$endpoint'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName),
          );

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ResumeApiException(
        'The server took too long to respond. Please try again.',
      );
    } on Exception {
      // http.ClientException, SocketException, HandshakeException, …
      throw const ResumeApiException(
        'Can’t reach the Verixa server. Check your connection — or, '
        'during development, that the backend is running.',
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw ResumeApiException(_messageFor(response));
  }

  String _messageFor(http.Response r) {
    String? detail;
    try {
      detail =
          (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail'] as String?;
    } catch (_) {}
    return switch (r.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      400 || 413 || 415 => detail ?? 'This file can’t be read.',
      422 =>
        'Some text is too short or too long. Check the fields and try again.',
      _ =>
        'Something went wrong on our side (${r.statusCode}). Please try again.',
    };
  }
}
