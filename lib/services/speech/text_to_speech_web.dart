import 'package:web/web.dart' as web;

bool isAndroidMobileBrowser() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') && (ua.contains('chrome') || ua.contains('crios'));
}

/// Call synchronously from Host / Join / Check camera (Android autoplay policy).
void primeSpeechSynthesisSync(String locale) {
  try {
    final synth = web.window.speechSynthesis;
    synth.resume();
    if (isAndroidMobileBrowser()) {
      final lang = locale.replaceAll('_', '-');
      final unlock = web.SpeechSynthesisUtterance('OK');
      unlock.lang = lang;
      unlock.volume = 0.5;
      unlock.rate = 1;
      synth.speak(unlock);
      return;
    }
    final lang = locale.replaceAll('_', '-');
    final warm = web.SpeechSynthesisUtterance('.');
    warm.lang = lang;
    warm.volume = 0.01;
    warm.rate = 1;
    synth.speak(warm);
  } catch (_) {}
}

void cancelBrowserSpeech() {
  if (isAndroidMobileBrowser()) {
    // cancel() on Android Chrome often kills speech until page reload.
    try {
      web.window.speechSynthesis.resume();
    } catch (_) {}
    return;
  }
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}

bool speakViaBrowser(String text, String locale) {
  try {
    final synth = web.window.speechSynthesis;
    synth.resume();
    final android = isAndroidMobileBrowser();
    if (!android) {
      synth.cancel();
    } else if (synth.speaking) {
      return true;
    }

    final lang = locale.replaceAll('_', '-');
    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.lang = lang;
    utterance.rate = android ? 0.9 : 0.92;
    utterance.volume = 1;
    utterance.pitch = 1;
    synth.speak(utterance);

    if (android) {
      synth.resume();
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Extra attempts for Android (no cancel between tries).
Future<bool> speakViaBrowserWithRetries(String text, String locale) async {
  if (speakViaBrowser(text, locale)) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final synth = web.window.speechSynthesis;
    if (synth.speaking || synth.pending) return true;
  }
  if (!isAndroidMobileBrowser()) return false;

  for (final ms in [150, 350, 700]) {
    await Future<void>.delayed(Duration(milliseconds: ms));
    try {
      web.window.speechSynthesis.resume();
    } catch (_) {}
    if (speakViaBrowser(text, locale)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final synth = web.window.speechSynthesis;
      if (synth.speaking || synth.pending) return true;
    }
  }
  return false;
}
