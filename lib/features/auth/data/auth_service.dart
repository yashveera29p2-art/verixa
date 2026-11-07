import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Result of asking Firebase to send an OTP.
sealed class OtpRequestResult {
  const OtpRequestResult();
}

/// An SMS was sent; the user must type the code.
class OtpSent extends OtpRequestResult {
  const OtpSent({required this.verificationId, this.resendToken});
  final String verificationId;
  final int? resendToken;
}

/// Android verified the number automatically and the user is signed in.
class OtpAutoVerified extends OtpRequestResult {
  const OtpAutoVerified(this.user);
  final User user;
}

/// Thin wrapper around [FirebaseAuth]. Phone number is the account identity;
/// Google can be linked later but is never required.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sends an OTP to [phoneNumber] (E.164, e.g. +919999999999).
  /// Pass [resendToken] from a previous [OtpSent] to resend.
  Future<OtpRequestResult> sendOtp(String phoneNumber, {int? resendToken}) {
    final completer = Completer<OtpRequestResult>();

    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      codeSent: (verificationId, token) {
        if (!completer.isCompleted) {
          completer.complete(
            OtpSent(verificationId: verificationId, resendToken: token),
          );
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      verificationCompleted: (credential) async {
        // Android can read the SMS (or skip it) and verify on its own.
        try {
          final result = await _auth.signInWithCredential(credential);
          if (!completer.isCompleted && result.user != null) {
            completer.complete(OtpAutoVerified(result.user!));
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  /// Signs in with the 6-digit [code] the user typed.
  Future<User> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Links a Google account to the signed-in (phone) user.
  /// Used later from the Profile screen; requires the Google provider to be
  /// enabled in the Firebase console.
  Future<User> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in with your phone number first.',
      );
    }
    final result = await user.linkWithProvider(GoogleAuthProvider());
    return result.user!;
  }

  /// Whether a Google account is already linked.
  bool get hasGoogleLinked =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID) ??
      false;

  Future<void> signOut() => _auth.signOut();
}
