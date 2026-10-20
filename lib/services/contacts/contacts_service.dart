import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_item.dart';

class ContactsService extends ChangeNotifier {
  ContactsService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  static const _storageKeyContacts = 'st_contacts_list';
  static const _storageKeyRequests = 'st_contacts_requests';

  SharedPreferences? _prefs;
  final List<ContactItem> _contacts = [];
  final List<ContactRequest> _requests = [];

  List<ContactItem> get savedContacts => List.unmodifiable(_contacts);

  List<ContactRequest> get incomingRequests => List.unmodifiable(
        _requests.where(
          (r) => r.isIncoming && r.status == ContactRequestStatus.pending,
        ),
      );

  List<ContactRequest> get outgoingRequests => List.unmodifiable(
        _requests.where(
          (r) => !r.isIncoming && r.status == ContactRequestStatus.pending,
        ),
      );

  int get pendingIncomingCount => incomingRequests.length;

  /// Global directory of registered users available for search.
  final List<ContactItem> _directory = [
    ContactItem(
      id: 'dir_1',
      username: 'vikram_singh',
      name: 'Vikram Singh',
      role: 'ISL Certified Interpreter',
      bio: 'Professional sign interpreter for webinars & medical consultations.',
      isOnline: true,
      addedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ContactItem(
      id: 'dir_2',
      username: 'ananya_k',
      name: 'Ananya Kapoor',
      role: 'ISL Educator & Tutor',
      bio: 'Teaching Indian Sign Language to parents and teachers.',
      isOnline: true,
      addedAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    ContactItem(
      id: 'dir_3',
      username: 'kabir_das',
      name: 'Kabir Das',
      role: 'Deaf Community Creator',
      bio: 'Sharing daily vlog stories in ISL.',
      isOnline: false,
      addedAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    ContactItem(
      id: 'dir_4',
      username: 'tanvi_isl',
      name: 'Tanvi Mehta',
      role: 'Speech & Hearing Specialist',
      bio: 'Clinical audiologist promoting inclusive communication.',
      isOnline: true,
      addedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    ContactItem(
      id: 'dir_5',
      username: 'aditya_sign',
      name: 'Aditya Rao',
      role: 'Accessible Tech Advocate',
      bio: 'Passionate about assistive tech for the deaf community.',
      isOnline: false,
      addedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
    ContactItem(
      id: 'dir_6',
      username: 'meera_joshi',
      name: 'Meera Joshi',
      role: 'Sign Language Volunteer',
      bio: 'Community organizer for deaf youth workshops.',
      isOnline: true,
      addedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ContactItem(
      id: 'dir_7',
      username: 'sid_nair',
      name: 'Siddharth Nair',
      role: 'Student & ISL Learner',
      bio: 'Learning ISL to communicate with deaf relatives.',
      isOnline: false,
      addedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ContactItem(
      id: 'dir_8',
      username: 'kavita_shah',
      name: 'Kavita Shah',
      role: 'Speech Language Pathologist',
      bio: 'Helping individuals bridge spoken and signed dialogue.',
      isOnline: true,
      addedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<ContactItem> get allDirectoryUsers => List.unmodifiable(_directory);

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final rawContacts = _prefs!.getStringList(_storageKeyContacts);
      final rawRequests = _prefs!.getStringList(_storageKeyRequests);

      if (rawContacts != null && rawContacts.isNotEmpty) {
        _contacts
          ..clear()
          ..addAll(
            rawContacts.map(
              (item) => ContactItem.fromJson(item),
            ),
          );
      } else {
        _populateDefaultContacts();
      }

      if (rawRequests != null) {
        _requests
          ..clear()
          ..addAll(
            rawRequests.map(
              (item) => ContactRequest.fromJson(item),
            ),
          );
      } else {
        _populateDefaultRequests();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsService] Failed to load from prefs: $e');
      }
      _populateDefaultContacts();
      _populateDefaultRequests();
    }
    notifyListeners();
  }

  void _populateDefaultContacts() {
    _contacts
      ..clear()
      ..addAll([
        ContactItem(
          id: 'c_1',
          username: 'aarav_isl',
          name: 'Aarav Sharma',
          role: 'ISL Specialist',
          bio: 'Always available for quick practice sessions.',
          isOnline: true,
          addedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        ContactItem(
          id: 'c_2',
          username: 'priya_sign',
          name: 'Priya Patel',
          role: 'Deaf Community Member',
          bio: 'Prefers sign language video calls.',
          isOnline: true,
          addedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
        ContactItem(
          id: 'c_3',
          username: 'dr_neha',
          name: 'Dr. Neha Verma',
          role: 'Speech Therapist',
          bio: 'Speech therapy & sign consultations.',
          isOnline: false,
          addedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ContactItem(
          id: 'c_4',
          username: 'rohan_g',
          name: 'Rohan Gupta',
          role: 'Sign Learner',
          bio: 'Practicing daily ISL alphabets and greetings.',
          isOnline: false,
          addedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
  }

  void _populateDefaultRequests() {
    _requests
      ..clear()
      ..add(
        ContactRequest(
          id: 'req_default_incoming',
          user: ContactItem(
            id: 'dir_1',
            username: 'vikram_singh',
            name: 'Vikram Singh',
            role: 'ISL Certified Interpreter',
            bio: 'Professional sign interpreter for webinars & medical consultations.',
            isOnline: true,
            addedAt: DateTime.now(),
          ),
          isIncoming: true,
          status: ContactRequestStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setStringList(
        _storageKeyContacts,
        _contacts.map((c) => c.toJson()).toList(),
      );
      await _prefs!.setStringList(
        _storageKeyRequests,
        _requests.map((r) => jsonEncode(r.toMap())).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ContactsService] Failed to persist contacts: $e');
      }
    }
    notifyListeners();
  }

  bool isContact(String username) {
    final clean = username.replaceAll('@', '').toLowerCase().trim();
    return _contacts.any(
      (c) => c.username.toLowerCase().trim() == clean,
    );
  }

  bool isRequestPending(String username) {
    final clean = username.replaceAll('@', '').toLowerCase().trim();
    return _requests.any(
      (r) =>
          r.status == ContactRequestStatus.pending &&
          r.user.username.toLowerCase().trim() == clean,
    );
  }

  /// Search across directory or generate dynamic match for any typed username.
  List<ContactItem> searchUsers(String query) {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty) {
      return _directory;
    }

    final matches = _directory.where((user) {
      final uMatch = user.username.toLowerCase().contains(q);
      final nMatch = user.name.toLowerCase().contains(q);
      final rMatch = user.role.toLowerCase().contains(q);
      return uMatch || nMatch || rMatch;
    }).toList();

    // If no exact match and query is valid username length, offer custom user
    final exactMatch = matches.any((u) => u.username.toLowerCase() == q);
    if (!exactMatch && q.length >= 2) {
      final formattedName = q
          .split(RegExp(r'[_.]'))
          .map((part) => part.isNotEmpty
              ? '${part[0].toUpperCase()}${part.substring(1)}'
              : '')
          .join(' ');

      matches.insert(
        0,
        ContactItem(
          id: 'custom_$q',
          username: q,
          name: formattedName.isNotEmpty ? formattedName : '@$q',
          role: 'SignTalk Member',
          bio: 'Registered user on SignTalk network.',
          isOnline: true,
          addedAt: DateTime.now(),
        ),
      );
    }

    return matches;
  }

  /// Send a contact request to another user.
  Future<void> sendRequest(ContactItem targetUser) async {
    // Check if already contact or pending
    if (isContact(targetUser.username)) return;
    if (isRequestPending(targetUser.username)) return;

    final request = ContactRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      user: targetUser,
      isIncoming: false,
      status: ContactRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    _requests.insert(0, request);
    await _persist();
  }

  /// Accept an incoming or outgoing request and save contact.
  Future<void> acceptRequest(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final req = _requests[index];
    final contact = req.user.copyWith(
      addedAt: DateTime.now(),
    );

    // Add to saved contacts if not already added
    if (!_contacts.any((c) => c.username == contact.username)) {
      _contacts.insert(0, contact);
    }

    // Remove or update the request
    _requests.removeAt(index);
    await _persist();
  }

  /// Decline / reject a request.
  Future<void> declineRequest(String requestId) async {
    _requests.removeWhere((r) => r.id == requestId);
    await _persist();
  }

  /// Cancel an outgoing request that user sent.
  Future<void> cancelOutgoingRequest(String requestId) async {
    _requests.removeWhere((r) => r.id == requestId);
    await _persist();
  }

  /// Simulate the opposite person accepting an outgoing request sent to them.
  /// This fulfills the user requirement:
  /// "opposite person use accept kare to vo contact mere contact me save ho jaye".
  Future<void> simulateAcceptOutgoingRequest(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;

    final req = _requests[index];
    final contact = req.user.copyWith(
      addedAt: DateTime.now(),
      isOnline: true,
    );

    if (!_contacts.any((c) => c.username == contact.username)) {
      _contacts.insert(0, contact);
    }

    _requests.removeAt(index);
    await _persist();
  }

  /// Remove a saved contact.
  Future<void> removeContact(String contactId) async {
    _contacts.removeWhere((c) => c.id == contactId);
    await _persist();
  }
}
