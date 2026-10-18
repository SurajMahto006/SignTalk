import 'isl_browser_recognizer.dart';

IslBrowserRecognizer createIslBrowserRecognizerImpl() => _UnsupportedIslBrowser();

class _UnsupportedIslBrowser implements IslBrowserRecognizer {
  @override
  bool get isSupported => false;

  @override
  Future<bool> init() async => false;

  @override
  bool start(String videoElementId) => false;

  @override
  void stop() {}

  @override
  IslBrowserHit? consume() => null;
}
