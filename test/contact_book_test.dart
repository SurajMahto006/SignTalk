import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/communication/contact_book.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a new account starts with the demo contact', () async {
    final book = ContactBook();
    await book.load();

    expect(book.contactsFor('demo'), ['Demo contact']);
  });

  test('added contacts stay with that account only', () async {
    final first = ContactBook();
    await first.load();
    expect(await first.add(ownerId: 'suraj006', name: 'Asha'), isNull);

    final second = ContactBook();
    await second.load();

    expect(second.contactsFor('suraj006'), ['Demo contact', 'Asha']);
    expect(second.contactsFor('demo'), ['Demo contact']);
    expect(
      await second.add(ownerId: 'suraj006', name: 'asha'),
      'That contact is already in your list.',
    );
  });

  test('removing a contact leaves the others', () async {
    final book = ContactBook();
    await book.load();
    await book.add(ownerId: 'demo', name: 'Asha');
    expect(await book.remove(ownerId: 'demo', name: 'Demo contact'), isTrue);

    final again = ContactBook();
    await again.load();
    expect(again.contactsFor('demo'), ['Asha']);
  });
}
