import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../platform/web_bridge.dart';

/// Opens a web page (or mailto: link) outside the app: the phone's browser
/// on Android, a new tab in the web app. Returns false if it couldn't.
Future<bool> openLink(String url) async {
  if (kIsWeb) return openInBrowser(url);
  try {
    return await const MethodChannel('verixa/device')
            .invokeMethod<bool>('openUrl', {'url': url}) ??
        false;
  } catch (_) {
    return false;
  }
}
