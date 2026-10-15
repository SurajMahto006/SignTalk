import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../services/webrtc/call_media_state.dart';
import '../../services/webrtc/webrtc_call_config.dart';
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
  late final TextEditingController _signalUrlController;
  final _assistController = TextEditingController();
  final _captions = SpeechTranscriptController();
  bool _captionsListening = false;
  bool _assistExpanded = false;
  bool _connecting = false;
  SpeechRecognitionService? _speech;
  final List<StreamSubscription<dynamic>> _captionSubs = [];

  @override
  void initState() {
    super.initState();
    _signalUrlController = TextEditingController(text: WebRtcCallConfig.signalingUrlForPage());
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

  Future<void> _releaseCameraPreviewForCall() async {
    final preview = SignTalkScope.of(context).cameraPreview;
    if (preview.isActive) await preview.stop();
  }

  Future<void> _checkMedia() async {
    if (_connecting) return;
    _connecting = true;
    setState(() {});
    await _releaseCameraPreviewForCall();
    await _call.requestLocalMediaPreview();
    _connecting = false;
    if (mounted) setState(() {});
  }

  Future<void> _hostCall() async {
    if (_connecting) return;
    _connecting = true;
    setState(() {});
    try {
      await _releaseCameraPreviewForCall();
      await _call.connectToRoom(
        signalingUrl: _signalUrlController.text,
        roomId: _roomController.text,
        asHost: true,
      );
    } on ArgumentError catch (e) {
      _showSnack(e.message ?? e.toString());
    } finally {
      _connecting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _joinCall() async {
    if (_connecting) return;
    _connecting = true;
    setState(() {});
    try {
      await _releaseCameraPreviewForCall();
      await _call.connectToRoom(
        signalingUrl: _signalUrlController.text,
        roomId: _roomController.text,
        asHost: false,
      );
    } on ArgumentError catch (e) {
      _showSnack(e.message ?? e.toString());
    } finally {
      _connecting = false;
      if (mounted) setState(() {});
    }
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
    if (_call.isActive) await _call.releaseMicForSpeechRecognition();
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
        final mediaConnected = _call.connectionState == CallConnectionState.connected;
        final islStatus = SignTalkScope.of(context).islRecognition.rawAdapter.displayName;

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                    const Expanded(
                      child: Text(
                        'Live video call',
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
              _CallStatusBanner(call: _call, connecting: _connecting),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            if (!_call.isActive)
                              _LobbyPanel(
                                roomController: _roomController,
                                signalUrlController: _signalUrlController,
                                connecting: _connecting,
                                onCheckMedia: () => unawaited(_checkMedia()),
                                onHost: () => unawaited(_hostCall()),
                                onJoin: () => unawaited(_joinCall()),
                              ),
                            SizedBox(
                              height: (constraints.maxHeight * 0.42).clamp(160, 320),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color: const Color(0xFF1C1C1E),
                                    child: _call.remoteRenderer.srcObject != null
                                        ? RTCVideoView(
                                            _call.remoteRenderer,
                                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                          )
                                        : Center(
                                            child: Text(
                                              mediaConnected
                                                  ? 'Waiting for remote video…'
                                                  : 'Remote participant video',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: _MediaChip(
                                      label: _call.hasRemoteAudio ? 'Remote audio' : 'No remote audio',
                                      ok: _call.hasRemoteAudio,
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    width: 96,
                                    height: 128,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: ColoredBox(
                                        color: Colors.black54,
                                        child: _call.localRenderer.srcObject != null
                                            ? RTCVideoView(_call.localRenderer, mirror: true)
                                            : const Center(
                                                child: Icon(Icons.videocam_off, color: Colors.white54, size: 28),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _CallControls(
                              enabled: _call.localMediaReady || _call.isActive,
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
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CallStatusBanner extends StatelessWidget {
  const _CallStatusBanner({required this.call, required this.connecting});

  final WebRtcCallService call;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final error = call.errorMessage;
    final status = call.statusMessage ?? 'Not connected';
    final media = call.mediaAccessDetail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            connecting ? 'Working…' : status,
            style: TextStyle(
              fontSize: 12,
              color: error != null ? SignTalkColors.callRed : SignTalkColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _MediaChip(label: _signalingLabel(call.signalingState), ok: call.signalingState == CallSignalingState.joined),
              _MediaChip(label: _mediaPathLabel(call.mediaPathState), ok: call.mediaPathState == CallMediaPathState.connected),
              _MediaChip(label: _accessLabel(call.mediaAccessState), ok: call.mediaAccessState == CallMediaAccessState.granted),
            ],
          ),
          if (media != null) ...[
            const SizedBox(height: 4),
            Text(media, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (!WebRtcCallConfig.pageIsSecureContext) ...[
            const SizedBox(height: 6),
            Text(
              WebRtcCallConfig.secureContextHint,
              style: TextStyle(fontSize: 10, color: SignTalkColors.callRed.withValues(alpha: 0.9)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Tracks — local: ${call.hasLocalVideo ? 1 : 0}v/${call.hasLocalAudio ? 1 : 0}a · '
            'remote: ${call.hasRemoteVideo ? 1 : 0}v/${call.hasRemoteAudio ? 1 : 0}a · '
            'remote events: ${call.remoteTracksReceived} · '
            'ICE: ${call.lastIceConnectionState} · peer: ${call.lastPeerConnectionState}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _signalingLabel(CallSignalingState s) => switch (s) {
        CallSignalingState.joined => 'Signaling joined',
        CallSignalingState.connecting => 'Signaling…',
        CallSignalingState.disconnected => 'Signaling lost',
        CallSignalingState.failed => 'Signaling failed',
        _ => 'Signaling idle',
      };

  static String _mediaPathLabel(CallMediaPathState s) => switch (s) {
        CallMediaPathState.connected => 'Media connected',
        CallMediaPathState.negotiating => 'Negotiating',
        CallMediaPathState.preparingLocalMedia => 'Opening camera/mic',
        CallMediaPathState.reconnecting => 'Reconnecting',
        CallMediaPathState.failed => 'Media failed',
        _ => 'Media idle',
      };

  static String _accessLabel(CallMediaAccessState s) => switch (s) {
        CallMediaAccessState.granted => 'Permissions OK',
        CallMediaAccessState.requesting => 'Requesting…',
        CallMediaAccessState.denied => 'Permission denied',
        CallMediaAccessState.unavailable => 'No device',
        CallMediaAccessState.error => 'Media error',
        _ => 'Media not checked',
      };
}

class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? SignTalkColors.tintBlue : SignTalkColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ok ? SignTalkColors.primaryBlue.withValues(alpha: 0.4) : SignTalkColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.roomController,
    required this.signalUrlController,
    required this.connecting,
    required this.onCheckMedia,
    required this.onHost,
    required this.onJoin,
  });

  final TextEditingController roomController;
  final TextEditingController signalUrlController;
  final bool connecting;
  final VoidCallback onCheckMedia;
  final VoidCallback onHost;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: signalUrlController,
            decoration: InputDecoration(
              labelText: 'Signaling WebSocket URL',
              hintText: WebRtcCallConfig.signalingUrlForPage(),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: roomController,
            decoration: const InputDecoration(
              labelText: 'Room ID (same on both devices)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: connecting ? null : onCheckMedia,
              child: const Text('Check camera & microphone'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: connecting ? null : onHost,
                  child: const Text('Host call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: connecting ? null : onJoin,
                  child: const Text('Join call'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Start the signaling server on your PC (port 8765). Laptop may use ws://127.0.0.1:8765; '
            'phone must use your PC LAN IP or wss:// when the app is served over HTTPS. '
            'Allow inbound TCP 8765 on Private networks in Windows Firewall if needed.',
            style: TextStyle(fontSize: 10, color: SignTalkColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.enabled,
    required this.micOn,
    required this.cameraOn,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onEnd,
  });

  final bool enabled;
  final bool micOn;
  final bool cameraOn;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundBtn(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Mute mic' : 'Unmute mic',
            onTap: enabled ? onToggleMic : null,
          ),
          _RoundBtn(
            icon: cameraOn ? Icons.videocam : Icons.videocam_off,
            label: cameraOn ? 'Camera off' : 'Camera on',
            onTap: enabled ? onToggleCamera : null,
          ),
          _RoundBtn(
            icon: Icons.call_end,
            label: 'End call',
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
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: disabled ? SignTalkColors.border.withValues(alpha: 0.3) : (color ?? SignTalkColors.card),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: disabled
                    ? SignTalkColors.secondaryText
                    : (color != null ? Colors.white : SignTalkColors.primaryText),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
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
            const Text('Assistance (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('ISL: $islStatus', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Captions / text for TTS…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: captionsListening ? onStopCaptions : onStartCaptions,
                    child: Text(captionsListening ? 'Stop captions' : 'Captions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: onSpeak, child: const Text('Speak')),
                ),
              ],
            ),
            TextButton(onPressed: onTryIsl, child: const Text('ISL adapter status')),
          ],
        ),
      ),
    );
  }
}
