import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_errors.dart';
import '../data/auth_service.dart';
import 'auth_providers.dart';
import 'session.dart';

/// State of the phone → OTP flow.
class PhoneAuthState {
  const PhoneAuthState({
    this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.isBusy = false,
    this.error,
    this.resendSecondsLeft = 0,
  });

  /// E.164 number the code was sent to, e.g. +919999999999.
  final String? phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final bool isBusy;
  final String? error;
  final int resendSecondsLeft;

  bool get canResend => resendSecondsLeft == 0 && !isBusy;

  PhoneAuthState copyWith({
    String? phoneNumber,
    String? verificationId,
    int? resendToken,
    bool? isBusy,
    String? error,
    bool clearError = false,
    int? resendSecondsLeft,
  }) =>
      PhoneAuthState(
        phoneNumber: phoneNumber ?? this.phoneNumber,
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
        resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
      );
}

/// What the UI should do after sending a code.
sealed class SendCodeOutcome {
  const SendCodeOutcome();
}

class CodeSent extends SendCodeOutcome {
  const CodeSent();
}

/// Android verified the number by itself — go straight to [route].
class SignedIn extends SendCodeOutcome {
  const SignedIn(this.route);
  final String route;
}

class SendFailed extends SendCodeOutcome {
  const SendFailed();
}

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(PhoneAuthController.new);

class PhoneAuthController extends Notifier<PhoneAuthState> {
  static const resendCooldownSeconds = 30;

  Timer? _timer;

  @override
  PhoneAuthState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PhoneAuthState();
  }

  AuthService get _auth => ref.read(authServiceProvider);

  /// Starts a fresh flow for [phoneNumber] (E.164).
  Future<SendCodeOutcome> sendCode(String phoneNumber) async {
    _timer?.cancel();
    state = PhoneAuthState(phoneNumber: phoneNumber, isBusy: true);
    return _request(phoneNumber);
  }

  /// Sends the code again to the same number.
  Future<SendCodeOutcome> resendCode() async {
    final phone = state.phoneNumber;
    if (phone == null || !state.canResend) return const SendFailed();
    state = state.copyWith(isBusy: true, clearError: true);
    return _request(phone, resendToken: state.resendToken);
  }

  Future<SendCodeOutcome> _request(String phone, {int? resendToken}) async {
    try {
      final result = await _auth.sendOtp(phone, resendToken: resendToken);
      switch (result) {
        case OtpSent(:final verificationId, resendToken: final token):
          state = state.copyWith(
            verificationId: verificationId,
            resendToken: token,
            isBusy: false,
          );
          _startCooldown();
          return const CodeSent();
        case OtpAutoVerified(:final user):
          final route =
              await routeForUser(user, ref.read(userRepositoryProvider));
          state = state.copyWith(isBusy: false);
          return SignedIn(route);
      }
    } catch (e) {
      state = state.copyWith(isBusy: false, error: friendlyAuthError(e));
      return const SendFailed();
    }
  }

  /// Checks the 6-digit [code]. Returns the route to open, or null on error
  /// (the message is in [PhoneAuthState.error]).
  Future<String?> verifyCode(String code) async {
    final verificationId = state.verificationId;
    if (verificationId == null || state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user =
          await _auth.verifyOtp(verificationId: verificationId, code: code);
      final route = await routeForUser(user, ref.read(userRepositoryProvider));
      state = state.copyWith(isBusy: false);
      return route;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: friendlyAuthError(e));
      return null;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  void _startCooldown() {
    _timer?.cancel();
    state = state.copyWith(resendSecondsLeft: resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.resendSecondsLeft - 1;
      state = state.copyWith(resendSecondsLeft: left < 0 ? 0 : left);
      if (left <= 0) timer.cancel();
    });
  }
}
