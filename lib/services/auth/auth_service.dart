import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud_database.dart';
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
  }

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  static const demoUserId = 'demo_user';
  static const demoPassword = 'SignTalk@123';

  static const _keyUsersList = 'st_registered_users_v1';
  static const _keyUserCredentials = 'st_user_credentials_v1';
  static const _keyActiveSessionUserId = 'st_active_session_user_id';

  SharedPreferences? _prefs;
  AuthUser? _currentUser;
  bool _initialized = false;
  int _sessionEpoch = 0;

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
      _upgradePlaintextPasswords();
      _ensureDefaultDemoUser();
      _restoreSession();
      if (_currentUser?.userId == demoUserId) {
        _currentUser = null;
        await _prefs?.remove(_keyActiveSessionUserId);
      }
      if (CloudDatabase.instance.ready) {
        final epoch = _sessionEpoch;
        final online = await CloudDatabase.instance.currentAccount();
        if (_sessionEpoch == epoch &&
            online != null &&
            online.userId != demoUserId &&
            (_currentUser == null || _currentUser!.userId == online.userId)) {
          _usersByUserId[online.userId] = online;
          _currentUser = online;
          await _prefs?.setString(_keyActiveSessionUserId, online.userId);
        }
      }
      await _persistUsers();
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Error loading auth state: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _loadUsersFromStorage() {
    _usersByUserId.clear();
    _passwordsByUserId.clear();
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
    _usersByUserId.putIfAbsent(
      demoUserId,
      () => AuthUser(
        id: 'usr_demo_001',
        userId: demoUserId,
        name: 'Demo User',
        email: 'demo@signtalk.org',
        role: 'ISL Signer & Advocate',
        createdAt: DateTime.now(),
      ),
    );
    _passwordsByUserId[demoUserId] = _hashPassword(demoUserId, demoPassword);

    _usersByUserId.putIfAbsent(
      'demo',
      () => AuthUser(
        id: 'usr_demo_002',
        userId: 'demo',
        name: 'Demo User',
        email: 'demo@signtalk.org',
        role: 'ISL Signer & Advocate',
        createdAt: DateTime.now(),
      ),
    );
    _passwordsByUserId['demo'] = _hashPassword('demo', 'demo');
  }

  void _upgradePlaintextPasswords() {
    for (final entry in _passwordsByUserId.entries.toList()) {
      if (!_isPasswordHash(entry.value)) {
        _passwordsByUserId[entry.key] = _hashPassword(entry.key, entry.value);
      }
    }
  }

  void _restoreSession() {
    final active = _prefs?.getString(_keyActiveSessionUserId)?.toLowerCase();
    _currentUser = active == null ? null : _usersByUserId[active];
  }

  static bool _isPasswordHash(String value) => value.startsWith('sha256:');

  static String _hashPassword(String userId, String password) {
    final digest = sha256.convert(
      utf8.encode('signtalk-account-v1:${userId.toLowerCase()}:$password'),
    );
    return 'sha256:$digest';
  }

  bool _passwordMatches(String userId, String stored, String password) {
    if (_isPasswordHash(stored)) {
      return stored == _hashPassword(userId, password);
    }
    return stored == password;
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

    if (CloudDatabase.instance.ready && cleanedUserId != demoUserId) {
      final cloud = await CloudDatabase.instance.registerAccount(
        userId: cleanedUserId,
        password: password,
        name: trimmedName,
        email: (email ?? '').trim(),
        role: (role ?? 'ISL Communicator').trim(),
      );
      if (!cloud.success || cloud.user == null) {
        if (!cloud.unavailable) {
          return AuthResult(success: false, message: cloud.message);
        }
      } else {
        return _startSession(cloud.user!, password);
      }
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
    _passwordsByUserId[cleanedUserId] = _hashPassword(cleanedUserId, password);
    await _persistUsers();

    // Auto log-in upon successful registration
    return _startSession(newUser, password);
  }

  /// Authenticates using Google Sign-In or creates a new Google-linked profile.
  Future<AuthResult> signInWithGoogle({
    String? email,
    String? name,
    String? role,
    String? photoUrl,
  }) async {
    final googleEmail = (email ?? 'surajmahto01062005@gmail.com').trim().toLowerCase();
    final googleName = (name ?? 'Suraj Mahto').trim();
    final chosenRole = (role ?? 'Normal person').trim();

    // Derive a clean, valid username from email or name
    String baseId = googleEmail.split('@').first.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    if (baseId.length < 3) baseId = 'user_${baseId.padRight(3, '0')}';

    // Check if user with this email or username already exists
    AuthUser? existingUser;
    for (final u in _usersByUserId.values) {
      if (u.email.toLowerCase() == googleEmail || u.userId.toLowerCase() == baseId) {
        existingUser = u;
        break;
      }
    }

    if (existingUser != null) {
      return _startSession(existingUser, 'google_oauth_token');
    }

    // If not existing, create new user
    String userId = baseId;
    int counter = 1;
    while (_usersByUserId.containsKey(userId)) {
      userId = '${baseId}_$counter';
      counter++;
    }

    final newUser = AuthUser(
      id: 'usr_g_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      name: googleName,
      email: googleEmail,
      role: chosenRole,
      createdAt: DateTime.now(),
    );

    return _startSession(newUser, 'google_oauth_token');
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

    if (CloudDatabase.instance.ready && cleanedUserId != demoUserId) {
      final cloud = await CloudDatabase.instance.loginAccount(
        userId: cleanedUserId,
        password: password,
      );
      if (cloud.success && cloud.user != null) {
        return _startSession(cloud.user!, password);
      }
      final stored = _passwordsByUserId[cleanedUserId];
      final localMatches =
          stored != null &&
          _passwordMatches(cleanedUserId, stored, password);
      if (!cloud.unavailable && !localMatches) {
        return AuthResult(success: false, message: cloud.message);
      }
    }

    if (!_usersByUserId.containsKey(cleanedUserId)) {
      return AuthResult(
        success: false,
        message: 'No account found with User ID "@$cleanedUserId". Please register first.',
      );
    }

    final storedPassword = _passwordsByUserId[cleanedUserId];
    if (storedPassword == null ||
        !_passwordMatches(cleanedUserId, storedPassword, password)) {
      return const AuthResult(
        success: false,
        message: 'Incorrect password. Please try again.',
      );
    }
    if (!_isPasswordHash(storedPassword)) {
      _passwordsByUserId[cleanedUserId] = _hashPassword(
        cleanedUserId,
        password,
      );
      await _persistUsers();
    }

    return _startSession(_usersByUserId[cleanedUserId]!, password);
  }

  Future<AuthResult> _startSession(AuthUser user, String password) async {
    _sessionEpoch++;
    final cleanedUserId = user.userId.toLowerCase();
    _usersByUserId[cleanedUserId] = user;
    _passwordsByUserId[cleanedUserId] = _hashPassword(cleanedUserId, password);
    _currentUser = user;
    await _persistUsers();
    await _prefs?.setString(_keyActiveSessionUserId, cleanedUserId);
    notifyListeners();
    return AuthResult(
      success: true,
      message: 'Welcome, ${user.name}!',
      user: user,
    );
  }

  Future<AuthResult> updateName(String name) async {
    final user = _currentUser;
    if (user == null) {
      return const AuthResult(
        success: false,
        message: 'Sign in before changing your name.',
      );
    }
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Please enter your name.',
      );
    }
    if (trimmed.length > 40) {
      return const AuthResult(
        success: false,
        message: 'Use a shorter name.',
      );
    }
    final updated = user.copyWith(name: trimmed);
    _usersByUserId[user.userId.toLowerCase()] = updated;
    _currentUser = updated;
    await _persistUsers();
    notifyListeners();
    unawaited(
      CloudDatabase.instance.saveProfile(
        userId: updated.userId,
        name: updated.name,
        email: updated.email,
        role: updated.role,
      ),
    );
    return AuthResult(
      success: true,
      message: 'Name updated.',
      user: updated,
    );
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return const AuthResult(
        success: false,
        message: 'Sign in before changing your password.',
      );
    }
    if (user.userId.toLowerCase() == demoUserId ||
        user.userId.toLowerCase() == 'demo') {
      return const AuthResult(
        success: false,
        message: 'The guest account keeps the password demo.',
      );
    }
    final stored = _passwordsByUserId[user.userId.toLowerCase()];
    if (stored == null ||
        !_passwordMatches(user.userId, stored, currentPassword)) {
      return const AuthResult(
        success: false,
        message: 'Current password is incorrect.',
      );
    }
    if (newPassword.length < 6) {
      return const AuthResult(
        success: false,
        message: 'Password must be at least 6 characters long.',
      );
    }
    if (newPassword == currentPassword) {
      return const AuthResult(
        success: false,
        message: 'Choose a different password.',
      );
    }
    if (CloudDatabase.instance.ready) {
      final cloudError = await CloudDatabase.instance.updatePassword(
        newPassword,
      );
      if (cloudError != null) {
        return AuthResult(success: false, message: cloudError);
      }
    }
    _passwordsByUserId[user.userId.toLowerCase()] = _hashPassword(
      user.userId,
      newPassword,
    );
    await _persistUsers();
    notifyListeners();
    return const AuthResult(success: true, message: 'Password updated.');
  }

  /// Ends the active user session and returns to login gate.
  Future<void> logout() async {
    _sessionEpoch++;
    _currentUser = null;
    await _prefs?.remove(_keyActiveSessionUserId);
    notifyListeners();
    unawaited(CloudDatabase.instance.signOut());
  }
}
