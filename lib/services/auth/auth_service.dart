import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_user.dart';

class AuthResult {
  const AuthResult({required this.success, this.message, this.user});

  final bool success;
  final String? message;
  final AuthUser? user;
}

/// Service managing user registration with unique User IDs, login authentication, and sessions.
class AuthService extends ChangeNotifier {
  AuthService._() {
    _ensureDefaultDemoUser();
    _currentUser = _usersByUserId[demoUserId];
  }

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  static const demoUserId = 'demo';
  static const demoPassword = 'demo';

  static const _keyUsersList = 'st_registered_users_v1';
  static const _keyUserCredentials = 'st_user_credentials_v1';
  static const _keyActiveSessionUserId = 'st_active_session_user_id';

  SharedPreferences? _prefs;
  AuthUser? _currentUser;
  bool _initialized = false;

  final Map<String, AuthUser> _usersByUserId = {};
  final Map<String, String> _passwordsByUserId = {};

  bool get isInitialized => _initialized;
  bool get isAuthenticated => _currentUser != null;
  AuthUser? get currentUser => _currentUser;

  Future<void> load() async {
    _ensureDefaultDemoUser();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _loadUsersFromStorage();
      _ensureDefaultDemoUser();

      await _persistUsers();
      final activeUserId = _prefs?.getString(_keyActiveSessionUserId)?.toLowerCase();
      if (activeUserId != null && _usersByUserId.containsKey(activeUserId)) {
        _currentUser = _usersByUserId[activeUserId];
      } else {
        _currentUser = _usersByUserId[demoUserId];
        await _prefs?.setString(_keyActiveSessionUserId, demoUserId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Error loading auth state: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _loadUsersFromStorage() {
    final rawUsers = _prefs?.getString(_keyUsersList);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUsers) as List<dynamic>;
        for (final item in decoded) {
          final user = AuthUser.fromMap(item as Map<String, dynamic>);
          _usersByUserId[user.userId.toLowerCase()] = user;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] Error parsing stored users: $e');
      }
    }

    final rawCreds = _prefs?.getString(_keyUserCredentials);
    if (rawCreds != null && rawCreds.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCreds) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _passwordsByUserId[entry.key.toLowerCase()] = entry.value.toString();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] Error parsing stored credentials: $e');
      }
    }
  }

  void _ensureDefaultDemoUser() {
    _usersByUserId[demoUserId] = AuthUser(
      id: 'usr_demo_001',
      userId: demoUserId,
      name: 'Demo User',
      email: 'demo@signtalk.org',
      role: 'ISL Signer & Advocate',
      createdAt: _usersByUserId[demoUserId]?.createdAt ?? DateTime.now(),
    );
    _passwordsByUserId[demoUserId] = demoPassword;
  }

  Future<void> _persistUsers() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final usersJson = jsonEncode(
        _usersByUserId.values.map((u) => u.toMap()).toList(),
      );
      await _prefs?.setString(_keyUsersList, usersJson);

      final credsJson = jsonEncode(_passwordsByUserId);
      await _prefs?.setString(_keyUserCredentials, credsJson);
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Error persisting users: $e');
    }
  }

  /// Checks whether a given User ID is available for registration (case-insensitive).
  bool isUserIdAvailable(String userId) {
    final cleaned = userId.trim().toLowerCase();
    if (cleaned.isEmpty) return false;
    return !_usersByUserId.containsKey(cleaned);
  }

  /// Registers a new user enforcing a strictly unique User ID.
  Future<AuthResult> register({
    required String userId,
    required String name,
    required String password,
    String? email,
    String? role,
  }) async {
    final cleanedUserId = userId.trim().toLowerCase();
    final trimmedName = name.trim();

    if (cleanedUserId.length < 3) {
      return const AuthResult(
        success: false,
        message: 'User ID must be at least 3 characters long.',
      );
    }

    // Disallow special characters that break URL/usernames
    final validIdRegex = RegExp(r'^[a-z0-9_.]+$');
    if (!validIdRegex.hasMatch(cleanedUserId)) {
      return const AuthResult(
        success: false,
        message: 'User ID can only contain letters, numbers, underscores (_), and dots (.).',
      );
    }

    if (!isUserIdAvailable(cleanedUserId)) {
      return AuthResult(
        success: false,
        message: 'User ID "@$cleanedUserId" is already taken. Please choose a unique User ID.',
      );
    }

    if (trimmedName.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter your full name.',
      );
    }

    if (password.length < 6) {
      return const AuthResult(
        success: false,
        message: 'Password must be at least 6 characters long.',
      );
    }

    final newUser = AuthUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      userId: cleanedUserId,
      name: trimmedName,
      email: (email ?? '').trim(),
      role: (role ?? 'ISL Communicator').trim(),
      createdAt: DateTime.now(),
    );

    _usersByUserId[cleanedUserId] = newUser;
    _passwordsByUserId[cleanedUserId] = password;
    await _persistUsers();

    // Auto log-in upon successful registration
    _currentUser = newUser;
    await _prefs?.setString(_keyActiveSessionUserId, cleanedUserId);
    notifyListeners();

    return AuthResult(
      success: true,
      message: 'Account created successfully with unique ID @$cleanedUserId!',
      user: newUser,
    );
  }

  /// Authenticates an existing user via their unique User ID and password.
  Future<AuthResult> login({
    required String userId,
    required String password,
  }) async {
    final cleanedUserId = userId.trim().toLowerCase();

    if (cleanedUserId.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter your User ID.',
      );
    }

    if (!_usersByUserId.containsKey(cleanedUserId)) {
      return AuthResult(
        success: false,
        message: 'No account found with User ID "@$cleanedUserId". Please register first.',
      );
    }

    final storedPassword = _passwordsByUserId[cleanedUserId];
    if (storedPassword != password) {
      return const AuthResult(
        success: false,
        message: 'Incorrect password. Please try again.',
      );
    }

    final user = _usersByUserId[cleanedUserId]!;
    _currentUser = user;
    await _prefs?.setString(_keyActiveSessionUserId, cleanedUserId);
    notifyListeners();

    return AuthResult(
      success: true,
      message: 'Welcome back, ${user.name}!',
      user: user,
    );
  }

  /// Ends the active user session and returns to login gate.
  Future<void> logout() async {
    _currentUser = null;
    await _prefs?.remove(_keyActiveSessionUserId);
    notifyListeners();
  }
}
