import 'package:flutter_test/flutter_test.dart';

import 'package:signtalk/app/sign_talk_app.dart';

void main() {
  testWidgets('SignTalk home loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SignTalkApp());

    expect(find.text('SignTalk'), findsOneWidget);
    expect(find.text('Communication,\nwithout barriers.'), findsOneWidget);
  });
}
