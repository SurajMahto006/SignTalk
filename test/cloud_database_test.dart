import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/cloud/cloud_database.dart';
import 'package:signtalk/services/cloud/firebase_config.dart';

void main() {
  test('ships with Firebase keys and stays offline until the app starts', () {
    expect(FirebaseConfig.isConfigured, isTrue);
    expect(CloudDatabase.instance.ready, isFalse);
    expect(CloudDatabase.instance.statusLabel, 'Not connected');
  });

  test('builds the account email from the user id', () {
    expect(FirebaseConfig.emailForUserId('Suraj006'), 'suraj006@signtalk.app');
    expect(FirebaseConfig.documentId('Asha / K'), 'Asha - K');
  });
}
