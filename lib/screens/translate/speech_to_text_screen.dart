import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../theme/sign_talk_colors.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({
    super.key,
    required this.onBack,
    required this.onSendToConversations,
    this.onOpenSettings,
  });

  final VoidCallback onBack;
  final void Function(String text) onSendToConversations;
  final VoidCallback? onOpenSettings;

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  final _transcript = SpeechTranscriptController();
  final _textController = TextEditingController();
  String _statusMessage = 'Ready to listen';
  bool _isPaused = false;
  bool _isListening = false;
  bool _available = false;
  String? _lastError;

  final List<StreamSubscription<dynamic>> _subs = [];
  SpeechRecognitionService? _speech;

  String get _language => SignTalkScope.preferencesOf(context).speechLanguageLabel;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (_textController.text != _transcript.text) {
        _transcript.onUserEdited(_textController.text);
      }
    });
    _transcript.addListener(_syncFieldFromTranscript);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSpeech());
  }

  void _syncFieldFromTranscript() {
    final next = _transcript.text;
    if (_textController.text != next) {
      _textController.text = next;
      _textController.selection = TextSelection.collapsed(offset: next.length);
    }
    if (mounted) setState(() {});
  }

  Future<void> _bindSpeech() async {
    final scope = SignTalkScope.of(context);
    final speech = _speech = scope.speechRecognition;
    speech.setLocale(SignTalkScope.preferencesOf(context).speechLocale);

    _subs
      ..add(speech.statusStream.listen((s) => setState(() => _statusMessage = s)))
      ..add(speech.partialTranscriptStream.listen(_transcript.applyPartial))
      ..add(speech.finalTranscriptStream.listen(_transcript.applyFinal))
      ..add(speech.errorStream.listen((e) {
        _lastError = e;
        _showSnack(e);
        setState(() {});
      }))
      ..add(speech.listeningStream.listen((l) => setState(() => _isListening = l)));

    final ok = await speech.initialize();
    if (!mounted) return;
    setState(() {
      _available = ok;
      if (!ok) _statusMessage = 'Speech recognition unavailable';
    });
  }

  @override
  void deactivate() {
    SignTalkScope.of(context).textToSpeech.stop();
    unawaited(_speech?.stopListening());
    super.deactivate();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_speech?.stopListening());
    _transcript.removeListener(_syncFieldFromTranscript);
    _transcript.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    SignTalkScope.preferencesOf(context).triggerHapticIfEnabled();
    final scope = SignTalkScope.of(context);
    final speech = scope.speechRecognition;
    if (!_available) {
      _showSnack(_statusMessage);
      return;
    }
    if (_isPaused) {
      _showSnack('Tap Resume before starting again.');
      return;
    }
    _transcript.onListenStarted();
    _lastError = null;
    await speech.startListening();
    final granted = speech.lastPermissionGranted;
    if (granted != null) {
      scope.permissionStatus.reportMicrophone(
        granted: granted,
        detail: granted ? 'Speech to Text' : 'Denied in browser',
      );
    }
    setState(() {});
  }

  Future<void> _stopListening() async {
    await _speech?.stopListening();
    setState(() {});
  }

  Future<void> _retryListening() async {
    await _stopListening();
    _lastError = null;
    setState(() => _statusMessage = 'Retrying…');
    await _startListening();
  }

  Future<void> _togglePause() async {
    final speech = SignTalkScope.of(context).speechRecognition;
    if (_isPaused) {
      speech.resumeUser();
      setState(() => _isPaused = false);
    } else {
      speech.pauseUser();
      await speech.stopListening();
      setState(() => _isPaused = true);
    }
  }

  void _clearTranscript() {
    SignTalkScope.of(context).speechRecognition.clearSession();
    _transcript.clear();
    _textController.clear();
    setState(() {});
  }

  Future<void> _speakTranscript() async {
    await _runTts(_textController.text);
  }

  Future<void> _stopSpeaking() async {
    await SignTalkScope.of(context).textToSpeech.stop();
  }

  Future<void> _runTts(String text) async {
    final prefs = SignTalkScope.preferencesOf(context);
    final tts = SignTalkScope.of(context).textToSpeech;
    if (text.trim().isEmpty) {
      _showSnack('Nothing to speak.');
      return;
    }
    if (!prefs.spokenOutputEnabled) {
      _showSnack('Spoken output is off in Settings.');
      return;
    }
    await tts.setLanguage(prefs.speechLocale);
    final outcome = await tts.speak(text, enabled: prefs.spokenOutputEnabled);
    if (outcome == SpeakOutcome.failed || outcome == SpeakOutcome.unavailable) {
      _showSnack('Could not speak text.');
    }
  }

  void _copyTranscript() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnack('Nothing to copy yet.');
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied to clipboard.');
  }

  void _sendToConversations() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnack('Add or dictate text first.');
      return;
    }
    widget.onSendToConversations(text);
    _showSnack('Sent to Conversations — review and send the message there.');
  }

  Future<void> _onLanguageTap() async {
    final prefs = SignTalkScope.preferencesOf(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Speech language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en_US|English (US)'),
            child: const Text('English (US)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en_IN|English (India)'),
            child: const Text('English (India)'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final parts = picked.split('|');
    await prefs.setSpeechLanguage(label: parts[1], locale: parts[0]);
    if (!mounted) return;
    SignTalkScope.of(context).speechRecognition.setLocale(parts[0]);
    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Color get _statusColor {
    if (_lastError != null && !_isListening) return SignTalkColors.callRed;
    if (_isPaused) return SignTalkColors.secondaryText;
    if (_isListening) return const Color(0xFF059669);
    if (!_available) return SignTalkColors.callRed;
    return SignTalkColors.secondaryText;
  }

  @override
  Widget build(BuildContext context) {
    final tts = SignTalkScope.of(context).textToSpeech;
    final statusText = _isPaused
        ? 'Paused'
        : (_isListening ? 'Listening…' : (_lastError ?? _statusMessage));

    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            _ScreenHeader(
              onBack: widget.onBack,
              onSettings: widget.onOpenSettings ?? () => _showSnack('Open the Settings tab for speech preferences.'),
            ),
            const SizedBox(height: 4),
            Text(
              'Dictate in Chrome, then edit the transcript below.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _MicrophoneCard(
              statusText: statusText,
              statusColor: _statusColor,
              language: _language,
              listening: _isListening,
              available: _available,
              paused: _isPaused,
              onLanguageTap: _onLanguageTap,
              onPrimaryMic: () {
                if (_isListening) {
                  unawaited(_stopListening());
                } else {
                  unawaited(_startListening());
                }
              },
            ),
            const SizedBox(height: 12),
            _TranscriptCard(controller: _textController),
            const SizedBox(height: 12),
            Text('Playback', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: tts.isSpeaking ? null : () => unawaited(_speakTranscript()),
                    icon: const Icon(Icons.volume_up_outlined, size: 18),
                    label: Text(tts.isSpeaking ? 'Speaking…' : 'Speak'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: tts.isSpeaking ? () => unawaited(_stopSpeaking()) : null,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Transcript', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyTranscript,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearTranscript,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _available ? () => unawaited(_retryListening()) : null,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_togglePause()),
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                    label: Text(_isPaused ? 'Resume' : 'Pause'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sendToConversations,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Send to Conversations'),
            ),
          ],
        );
      },
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.onBack, required this.onSettings});

  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: SignTalkColors.primaryText),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Speech to Text',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SignTalkColors.primaryText),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.settings_outlined, size: 22, color: SignTalkColors.primaryText),
            ),
          ),
        ),
      ],
    );
  }
}

class _MicrophoneCard extends StatelessWidget {
  const _MicrophoneCard({
    required this.statusText,
    required this.statusColor,
    required this.language,
    required this.listening,
    required this.available,
    required this.paused,
    required this.onLanguageTap,
    required this.onPrimaryMic,
  });

  final String statusText;
  final Color statusColor;
  final String language;
  final bool listening;
  final bool available;
  final bool paused;
  final VoidCallback onLanguageTap;
  final VoidCallback onPrimaryMic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: listening ? 'Stop listening' : 'Start listening',
              child: Material(
                color: listening ? SignTalkColors.primaryBlue : SignTalkColors.tintBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onPrimaryMic,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(
                      listening ? Icons.stop_rounded : Icons.mic,
                      size: 32,
                      color: listening ? Colors.white : SignTalkColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(statusText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor)),
            const SizedBox(height: 8),
            Material(
              color: SignTalkColors.dividerLight,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onLanguageTap,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(language, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editable transcript', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Tap the microphone and speak, or type here…',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
