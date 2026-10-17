import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/isl/include_gloss_phrases.dart';

void main() {
  test('template sentence for hello friend', () {
    expect(
      IncludeGlossPhrases.toTemplateSentence(['hello', 'friend']),
      'Hello, friend.',
    );
  });

  test('single gloss gets period', () {
    expect(IncludeGlossPhrases.toTemplateSentence(['water']), 'Water.');
  });
}
