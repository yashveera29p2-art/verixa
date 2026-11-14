import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/install_counter.dart';
import 'core/utils/perf_probe.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Anonymous install count (device model, app version; no personal data).
  recordInstall(FirebaseFirestore.instance);
  runApp(const ProviderScope(child: VerixaApp()));
  startPerfProbe();
}
