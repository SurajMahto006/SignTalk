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

    expect(find.text('Communication,\nwithout barriers.'), findsOneWidget);
  });
}
