import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A login problem the user can act on (message shown as-is).
class OtpApiException implements Exception {
  const OtpApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Verixa's own phone OTP login (backend `/v1/auth/otp/*`).
///
/// The backend sends the SMS, checks the code and returns a Firebase custom
/// token for the one account that belongs to the number.
class OtpApi {
  OtpApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  // The free server may need ~1 minute to wake up.
  static const _timeout = Duration(seconds: 75);

  /// Sends a code to [phone]. Returns the session to pass to [verify].
  Future<String> start(String phone) async {
    final body = await _post('/v1/auth/otp/start', {'phone': phone});
    return body['session'] as String;
  }

  /// Whether [phone] already has a Verixa account (no SMS is sent).
  Future<bool> accountExists(String phone) async {
    final body = await _post('/v1/auth/account/exists', {'phone': phone});
    return body['exists'] == true;
  }

  /// Checks [code]. Returns a Firebase custom token.
  Future<String> verify({required String session, required String code}) async {
    final body = await _post('/v1/auth/otp/verify', {
      'session': session,
      'code': code,
    });
    return body['firebaseToken'] as String;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> body,
  ) async {
    final http.Response r;
    try {
      r = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const OtpApiException(
        'The server is taking too long. Please try again.',
      );
    } on Exception {
      throw const OtpApiException(
        'No internet connection. Check your network and try again.',
      );
    }
    Map<String, dynamic> json = const {};
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode == 200) return json;
    final detail = json['detail'];
    throw OtpApiException(
      detail is String
          ? detail
          : 'Something went wrong (${r.statusCode}). Please try again.',
    );
  }
}
