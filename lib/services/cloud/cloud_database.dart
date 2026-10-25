import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_user.dart';
import 'firebase_config.dart';

class CloudSignIn {
  const CloudSignIn({
    required this.success,
    this.message,
    this.user,
    this.unavailable = false,
  });

  final bool success;
  final String? message;
  final AuthUser? user;

  /// The database could not be used. The phone copy can still sign the person in.
  final bool unavailable;
}

/// Accounts, contacts, and chats in Cloud Firestore.
///
/// The phone copy still works when Firebase keys are missing. The guest
/// account is never uploaded.
class CloudDatabase extends ChangeNotifier {
  CloudDatabase._();

  static final CloudDatabase instance = CloudDatabase._();

  bool ready = false;
  String? lastError;

  String get statusLabel {
    if (ready) return 'Connected';
    return 'Not connected';
  }

  Future<void> start() async {
    if (!FirebaseConfig.isConfigured) {
      ready = false;
      notifyListeners();
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseConfig.options);
      }
      ready = true;
      lastError = null;
    } catch (error) {
      ready = false;
      lastError = error.toString();
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Firebase did not start: $error');
      }
    }
    notifyListeners();
  }

  bool _canSync(String userId) =>
      ready && userId.trim().toLowerCase() != FirebaseConfig.guestUserId;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId.trim().toLowerCase());
  }

  Future<CloudSignIn> registerAccount({
    required String userId,
    required String password,
    required String name,
    required String email,
    required String role,
  }) async {
    if (!_canSync(userId)) {
      return const CloudSignIn(
        success: false,
        message: 'Cloud sign-in is not available for this account.',
      );
    }
    final cleaned = userId.trim().toLowerCase();
    final createdAt = DateTime.now().toIso8601String();
    final profile = {
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt,
    };
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: FirebaseConfig.emailForUserId(cleaned),
        password: password,
      );
      try {
        await _saveUserDoc(cleaned, profile);
      } catch (error) {
        lastError = error.toString();
        if (kDebugMode) {
          debugPrint('[CloudDatabase] Profile save failed: $error');
        }
      }
      notifyListeners();
      return CloudSignIn(success: true, user: _accountFromMap(cleaned, profile));
    } on FirebaseAuthException catch (error) {
      return _failedSignIn(error, userId: cleaned);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return const CloudSignIn(
        success: false,
        unavailable: true,
        message: 'Could not save this account online. It will stay on this phone.',
      );
    }
  }

  Future<CloudSignIn> loginAccount({
    required String userId,
    required String password,
  }) async {
    if (!_canSync(userId)) {
      return const CloudSignIn(
        success: false,
        message: 'Cloud sign-in is not available for this account.',
      );
    }
    final cleaned = userId.trim().toLowerCase();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: FirebaseConfig.emailForUserId(cleaned),
        password: password,
      );
      Map<String, dynamic>? data;
      try {
        final doc = await _userDoc(cleaned).get();
        data = doc.data();
        if (!doc.exists || data == null) {
          data = {
            'name': cleaned,
            'email': '',
            'role': 'ISL Communicator',
            'createdAt': DateTime.now().toIso8601String(),
          };
          await _saveUserDoc(cleaned, data);
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[CloudDatabase] Profile read failed: $error');
        }
        data = {
          'name': cleaned,
          'email': '',
          'role': 'ISL Communicator',
        };
      }
      lastError = null;
      notifyListeners();
      return CloudSignIn(
        success: true,
        user: _accountFromMap(cleaned, data),
      );
    } on FirebaseAuthException catch (error) {
      return _failedSignIn(error, userId: cleaned);
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      return const CloudSignIn(
        success: false,
        unavailable: true,
        message: 'Could not reach the database. Check your connection and try again.',
      );
    }
  }

  Future<AuthUser?> currentAccount() async {
    if (!ready) return null;
    final signedIn = FirebaseAuth.instance.currentUser;
    final email = signedIn?.email;
    if (email == null || !email.endsWith('@signtalk.app')) return null;
    final userId = email.split('@').first;
    if (userId == FirebaseConfig.guestUserId) return null;
    try {
      final doc = await _userDoc(userId).get();
      return _accountFromMap(userId, doc.data());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Could not load the signed-in account: $error');
      }
      return null;
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    if (!ready) return null;
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (error) {
      return error.message ?? 'Could not update the password.';
    } catch (_) {
      return 'Could not update the password.';
    }
  }

  Future<void> _saveUserDoc(String userId, Map<String, dynamic> profile) async {
    await _userDoc(userId).set({
      'userId': userId,
      ...profile,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  CloudSignIn _failedSignIn(FirebaseAuthException error, {required String userId}) {
    final unavailable = _cloudUnavailable(error.code);
    if (unavailable) {
      ready = false;
      lastError = error.code;
      notifyListeners();
    }
    return CloudSignIn(
      success: false,
      unavailable: unavailable,
      message: _friendlyAuthMessage(error, userId: userId),
    );
  }

  bool _cloudUnavailable(String code) {
    return code.contains('api-key') ||
        code == 'app-not-authorized' ||
        code == 'operation-not-allowed' ||
        code == 'unauthorized-domain' ||
        code == 'network-request-failed';
  }

  String _friendlyAuthMessage(FirebaseAuthException error, {required String userId}) {
    final code = error.code;
    if (code.contains('api-key') || code == 'app-not-authorized') {
      return 'Online accounts are not available right now. This account stays on this phone.';
    }
    return switch (code) {
      'email-already-in-use' =>
        'User ID "@$userId" is already taken. Please choose another one.',
      'invalid-credential' || 'user-not-found' || 'wrong-password' =>
        'That User ID and password do not match. Try again, or create an account.',
      'operation-not-allowed' || 'unauthorized-domain' =>
        'Online sign-in is not available on this site yet. You can continue as guest, or create an account on this phone.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' =>
        'Too many tries. Wait a minute and try again.',
      'weak-password' => 'Use a password of at least 6 characters.',
      _ => 'Could not sign in just now. You can continue as guest.',
    };
  }

  AuthUser _accountFromMap(String userId, Map<String, dynamic>? data) {
    return AuthUser(
      id: 'usr_$userId',
      userId: userId,
      name: data?['name'] as String? ?? userId,
      email: data?['email'] as String? ?? '',
      role: data?['role'] as String? ?? 'ISL Communicator',
      createdAt:
          DateTime.tryParse(data?['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  CollectionReference<Map<String, dynamic>> _contacts(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId.trim().toLowerCase())
        .collection('contacts');
  }

  Future<void> signInAccount({
    required String userId,
    required String password,
    required String name,
    required String email,
    required String role,
  }) async {
    if (!_canSync(userId)) return;
    final accountEmail = FirebaseConfig.emailForUserId(userId);
    try {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: accountEmail,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        final missing =
            error.code == 'user-not-found' || error.code == 'invalid-credential';
        if (!missing) rethrow;
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: accountEmail,
          password: password,
        );
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId.trim().toLowerCase())
          .set({
            'userId': userId.trim().toLowerCase(),
            'name': name,
            'email': email,
            'role': role,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      lastError = null;
    } catch (error) {
      lastError = error.toString();
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Account sync failed: $error');
      }
    }
    notifyListeners();
  }

  Future<void> saveProfile({
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    if (!_canSync(userId)) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId.trim().toLowerCase())
          .set({
            'userId': userId.trim().toLowerCase(),
            'name': name,
            'email': email,
            'role': role,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Profile save failed: $error');
      }
    }
  }

  Future<void> signOut() async {
    if (!ready) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Sign out failed: $error');
      }
    }
  }

  Future<void> saveContact({
    required String userId,
    required String name,
  }) async {
    if (!_canSync(userId)) return;
    try {
      await _contacts(userId).doc(FirebaseConfig.documentId(name)).set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Contact save failed: $error');
      }
    }
  }

  Future<void> renameContact({
    required String userId,
    required String fromName,
    required String toName,
  }) async {
    if (!_canSync(userId)) return;
    try {
      final from = _contacts(userId).doc(FirebaseConfig.documentId(fromName));
      final to = _contacts(userId).doc(FirebaseConfig.documentId(toName));
      final messages = await from.collection('messages').get();
      for (final message in messages.docs) {
        await to.collection('messages').doc(message.id).set(message.data());
        await message.reference.delete();
      }
      await to.set({
        'name': toName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await from.delete();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Contact rename failed: $error');
      }
    }
  }

  Future<void> deleteContact({
    required String userId,
    required String name,
  }) async {
    if (!_canSync(userId)) return;
    try {
      final contact = _contacts(userId).doc(FirebaseConfig.documentId(name));
      final messages = await contact.collection('messages').get();
      for (final message in messages.docs) {
        await message.reference.delete();
      }
      await contact.delete();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Contact delete failed: $error');
      }
    }
  }

  Future<String?> saveMessage({
    required String userId,
    required String contactName,
    required String kind,
    required String body,
    required DateTime createdAt,
  }) async {
    if (!_canSync(userId)) return null;
    try {
      final contact = _contacts(userId).doc(
        FirebaseConfig.documentId(contactName),
      );
      await contact.set({
        'name': contactName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final saved = await contact.collection('messages').add({
        'kind': kind,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      });
      return saved.id;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Message save failed: $error');
      }
      return null;
    }
  }

  Future<void> deleteMessage({
    required String userId,
    required String contactName,
    required String cloudId,
  }) async {
    if (!_canSync(userId) || cloudId.isEmpty) return;
    try {
      await _contacts(userId)
          .doc(FirebaseConfig.documentId(contactName))
          .collection('messages')
          .doc(cloudId)
          .delete();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudDatabase] Message delete failed: $error');
      }
    }
  }
}
