import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/isl/text_to_sign_reference.dart';

void main() {
  test('finds glossary hint for hello', () {
    final hint = TextToSignReference.hintForText('Hello!');
    expect(hint, isNotNull);
    expect(hint!.toLowerCase(), contains('hello'));
  });

  test('returns null for unknown words', () {
    expect(TextToSignReference.hintForText('xyzunknown'), isNull);
  });

  test('keeps a sentence in order and fingerspells unknown words', () {
    final plan = TextToSignReference.planForText(
      'Hello friend, I need water',
    );

    expect(plan.map((step) => step.label).toList(), [
      'HELLO',
      'FRIEND',
      'i',
      'need',
      'WATER',
    ]);
    expect(plan[0].known, isTrue);
    expect(plan[2].known, isFalse);
    expect(plan[2].detail.toLowerCase(), contains('fingerspell'));
    expect(plan[4].known, isTrue);
  });

  test('lists known signs for the learn page', () {
    final steps = TextToSignReference.learnSteps();
    expect(steps.length, greaterThan(40));
    expect(
      steps.firstWhere((step) => step.label == 'HELLO').detail,
      contains('forehead'),
    );
  });

  test('treats thank you as one sign', () {
    final plan = TextToSignReference.planForText('Thank you');
    expect(plan, hasLength(1));
    expect(plan.single.label, 'THANKYOU');
    expect(plan.single.known, isTrue);
  });
}
