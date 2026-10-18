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

  test('catalog numbers and camel case become readable words', () {
    expect(IncludeGlossPhrases.glossToReadable('4.sad'), 'Sad');
    expect(IncludeGlossPhrases.glossToReadable('GoodAfternoon'), 'Good afternoon');
  });

  test('several signs become one sentence', () {
    expect(
      IncludeGlossPhrases.toTemplateSentence(['doctor', 'friend']),
      'Doctor friend.',
    );
    expect(
      IncludeGlossPhrases.toTemplateSentence(['hello', 'friend', 'doctor']),
      'Hello friend doctor.',
    );
  });
}
