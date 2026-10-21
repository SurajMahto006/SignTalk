import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/logs/activity_log_service.dart';
import 'package:signtalk/services/notices/notice_center.dart';

void main() {
  final seenAt = DateTime(2026, 10, 20, 21, 0);

  test('stays quiet when permissions and settings are fine', () {
    final notices = NoticeCenter.buildNotices(
      cameraGranted: true,
      microphoneGranted: true,
      captionsEnabled: true,
      spokenOutputEnabled: true,
      settingsError: null,
      logs: const [],
      seenAt: seenAt,
    );

    expect(notices, isEmpty);
  });

  test('reports a blocked camera and captions that are off', () {
    final notices = NoticeCenter.buildNotices(
      cameraGranted: false,
      microphoneGranted: null,
      captionsEnabled: false,
      spokenOutputEnabled: true,
      settingsError: null,
      logs: const [],
      seenAt: seenAt,
    );

    expect(notices.map((notice) => notice.kind), [
      NoticeKind.cameraDenied,
      NoticeKind.captionsOff,
    ]);
  });

  test('shows only chats and calls that arrived after the bell was opened', () {
    final notices = NoticeCenter.buildNotices(
      cameraGranted: true,
      microphoneGranted: true,
      captionsEnabled: true,
      spokenOutputEnabled: true,
      settingsError: null,
      logs: [
        ActivityLogEntry(
          type: ActivityLogType.chat,
          contactName: 'Demo contact',
          title: 'Chat conversation',
          preview: 'New hello',
          createdAt: seenAt.add(const Duration(minutes: 5)),
        ),
        ActivityLogEntry(
          type: ActivityLogType.call,
          contactName: 'Demo contact',
          title: 'Video call',
          preview: 'Room: signtalk-demo',
          createdAt: seenAt.subtract(const Duration(minutes: 5)),
        ),
      ],
      seenAt: seenAt,
    );

    expect(notices, hasLength(1));
    expect(notices.single.kind, NoticeKind.chat);
    expect(notices.single.body, 'New hello');
  });
}
