/// Static gloss hints for text-to-sign (reference only — not live animation).
class TextToSignReference {
  static const String limitationMessage =
      'Verified ISL sign videos are not bundled in this prototype. '
      'Below is a glossary hint for common INCLUDE-50 glosses only.';

  /// Normalized gloss keys from INCLUDE-50 label map (subset for demo).
  static const Map<String, String> glossHints = {
    'hello': 'Greeting sign — open hand salute near forehead.',
    'thankyou': 'Flat hand from chin forward.',
    'goodmorning': 'Composite concept — use separate signs in full ISL.',
    'good': 'Touch fingers to lips, hand down.',
    'yes': 'Not in INCLUDE-50 bundle — use fingerspelling or alternate sign.',
    'help': 'Not in INCLUDE-50 bundle — describe with available glosses.',
  };

  /// Returns a reference line for [text], or null if no known gloss match.
  static String? hintForText(String text) {
    final normalized = text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized.isEmpty) return null;
    for (final entry in glossHints.entries) {
      if (normalized == entry.key || normalized.contains(entry.key)) {
        return '${entry.key.toUpperCase()}: ${entry.value}';
      }
    }
    return null;
  }
}
