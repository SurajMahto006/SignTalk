bool isAndroidMobileBrowser() => false;

void primeSpeechSynthesisSync(String locale) {}

void cancelBrowserSpeech() {}

bool speakViaBrowser(String text, String locale) => false;

Future<bool> speakViaBrowserWithRetries(String text, String locale) async => false;
