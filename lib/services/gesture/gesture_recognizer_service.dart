import 'gesture_detection.dart';
import 'gesture_recognizer_stub.dart'
    if (dart.library.js_interop) 'gesture_recognizer_web.dart';

export 'gesture_detection.dart';

abstract class GestureRecognizerService {
  bool get isSupported;

  Future<GestureInitResult> init();

  GestureStartResult startOnVideoElementId(String videoElementId);

  void stop();

  GestureDetection? consumeLatest();

  /// Partner’s main video on this device (display + TTS; does not send signaling).
  GestureStartResult startRemoteOnVideoElementId(String videoElementId);

  void stopRemote();

  GestureDetection? consumeRemoteLatest();

  GestureRuntimeStatus get runtimeStatus;
}

class GestureInitResult {
  const GestureInitResult({required this.ready, this.error});

  final bool ready;
  final String? error;
}

class GestureStartResult {
  const GestureStartResult({required this.ok, this.error});

  final bool ok;
  final String? error;
}

class GestureRuntimeStatus {
  const GestureRuntimeStatus({required this.ready, required this.running, this.error});

  final bool ready;
  final bool running;
  final String? error;
}

GestureRecognizerService createGestureRecognizerService() => createGestureRecognizerServiceImpl();
