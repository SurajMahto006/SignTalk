import 'package:flutter/material.dart';
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

  testWidgets(
    'Contacts flow: Open from Home, view saved contacts, accept request, and start conversation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SignTalkApp());
      await tester.pumpAndSettle();

      // Sign in with demo account
      await tester.tap(find.text('Fill Demo Account (@demo_user)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In to SignTalk'));
      await tester.pumpAndSettle();

      // 1. Verify Quick Action "Contacts" is visible on Home
      expect(find.text('Contacts'), findsWidgets);
      await tester.ensureVisible(find.text('Contacts').first);
      await tester.tap(find.text('Contacts').first);
      await tester.pumpAndSettle();

      // 2. Contacts Screen opened
      expect(find.text('Saved Contacts'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);

      // 3. Switch to Requests tab
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Incoming Requests (1)'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsOneWidget);

      // 4. Accept the incoming request
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      // 5. Switch back to Saved Contacts tab
      await tester.tap(find.text('Saved Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Vikram Singh'), findsOneWidget);

      // 6. Tap on a saved contact to open conversation
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // 7. Verify Conversation screen opens with Aarav Sharma
      expect(find.text('Aarav Sharma'), findsWidgets);
      expect(find.byTooltip('Back to Home'), findsOneWidget);
    },
  );
}
