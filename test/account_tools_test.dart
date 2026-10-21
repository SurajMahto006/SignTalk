import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/auth/auth_service.dart';
import 'package:signtalk/services/communication/contact_book.dart';
import 'package:signtalk/services/communication/conversation_store.dart';
import 'package:signtalk/services/isl/favorite_signs.dart';
import 'package:signtalk/services/isl/text_to_sign_reference.dart';
import 'package:signtalk/services/logs/activity_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
  });

  test('search matches part of a contact name', () {
    expect(
      ContactBook.matching(['Demo contact', 'Asha', 'Aman'], 'ash'),
      ['Asha'],
    );
  });

  test('renaming a contact keeps the saved chat', () async {
    final book = ContactBook();
    final chats = ConversationStore();
    final logs = ActivityLogService();
    await book.load();
    await chats.load();
    await logs.load();
    await book.add(ownerId: 'demo', name: 'Asha');
    await chats.append(
      ownerId: 'demo',
      contactName: 'Asha',
      kind: 'typed',
      body: 'Hello Asha',
      createdAt: DateTime(2026, 10, 20),
    );
    await logs.addChat(ownerId: 'demo', contactName: 'Asha', preview: 'Hello Asha');

    expect(
      await book.rename(ownerId: 'demo', fromName: 'Asha', toName: 'Asha K'),
      isNull,
    );
    await chats.renameContact(
      ownerId: 'demo',
      fromName: 'Asha',
      toName: 'Asha K',
    );
    await logs.renameContact(
      ownerId: 'demo',
      fromName: 'Asha',
      toName: 'Asha K',
    );

    expect(
      chats.messagesFor(ownerId: 'demo', contactName: 'Asha K').single.body,
      'Hello Asha',
    );
    expect(logs.entriesFor('demo').single.contactName, 'Asha K');
  });

  test('one message can be removed without clearing the thread', () async {
    final chats = ConversationStore();
    await chats.load();
    await chats.append(
      ownerId: 'demo',
      contactName: 'Asha',
      kind: 'typed',
      body: 'One',
      createdAt: DateTime(2026, 10, 20),
    );
    await chats.append(
      ownerId: 'demo',
      contactName: 'Asha',
      kind: 'typed',
      body: 'Two',
      createdAt: DateTime(2026, 10, 20, 1),
    );

    await chats.removeMessage(ownerId: 'demo', contactName: 'Asha', index: 0);

    final left = chats.messagesFor(ownerId: 'demo', contactName: 'Asha');
    expect(left.map((message) => message.body), ['Two']);
  });

  test('a created account can change its name and password', () async {
    final auth = AuthService.instance;
    final registered = await auth.register(
      userId: 'tooluser',
      name: 'Tool User',
      password: 'Password123',
    );
    expect(registered.success, isTrue, reason: registered.message);

    final named = await auth.updateName('Suraj Mahto');
    expect(named.success, isTrue);
    expect(auth.currentUser?.name, 'Suraj Mahto');

    final changed = await auth.changePassword(
      currentPassword: 'Password123',
      newPassword: 'Better456',
    );
    expect(changed.success, isTrue);

    await auth.logout();
    expect(
      (await auth.login(userId: 'tooluser', password: 'Password123')).success,
      isFalse,
    );
    expect(
      (await auth.login(userId: 'tooluser', password: 'Better456')).success,
      isTrue,
    );
  });

  test('the guest password stays demo', () async {
    final auth = AuthService.instance;
    await auth.login(userId: 'demo', password: 'demo');
    final result = await auth.changePassword(
      currentPassword: 'demo',
      newPassword: 'Better456',
    );
    expect(result.success, isFalse);
    expect(result.message, contains('demo'));
  });

  test('starred signs stay on the phone and search finds hello', () async {
    final stars = FavoriteSigns();
    await stars.load();
    await stars.toggle('HELLO');
    final again = FavoriteSigns();
    await again.load();
    expect(again.isFavorite('hello'), isTrue);

    final found = TextToSignReference.filterSteps(
      TextToSignReference.learnSteps(),
      'forehead',
    );
    expect(found.map((step) => step.label), contains('HELLO'));
  });
}
