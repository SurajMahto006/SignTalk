import 'camera_preview_service.dart';

CameraPreviewService createCameraPreviewService() => _CameraPreviewStub();

class _CameraPreviewStub implements CameraPreviewService {
  @override
  bool get isSupported => false;

  @override
  bool get isActive => false;

  @override
  bool get isPaused => false;

  @override
  String? get viewType => null;

  @override
  String? get lastError => 'Camera preview is only implemented for Flutter web in this build.';

  @override
  bool? get lastPermissionGranted => null;

  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}

  @override
  void pausePreview() {}

  @override
  void resumePreview() {}

  @override
  void dispose() {}
}
