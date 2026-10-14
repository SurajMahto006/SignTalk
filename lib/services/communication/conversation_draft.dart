import 'package:flutter/foundation.dart';

/// Passes composer text from Speech / Sign screens into Conversations (in-memory only).
class ConversationDraft extends ChangeNotifier {
  String? pendingText;
  bool preferSpokenBubble = false;
  bool fromIslModel = false;

  void stage(
    String text, {
    bool asSpoken = false,
    bool asRecognizedSign = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    pendingText = trimmed;
    preferSpokenBubble = asSpoken;
    fromIslModel = asRecognizedSign;
    notifyListeners();
  }

  /// Returns staged text once, then clears.
  ({String text, bool asSpoken, bool asRecognizedSign})? consume() {
    final text = pendingText;
    if (text == null || text.isEmpty) return null;
    final asSpoken = preferSpokenBubble;
    final asRecognizedSign = fromIslModel;
    pendingText = null;
    preferSpokenBubble = false;
    fromIslModel = false;
    notifyListeners();
    return (text: text, asSpoken: asSpoken, asRecognizedSign: asRecognizedSign);
  }
}
