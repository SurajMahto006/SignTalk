import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class VideoFrameCapture {
  const VideoFrameCapture();

  bool get isSupported => true;

  @JS('SignTalkFrameCapture')
  external static _SignTalkFrameCaptureJs? get _api;

  Future<List<int>> captureSingleJpeg({String? videoElementId}) async {
    final clip = await captureClipJpegs(
      videoElementId: videoElementId,
      frameCount: 1,
      intervalMs: 0,
    );
    if (clip.isEmpty) return const [];
    return clip.first;
  }

  Future<List<List<int>>> captureClipJpegs({
    String? videoElementId,
    int frameCount = 8,
    int intervalMs = 80,
  }) async {
    final api = _api;
    if (api == null) return [];

    try {
      final promise = api.captureClip(
        videoElementId ?? '',
        frameCount,
        intervalMs,
        0.72,
      );
      final result = await promise.toDart;
      final map = _jsToMap(result);
      if (map['ok'] != true) return [];
      final frames = map['frames'];
      if (frames is! List) return [];
      final out = <List<int>>[];
      for (final item in frames) {
        if (item is String) {
          out.add(base64Decode(item));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}

extension type _SignTalkFrameCaptureJs._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> captureClip(
    String preferredId,
    int count,
    int intervalMs,
    double quality,
  );
}

Map<String, dynamic> _jsToMap(JSAny? value) {
  if (value == null) return {};
  try {
    final jsonObj = globalContext['JSON'] as JSObject?;
    if (jsonObj == null) return {};
    final jsonStr = (jsonObj.callMethod('stringify'.toJS, value) as JSString).toDart;
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return {};
}
