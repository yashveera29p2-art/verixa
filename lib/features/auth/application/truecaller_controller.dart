import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truecaller_sdk/truecaller_sdk.dart';

import '../data/auth_errors.dart';
import 'auth_providers.dart';
import 'session.dart';

/// Where the Truecaller check is.
enum TcStep {
  starting,

  /// Truecaller's consent sheet is open (Truecaller app users).
  consent,

  /// Call-log permission is off: the user is shown how to allow it.
  needsPermission,

  /// Waiting for Truecaller's missed call on this phone.
  waitingCall,

  /// Truecaller sent a code by SMS; the user types it.
  enterOtp,

  /// Confirming with the Verixa server.
  checking,
  done,
  failed,
}

class TcState {
  const TcState({
    this.step = TcStep.starting,
    this.phone,
    this.error,
    this.secondsLeft = 0,
    this.route,
  });

  final TcStep step;

  /// E.164 number being verified, e.g. +919876543210.
  final String? phone;
  final String? error;

  /// Time left for the missed call / code (from Truecaller's TTL).
  final int secondsLeft;

  /// Where to go once signed in.
  final String? route;

  TcState copyWith({
    TcStep? step,
    String? error,
    int? secondsLeft,
    String? route,
  }) => TcState(
    step: step ?? this.step,
    phone: phone,
    error: error,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    route: route ?? this.route,
  );
}

final truecallerControllerProvider =
    NotifierProvider.autoDispose<TruecallerController, TcState>(
      TruecallerController.new,
    );

/// Verifies a phone number with Truecaller's SDK (free, Indian numbers):
/// one tap for Truecaller users, a missed call (or Truecaller's own SMS
/// code) for everyone else. The proof is checked by the Verixa server,
/// which signs the user in to that number's account.
class TruecallerController extends Notifier<TcState> {
  static const _device = MethodChannel('verixa/device');

  StreamSubscription<TcSdkCallback>? _events;
  Timer? _timer;
  String? _oauthState;
  String? _codeVerifier;

  @override
  TcState build() {
    ref.onDispose(() {
      _events?.cancel();
      _timer?.cancel();
    });
    return const TcState();
  }

  /// Starts verifying [phone] (E.164).
  Future<void> start(String phone) async {
    _timer?.cancel();
    state = TcState(phone: phone);
    _watch(TcStep.starting);
    try {
      await _send(
        TcSdk.initializeSDK(sdkOption: TcSdkOptions.OPTION_VERIFY_ALL_USERS),
      );
      _events ??= TcSdk.streamCallbackData.listen(_onEvent);
      final usable = await TcSdk.isOAuthFlowUsable.timeout(_sdkTimeout) == true;
      debugPrint('truecaller: initialised, oauth usable=$usable');
      if (usable && await _openConsent()) return;
      await _verifyByCall();
    } catch (e) {
      debugPrint('truecaller: start failed: $e');
      _fail(e);
    }
  }

  static const _sdkTimeout = Duration(seconds: 15);

  /// Most of the plugin's calls never report back (only errors do, and
  /// those come at once), so wait briefly for an error instead of a result.
  static Future<void> _send(Future<dynamic> call) =>
      call.timeout(const Duration(milliseconds: 700), onTimeout: () => null);

  /// Fails with a clear message if Truecaller stays silent in [step].
  void _watch(TcStep step) {
    Future.delayed(const Duration(seconds: 45), () {
      if (ref.mounted && state.step == step) {
        _fail('Truecaller didn’t respond. Check your internet connection '
            'and try again.');
      }
    });
  }

  /// Truecaller app on this phone: show its one-tap consent sheet.
  Future<bool> _openConsent() async {
    final verifier = await TcSdk.generateRandomCodeVerifier as String?;
    if (verifier == null) return false;
    final challenge = await TcSdk.generateCodeChallenge(verifier) as String?;
    if (challenge == null) return false;
    _codeVerifier = verifier;
    _oauthState = _randomState();
    await _send(TcSdk.setOAuthState(_oauthState!));
    await _send(TcSdk.setOAuthScopes(['openid', 'phone']));
    await _send(TcSdk.setCodeChallenge(challenge));
    state = state.copyWith(step: TcStep.consent);
    await _send(TcSdk.getAuthorizationCode);
    return true;
  }

  /// No Truecaller app (or the user picked another number): Truecaller
  /// gives this phone a missed call, which needs call-log permission so the
  /// app can spot it. Without the permission the user is shown how to allow
  /// it (or can choose an SMS code instead).
  Future<void> _verifyByCall() async {
    state = state.copyWith(step: TcStep.starting);
    var granted = false;
    try {
      granted = await _device.invokeMethod<bool>('phonePermissions') ?? false;
    } catch (_) {}
    if (!granted) {
      state = state.copyWith(step: TcStep.needsPermission);
      return;
    }
    await _requestVerification();
  }

  /// Opens Verixa's App info page so the user can allow call logs.
  Future<void> openSettings() async {
    try {
      await _device.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }

  /// Back from Settings: carry on if the permission is now on.
  Future<void> recheckPermission() async {
    if (state.step != TcStep.needsPermission) return;
    var granted = false;
    try {
      granted = await _device.invokeMethod<bool>('hasPhonePermissions') ?? false;
    } catch (_) {}
    if (granted) {
      state = state.copyWith(step: TcStep.starting);
      try {
        await _requestVerification();
      } catch (e) {
        _fail(e);
      }
    }
  }

  /// Skip the missed call: Truecaller sends a code by SMS instead.
  Future<void> useSmsCode() async {
    if (state.step != TcStep.needsPermission) return;
    state = state.copyWith(step: TcStep.starting);
    try {
      await _requestVerification();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _requestVerification() async {
    final digits = (state.phone ?? '').replaceAll(RegExp(r'\D'), '');
    _watch(TcStep.starting);
    await _send(
      TcSdk.requestVerification(
        phoneNumber: digits.substring(digits.length - 10),
      ),
    );
    debugPrint('truecaller: verification requested');
  }

  /// The code Truecaller texted (when it verifies by SMS instead of a call).
  Future<void> submitOtp(String code) async {
    if (state.step != TcStep.enterOtp) return;
    state = state.copyWith(step: TcStep.checking);
    try {
      await _send(
        TcSdk.verifyOtp(firstName: 'Verixa', lastName: 'User', otp: code),
      );
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _onEvent(TcSdkCallback event) async {
    debugPrint('truecaller: event ${event.result}');
    switch (event.result) {
      case TcSdkCallbackResult.success:
        final data = event.tcOAuthData;
        if (data == null || data.state != _oauthState) {
          return _fail('Truecaller sign-in didn’t match. Please try again.');
        }
        await _signIn(
          authorizationCode: data.authorizationCode,
          codeVerifier: _codeVerifier ?? '',
        );
      case TcSdkCallbackResult.verification:
        // "Use another number" on the consent sheet, or not possible there.
        try {
          await _verifyByCall();
        } catch (e) {
          _fail(e);
        }
      case TcSdkCallbackResult.failure:
        _fail(
          event.error?.message?.isNotEmpty == true
              ? event.error!.message!
              : 'Truecaller sign-in was cancelled.',
        );
      case TcSdkCallbackResult.missedCallInitiated:
        _countdown(TcStep.waitingCall, event.ttl);
      case TcSdkCallbackResult.missedCallReceived:
        _timer?.cancel();
        state = state.copyWith(step: TcStep.checking);
        await _send(
          TcSdk.verifyMissedCall(firstName: 'Verixa', lastName: 'User'),
        );
      case TcSdkCallbackResult.otpInitiated ||
          TcSdkCallbackResult.imOtpInitiated:
        _countdown(TcStep.enterOtp, event.ttl);
      case TcSdkCallbackResult.otpReceived || TcSdkCallbackResult.imOtpReceived:
        final otp = event.otp;
        if (otp != null && otp.isNotEmpty) {
          state = state.copyWith(step: TcStep.enterOtp);
          await submitOtp(otp);
        }
      case TcSdkCallbackResult.verificationComplete:
        await _signIn(accessToken: event.accessToken ?? '');
      case TcSdkCallbackResult.verifiedBefore:
        await _signIn(accessToken: event.profile?.accessToken ?? '');
      case TcSdkCallbackResult.exception:
        final message = event.exception?.message ?? '';
        _fail(
          message.toLowerCase().contains('credential')
              ? 'Phone verification isn’t set up yet. Please try again later.'
              : message.isNotEmpty
              ? message
              : 'Couldn’t verify your number.',
        );
    }
  }

  Future<void> _signIn({
    String authorizationCode = '',
    String codeVerifier = '',
    String accessToken = '',
  }) async {
    _timer?.cancel();
    state = state.copyWith(step: TcStep.checking);
    try {
      final user = await ref
          .read(authServiceProvider)
          .signInWithTruecaller(
            authorizationCode: authorizationCode,
            codeVerifier: codeVerifier,
            accessToken: accessToken,
          );
      final route = await routeForUser(ref.read, user);
      state = state.copyWith(step: TcStep.done, route: route);
    } catch (e) {
      _fail(e);
    }
  }

  void _countdown(TcStep step, String? ttl) {
    _timer?.cancel();
    state = state.copyWith(
      step: step,
      secondsLeft: int.tryParse(ttl ?? '') ?? 60,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        if (state.step == step) {
          _fail(
            'Time ran out before your number was confirmed. Please try again.',
          );
        }
        return;
      }
      state = state.copyWith(step: state.step, secondsLeft: left);
    });
  }

  void _fail(Object error) {
    _timer?.cancel();
    final message = switch (error) {
      String m => m,
      PlatformException e => e.message ?? 'Couldn’t verify your number.',
      _ => friendlyAuthError(error),
    };
    state = state.copyWith(step: TcStep.failed, error: message);
  }

  static String _randomState() {
    final r = Random.secure();
    return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}
