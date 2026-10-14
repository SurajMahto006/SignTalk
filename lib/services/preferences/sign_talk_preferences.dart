import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only settings (no conversation content or media).
class SignTalkPreferences extends ChangeNotifier {
  SignTalkPreferences._();

  static const _keyCaptions = 'st_captions';
  static const _keyHaptic = 'st_haptic';
  static const _keySpokenOutput = 'st_spoken_output';
  static const _keyTextSize = 'st_text_size';
  static const _keySpeechLocale = 'st_speech_locale';
  static const _keySpeechLanguageLabel = 'st_speech_language_label';

  static SignTalkPreferences? _instance;
  static SignTalkPreferences get instance => _instance ??= SignTalkPreferences._();

  SharedPreferences? _prefs;
  String? _loadError;

  bool captionsEnabled = true;
  bool hapticEnabled = true;
  bool spokenOutputEnabled = true;
  String textSize = 'Medium';
  String speechLocale = 'en_US';
  String speechLanguageLabel = 'English (US)';

  double get textScaleFactor => switch (textSize) {
        'Small' => 0.9,
        'Large' => 1.15,
        _ => 1.0,
      };

  String? get loadError => _loadError;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadError = null;
      captionsEnabled = _prefs!.getBool(_keyCaptions) ?? true;
      hapticEnabled = _prefs!.getBool(_keyHaptic) ?? true;
      spokenOutputEnabled = _prefs!.getBool(_keySpokenOutput) ?? true;
      textSize = _prefs!.getString(_keyTextSize) ?? 'Medium';
      speechLocale = _prefs!.getString(_keySpeechLocale) ?? 'en_US';
      speechLanguageLabel = _prefs!.getString(_keySpeechLanguageLabel) ?? 'English (US)';
    } catch (e) {
      _loadError = 'Settings could not be loaded; using defaults. ($e)';
      if (kDebugMode) debugPrint(_loadError);
    }
    notifyListeners();
  }

  Future<void> _persist(Future<bool> Function(SharedPreferences prefs) action) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await action(_prefs!);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save preference: $e');
    }
    notifyListeners();
  }

  Future<void> setCaptionsEnabled(bool value) async {
    captionsEnabled = value;
    await _persist((p) => p.setBool(_keyCaptions, value));
  }

  Future<void> setHapticEnabled(bool value) async {
    hapticEnabled = value;
    await _persist((p) => p.setBool(_keyHaptic, value));
  }

  Future<void> setSpokenOutputEnabled(bool value) async {
    spokenOutputEnabled = value;
    await _persist((p) => p.setBool(_keySpokenOutput, value));
  }

  Future<void> setTextSize(String value) async {
    textSize = value;
    await _persist((p) => p.setString(_keyTextSize, value));
  }

  Future<void> setSpeechLanguage({required String label, required String locale}) async {
    speechLanguageLabel = label;
    speechLocale = locale;
    await _persist((p) async {
      await p.setString(_keySpeechLanguageLabel, label);
      return p.setString(_keySpeechLocale, locale);
    });
  }

  void triggerHapticIfEnabled() {
    if (!hapticEnabled) return;
    HapticFeedback.lightImpact();
  }
}
