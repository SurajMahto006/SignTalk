/// Non-web: no JPEG capture from DOM video.
class VideoFrameCapture {
  const VideoFrameCapture();

  bool get isSupported => false;

  Future<List<int>> captureSingleJpeg({String? videoElementId}) async => const [];

  Future<List<List<int>>> captureClipJpegs({
    String? videoElementId,
    int frameCount = 8,
    int intervalMs = 80,
  }) async =>
      [];
}
