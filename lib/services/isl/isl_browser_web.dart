import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'isl_browser_recognizer.dart';

IslBrowserRecognizer createIslBrowserRecognizerImpl() => _IslBrowserWeb();

@JS('SignTalkIsl')
external _SignTalkIslJs? get _signTalkIsl;

extension type _SignTalkIslJs._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external JSObject start(String videoElementId);
  external void stop();
  external JSObject consume();
}

class _IslBrowserWeb implements IslBrowserRecognizer {
  _SignTalkIslJs? get _api {
    try {
      return _signTalkIsl;
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isSupported => true;

  @override
  Future<bool> init() async {
    final api = _api;
    if (api == null) return false;
    try {
      final map = _jsObjectToMap(await api.init().toDart);
      return map['ready'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool start(String videoElementId) {
    final api = _api;
    if (api == null) return false;
    try {
      final map = _jsObjectToMap(api.start(videoElementId));
      return map['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  void stop() {
    _api?.stop();
  }

  @override
  IslBrowserHit? consume() {
    final api = _api;
    if (api == null) return null;
    try {
      final map = _jsObjectToMap(api.consume());
      final status = map['status']?.toString() ?? 'idle';
      if (status == 'idle') return null;
      final word = map['word']?.toString();
      return IslBrowserHit(
        status: status,
        word: word == null || word.isEmpty ? null : word,
        score: (map['score'] as num?)?.toDouble() ?? 0,
        message: map['message']?.toString(),
      );
    } catch (_) {
      return null;
    }
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
