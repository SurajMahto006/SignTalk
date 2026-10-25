/// Turns typed English into an ordered sign plan.
///
/// Movement notes exist only for a few words. Other INCLUDE-50 words are
/// named, but this prototype does not include sign videos.
class SignPlanStep {
  const SignPlanStep({
    required this.label,
    required this.detail,
    required this.known,
  });

  final String label;
  final String detail;
  final bool known;
}

class TextToSignReference {
  static const String limitationMessage =
      'Sign videos are not in the app. Follow the words in order. '
      'Fingerspell any word that is not a known sign.';

  static const Map<String, String> movementNotes = {
    'hello': 'Greeting sign — open hand salute near forehead.',
    'thankyou': 'Flat hand from chin forward.',
    'good': 'Touch fingers to lips, hand down.',
    'goodmorning': 'Use the separate signs for good and morning.',
  };

  /// INCLUDE-50 glosses, plus the one-word greeting used in the composer.
  static const Set<String> knownGlosses = {
    'hello',
    'thankyou',
    'yes',
    'no',
    'please',
    'sorry',
    'help',
    'good',
    'morning',
    'goodmorning',
    'friend',
    'teacher',
    'student',
    'water',
    'food',
    'home',
    'work',
    'time',
    'today',
    'tomorrow',
    'yesterday',
    'mother',
    'father',
    'boy',
    'girl',
    'man',
    'woman',
    'happy',
    'sad',
    'angry',
    'tired',
    'hungry',
    'hot',
    'cold',
    'big',
    'small',
    'colour',
    'red',
    'blue',
    'green',
    'one',
    'two',
    'three',
    'four',
    'five',
    'what',
    'where',
    'when',
    'who',
    'why',
    'how',
  };

  static const Map<String, String> aliases = {
    'thanks': 'thankyou',
    'ok': 'yes',
    'okay': 'yes',
    'color': 'colour',
  };

  static List<SignPlanStep> filterSteps(
    List<SignPlanStep> steps,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return steps;
    return [
      for (final step in steps)
        if (step.label.toLowerCase().contains(needle) ||
            step.detail.toLowerCase().contains(needle))
          step,
    ];
  }

  /// Every known sign, in alphabetical order, for the Learn page.
  static List<SignPlanStep> learnSteps() {
    final words = knownGlosses.toList()..sort();
    return [
      for (final word in words) ...planForText(word),
    ];
  }

  /// One line for the first matching known sign, kept for older call sites.
  static String? hintForText(String text) {
    final known = planForText(text).where((step) => step.known);
    if (known.isEmpty) return null;
    return known.map((step) => '${step.label}: ${step.detail}').join('\n');
  }

  /// Every word in [text], in order. Unknown words are marked for fingerspelling.
  static List<SignPlanStep> planForText(String text) {
    final tokens = _tokens(text);
    if (tokens.isEmpty) return const [];

    final steps = <SignPlanStep>[];
    for (var i = 0; i < tokens.length; i++) {
      var word = tokens[i];
      if (word == 'thank' && i + 1 < tokens.length && tokens[i + 1] == 'you') {
        word = 'thankyou';
        i++;
      }
      final gloss = aliases[word] ?? word;
      if (knownGlosses.contains(gloss)) {
        steps.add(
          SignPlanStep(
            label: gloss.toUpperCase(),
            detail: movementNotes[gloss] ??
                'Known INCLUDE word. Sign video is not in the app yet.',
            known: true,
          ),
        );
      } else {
        steps.add(
          SignPlanStep(
            label: word,
            detail: 'Fingerspell this word. It is not in the sign list.',
            known: false,
          ),
        );
      }
    }
    return steps;
  }

  static List<String> _tokens(String text) {
    return RegExp(r"[A-Za-z']+")
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => word.isNotEmpty)
        .toList();
  }
}
