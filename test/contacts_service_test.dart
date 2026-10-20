import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/contacts/contact_item.dart';
import 'package:signtalk/services/contacts/contacts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactsService Tests', () {
    late ContactsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ContactsService();
      await service.load();
    });

    test('Initial state loads default contacts and incoming requests', () {
      expect(service.savedContacts.isNotEmpty, isTrue);
      expect(service.savedContacts.any((c) => c.username == 'aarav_isl'), isTrue);
      expect(service.incomingRequests.isNotEmpty, isTrue);
      expect(service.incomingRequests.first.user.username, 'vikram_singh');
    });

    test('Accepting an incoming request adds to contacts and removes from requests', () async {
      final initialCount = service.savedContacts.length;
      final req = service.incomingRequests.first;

      await service.acceptRequest(req.id);

      expect(service.savedContacts.length, initialCount + 1);
      expect(service.isContact(req.user.username), isTrue);
      expect(service.incomingRequests.any((r) => r.id == req.id), isFalse);
    });

    test('Search users finds matching usernames and names', () {
      final results = service.searchUsers('ananya');
      expect(results.any((u) => u.username == 'ananya_k'), isTrue);

      final customResults = service.searchUsers('@new_friend');
      expect(customResults.any((u) => u.username == 'new_friend'), isTrue);
    });

    test('Sending request adds to outgoing requests and simulation accepts it', () async {
      final targetUser = ContactItem(
        id: 'test_user_id',
        username: 'test_friend',
        name: 'Test Friend',
        role: 'Signer',
        addedAt: DateTime.now(),
      );

      await service.sendRequest(targetUser);
      expect(service.isRequestPending('test_friend'), isTrue);
      expect(service.outgoingRequests.any((r) => r.user.username == 'test_friend'), isTrue);

      final outReq = service.outgoingRequests.firstWhere((r) => r.user.username == 'test_friend');
      await service.simulateAcceptOutgoingRequest(outReq.id);

      expect(service.isContact('test_friend'), isTrue);
      expect(service.isRequestPending('test_friend'), isFalse);
    });

    test('Removing a contact deletes it from saved contacts', () async {
      final contact = service.savedContacts.first;
      final initialCount = service.savedContacts.length;

      await service.removeContact(contact.id);
      expect(service.savedContacts.length, initialCount - 1);
      expect(service.isContact(contact.username), isFalse);
    });
  });
}
