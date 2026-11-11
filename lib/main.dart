import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

/// Set with `--dart-define=VERIXA_TEST_OTP=true` (emulator runs only).
/// Skips Play Integrity / reCAPTCHA so the Firebase test number
/// (+91 9999999999 / 123456) works on the emulator. Real numbers do NOT
/// work while this is on, so phone builds leave it off.
const _testOtpOnly = bool.fromEnvironment('VERIXA_TEST_OTP');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_testOtpOnly) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }

  runApp(const ProviderScope(child: VerixaApp()));
}
