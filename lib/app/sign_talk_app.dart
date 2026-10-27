import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import '../services/auth/auth_service.dart';
import '../services/cloud/cloud_database.dart';
import '../services/communication/contact_book.dart';
import '../services/communication/conversation_draft.dart';
import '../services/communication/conversation_store.dart';
import '../services/contacts/contacts_service.dart';
import '../services/isl/favorite_signs.dart';
import '../services/isl/isl_recognition_adapter.dart';
import '../services/isl/isl_recognition_factory.dart';
import '../services/logs/activity_log_service.dart';
import '../services/media/camera_preview_service.dart';
import '../services/notices/notice_center.dart';
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
  final ContactsService _contactsService = ContactsService();
  final ContactBook _contacts = ContactBook();
  final ConversationStore _conversations = ConversationStore();
  final FavoriteSigns _favoriteSigns = FavoriteSigns();
  final NoticeCenter _notices = NoticeCenter();
  final SpeechRecognitionService _speechRecognition =
      SpeechRecognitionService();
  final TextToSpeechService _textToSpeech = TextToSpeechService();
  final CameraPreviewService _cameraPreview = CameraPreviewService.create();
  final DevicePermissionStatus _permissionStatus = DevicePermissionStatus();
  final ConversationDraft _conversationDraft = ConversationDraft();
  final ActivityLogService _activityLogs = ActivityLogService();
  late final SmoothedIslRecognitionService _islRecognition =
      SmoothedIslRecognitionService(createIslRecognitionAdapter());

  @override
  void initState() {
    super.initState();
    _preferences.load();
    _authService.load();
    _activityLogs.load();
    _contactsService.load();
    _contacts.load();
    _conversations.load();
    _favoriteSigns.load();
    _notices.load();
  }

  @override
  void dispose() {
    _speechRecognition.dispose();
    _cameraPreview.dispose();
    _contactsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignTalkScope(
      preferences: _preferences,
      authService: _authService,
      contactsService: _contactsService,
      contacts: _contacts,
      conversations: _conversations,
      favoriteSigns: _favoriteSigns,
      notices: _notices,
      speechRecognition: _speechRecognition,
      textToSpeech: _textToSpeech,
      cameraPreview: _cameraPreview,
      permissionStatus: _permissionStatus,
      conversationDraft: _conversationDraft,
      islRecognition: _islRecognition,
      activityLogs: _activityLogs,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _preferences,
          _authService,
          _textToSpeech,
          _conversationDraft,
          _contactsService,
          _contacts,
          _conversations,
          _favoriteSigns,
          _notices,
          CloudDatabase.instance,
        ]),
        builder: (context, _) {
          return MaterialApp(
            title: 'SignTalk',
            debugShowCheckedModeBanner: false,
            theme: SignTalkTheme.light,
            builder: (context, child) {
              final scale = _preferences.textScaleFactor;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
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
