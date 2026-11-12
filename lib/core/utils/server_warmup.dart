import 'dart:async';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Wakes the backend in the background as soon as the app opens.
///
/// The free server sleeps when idle and takes ~50 s to wake up; pinging it
/// during the splash means it's usually awake by the time someone asks for
/// an OTP or scans a resume. Errors are ignored: this is only a head start.
void warmUpServer() {
  unawaited(http
      .get(Uri.parse('${ApiConfig.baseUrl}/health'))
      .timeout(const Duration(seconds: 90))
      .then((_) {}, onError: (_) {}));
}
