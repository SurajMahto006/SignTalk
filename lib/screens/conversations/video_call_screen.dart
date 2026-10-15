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
  bool _connectionDetailsExpanded = false;
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
        final inCall = _call.isActive;

        return ColoredBox(
          color: inCall ? const Color(0xFF0B0B0C) : SignTalkColors.background,
          child: SafeArea(
            child: Column(
              children: [
                _VideoCallTopBar(
                  onDark: inCall,
                  assistExpanded: _assistExpanded,
                  onClose: widget.onClose,
                  onToggleAssist: () => setState(() => _assistExpanded = !_assistExpanded),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _EssentialStatusLine(
                    call: _call,
                    connecting: _connecting,
                    onDark: inCall,
                  ),
                ),
                if (!inCall)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          _LobbyPanel(
                            roomController: _roomController,
                            signalUrlController: _signalUrlController,
                            connecting: _connecting,
                            onCheckMedia: () => unawaited(_checkMedia()),
                            onHost: () => unawaited(_hostCall()),
                            onJoin: () => unawaited(_joinCall()),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 200,
                                child: _CallVideoStack(
                                  call: _call,
                                  mediaConnected: mediaConnected,
                                  showRemotePlaceholder: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _CallVideoStack(
                          call: _call,
                          mediaConnected: mediaConnected,
                          showRemotePlaceholder: true,
                        ),
                      ),
                    ),
                  ),
                _CallControls(
                  enabled: _call.localMediaReady || _call.isActive,
                  micOn: _call.micEnabled,
                  cameraOn: _call.cameraEnabled,
                  onDark: inCall,
                  onToggleMic: () => unawaited(_call.setMicEnabled(!_call.micEnabled)),
                  onToggleCamera: () => unawaited(_call.setCameraEnabled(!_call.cameraEnabled)),
                  onEnd: () => unawaited(_endCall()),
                ),
                _ConnectionDetailsSection(
                  call: _call,
                  connecting: _connecting,
                  initiallyExpanded: _connectionDetailsExpanded,
                  onExpansionChanged: (v) => setState(() => _connectionDetailsExpanded = v),
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
    );
  }
}

class _VideoCallTopBar extends StatelessWidget {
  const _VideoCallTopBar({
    required this.onDark,
    required this.assistExpanded,
    required this.onClose,
    required this.onToggleAssist,
  });

  final bool onDark;
  final bool assistExpanded;
  final VoidCallback onClose;
  final VoidCallback onToggleAssist;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : SignTalkColors.primaryText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: fg),
            tooltip: 'Close',
          ),
          Expanded(
            child: Text(
              'Live video call',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
          IconButton(
            onPressed: onToggleAssist,
            icon: Icon(assistExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: fg),
            tooltip: 'Assistance panel',
          ),
        ],
      ),
    );
  }
}

class _EssentialStatusLine extends StatelessWidget {
  const _EssentialStatusLine({
    required this.call,
    required this.connecting,
    required this.onDark,
  });

  final WebRtcCallService call;
  final bool connecting;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final error = call.errorMessage;
    final text = connecting ? 'Working…' : _friendlyStatus(call, error);
    final color = error != null
        ? SignTalkColors.callRed
        : (onDark ? Colors.white.withValues(alpha: 0.85) : SignTalkColors.secondaryText);

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.25, color: color),
    );
  }

  static String _friendlyStatus(WebRtcCallService call, String? error) {
    if (error != null) return error;
    if (call.mediaPathState == CallMediaPathState.reconnecting) {
      return 'Reconnecting…';
    }
    if (call.signalingState == CallSignalingState.connecting ||
        call.mediaPathState == CallMediaPathState.negotiating ||
        call.mediaPathState == CallMediaPathState.preparingLocalMedia) {
      return 'Connecting…';
    }
    if (call.mediaPathState == CallMediaPathState.connected && call.isActive) {
      return 'Connected';
    }
    if (call.statusMessage != null && call.statusMessage!.isNotEmpty) {
      return call.statusMessage!;
    }
    return 'Set up room details below, then host or join.';
  }
}

class _CallVideoStack extends StatelessWidget {
  const _CallVideoStack({
    required this.call,
    required this.mediaConnected,
    required this.showRemotePlaceholder,
  });

  final WebRtcCallService call;
  final bool mediaConnected;
  final bool showRemotePlaceholder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF1C1C1E),
          child: call.remoteRenderer.srcObject != null
              ? RTCVideoView(
                  call.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : (showRemotePlaceholder
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          mediaConnected ? 'Waiting for remote video…' : 'Remote participant',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : null),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 92,
                height: 124,
                child: ColoredBox(
                  color: Colors.black54,
                  child: call.localRenderer.srcObject != null
                      ? RTCVideoView(call.localRenderer, mirror: true)
                      : const Center(
                          child: Icon(Icons.videocam_off, color: Colors.white54, size: 26),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionDetailsSection extends StatelessWidget {
  const _ConnectionDetailsSection({
    required this.call,
    required this.connecting,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

  final WebRtcCallService call;
  final bool connecting;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.card,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: const Text(
          'Connection details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SignTalkColors.primaryText),
        ),
        subtitle: Text(
          connecting ? 'Working…' : (call.statusMessage ?? 'Diagnostics'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MediaChip(
                label: _CallDiagnostics.signalingLabel(call.signalingState),
                ok: call.signalingState == CallSignalingState.joined,
              ),
              _MediaChip(
                label: _CallDiagnostics.mediaPathLabel(call.mediaPathState),
                ok: call.mediaPathState == CallMediaPathState.connected,
              ),
              _MediaChip(
                label: _CallDiagnostics.accessLabel(call.mediaAccessState),
                ok: call.mediaAccessState == CallMediaAccessState.granted,
              ),
              _MediaChip(label: call.hasRemoteAudio ? 'Remote audio' : 'No remote audio', ok: call.hasRemoteAudio),
            ],
          ),
          if (call.mediaAccessDetail != null) ...[
            const SizedBox(height: 8),
            Text(call.mediaAccessDetail!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (!WebRtcCallConfig.pageIsSecureContext) ...[
            const SizedBox(height: 8),
            Text(
              WebRtcCallConfig.secureContextHint,
              style: TextStyle(fontSize: 11, color: SignTalkColors.callRed.withValues(alpha: 0.9)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Tracks — local: ${call.hasLocalVideo ? 1 : 0}v/${call.hasLocalAudio ? 1 : 0}a · '
            'remote: ${call.hasRemoteVideo ? 1 : 0}v/${call.hasRemoteAudio ? 1 : 0}a · '
            'remote events: ${call.remoteTracksReceived}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'ICE: ${call.lastIceConnectionState} · peer: ${call.lastPeerConnectionState}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 8),
          const Text(
            'Run the signaling server on your PC (port 8765). Use ws://127.0.0.1:8765 on this device or your LAN IP / wss:// when the app is served over HTTPS. Allow inbound TCP 8765 on Private networks in Windows Firewall if needed.',
            style: TextStyle(fontSize: 11, color: SignTalkColors.secondaryText, height: 1.35),
          ),
        ],
      ),
    );
  }
}

abstract final class _CallDiagnostics {
  static String signalingLabel(CallSignalingState s) => switch (s) {
        CallSignalingState.joined => 'Signaling joined',
        CallSignalingState.connecting => 'Signaling…',
        CallSignalingState.disconnected => 'Signaling lost',
        CallSignalingState.failed => 'Signaling failed',
        _ => 'Signaling idle',
      };

  static String mediaPathLabel(CallMediaPathState s) => switch (s) {
        CallMediaPathState.connected => 'Media connected',
        CallMediaPathState.negotiating => 'Negotiating',
        CallMediaPathState.preparingLocalMedia => 'Opening camera/mic',
        CallMediaPathState.reconnecting => 'Reconnecting',
        CallMediaPathState.failed => 'Media failed',
        _ => 'Media idle',
      };

  static String accessLabel(CallMediaAccessState s) => switch (s) {
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
            decoration: const InputDecoration(
              labelText: 'Signaling WebSocket URL',
              hintText: 'wss:// or ws://…',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: roomController,
            decoration: const InputDecoration(
              labelText: 'Room ID (same on both devices)',
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
    required this.onDark,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onEnd,
  });

  final bool enabled;
  final bool micOn;
  final bool cameraOn;
  final bool onDark;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundBtn(
            icon: micOn ? Icons.mic : Icons.mic_off,
            label: micOn ? 'Mute' : 'Unmute',
            onDark: onDark,
            onTap: enabled ? onToggleMic : null,
          ),
          _RoundBtn(
            icon: cameraOn ? Icons.videocam : Icons.videocam_off,
            label: cameraOn ? 'Video off' : 'Video on',
            onDark: onDark,
            onTap: enabled ? onToggleCamera : null,
          ),
          _RoundBtn(
            icon: Icons.call_end,
            label: 'End',
            color: SignTalkColors.callRed,
            onDark: onDark,
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
    required this.onDark,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool onDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = color ??
        (disabled
            ? (onDark ? Colors.white12 : SignTalkColors.border.withValues(alpha: 0.5))
            : (onDark ? Colors.white.withValues(alpha: 0.14) : SignTalkColors.card));
    final iconColor = disabled
        ? SignTalkColors.secondaryText
        : (color != null ? Colors.white : (onDark ? Colors.white : SignTalkColors.primaryText));
    final labelColor = onDark ? Colors.white70 : SignTalkColors.secondaryText;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: labelColor), textAlign: TextAlign.center),
        ],
      ),
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
