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
  });

  final ActivityLogType type;
  final String contactName;
  final String title;
  final String preview;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'type': type.name,
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

  Future<void> addChat({required String contactName, required String preview}) {
    return _add(
      ActivityLogEntry(
        type: ActivityLogType.chat,
        contactName: contactName,
        title: 'Chat conversation',
        preview: preview,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> addCall({required String contactName, required String roomId}) {
    return _add(
      ActivityLogEntry(
        type: ActivityLogType.call,
        contactName: contactName,
        title: 'Video call',
        preview: 'Room: $roomId',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> clear() async {
    _entries.clear();
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
