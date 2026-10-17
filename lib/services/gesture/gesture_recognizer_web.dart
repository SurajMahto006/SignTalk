import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'gesture_recognizer_service.dart';

GestureRecognizerService createGestureRecognizerServiceImpl() => _GestureRecognizerWeb();

@JS('SignTalkGesture')
external _SignTalkGestureJs? get _signTalkGesture;

extension type _SignTalkGestureJs._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external JSObject start(String videoElementId);
  external void stop();
  external JSObject consume();
  external JSObject startRemote(String videoElementId);
  external void stopRemote();
  external JSObject consumeRemote();
  external JSObject status();
}

class _GestureRecognizerWeb implements GestureRecognizerService {
  _SignTalkGestureJs? get _api {
    try {
      return _signTalkGesture;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isSupported => true;

  @override
  Future<GestureInitResult> init() async {
    final api = _api;
    if (api == null) {
      return const GestureInitResult(
        ready: false,
        error: 'SignTalkGesture script not loaded (check web/gesture_recognizer.js).',
      );
    }
    try {
      final result = await api.init().toDart;
      final map = _jsObjectToMap(result);
      return GestureInitResult(
        ready: map['ready'] == true,
        error: map['error']?.toString(),
      );
    } catch (e) {
      return GestureInitResult(ready: false, error: e.toString());
    }
  }

  @override
  GestureStartResult startOnVideoElementId(String videoElementId) {
    final api = _api;
    if (api == null) {
      return const GestureStartResult(ok: false, error: 'SignTalkGesture not available');
    }
    try {
      final map = _jsObjectToMap(api.start(videoElementId));
      return GestureStartResult(
        ok: map['ok'] == true,
        error: map['error']?.toString(),
      );
    } catch (e) {
      return GestureStartResult(ok: false, error: e.toString());
    }
  }

  @override
  void stop() {
    _api?.stop();
  }

  @override
  GestureStartResult startRemoteOnVideoElementId(String videoElementId) {
    final api = _api;
    if (api == null) {
      return const GestureStartResult(ok: false, error: 'SignTalkGesture not available');
    }
    try {
      final map = _jsObjectToMap(api.startRemote(videoElementId));
      return GestureStartResult(
        ok: map['ok'] == true,
        error: map['error']?.toString(),
      );
    } catch (e) {
      return GestureStartResult(ok: false, error: e.toString());
    }
  }

  @override
  void stopRemote() {
    _api?.stopRemote();
  }

  @override
  GestureDetection? consumeRemoteLatest() {
    final api = _api;
    if (api == null) return null;
    try {
      final map = _jsObjectToMap(api.consumeRemote());
      if (map.isEmpty || map['status'] == 'idle') return null;
      return GestureDetection(
        status: map['status']?.toString() ?? 'unknown',
        gesture: map['gesture']?.toString(),
        label: map['label']?.toString(),
        score: (map['score'] as num?)?.toDouble() ?? 0,
        message: map['message']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  GestureDetection? consumeLatest() {
    final api = _api;
    if (api == null) return null;
    try {
      final map = _jsObjectToMap(api.consume());
      if (map.isEmpty || map['status'] == 'idle') return null;
      return GestureDetection(
        status: map['status']?.toString() ?? 'unknown',
        gesture: map['gesture']?.toString(),
        label: map['label']?.toString(),
        score: (map['score'] as num?)?.toDouble() ?? 0,
        message: map['message']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  GestureRuntimeStatus get runtimeStatus {
    final api = _api;
    if (api == null) {
      return const GestureRuntimeStatus(ready: false, running: false, error: 'SignTalkGesture not loaded');
    }
    try {
      final map = _jsObjectToMap(api.status());
      return GestureRuntimeStatus(
        ready: map['ready'] == true,
        running: map['running'] == true,
        error: map['error']?.toString(),
      );
    } catch (e) {
      return GestureRuntimeStatus(ready: false, running: false, error: e.toString());
    }
  }

  Map<String, dynamic> _jsObjectToMap(JSAny? value) {
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
}
