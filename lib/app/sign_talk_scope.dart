import 'package:flutter/material.dart';

import '../services/auth/auth_service.dart';
import '../services/communication/contact_book.dart';
import '../services/communication/conversation_draft.dart';
import '../services/communication/conversation_store.dart';
import '../services/contacts/contacts_service.dart';
import '../services/isl/favorite_signs.dart';
import '../services/isl/isl_recognition_adapter.dart';
import '../services/logs/activity_log_service.dart';
import '../services/media/camera_preview_service.dart';
import '../services/notices/notice_center.dart';
import '../services/permissions/device_permission_status.dart';
import '../services/preferences/sign_talk_preferences.dart';
import '../services/speech/speech_recognition_service.dart';
import '../services/speech/text_to_speech_service.dart';

class SignTalkScope extends InheritedNotifier<SignTalkPreferences> {
  const SignTalkScope({
    super.key,
    required SignTalkPreferences preferences,
    required this.authService,
    required this.speechRecognition,
    required this.textToSpeech,
    required this.cameraPreview,
    required this.permissionStatus,
    required this.conversationDraft,
    required this.islRecognition,
    required this.activityLogs,
    required this.contacts,
    required this.conversations,
    required this.favoriteSigns,
    required this.notices,
    this.contactsService,
    required super.child,
  }) : super(notifier: preferences);

  final AuthService authService;
  final SpeechRecognitionService speechRecognition;
  final TextToSpeechService textToSpeech;
  final CameraPreviewService cameraPreview;
  final DevicePermissionStatus permissionStatus;
  final ConversationDraft conversationDraft;
  final SmoothedIslRecognitionService islRecognition;
  final ActivityLogService activityLogs;
  final ContactBook contacts;
  final ConversationStore conversations;
  final FavoriteSigns favoriteSigns;
  final NoticeCenter notices;
  final ContactsService? contactsService;

  static SignTalkScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SignTalkScope>();
    assert(scope != null, 'SignTalkScope not found');
    return scope!;
  }

  static SignTalkPreferences preferencesOf(BuildContext context) =>
      of(context).notifier!;
  static AuthService authOf(BuildContext context) => of(context).authService;
  static ContactsService contactsOf(BuildContext context) =>
      of(context).contactsService ?? ContactsService();
}
