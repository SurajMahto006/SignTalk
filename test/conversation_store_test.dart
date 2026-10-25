import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/communication/conversation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('messages stay after a new store loads the same device data', () async {
    final first = ConversationStore();
    await first.load();
    final sentAt = DateTime(2026, 10, 20, 21, 5);
    await first.append(
      ownerId: 'demo',
      contactName: 'Demo contact',
      kind: 'typed',
      body: 'Hello from SignTalk',
      createdAt: sentAt,
    );

    final second = ConversationStore();
    await second.load();
    final saved = second.messagesFor(
      ownerId: 'demo',
      contactName: 'Demo contact',
    );

    expect(saved, hasLength(1));
    expect(saved.single.body, 'Hello from SignTalk');
    expect(saved.single.kind, 'typed');
    expect(saved.single.createdAt, sentAt);
  });

  test('clearing one contact leaves another contact', () async {
    final store = ConversationStore();
    await store.load();
    await store.append(
      ownerId: 'demo',
      contactName: 'Demo contact',
      kind: 'spoken',
      body: 'One',
      createdAt: DateTime(2026, 10, 20),
    );
    await store.append(
      ownerId: 'demo',
      contactName: 'Other',
      kind: 'typed',
      body: 'Two',
      createdAt: DateTime(2026, 10, 20),
    );

    await store.clearContact(ownerId: 'demo', contactName: 'Demo contact');

    expect(
      store.messagesFor(ownerId: 'demo', contactName: 'Demo contact'),
      isEmpty,
    );
    expect(
      store.messagesFor(ownerId: 'demo', contactName: 'Other').single.body,
      'Two',
    );
  });

  test('two accounts keep separate chats with the same contact', () async {
    final store = ConversationStore();
    await store.load();
    await store.append(
      ownerId: 'demo',
      contactName: 'Demo contact',
      kind: 'typed',
      body: 'From guest',
      createdAt: DateTime(2026, 10, 20),
    );
    await store.append(
      ownerId: 'suraj006',
      contactName: 'Demo contact',
      kind: 'typed',
      body: 'From Suraj',
      createdAt: DateTime(2026, 10, 20),
    );

    expect(
      store.messagesFor(ownerId: 'demo', contactName: 'Demo contact').single.body,
      'From guest',
    );
    expect(
      store
          .messagesFor(ownerId: 'suraj006', contactName: 'Demo contact')
          .single
          .body,
      'From Suraj',
    );
  });
}
