import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _motionEvent => globalContext['DeviceMotionEvent'] as JSObject?;

/// iPhone Safari only reports tilt after the user allows "Motion & Orientation".
bool get needsMotionPermission =>
    _motionEvent?.has('requestPermission') ?? false;

/// Shows Safari's motion permission prompt. Must run from a tap.
Future<bool> requestMotionPermission() async {
  final event = _motionEvent;
  if (event == null || !event.has('requestPermission')) return true;
  try {
    final result = await event
        .callMethod<JSPromise<JSString>>('requestPermission'.toJS)
        .toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

JSObject? get _storage {
  try {
    return globalContext['localStorage'] as JSObject?;
  } catch (_) {
    return null; // private mode / blocked storage
  }
}

String? storageGet(String key) {
  try {
    return _storage
        ?.callMethod<JSString?>('getItem'.toJS, key.toJS)
        ?.toDart;
  } catch (_) {
    return null;
  }
}

void storageSet(String key, String value) {
  try {
    _storage?.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
  } catch (_) {}
}

String get browserUserAgent {
  final navigator = globalContext['navigator'] as JSObject?;
  return (navigator?['userAgent'] as JSString?)?.toDart ?? '';
}

bool get isStandaloneWebApp {
  final navigator = globalContext['navigator'] as JSObject?;
  final ios = navigator?['standalone'];
  if (ios != null && ios.isA<JSBoolean>() && (ios as JSBoolean).toDart) {
    return true;
  }
  try {
    final query = globalContext.callMethod<JSObject>(
      'matchMedia'.toJS,
      '(display-mode: standalone)'.toJS,
    );
    return (query['matches'] as JSBoolean?)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

/// Phone tilt from Safari's `deviceorientation` events, in degrees
/// (beta = front/back, gamma = left/right).
Stream<({double beta, double gamma})> orientationStream() {
  late final StreamController<({double beta, double gamma})> controller;
  final JSFunction listener = ((JSObject e) {
    final beta = (e['beta'] as JSNumber?)?.toDartDouble;
    final gamma = (e['gamma'] as JSNumber?)?.toDartDouble;
    if (beta != null && gamma != null) {
      controller.add((beta: beta, gamma: gamma));
    }
  }).toJS;
  controller = StreamController.broadcast(
    onListen: () => globalContext.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'deviceorientation'.toJS,
      listener,
    ),
    onCancel: () => globalContext.callMethod<JSAny?>(
      'removeEventListener'.toJS,
      'deviceorientation'.toJS,
      listener,
    ),
  );
  return controller.stream;
}
