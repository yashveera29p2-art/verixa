/// Native builds: nothing to bridge.
bool get needsMotionPermission => false;

Future<bool> requestMotionPermission() async => true;

String? storageGet(String key) => null;

void storageSet(String key, String value) {}

String get browserUserAgent => '';

/// True when opened from the home screen (not inside a browser tab).
bool get isStandaloneWebApp => false;

/// Phone tilt in degrees (beta = front/back, gamma = left/right).
Stream<({double beta, double gamma})> orientationStream() =>
    const Stream.empty();

/// Web only: opens [url] in a new browser tab. Native builds use the
/// platform channel instead (see core/utils/links.dart).
bool openInBrowser(String url) => false;
