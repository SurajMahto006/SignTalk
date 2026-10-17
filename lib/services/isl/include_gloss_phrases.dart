/// Maps INCLUDE / ISL gloss tokens to short English for UI and TTS.
///
/// Extend this map as you validate more signs from the pretrained model.
abstract final class IncludeGlossPhrases {
  static const glossToEnglish = <String, String>{
    'hello': 'Hello',
    'thankyou': 'Thank you',
    'thanks': 'Thank you',
    'yes': 'Yes',
    'no': 'No',
    'help': 'Help',
    'please': 'Please',
    'sorry': 'Sorry',
    'good': 'Good',
    'morning': 'Morning',
    'goodmorning': 'Good morning',
    'friend': 'Friend',
    'water': 'Water',
    'food': 'Food',
    'stop': 'Stop',
  };

  static String glossToReadable(String gloss) {
    final key = gloss.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.isEmpty) return gloss;
    return glossToEnglish[key] ?? _titleCase(gloss.replaceAll('_', ' '));
  }

  static String toReadableSentence(Iterable<String> glosses) {
    final parts = glosses.map(glossToReadable).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.join(' ');
  }

  /// Controlled English for multi-sign utterances (template layer — no LLM).
  static String toTemplateSentence(List<String> glosses) {
    final keys = glosses
        .map((g) => g.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((k) => k.isNotEmpty)
        .toList();
    if (keys.isEmpty) return '';
    if (keys.length == 1) {
      final w = glossToReadable(keys.first);
      return w.endsWith('.') ? w : '$w.';
    }

    // Ordered pattern match (longest first).
    final joined = keys.join('|');
    const patterns = <String, String>{
      'hello|friend': 'Hello, friend.',
      'hello|thankyou': 'Hello, thank you.',
      'thankyou|friend': 'Thank you, friend.',
      'help|water': 'I need water.',
      'help|food': 'I need food.',
      'help|please': 'Help, please.',
      'good|morning': 'Good morning.',
      'goodmorning|friend': 'Good morning, friend.',
      'yes|please': 'Yes, please.',
      'no|thankyou': 'No, thank you.',
      'sorry|help': 'Sorry, I need help.',
    };
    if (patterns.containsKey(joined)) return patterns[joined]!;

    // WH- starters (INCLUDE-style gloss order).
    if (keys.first == 'what' && keys.length >= 2) {
      return 'What ${glossToReadable(keys[1]).toLowerCase()}?';
    }
    if (keys.first == 'where' && keys.length >= 2) {
      return 'Where is ${glossToReadable(keys[1]).toLowerCase()}?';
    }
    if (keys.first == 'how' && keys.length >= 2) {
      return 'How ${glossToReadable(keys[1]).toLowerCase()}?';
    }

    final words = keys.map(glossToReadable).toList();
    return '${words.join(', ')}.';
  }

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
