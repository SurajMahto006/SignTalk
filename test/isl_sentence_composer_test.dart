import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/isl/isl_sentence_composer.dart';

void main() {
  test('commits words after pause and builds readable sentence', () {
    final composer = IslSentenceComposer(
      wordCommitPause: const Duration(milliseconds: 100),
      minWordGap: const Duration(milliseconds: 50),
    );

    composer.observeStableWord('hello');
    composer.tick(DateTime.now().add(const Duration(milliseconds: 150)));

    expect(composer.glosses, ['hello']);
    expect(composer.readableSentence, 'Hello.');

    composer.observeStableWord('friend');
    composer.tick(DateTime.now().add(const Duration(milliseconds: 300)));

    expect(composer.glosses.length, 2);
    expect(composer.readableSentence, 'Hello, friend.');
  });

  test('clears utterance after prolonged silence', () {
    final composer = IslSentenceComposer(
      wordCommitPause: const Duration(milliseconds: 50),
      utteranceSilence: const Duration(milliseconds: 200),
    );
    composer.observeStableWord('hello');
    composer.tick(DateTime.now().add(const Duration(milliseconds: 100)));
    expect(composer.glosses, isNotEmpty);

    final ended = composer.tick(DateTime.now().add(const Duration(milliseconds: 500)));
    expect(ended, isTrue);
    expect(composer.glosses, isEmpty);
  });
}
