import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signtalk/services/logs/activity_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('each account keeps its own history', () async {
    final first = ActivityLogService();
    await first.load();
    await first.addChat(
      ownerId: 'demo',
      contactName: 'Asha',
      preview: 'Hello',
    );
    await first.addCall(
      ownerId: 'suraj006',
      contactName: 'Asha',
      roomId: 'room-1',
    );

    final second = ActivityLogService();
    await second.load();

    expect(second.entriesFor('demo'), hasLength(1));
    expect(second.entriesFor('demo').single.preview, 'Hello');
    expect(second.entriesFor('suraj006').single.type, ActivityLogType.call);

    await second.clearOwner('demo');
    expect(second.entriesFor('demo'), isEmpty);
    expect(second.entriesFor('suraj006'), hasLength(1));
  });
}
