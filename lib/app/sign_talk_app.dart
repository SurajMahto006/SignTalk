import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import '../services/auth/auth_service.dart';
import '../services/cloud/cloud_database.dart';
import '../services/communication/contact_book.dart';
import '../services/communication/conversation_draft.dart';
import '../services/communication/conversation_store.dart';
import '../services/isl/favorite_signs.dart';
import '../services/isl/isl_recognition_adapter.dart';
import '../services/isl/isl_recognition_factory.dart';
import '../services/logs/activity_log_service.dart';
import '../services/notices/notice_center.dart';
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
  final AuthService _authService = AuthService.instance;
  final SpeechRecognitionService _speechRecognition = SpeechRecognitionService();
  final TextToSpeechService _textToSpeech = TextToSpeechService();
  final CameraPreviewService _cameraPreview = CameraPreviewService.create();
  final DevicePermissionStatus _permissionStatus = DevicePermissionStatus();
  final ConversationDraft _conversationDraft = ConversationDraft();
  final ConversationStore _conversations = ConversationStore();
  final ContactBook _contacts = ContactBook();
  final ActivityLogService _activityLogs = ActivityLogService();
  final NoticeCenter _notices = NoticeCenter();
  final FavoriteSigns _favoriteSigns = FavoriteSigns();
  late final SmoothedIslRecognitionService _islRecognition =
      SmoothedIslRecognitionService(createIslRecognitionAdapter());

  @override
  void initState() {
    super.initState();
    _preferences.load();
    _authService.load();
    _activityLogs.load();
    _notices.load();
    _favoriteSigns.load();
    _conversations.load();
    _contacts.load();
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
      authService: _authService,
      speechRecognition: _speechRecognition,
      textToSpeech: _textToSpeech,
      cameraPreview: _cameraPreview,
      permissionStatus: _permissionStatus,
      conversationDraft: _conversationDraft,
      conversations: _conversations,
      contacts: _contacts,
      islRecognition: _islRecognition,
      activityLogs: _activityLogs,
      notices: _notices,
      favoriteSigns: _favoriteSigns,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _preferences,
          _authService,
          _textToSpeech,
          _conversationDraft,
          _conversations,
          _contacts,
          _activityLogs,
          _permissionStatus,
          _notices,
          _favoriteSigns,
          CloudDatabase.instance,
        ]),
        builder: (context, _) {
          return MaterialApp(
            title: 'SignTalk',
            debugShowCheckedModeBanner: false,
            theme: SignTalkTheme.light,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final scale = _preferences.textScaleFactor;
              // Android phones use the real width. A laptop stays a 412px phone column.
              const androidWidth = 412.0;
              final onAndroid = media.size.width <= 520;
              final width = onAndroid ? media.size.width : androidWidth;
              final framed = MediaQuery(
                data: media.copyWith(
                  size: Size(width, media.size.height),
                  textScaler: TextScaler.linear(scale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
              if (onAndroid) return framed;
              return ColoredBox(
                color: const Color(0xFFE6EDF6),
                child: Center(
                  child: SizedBox(width: androidWidth, child: framed),
                ),
              );
            },
            home: _authService.isAuthenticated
                ? MainShell(permissionStatus: _permissionStatus)
                : const AuthScreen(),
          );
        },
      ),
    );
  }
}
