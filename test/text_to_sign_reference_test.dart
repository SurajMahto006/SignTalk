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
}
