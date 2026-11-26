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
/// Android app: Truecaller verifies the number (one tap for Truecaller
/// users, a missed call for everyone else) and the backend turns that into
/// a Firebase custom token. Team test numbers and the web app use the
/// backend's code login. Every path signs in to the same Firebase account
/// for a number, so existing users keep their data.
class AuthService {
  AuthService(this._auth, this._otp);

  final FirebaseAuth _auth;
  final OtpApi _otp;

  /// Firebase Phone Auth needs the Blaze plan. Until then numbers are
  /// verified by Truecaller ([signInWithTruecaller]); team test numbers
  /// and the web app use the backend's code login.
  static const _firebaseSms = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sends an OTP to [phoneNumber] (E.164, e.g. +919876543210).
  Future<OtpRequestResult> sendOtp(
    String phoneNumber, {
    int? resendToken,
  }) async {
    if (!_firebaseSms) {
      final session = await _otp.start(phoneNumber);
      return OtpSent(verificationId: session);
    }
    final result = Completer<OtpRequestResult>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      // Android read the SMS (or verified instantly): sign in right away.
      verificationCompleted: (credential) async {
        try {
          final signedIn = await _auth.signInWithCredential(credential);
          if (!result.isCompleted) {
            result.complete(OtpAutoVerified(signedIn.user!));
          }
        } catch (e) {
          if (!result.isCompleted) result.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!result.isCompleted) result.completeError(e);
      },
      codeSent: (verificationId, token) {
        if (!result.isCompleted) {
          result.complete(
            OtpSent(verificationId: verificationId, resendToken: token),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return result.future;
  }

  /// "code" for team test numbers (fixed code), "truecaller" otherwise.
  /// The web app always uses codes (Truecaller's SDK is Android-only).
  Future<String> loginMethod(String phoneNumber) async =>
      kIsWeb ? 'code' : _otp.loginMethod(phoneNumber);

  /// Signs in with a Truecaller verification, checked by the backend.
  Future<User> signInWithTruecaller({
    String authorizationCode = '',
    String codeVerifier = '',
    String accessToken = '',
  }) async {
    final token = await _otp.truecaller(
      authorizationCode: authorizationCode,
      codeVerifier: codeVerifier,
      accessToken: accessToken,
    );
    final result = await _auth.signInWithCustomToken(token);
    return result.user!;
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
    if (_firebaseSms) {
      // Android may already have signed in by reading the SMS itself.
      final already = _auth.currentUser;
      if (already != null && already.phoneNumber != null) return already;
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user!;
    }
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
