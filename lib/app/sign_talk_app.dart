import 'package:flutter/material.dart';

import '../services/communication/conversation_draft.dart';
import '../services/isl/isl_recognition_adapter.dart';
import '../services/media/camera_preview_service.dart';
import '../services/permissions/device_permission_status.dart';
import '../services/preferences/sign_talk_preferences.dart';
import '../services/speech/speech_recognition_service.dart';
import '../services/speech/text_to_speech_service.dart';
import '../theme/sign_talk_theme.dart';
import 'main_shell.dart';
import 'sign_talk_scope.dart';

class SignTalkApp extends StatefulWidget {
  const SignTalkApp({super.key});

  @override
  State<SignTalkApp> createState() => _SignTalkAppState();
}

class _SignTalkAppState extends State<SignTalkApp> {
  final SignTalkPreferences _preferences = SignTalkPreferences.instance;
  final SpeechRecognitionService _speechRecognition = SpeechRecognitionService();
  final TextToSpeechService _textToSpeech = TextToSpeechService();
  final CameraPreviewService _cameraPreview = CameraPreviewService.create();
  final DevicePermissionStatus _permissionStatus = DevicePermissionStatus();
  final ConversationDraft _conversationDraft = ConversationDraft();
  late final SmoothedIslRecognitionService _islRecognition =
      SmoothedIslRecognitionService(DisconnectedIslRecognitionAdapter());

  @override
  void initState() {
    super.initState();
    _preferences.load();
  }

  @override
  void dispose() {
    _speechRecognition.dispose();
    _cameraPreview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignTalkScope(
      preferences: _preferences,
      speechRecognition: _speechRecognition,
      textToSpeech: _textToSpeech,
      cameraPreview: _cameraPreview,
      permissionStatus: _permissionStatus,
      conversationDraft: _conversationDraft,
      islRecognition: _islRecognition,
      child: ListenableBuilder(
        listenable: Listenable.merge([_preferences, _textToSpeech, _conversationDraft]),
        builder: (context, _) {
          return MaterialApp(
            title: 'SignTalk',
            debugShowCheckedModeBanner: false,
            theme: SignTalkTheme.light,
            builder: (context, child) {
              final scale = _preferences.textScaleFactor;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              );
            },
            home: MainShell(permissionStatus: _permissionStatus),
          );
        },
      ),
    );
  }
}
