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
    'Test all core buttons and navigation flows with authentication',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SignTalkApp());
      await tester.pumpAndSettle();

      expect(find.text('Continue as guest'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue as guest'));
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      // 1. Verify Home screen buttons
      expect(find.text('SignTalk'), findsOneWidget);
      expect(find.text('Sign to Text'), findsWidgets);
      expect(find.text('Speech to Text'), findsWidgets);
      expect(find.text('Start a Conversation'), findsOneWidget);

      // 2. Tap profile button on Home -> navigates to Settings
      await tester.tap(find.text('DU'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Accessibility'), findsOneWidget);

      // 3. Navigate back to Home via bottom nav
      final homeNav = find.text('Home');
      await tester.tap(homeNav);
      await tester.pumpAndSettle();
      expect(find.text('Start a Conversation'), findsOneWidget);

      // 4. Tap "Start a Conversation" -> opens Conversations screen
      await tester.ensureVisible(find.text('Start a Conversation'));
      await tester.tap(find.text('Start a Conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Conversations'), findsWidgets);

      // 5. Test Conversations Back Button -> returns to Home
      final backBtn = find.byTooltip('Back to Home');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      expect(find.text('Start a Conversation'), findsOneWidget);

      // 6. Sign and speech actions open their dedicated working tools.
      await tester.tap(find.text('Sign to Text').first);
      await tester.pumpAndSettle();
      expect(find.text('Sign to Text'), findsOneWidget);

      // 7. Verify the four primary tabs.
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();
      expect(find.text('Your activity will appear here'), findsOneWidget);

      await tester.tap(find.text('Conversations'));
      await tester.pumpAndSettle();
      expect(find.text('Demo contact'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Accessibility'), findsOneWidget);
    },
  );
}
