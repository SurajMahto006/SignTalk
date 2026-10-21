import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud_database.dart';

class StoredChatMessage {
  const StoredChatMessage({
    required this.kind,
    required this.body,
    required this.createdAt,
    this.cloudId,
  });

  final String kind;
  final String body;
  final DateTime createdAt;
  final String? cloudId;

  Map<String, Object> toJson() => {
    'kind': kind,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    if (cloudId != null) 'cloudId': cloudId!,
  };

  factory StoredChatMessage.fromJson(Map<String, dynamic> json) {
    return StoredChatMessage(
      kind: json['kind'] as String? ?? 'typed',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      cloudId: json['cloudId'] as String?,
    );
  }
}

/// Saves each contact's chat on this device. Messages stay after leaving the screen.
class ConversationStore extends ChangeNotifier {
  static const _storageKey = 'st_conversation_messages_v1';
  static const _maxPerContact = 200;

  final Map<String, List<StoredChatMessage>> _byContact = {};
  SharedPreferences? _prefs;
  bool isLoaded = false;

  static String threadKey(String ownerId, String contactName) {
    return '${ownerId.trim().toLowerCase()}::$contactName';
  }

  List<StoredChatMessage> messagesFor({
    required String ownerId,
    required String contactName,
  }) {
    return List.unmodifiable(
      _byContact[threadKey(ownerId, contactName)] ?? const [],
    );
  }

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      _byContact.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final items = entry.value;
            if (items is! List) continue;
            final rawKey = entry.key.toString();
            final key = rawKey.contains('::') ? rawKey : 'demo::$rawKey';
            _byContact[key] = [
              for (final item in items)
                if (item is Map)
                  StoredChatMessage.fromJson(Map<String, dynamic>.from(item)),
            ];
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ConversationStore] Error loading messages: $error');
      }
    }
    isLoaded = true;
    notifyListeners();
  }

  Future<void> append({
    required String ownerId,
    required String contactName,
    required String kind,
    required String body,
    required DateTime createdAt,
  }) async {
    final list = _byContact.putIfAbsent(
      threadKey(ownerId, contactName),
      () => [],
    );
    list.add(
      StoredChatMessage(kind: kind, body: body, createdAt: createdAt),
    );
    if (list.length > _maxPerContact) {
      list.removeRange(0, list.length - _maxPerContact);
    }
    await _persist();
    notifyListeners();
    final owner = ownerId.trim().toLowerCase();
    final cloudId = await CloudDatabase.instance.saveMessage(
      userId: owner,
      contactName: contactName,
      kind: kind,
      body: body,
      createdAt: createdAt,
    );
    if (cloudId != null && list.isNotEmpty) {
      final saved = list.last;
      list[list.length - 1] = StoredChatMessage(
        kind: saved.kind,
        body: saved.body,
        createdAt: saved.createdAt,
        cloudId: cloudId,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> renameContact({
    required String ownerId,
    required String fromName,
    required String toName,
  }) async {
    final fromKey = threadKey(ownerId, fromName);
    final toKey = threadKey(ownerId, toName);
    if (fromKey == toKey) return;
    unawaited(
      CloudDatabase.instance.renameContact(
        userId: ownerId,
        fromName: fromName,
        toName: toName,
      ),
    );
    final moving = _byContact.remove(fromKey);
    if (moving == null) return;
    final existing = _byContact[toKey];
    if (existing == null) {
      _byContact[toKey] = moving;
    } else {
      existing.addAll(moving);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeMessage({
    required String ownerId,
    required String contactName,
    required int index,
  }) async {
    final list = _byContact[threadKey(ownerId, contactName)];
    if (list == null || index < 0 || index >= list.length) return;
    final cloudId = list[index].cloudId;
    list.removeAt(index);
    if (cloudId != null) {
      unawaited(
        CloudDatabase.instance.deleteMessage(
          userId: ownerId,
          contactName: contactName,
          cloudId: cloudId,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clearContact({
    required String ownerId,
    required String contactName,
  }) async {
    _byContact.remove(threadKey(ownerId, contactName));
    unawaited(
      CloudDatabase.instance.deleteContact(
        userId: ownerId,
        name: contactName,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final encoded = {
        for (final entry in _byContact.entries)
          entry.key: entry.value.map((message) => message.toJson()).toList(),
      };
      await _prefs!.setString(_storageKey, jsonEncode(encoded));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ConversationStore] Error saving messages: $error');
      }
    }
  }
}
