import '../media/video_frame_capture.dart';
import 'isl_recognition_adapter.dart';

/// Captures a short JPEG clip from a web video element and runs ISL recognition.
class IslLiveRecognition {
  IslLiveRecognition({
    VideoFrameCapture? frameCapture,
  }) : _frames = frameCapture ?? VideoFrameCapture();

  final VideoFrameCapture _frames;

  bool get isSupported => _frames.isSupported;

  Future<List<List<int>>> captureClip({
    String? videoElementId,
    int frameCount = 8,
    int intervalMs = 80,
  }) {
    return _frames.captureClipJpegs(
      videoElementId: videoElementId,
      frameCount: frameCount,
      intervalMs: intervalMs,
    );
  }

  Future<IslRecognitionResult> recognizeFromVideo({
    required SmoothedIslRecognitionService isl,
    String? videoElementId,
    int frameCount = 8,
  }) async {
    final clip = await captureClip(
      videoElementId: videoElementId,
      frameCount: frameCount,
    );
    return isl.recognizeClip(jpegFrames: clip);
  }
}
