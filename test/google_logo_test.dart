import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/screens/auth/auth_screen.dart';
import 'package:signtalk/services/auth/auth_service.dart';
import 'package:signtalk/widgets/google_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
  });

  testWidgets('auth screen shows the Google logo on sign-in and register', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    // The Google button must not use the old plain "G" text glyph.
    expect(find.text('G'), findsNothing);

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.text('Register with Google'), findsOneWidget);
  });
}
