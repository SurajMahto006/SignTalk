import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
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
  bool _cameraActive = false;
  String? _cameraError;
  String? _lastError;

  final List<StreamSubscription<dynamic>> _subs = [];
  SpeechRecognitionService? _speech;
  Timer? _captionRestart;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (_textController.text != _transcript.text) {
        _transcript.onUserEdited(_textController.text);
      }
    });
    _transcript.addListener(_syncFieldFromTranscript);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCameraAndCaptions());
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
        final network = e.toLowerCase().contains('network') || e.contains('400');
        _lastError = network
            ? 'Captions need Chrome and an internet connection. Your camera can stay on.'
            : e;
        if (!network) _showSnack(_lastError!);
        setState(() {});
      }))
      ..add(speech.listeningStream.listen((listening) {
        setState(() => _isListening = listening);
        _captionRestart?.cancel();
        if (!listening && _cameraActive && !_isPaused && _lastError == null) {
          _captionRestart = Timer(const Duration(milliseconds: 500), () {
            if (mounted && !_isListening && _lastError == null && !_isPaused) {
              unawaited(_speech?.startListening());
            }
          });
        }
      }));

    final ok = await speech.initialize();
    if (!mounted) return;
    setState(() {
      _available = ok;
      if (!ok) _statusMessage = 'Speech recognition unavailable';
    });
  }

  Future<void> _openCameraAndCaptions() async {
    await _bindSpeech();
    if (!mounted) return;
    final scope = SignTalkScope.of(context);
    final camera = scope.cameraPreview;
    final started = camera.isActive || await camera.start();
    scope.permissionStatus.reportCamera(
      granted: camera.lastPermissionGranted ?? started,
      detail: started ? 'Speech captions' : camera.lastError,
    );
    if (!mounted) return;
    setState(() {
      _cameraActive = started;
      _cameraError = started ? null : camera.lastError;
    });
    if (started) await _startListening();
  }

  @override
  void deactivate() {
    final preview = SignTalkScope.of(context).cameraPreview;
    unawaited(preview.stop());
    SignTalkScope.of(context).textToSpeech.stop();
    unawaited(_speech?.stopListening());
    super.deactivate();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _captionRestart?.cancel();
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

  Future<void> _stopSpeaking() async {
    await SignTalkScope.of(context).textToSpeech.stop();
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _ScreenHeader(
                onBack: widget.onBack,
                onSettings: widget.onOpenSettings ??
                    () => _showSnack('Open the Settings tab for speech preferences.'),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TalkingCamera(
                  cameraActive: _cameraActive,
                  viewType: SignTalkScope.of(context).cameraPreview.viewType,
                  errorMessage: _cameraError,
                  caption: _textController.text.trim().isEmpty
                      ? statusText
                      : _textController.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => unawaited(_togglePause()),
                          child: Text(_isPaused ? 'Resume captions' : 'Pause captions'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearTranscript,
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _sendToConversations,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: const Text('Send to Conversations'),
                  ),
                  if (tts.isSpeaking)
                    TextButton(
                      onPressed: () => unawaited(_stopSpeaking()),
                      child: const Text('Stop speaking'),
                    ),
                ],
              ),
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

class _TalkingCamera extends StatelessWidget {
  const _TalkingCamera({
    required this.cameraActive,
    required this.viewType,
    required this.caption,
    this.errorMessage,
  });

  final bool cameraActive;
  final String? viewType;
  final String caption;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraActive && viewType != null)
            HtmlElementView(viewType: viewType!)
          else
            ColoredBox(
              color: const Color(0xFF1C1C1E),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    errorMessage ?? 'Opening your camera…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
