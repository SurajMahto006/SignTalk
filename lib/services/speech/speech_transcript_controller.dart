import 'package:flutter/foundation.dart';

/// Merges speech partial/final results into one editable transcript string.
class SpeechTranscriptController extends ChangeNotifier {
  SpeechTranscriptController();

  String _committed = '';
  String _partial = '';
  bool userEditedSinceListen = false;

  String get text {
    if (_partial.isEmpty) return _committed;
    if (_committed.isEmpty) return _partial;
    return '$_committed $_partial'.trim();
  }

  bool get isEmpty => text.trim().isEmpty;

  void onUserEdited(String value) {
    userEditedSinceListen = true;
    _committed = value.trim();
    _partial = '';
    notifyListeners();
  }

  void applyPartial(String partial) {
    if (userEditedSinceListen) return;
    _partial = partial.trim();
    notifyListeners();
  }

  void applyFinal(String finalText) {
    final chunk = finalText.trim();
    if (chunk.isEmpty) return;
    if (userEditedSinceListen) {
      _committed = text.isEmpty ? chunk : '${text.trim()} $chunk';
    } else {
      _committed = _committed.isEmpty ? chunk : '${_committed.trim()} $chunk';
    }
    _partial = '';
    userEditedSinceListen = false;
    notifyListeners();
  }

  void clear() {
    _committed = '';
    _partial = '';
    userEditedSinceListen = false;
    notifyListeners();
  }

  void onListenStarted() {
    userEditedSinceListen = false;
  }
}
