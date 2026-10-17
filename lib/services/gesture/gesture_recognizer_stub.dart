import 'gesture_recognizer_service.dart';

GestureRecognizerService createGestureRecognizerServiceImpl() => _GestureRecognizerStub();

class _GestureRecognizerStub implements GestureRecognizerService {
  @override
  bool get isSupported => false;

  @override
  Future<GestureInitResult> init() async =>
      const GestureInitResult(ready: false, error: 'Gesture recognition is web-only in this build.');

  @override
  GestureStartResult startOnVideoElementId(String videoElementId) =>
      const GestureStartResult(ok: false, error: 'Not supported on this platform');

  @override
  void stop() {}

  @override
  GestureDetection? consumeLatest() => null;

  @override
  GestureStartResult startRemoteOnVideoElementId(String videoElementId) =>
      const GestureStartResult(ok: false, error: 'Not supported on this platform');

  @override
  void stopRemote() {}

  @override
  GestureDetection? consumeRemoteLatest() => null;

  @override
  GestureRuntimeStatus get runtimeStatus =>
      const GestureRuntimeStatus(ready: false, running: false, error: 'Unsupported platform');
}
