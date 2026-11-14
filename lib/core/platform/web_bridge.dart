/// Small browser helpers for the iPhone web app. On Android/iOS builds these
/// are harmless no-ops (see web_bridge_stub.dart).
library;

export 'web_bridge_stub.dart' if (dart.library.js_interop) 'web_bridge_web.dart';
