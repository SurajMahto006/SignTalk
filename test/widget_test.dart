import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/app/sign_talk_app.dart';
import 'package:signtalk/services/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
  });

  testWidgets('SignTalk authentication and home load flow', (WidgetTester tester) async {
    await tester.pumpWidget(const SignTalkApp());
    await tester.pumpAndSettle();

    // 1. Initial auth screen is loaded
    expect(find.text('SignTalk'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);

    // 2. Auto-fill demo account and authenticate
    await tester.tap(find.text('Fill Demo Account (@demo_user)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In to SignTalk'));
    await tester.pumpAndSettle();

    // 3. User is authenticated and enters main shell
    expect(find.text('Communication,\nwithout barriers.'), findsOneWidget);
  });
}
