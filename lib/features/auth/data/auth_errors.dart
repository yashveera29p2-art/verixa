import 'package:firebase_auth/firebase_auth.dart';

import 'otp_api.dart';

/// Turns login errors (backend OTP or Firebase) into short messages a user
/// can act on.
String friendlyAuthError(Object error) {
  if (error is OtpApiException) return error.message;
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  return switch (error.code) {
    'invalid-phone-number' => 'That phone number doesn’t look right.',
    'invalid-verification-code' => 'That code is incorrect. Check and try again.',
    'session-expired' || 'code-expired' =>
      'This code has expired. Tap “Resend code” to get a new one.',
    'too-many-requests' =>
      'Too many attempts. Please wait a while and try again.',
    'quota-exceeded' =>
      'We can’t send more codes right now. Please try again later.',
    'operation-not-allowed' =>
      'Phone sign-in isn’t available for this number’s country yet.',
    'network-request-failed' =>
      'No internet connection. Check your network and try again.',
    'credential-already-in-use' || 'account-exists-with-different-credential' =>
      'That Google account is already linked to another Verixa account.',
    'provider-already-linked' => 'A Google account is already linked.',
    'web-context-canceled' || 'canceled' => 'Sign-in was cancelled.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}
