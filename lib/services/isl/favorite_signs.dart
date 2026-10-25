import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Words the person starred on the Learn page. Stored on this phone only.
class FavoriteSigns extends ChangeNotifier {
  static const _storageKey = 'st_favorite_signs_v1';

  final Set<String> _words = {};
  SharedPreferences? _prefs;

  bool isFavorite(String label) => _words.contains(label.toLowerCase());

  List<String> get words => _words.toList()..sort();

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      _words.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is String && item.trim().isNotEmpty) {
              _words.add(item.toLowerCase());
            }
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FavoriteSigns] Error loading stars: $error');
      }
    }
    notifyListeners();
  }

  Future<void> toggle(String label) async {
    final key = label.trim().toLowerCase();
    if (key.isEmpty) return;
    if (!_words.add(key)) _words.remove(key);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_storageKey, jsonEncode(_words.toList()));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[FavoriteSigns] Error saving stars: $error');
      }
    }
    notifyListeners();
  }
}
