import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// App version, set at build time by tool/release.ps1
/// (`--dart-define=VERIXA_VERSION=1.7.0`).
const appVersion = String.fromEnvironment('VERIXA_VERSION', defaultValue: 'dev');

/// Counts installs anonymously: one document per phone in `installs`, with
/// the make/model, Android version, app version and first/last opened
/// dates. No name, number or location. Runs in the background and never
/// blocks or breaks the app.
void recordInstall(FirebaseFirestore db) {
  if (!Platform.isAndroid) return;
  unawaited(_record(db).catchError((_) {}));
}

Future<void> _record(FirebaseFirestore db) async {
  final info = await const MethodChannel('verixa/device')
      .invokeMapMethod<String, Object?>('info');
  final id = info?['id'] as String?;
  if (id == null || id.isEmpty) return;
  final doc = db.collection('installs').doc(id);
  final now = FieldValue.serverTimestamp();
  final details = {
    'manufacturer': '${info!['manufacturer'] ?? ''}',
    'model': '${info['model'] ?? ''}',
    'android': '${info['android'] ?? ''}',
    'appVersion': appVersion,
    'lastOpened': now,
  };
  try {
    // First open on this phone: create it with the install date.
    await doc.set({...details, 'firstOpened': now}).timeout(const Duration(seconds: 20));
  } on FirebaseException catch (e) {
    // Already counted (create-only rule refuses a second create): just
    // refresh the version and last-opened date.
    if (e.code == 'permission-denied') {
      await doc.update(details).timeout(const Duration(seconds: 20));
    }
  }
}
