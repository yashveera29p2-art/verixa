import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../platform/web_bridge.dart';

String? _cached;

/// Identifies this installation of the app: it changes when the app is
/// reinstalled (Android) or the browser's storage is cleared (web app).
/// Used to show the Terms and the guided tour once per installation.
Future<String> installKey() async {
  if (_cached != null) return _cached!;
  if (kIsWeb) {
    var id = storageGet('verixa.installKey');
    if (id == null) {
      final r = Random.secure();
      id = 'web-${List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join()}';
      storageSet('verixa.installKey', id);
    }
    return _cached = id;
  }
  try {
    final info = await const MethodChannel('verixa/device')
        .invokeMapMethod<String, Object?>('info');
    final key = info?['installKey'] as String?;
    if (key != null && key.isNotEmpty) return _cached = key;
  } catch (_) {}
  return _cached = 'unknown';
}
