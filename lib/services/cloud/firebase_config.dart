import 'package:firebase_core/firebase_core.dart';

import 'firebase_keys.dart';

/// Reads keys from [FirebaseKeys]. A dart-define value overrides the file.
class FirebaseConfig {
  static const guestUserId = 'demo';

  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: FirebaseKeys.apiKey,
  );
  static const appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: FirebaseKeys.appId,
  );
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: FirebaseKeys.messagingSenderId,
  );
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: FirebaseKeys.projectId,
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: FirebaseKeys.authDomain,
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: FirebaseKeys.storageBucket,
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );

  static String emailForUserId(String userId) =>
      '${userId.trim().toLowerCase()}@signtalk.app';

  static String documentId(String name) =>
      name.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), ' ');
}
