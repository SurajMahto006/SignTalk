import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../services/webrtc/webrtc_call_service.dart';
import '../../theme/sign_talk_colors.dart';

/// Live WebRTC video call with SignTalk assistance (STT/TTS). Requires signaling server.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _call = WebRtcCallService();
  final _roomController = TextEditingController(text: 'signtalk-demo');
  final _signalUrlController =
      TextEditingController(text: WebRtcCallService.defaultSignalingUrl);
  final _assistController = TextEditingController();
  final _captions = SpeechTranscriptController();
  bool _captionsListening = false;
  bool _assistExpanded = true;
  SpeechRecognitionService? _speech;
  final List<StreamSubscription<dynamic>> _captionSubs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SignTalkScope.of(context).cameraPreview.stop();
      await _call.ensureRenderers();
      if (mounted) setState(() {});
    });
    _captions.addListener(_syncCaptionsToField);
  }

  void _syncCaptionsToField() {
    final t = _captions.text;
    if (_assistController.text != t) {
      _assistController.text = t;
      _assistController.selection = TextSelection.collapsed(offset: t.length);
    }
    if (mounted) setState(() {});
  }

  @override
  void deactivate() {
    unawaited(_stopCaptions());
    unawaited(_call.hangUp());
    super.deactivate();
  }

  @override
  void dispose() {
    for (final s in _captionSubs) {
      unawaited(s.cancel());
    }
    _captions.removeListener(_syncCaptionsToField);
    _captions.dispose();
    _call.dispose();
    _roomController.dispose();
    _signalUrlController.dispose();
    _assistController.dispose();
    super.dispose();
  }

  Future<void> _hostCall() async {
    await _call.connectToRoom(
      signalingUrl: _signalUrlController.text,
      roomId: _roomController.text,
      asHost: true,
    );
    setState(() {});
  }

  Future<void> _joinCall() async {
    await _call.connectToRoom(
      signalingUrl: _signalUrlController.text,
      roomId: _roomController.text,
      asHost: false,
    );
    setState(() {});
  }

  Future<void> _endCall() async {
    await _stopCaptions();
    await _call.hangUp();
    setState(() {});
  }

  Future<void> _startCaptions() async {
    if (_captionsListening) return;
    final scope = SignTalkScope.of(context);
    final speech = _speech = scope.speechRecognition;
    if (_call.isActive) {
      await _call.releaseMicForSpeechRecognition();
    }
    final ok = await speech.initialize();
    if (!mounted) return;
    if (!ok) {
      _showSnack('Speech recognition unavailable in this browser.');
      return;
    }
    speech.setLocale(SignTalkScope.preferencesOf(context).speechLocale);
    _captionSubs
      ..add(speech.partialTranscriptStream.listen(_captions.applyPartial))
      ..add(speech.finalTranscriptStream.listen(_captions.applyFinal));
    _captions.onListenStarted();
    await speech.startListening();
    setState(() => _captionsListening = true);
    _showSnack('Captions on — call mic muted to avoid conflict.');
  }

  Future<void> _stopCaptions() async {
    if (!_captionsListening) return;
    for (final s in _captionSubs) {
      unawaited(s.cancel());
    }
    _captionSubs.clear();
    await _speech?.stopListening();
    await _call.restoreMicAfterSpeechRecognition();
    setState(() => _captionsListening = false);
  }

  Future<void> _speakAssistText() async {
    final prefs = SignTalkScope.preferencesOf(context);
    final tts = SignTalkScope.of(context).textToSpeech;
    final text = _assistController.text.trim();
    if (text.isEmpty) {
      _showSnack('Enter text to speak.');
      return;
    }
    await tts.setLanguage(prefs.speechLocale);
    final outcome = await tts.speak(text, enabled: prefs.spokenOutputEnabled);
    if (outcome == SpeakOutcome.failed || outcome == SpeakOutcome.unavailable) {
      _showSnack('Could not speak text.');
    }
  }

  Future<void> _tryIslFromCall() async {
    final isl = SignTalkScope.of(context).islRecognition;
    final result = await isl.recognizeClip(jpegFrames: const []);
    _showSnack(result.message ?? isl.rawAdapter.displayName);
    if (result.isSuccess && result.label != null) {
      _assistController.text = result.label!;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _call,
      builder: (context, _) {
        final connected = _call.connectionState == CallConnectionState.connected;
        final islStatus = SignTalkScope.of(context).islRecognition.rawAdapter.displayName;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                  const Expanded(
                    child: Text(
                      'Live video call (WebRTC)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _assistExpanded = !_assistExpanded),
                    icon: Icon(_assistExpanded ? Icons.expand_more : Icons.expand_less),
                    tooltip: 'Assistance panel',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _call.statusMessage ?? 'Not connected',
                style: TextStyle(
                  fontSize: 12,
                  color: _call.errorMessage != null
                      ? SignTalkColors.callRed
                      : SignTalkColors.secondaryText,
                ),
              ),
            ),
            if (!_call.isActive) _LobbyPanel(
              roomController: _roomController,
              signalUrlController: _signalUrlController,
              onHost: () => unawaited(_hostCall()),
              onJoin: () => unawaited(_joinCall()),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFF1C1C1E),
                    child: _call.remoteRenderer.srcObject != null
                        ? RTCVideoView(_call.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                        : Center(
                            child: Text(
                              connected ? 'Waiting for remote video…' : 'Start or join a call',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    width: 110,
                    height: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: Colors.black54,
                        child: _call.localRenderer.srcObject != null
                            ? RTCVideoView(_call.localRenderer, mirror: true)
                            : const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white54),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _CallControls(
              micOn: _call.micEnabled,
              cameraOn: _call.cameraEnabled,
              onToggleMic: () => unawaited(_call.setMicEnabled(!_call.micEnabled)),
              onToggleCamera: () => unawaited(_call.setCameraEnabled(!_call.cameraEnabled)),
              onEnd: () => unawaited(_endCall()),
            ),
            if (_assistExpanded)
              _AssistancePanel(
                controller: _assistController,
                captionsListening: _captionsListening,
                islStatus: islStatus,
                onStartCaptions: () => unawaited(_startCaptions()),
                onStopCaptions: () => unawaited(_stopCaptions()),
                onSpeak: () => unawaited(_speakAssistText()),
                onTryIsl: () => unawaited(_tryIslFromCall()),
              ),
          ],
        );
      },
    );
  }
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.roomController,
    required this.signalUrlController,
    required this.onHost,
    required this.onJoin,
  });

  final TextEditingController roomController;
  final TextEditingController signalUrlController;
  final VoidCallback onHost;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: signalUrlController,
            decoration: const InputDecoration(
              labelText: 'Signaling WebSocket URL',
              hintText: 'ws://192.168.1.10:8765',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: roomController,
            decoration: const InputDecoration(
              labelText: 'Room ID (same on both devices)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onHost, child: const Text('Host call')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: onJoin, child: const Text('Join call')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Run tools/signaling-server on your PC. Phone must use your PC LAN IP, same Wi‑Fi.',
            style: TextStyle(fontSize: 11, color: SignTalkColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.micOn,
    required this.cameraOn,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onEnd,
  });

  final bool micOn;
  final bool cameraOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundBtn(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Mute' : 'Unmute',
            onTap: onToggleMic,
          ),
          _RoundBtn(
            icon: cameraOn ? Icons.videocam : Icons.videocam_off,
            label: cameraOn ? 'Cam off' : 'Cam on',
            onTap: onToggleCamera,
          ),
          _RoundBtn(
            icon: Icons.call_end,
            label: 'End',
            color: SignTalkColors.callRed,
            onTap: onEnd,
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color ?? SignTalkColors.card,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: color != null ? Colors.white : SignTalkColors.primaryText),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _AssistancePanel extends StatelessWidget {
  const _AssistancePanel({
    required this.controller,
    required this.captionsListening,
    required this.islStatus,
    required this.onStartCaptions,
    required this.onStopCaptions,
    required this.onSpeak,
    required this.onTryIsl,
  });

  final TextEditingController controller;
  final bool captionsListening;
  final String islStatus;
  final VoidCallback onStartCaptions;
  final VoidCallback onStopCaptions;
  final VoidCallback onSpeak;
  final VoidCallback onTryIsl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SignTalkColors.card,
        border: Border(top: BorderSide(color: SignTalkColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('SignTalk assistance (call stays active)', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('ISL: $islStatus', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Captions / editable text for TTS…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: captionsListening ? onStopCaptions : onStartCaptions,
                    child: Text(captionsListening ? 'Stop captions' : 'Start captions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: onSpeak, child: const Text('Speak text')),
                ),
              ],
            ),
            TextButton(onPressed: onTryIsl, child: const Text('Check ISL model adapter')),
          ],
        ),
      ),
    );
  }
}
