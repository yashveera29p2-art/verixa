/// Where the Verixa backend lives.
///
/// Default: the Android emulator's alias for the PC running the backend.
/// For a real phone on the same Wi-Fi, run the app with
/// `--dart-define=VERIXA_API_URL=http://<your-pc-ip>:8001`.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'VERIXA_API_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );

  /// Must match the backend's VERIXA_MAX_UPLOAD_MB.
  static const maxUploadBytes = 5 * 1024 * 1024;
}
