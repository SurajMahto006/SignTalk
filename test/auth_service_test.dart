import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
  });

  group('AuthService Unique User ID & Authentication Tests', () {
    test('Initializes with default demo_user account', () {
      final auth = AuthService.instance;
      expect(auth.isUserIdAvailable('demo'), isFalse);
      expect(auth.isUserIdAvailable('new_unique_user'), isTrue);
    });

    test('Registers new user with unique User ID successfully', () async {
      final auth = AuthService.instance;

      final result = await auth.register(
        userId: 'suraj006',
        name: 'Suraj Mahto',
        password: 'Password123',
        role: 'ISL Signer',
      );

      expect(result.success, isTrue);
      expect(result.user?.userId, 'suraj006');
      expect(result.user?.name, 'Suraj Mahto');
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.userId, 'suraj006');

      // Now suraj006 is taken!
      expect(auth.isUserIdAvailable('suraj006'), isFalse);
    });

    test('Rejects duplicate User ID during registration (case-insensitive)', () async {
      final auth = AuthService.instance;

      final result = await auth.register(
        userId: 'DEMO',
        name: 'Imposter',
        password: 'Password123',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('already taken'));
      expect(result.message, contains('unique User ID'));
    });

    test('Enforces User ID format constraints (minimum 3 characters, valid characters)', () async {
      final auth = AuthService.instance;

      final shortResult = await auth.register(
        userId: 'ab',
        name: 'Short',
        password: 'Password123',
      );
      expect(shortResult.success, isFalse);
      expect(shortResult.message, contains('at least 3 characters'));

      final invalidResult = await auth.register(
        userId: 'user@name!',
        name: 'Invalid',
        password: 'Password123',
      );
      expect(invalidResult.success, isFalse);
      expect(invalidResult.message, contains('letters, numbers, underscores'));
    });

    test('Authenticates registered user and rejects bad password', () async {
      final auth = AuthService.instance;

      // Correct login
      final okLogin = await auth.login(
        userId: 'demo',
        password: 'demo',
      );
      expect(okLogin.success, isTrue);
      expect(auth.isAuthenticated, isTrue);

      // Logout
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);

      // Wrong password
      final badLogin = await auth.login(
        userId: 'demo',
        password: 'WrongPassword',
      );
      expect(badLogin.success, isFalse);
      expect(badLogin.message, contains('Incorrect password'));
      expect(auth.isAuthenticated, isFalse);
    });

    test('opens on sign in instead of restoring the guest demo', () async {
      final auth = AuthService.instance;
      final guest = await auth.login(userId: 'demo', password: 'demo');
      expect(guest.success, isTrue);
      expect(auth.currentUser?.userId, 'demo');

      await auth.load();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('keeps a signed-in account after reload and does not store the password', () async {
      final auth = AuthService.instance;
      final registered = await auth.register(
        userId: 'sessionuser',
        name: 'Suraj Mahto',
        password: 'Password123',
      );
      expect(registered.success, isTrue, reason: registered.message);

      await auth.load();
      expect(auth.currentUser?.userId, 'sessionuser');

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('st_user_credentials_v1') ?? '';
      expect(stored, isNot(contains('Password123')));
      expect(stored, contains('sha256:'));

      await auth.logout();
      await auth.load();
      expect(auth.isAuthenticated, isFalse);

      final again = await auth.login(
        userId: 'sessionuser',
        password: 'Password123',
      );
      expect(again.success, isTrue);
    });
  });
}
