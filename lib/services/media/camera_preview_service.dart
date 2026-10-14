import 'camera_preview_stub.dart'
    if (dart.library.js_interop) 'camera_preview_web.dart';

/// Platform camera preview (`getUserMedia` on Flutter web).
abstract class CameraPreviewService {
  static CameraPreviewService create() => createCameraPreviewService();

  bool get isSupported;
  bool get isActive;
  bool get isPaused;
  String? get viewType;
  String? get lastError;
  bool? get lastPermissionGranted;

  Future<bool> start();
  Future<void> stop();
  void pausePreview();
  void resumePreview();
  void dispose();
}
