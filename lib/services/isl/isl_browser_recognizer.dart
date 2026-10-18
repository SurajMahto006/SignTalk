import 'isl_browser_stub.dart' if (dart.library.js_interop) 'isl_browser_web.dart';

class IslBrowserHit {
  const IslBrowserHit({required this.status, this.word, this.score = 0, this.message});

  final String status;
  final String? word;
  final double score;
  final String? message;

  bool get isRecognized => status == 'recognized' && word != null && word!.isNotEmpty;
}

abstract class IslBrowserRecognizer {
  bool get isSupported;

  Future<bool> init();

  bool start(String videoElementId);

  void stop();

  IslBrowserHit? consume();
}

IslBrowserRecognizer createIslBrowserRecognizer() => createIslBrowserRecognizerImpl();
