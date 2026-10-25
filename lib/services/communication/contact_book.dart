import 'dart:convert';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud_database.dart';

/// People each account can message. Stored on this phone only.
class ContactBook extends ChangeNotifier {
  static const defaultContact = 'Demo contact';
  static const _storageKey = 'st_contacts_v1';

  final Map<String, List<String>> _byOwner = {};
  SharedPreferences? _prefs;

  List<String> contactsFor(String ownerId) {
    final owner = ownerId.trim().toLowerCase();
    if (!_byOwner.containsKey(owner)) return const [defaultContact];
    return List.unmodifiable(_byOwner[owner]!);
  }

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      _byOwner.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final names = entry.value;
            if (names is! List) continue;
            _byOwner[entry.key.toString()] = [
              for (final name in names)
                if (name is String && name.trim().isNotEmpty) name.trim(),
            ];
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactBook] Error loading contacts: $error');
      }
    }
    notifyListeners();
  }

  /// Adds [name] for [ownerId]. Returns an error message, or null on success.
  Future<String?> add({
    required String ownerId,
    required String name,
  }) async {
    final cleaned = _clean(name);
    final error = _validate(cleaned);
    if (error != null) return error;

    final owner = ownerId.trim().toLowerCase();
    final list = List<String>.from(contactsFor(owner));
    if (list.any((item) => item.toLowerCase() == cleaned.toLowerCase())) {
      return 'That contact is already in your list.';
    }
    list.add(cleaned);
    _byOwner[owner] = list;
    await _persist();
    notifyListeners();
    unawaited(
      CloudDatabase.instance.saveContact(userId: owner, name: cleaned),
    );
    return null;
  }

  Future<void> ensure({
    required String ownerId,
    required String name,
  }) async {
    final cleaned = _clean(name);
    if (_validate(cleaned) != null) return;
    final owner = ownerId.trim().toLowerCase();
    final list = List<String>.from(contactsFor(owner));
    if (list.any((item) => item.toLowerCase() == cleaned.toLowerCase())) {
      return;
    }
    list.add(cleaned);
    _byOwner[owner] = list;
    await _persist();
    notifyListeners();
  }

  static List<String> matching(List<String> names, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return List<String>.from(names);
    return [
      for (final name in names)
        if (name.toLowerCase().contains(needle)) name,
    ];
  }

  Future<String?> rename({
    required String ownerId,
    required String fromName,
    required String toName,
  }) async {
    final cleaned = _clean(toName);
    final error = _validate(cleaned);
    if (error != null) return error;
    final owner = ownerId.trim().toLowerCase();
    final list = List<String>.from(
      _byOwner[owner] ?? const [defaultContact],
    );
    final index = list.indexWhere(
      (item) => item.toLowerCase() == _clean(fromName).toLowerCase(),
    );
    if (index < 0) return 'That contact is not in your list.';
    final taken = list.indexWhere(
      (item) => item.toLowerCase() == cleaned.toLowerCase(),
    );
    if (taken >= 0 && taken != index) {
      return 'That contact is already in your list.';
    }
    list[index] = cleaned;
    _byOwner[owner] = list;
    await _persist();
    notifyListeners();
    unawaited(
      CloudDatabase.instance.renameContact(
        userId: owner,
        fromName: fromName,
        toName: cleaned,
      ),
    );
    return null;
  }

  Future<bool> remove({
    required String ownerId,
    required String name,
  }) async {
    final owner = ownerId.trim().toLowerCase();
    final cleaned = _clean(name);
    final list = List<String>.from(
      _byOwner[owner] ?? const [defaultContact],
    );
    final removed = list
        .where((item) => item.toLowerCase() == cleaned.toLowerCase())
        .length;
    if (removed == 0) return false;
    list.removeWhere((item) => item.toLowerCase() == cleaned.toLowerCase());
    _byOwner[owner] = list;
    await _persist();
    notifyListeners();
    unawaited(
      CloudDatabase.instance.deleteContact(userId: owner, name: cleaned),
    );
    return true;
  }

  static String _clean(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _validate(String name) {
    if (name.isEmpty) return 'Enter a name.';
    if (name.length > 40) return 'Use a shorter name.';
    final valid = RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .'-]*$");
    if (!valid.hasMatch(name)) {
      return 'Use letters, numbers, spaces, apostrophes, or dots.';
    }
    return null;
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_storageKey, jsonEncode(_byOwner));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ContactBook] Error saving contacts: $error');
      }
    }
  }
}
