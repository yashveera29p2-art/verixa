import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/parsed_resume.dart';

/// A failure the user can understand (shown as-is in the UI).
class ResumeApiException implements Exception {
  const ResumeApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the Verixa backend's resume endpoints.
class ResumeApi {
  ResumeApi({
    required this.baseUrl,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

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
  }) async {
    final String? token;
    try {
      token = await idToken().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ResumeApiException(
          'Couldn’t confirm your sign-in. Check your internet connection.');
    }
    if (token == null) {
      throw const ResumeApiException('Please sign in again.');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/resumes/parse'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const ResumeApiException(
          'The server took too long to respond. Please try again.');
    } on Exception {
      // http.ClientException, SocketException, HandshakeException, …
      throw const ResumeApiException(
          'Can’t reach the Verixa server. Check your connection — or, '
          'during development, that the backend is running.');
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return ParsedResume.fromJson(json as Map<String, dynamic>);
    }
    throw ResumeApiException(_messageFor(response));
  }

  String _messageFor(http.Response r) {
    String? detail;
    try {
      detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail'] as String?;
    } catch (_) {}
    return switch (r.statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      400 || 413 || 415 => detail ?? 'This file can’t be read.',
      _ => 'Something went wrong on our side (${r.statusCode}). Please try again.',
    };
  }
}
