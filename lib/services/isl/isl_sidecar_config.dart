/// INCLUDE / OpenHands sidecar (pretrained evaluate — no training required in app).
abstract final class IslSidecarConfig {
  /// HTTP base URL, e.g. `http://127.0.0.1:8766`.
  /// Empty disables the sidecar adapter (falls back to disconnected stub).
  static const baseUrl = String.fromEnvironment(
    'ISL_SIDECAR_URL',
    defaultValue: 'http://127.0.0.1:8766',
  );

  static bool get enabled => baseUrl.trim().isNotEmpty;

  static Uri get recognizeUri => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/recognize');

  static Uri get healthUri => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/health');
}
