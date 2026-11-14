import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'otp_api.dart';

/// Result of asking for an OTP.
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

/// Sign-in service. Phone number is the account identity.
///
/// Codes are sent and checked by Verixa's own backend ([OtpApi]), which
/// then hands back a Firebase custom token for the one account that owns
/// the number. Firebase still stores the account and session.
class AuthService {
  AuthService(this._auth, this._otp);

  final FirebaseAuth _auth;
  final OtpApi _otp;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sends an OTP to [phoneNumber] (E.164, e.g. +919876543210).
  /// [resendToken] is unused (kept so callers don't change).
  Future<OtpRequestResult> sendOtp(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final session = await _otp.start(phoneNumber);
    return OtpSent(verificationId: session);
  }

  /// Whether [phoneNumber] already has an account; null if the server
  /// couldn't be asked (callers then just carry on with the OTP).
  Future<bool?> accountExists(String phoneNumber) async {
    try {
      return await _otp.accountExists(phoneNumber);
    } catch (_) {
      return null;
    }
  }

  /// Signs in with the 6-digit [code] the user typed.
  Future<User> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    final token = await _otp.verify(session: verificationId, code: code);
    final result = await _auth.signInWithCustomToken(token);
    return result.user!;
  }

  /// Links a Google account to the signed-in (phone) user, using the
  /// phone's own Google account picker (no browser).
  Future<User> linkGoogleAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sign in with your phone number first.',
      );
    }
    if (kIsWeb) {
      // Web app: Google's own sign-in window.
      final result = await user.linkWithPopup(GoogleAuthProvider());
      return result.user ?? user;
    }
    final google = GoogleSignIn.instance;
    await (_googleReady ??= google.initialize());
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      throw FirebaseAuthException(
        code: e.code == GoogleSignInExceptionCode.canceled
            ? 'canceled'
            : 'google-sign-in-failed',
        message: 'Couldn’t open Google sign-in. Please try again.',
      );
    }
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    try {
      final result = await user.linkWithCredential(credential);
      await result.user?.reload();
      return _auth.currentUser ?? result.user!;
    } finally {
      // Forget the picker choice so another account can be picked next time.
      await google.signOut();
    }
  }

  Future<void>? _googleReady;

  /// Whether a Google account is already linked.
  bool get hasGoogleLinked =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
      ) ??
      false;

  Future<void> signOut() => _auth.signOut();
}
