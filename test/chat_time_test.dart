import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/communication/chat_time.dart';

void main() {
  final now = DateTime(2026, 10, 20, 21, 30);

  test('labels today, yesterday, and an older day', () {
    expect(chatDayLabel(now, now), 'Today');
    expect(
      chatDayLabel(now.subtract(const Duration(days: 1)), now),
      'Yesterday',
    );
    expect(chatDayLabel(DateTime(2026, 10, 14, 9), now), '14 Oct 2026');
  });
}
