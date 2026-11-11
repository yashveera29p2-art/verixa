/// Where the Verixa backend lives.
///
/// Default: the Android emulator's alias for the PC running the backend.
/// Phone builds (tool/phone.ps1) use `http://localhost:8001`, forwarded
/// to the PC over USB with `adb reverse`.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'VERIXA_API_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );

  /// Must match the backend's VERIXA_MAX_UPLOAD_MB.
  static const maxUploadBytes = 5 * 1024 * 1024;
}
