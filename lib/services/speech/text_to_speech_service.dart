import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'text_to_speech_web_stub.dart'
    if (dart.library.js_interop) 'text_to_speech_web.dart';

enum SpeakOutcome { success, empty, unavailable, failed, cancelled }

class TextToSpeechService extends ChangeNotifier {
  TextToSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;
  bool _speaking = false;
  String _languageLocale = 'en-US';
  bool _webSpeechPrimed = false;

  bool get isSpeaking => _speaking;

  /// Must run synchronously inside a button tap (Android Chrome autoplay policy).
  void primeWebSpeechFromUserGesture() {
    if (!kIsWeb) return;
    primeSpeechSynthesisSync(_languageLocale);
    _webSpeechPrimed = true;
  }

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(_onStopped);
      _tts.setCancelHandler(_onStopped);
      _initialized = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TTS init failed: $e');
      }
      return false;
    }
  }

  void _onStopped() {
    _speaking = false;
    notifyListeners();
  }

  Future<void> setLanguage(String locale) async {
    _languageLocale = locale.replaceAll('_', '-');
    await initialize();
    try {
      await _tts.setLanguage(locale);
    } catch (_) {}
  }

  Future<SpeakOutcome> speak(String text, {bool enabled = true}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return SpeakOutcome.empty;
    if (!enabled) return SpeakOutcome.unavailable;

    if (kIsWeb) {
      if (!_webSpeechPrimed) {
        primeSpeechSynthesisSync(_languageLocale);
      }
      if (!isAndroidMobileBrowser()) {
        await stopBrowserSpeech();
      }
      if (await speakViaBrowserWithRetries(trimmed, _languageLocale)) {
        _speaking = true;
        notifyListeners();
        return SpeakOutcome.success;
      }
    }

    final ok = await initialize();
    if (!ok && !kIsWeb) return SpeakOutcome.unavailable;

    try {
      await stop();
      final result = await _tts.speak(trimmed);
      if (result == 1 || (kIsWeb && result == 0)) {
        _speaking = true;
        notifyListeners();
        return SpeakOutcome.success;
      }
      if (kIsWeb && speakViaBrowser(trimmed, _languageLocale)) {
        _speaking = true;
        notifyListeners();
        return SpeakOutcome.success;
      }
      return SpeakOutcome.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak failed: $e');
      if (kIsWeb && speakViaBrowser(trimmed, _languageLocale)) {
        _speaking = true;
        notifyListeners();
        return SpeakOutcome.success;
      }
      _speaking = false;
      notifyListeners();
      return SpeakOutcome.failed;
    }
  }

  Future<void> stopBrowserSpeech() async {
    if (!kIsWeb) return;
    cancelBrowserSpeech();
  }

  Future<void> stop() async {
    await stopBrowserSpeech();
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
    notifyListeners();
  }
}
