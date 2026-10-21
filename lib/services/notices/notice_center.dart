import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logs/activity_log_service.dart';
import '../permissions/device_permission_status.dart';
import '../preferences/sign_talk_preferences.dart';

enum NoticeKind {
  cameraDenied,
  microphoneDenied,
  captionsOff,
  speechOff,
  settingsError,
  chat,
  call,
}

class AppNotice {
  const AppNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
  });

  final String id;
  final String title;
  final String body;
  final NoticeKind kind;
}

/// Local notices for the bell. Nothing is sent to a server.
class NoticeCenter extends ChangeNotifier {
  static const _seenKey = 'st_notices_seen_at';

  DateTime? seenAt;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      seenAt = DateTime.tryParse(_prefs!.getString(_seenKey) ?? '');
      seenAt ??= DateTime.now();
      await _prefs!.setString(_seenKey, seenAt!.toIso8601String());
    } catch (error) {
      seenAt ??= DateTime.now();
      if (kDebugMode) {
        debugPrint('[NoticeCenter] Error loading seen time: $error');
      }
    }
    notifyListeners();
  }

  Future<void> markSeen() async {
    seenAt = DateTime.now();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_seenKey, seenAt!.toIso8601String());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[NoticeCenter] Error saving seen time: $error');
      }
    }
    notifyListeners();
  }

  List<AppNotice> collect({
    required DevicePermissionStatus permissions,
    required SignTalkPreferences preferences,
    required List<ActivityLogEntry> logs,
  }) {
    return buildNotices(
      cameraGranted: permissions.cameraGranted,
      microphoneGranted: permissions.microphoneGranted,
      captionsEnabled: preferences.captionsEnabled,
      spokenOutputEnabled: preferences.spokenOutputEnabled,
      settingsError: preferences.loadError,
      logs: logs,
      seenAt: seenAt,
    );
  }

  static List<AppNotice> buildNotices({
    required bool? cameraGranted,
    required bool? microphoneGranted,
    required bool captionsEnabled,
    required bool spokenOutputEnabled,
    required String? settingsError,
    required List<ActivityLogEntry> logs,
    required DateTime? seenAt,
  }) {
    final notices = <AppNotice>[];
    if (cameraGranted == false) {
      notices.add(
        const AppNotice(
          id: 'camera-denied',
          title: 'Camera is blocked',
          body:
              'Allow the camera in the browser to use sign recognition and video calls.',
          kind: NoticeKind.cameraDenied,
        ),
      );
    }
    if (microphoneGranted == false) {
      notices.add(
        const AppNotice(
          id: 'microphone-denied',
          title: 'Microphone is blocked',
          body:
              'Allow the microphone in the browser to dictate and to talk on a call.',
          kind: NoticeKind.microphoneDenied,
        ),
      );
    }
    if (!captionsEnabled) {
      notices.add(
        const AppNotice(
          id: 'captions-off',
          title: 'Captions are off',
          body: 'Turn captions on in Settings to show them in conversations.',
          kind: NoticeKind.captionsOff,
        ),
      );
    }
    if (!spokenOutputEnabled) {
      notices.add(
        const AppNotice(
          id: 'speech-off',
          title: 'Spoken output is off',
          body: 'Messages will not be read aloud until you turn it on in Settings.',
          kind: NoticeKind.speechOff,
        ),
      );
    }
    if (settingsError != null && settingsError.isNotEmpty) {
      notices.add(
        AppNotice(
          id: 'settings-error',
          title: 'Settings could not load',
          body: settingsError,
          kind: NoticeKind.settingsError,
        ),
      );
    }

    if (seenAt != null) {
      final fresh = logs.where((entry) => entry.createdAt.isAfter(seenAt));
      for (final entry in fresh.take(8)) {
        final isCall = entry.type == ActivityLogType.call;
        notices.add(
          AppNotice(
            id: 'activity-${entry.createdAt.toIso8601String()}-${entry.contactName}',
            title: isCall
                ? 'Video call with ${entry.contactName}'
                : 'Message with ${entry.contactName}',
            body: entry.preview,
            kind: isCall ? NoticeKind.call : NoticeKind.chat,
          ),
        );
      }
    }
    return notices;
  }
}
