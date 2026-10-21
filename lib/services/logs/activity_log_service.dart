import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivityLogType { chat, call }

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.type,
    required this.contactName,
    required this.title,
    required this.preview,
    required this.createdAt,
    this.ownerId = 'demo',
  });

  final ActivityLogType type;
  final String ownerId;
  final String contactName;
  final String title;
  final String preview;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'type': type.name,
    'ownerId': ownerId,
    'contactName': contactName,
    'title': title,
    'preview': preview,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      type: ActivityLogType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => ActivityLogType.chat,
      ),
      ownerId: (json['ownerId'] as String?)?.toLowerCase() ?? 'demo',
      contactName: json['contactName'] as String? ?? 'Unknown contact',
      title: json['title'] as String? ?? 'Conversation',
      preview: json['preview'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ActivityLogService extends ChangeNotifier {
  static const _storageKey = 'st_activity_logs';

  final List<ActivityLogEntry> _entries = [];
  SharedPreferences? _prefs;

  List<ActivityLogEntry> get entries => List.unmodifiable(_entries);

  List<ActivityLogEntry> entriesFor(String ownerId) {
    final owner = ownerId.trim().toLowerCase();
    return List.unmodifiable(
      _entries.where((entry) => entry.ownerId == owner),
    );
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getStringList(_storageKey) ?? [];
      _entries
        ..clear()
        ..addAll(
          raw.map(
            (item) => ActivityLogEntry.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          ),
        );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ActivityLogService] Error loading logs: $error');
      }
    }
    notifyListeners();
  }

  Future<void> addChat({
    required String ownerId,
    required String contactName,
    required String preview,
  }) {
    return _add(
      ActivityLogEntry(
        type: ActivityLogType.chat,
        ownerId: ownerId.trim().toLowerCase(),
        contactName: contactName,
        title: 'Chat conversation',
        preview: preview,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> addCall({
    required String ownerId,
    required String contactName,
    required String roomId,
  }) {
    return _add(
      ActivityLogEntry(
        type: ActivityLogType.call,
        ownerId: ownerId.trim().toLowerCase(),
        contactName: contactName,
        title: 'Video call',
        preview: 'Room: $roomId',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> renameContact({
    required String ownerId,
    required String fromName,
    required String toName,
  }) async {
    final owner = ownerId.trim().toLowerCase();
    final from = fromName.trim().toLowerCase();
    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.ownerId == owner &&
          entry.contactName.toLowerCase() == from) {
        _entries[i] = ActivityLogEntry(
          type: entry.type,
          ownerId: entry.ownerId,
          contactName: toName.trim(),
          title: entry.title,
          preview: entry.preview,
          createdAt: entry.createdAt,
        );
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> clearOwner(String ownerId) async {
    final owner = ownerId.trim().toLowerCase();
    _entries.removeWhere((entry) => entry.ownerId == owner);
    await _persist();
    notifyListeners();
  }

  Future<void> _add(ActivityLogEntry entry) async {
    _entries.insert(0, entry);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setStringList(
        _storageKey,
        _entries.map((entry) => jsonEncode(entry.toJson())).toList(),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ActivityLogService] Error saving logs: $error');
      }
    }
  }
}
