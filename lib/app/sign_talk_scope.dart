import 'package:flutter/material.dart';

import '../services/communication/conversation_draft.dart';
import '../services/isl/isl_recognition_adapter.dart';
import '../services/media/camera_preview_service.dart';
import '../services/permissions/device_permission_status.dart';
import '../services/preferences/sign_talk_preferences.dart';
import '../services/speech/speech_recognition_service.dart';
import '../services/speech/text_to_speech_service.dart';

class SignTalkScope extends InheritedNotifier<SignTalkPreferences> {
  const SignTalkScope({
    super.key,
    required SignTalkPreferences preferences,
    required this.speechRecognition,
    required this.textToSpeech,
    required this.cameraPreview,
    required this.permissionStatus,
    required this.conversationDraft,
    required this.islRecognition,
    required super.child,
  }) : super(notifier: preferences);

  final SpeechRecognitionService speechRecognition;
  final TextToSpeechService textToSpeech;
  final CameraPreviewService cameraPreview;
  final DevicePermissionStatus permissionStatus;
  final ConversationDraft conversationDraft;
  final SmoothedIslRecognitionService islRecognition;

  static SignTalkScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SignTalkScope>();
    assert(scope != null, 'SignTalkScope not found');
    return scope!;
  }

  static SignTalkPreferences preferencesOf(BuildContext context) => of(context).notifier!;
}
