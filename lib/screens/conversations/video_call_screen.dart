import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/auth/auth_service.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../services/webrtc/call_media_state.dart';
import '../../services/webrtc/webrtc_call_config.dart';
import '../../services/gesture/gesture_demo_labels.dart';
import '../../services/gesture/gesture_recognizer_service.dart';
import '../../services/webrtc/webrtc_call_service.dart';
import '../../theme/sign_talk_colors.dart';

/// Live WebRTC video call with SignTalk assistance (STT/TTS). Requires signaling server.
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.onClose,
  });

  final String contactName;
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
  final _gestures = createGestureRecognizerService();
  Timer? _gesturePollTimer;
  Timer? _remoteGesturePollTimer;
  StreamSubscription<GestureCaptionMessage>? _remoteGestureSub;
  bool _gesturePipelineActive = false;
  bool _remoteGesturePipelineActive = false;
  String _gestureStatus = 'Gestures idle';
  String? _localGestureCaption;
  String? _remoteGestureCaption;
  String? _lastSentGesture;
  DateTime? _lastSentAt;
  String? _lastSpokenRemoteLabel;
  DateTime? _lastSpokenRemoteAt;
  bool _gestureReleaseArmed = true;
  String? _latchedGestureId;
  bool _remoteDetectReleaseArmed = true;
  String? _remoteDetectLatchedId;
  String? _lastRemoteDetectCaption;
  DateTime? _lastRemoteDetectAt;
  bool _callWasLogged = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _signalUrlController = TextEditingController(
      text: WebRtcCallConfig.signalingUrlForPage(),
    );
    _call.addListener(_syncGesturePipelineWithCall);
    _remoteGestureSub = _call.gestureCaptions.listen(_onRemoteGestureCaption);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _closing) return;
      await SignTalkScope.of(context).cameraPreview.stop();
      if (!mounted || _closing) return;
      await _call.ensureRenderers();
      if (mounted && !_closing) setState(() {});
      _syncGesturePipelineWithCall();
    });
    _captions.addListener(_syncCaptionsToField);
  }

  void _syncGesturePipelineWithCall() {
    if (_closing) return;
    final localShould = _call.isActive && _call.hasLocalVideo;
    if (localShould && !_gesturePipelineActive) {
      unawaited(_startGesturePipeline());
    } else if (!localShould && _gesturePipelineActive) {
      _stopLocalGesturePipeline();
    }

    final remoteShould = _call.isActive && _call.hasRemoteVideo;
    if (remoteShould && !_remoteGesturePipelineActive) {
      unawaited(_startRemoteGesturePipeline());
    } else if (!remoteShould && _remoteGesturePipelineActive) {
      _stopRemoteGesturePipeline();
    }
  }

  Future<void> _startGesturePipeline() async {
    if (_closing) return;
    if (_gesturePipelineActive) return;
    if (!_gestures.isSupported) {
      if (!mounted || _closing) return;
      setState(() => _gestureStatus = 'Gestures: Chrome/web only');
      return;
    }
    if (!mounted || _closing) return;
    setState(() => _gestureStatus = 'Loading gesture model…');
    final init = await _gestures.init();
    if (!mounted || _closing) return;
    if (!init.ready) {
      setState(
        () =>
            _gestureStatus = 'Gesture model failed: ${init.error ?? 'unknown'}',
      );
      return;
    }
    GestureStartResult? start;
    String lastVideoId = '';
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted || _closing || !_call.isActive) return;
      lastVideoId = webrtcLocalVideoElementId(_call.localRenderer);
      start = _gestures.startOnVideoElementId(lastVideoId);
      if (start.ok) break;
      if (attempt == 0 || attempt % 4 == 0) {
        setState(
          () => _gestureStatus =
              'Waiting for your camera preview… (${attempt + 1}/24)',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (start == null || !start.ok) {
      setState(
        () => _gestureStatus =
            'Gesture camera hook failed: ${start?.error ?? lastVideoId}. Retrying…',
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted &&
            !_closing &&
            _call.isActive &&
            _call.hasLocalVideo &&
            !_gesturePipelineActive) {
          unawaited(_startGesturePipeline());
        }
      });
      return;
    }
    _gesturePipelineActive = true;
    _gesturePollTimer?.cancel();
    _gesturePollTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _pollLocalGesture(),
    );
    setState(
      () => _gestureStatus = 'Detecting — show HELLO, YES, or STOP pose',
    );
  }

  void _stopLocalGesturePipeline() {
    _gesturePollTimer?.cancel();
    _gesturePollTimer = null;
    _gestures.stop();
    _gesturePipelineActive = false;
    if (mounted && !_closing) {
      setState(() {
        _gestureStatus = 'Gestures stopped';
        _localGestureCaption = null;
      });
    }
  }

  void _stopRemoteGesturePipeline() {
    _remoteGesturePollTimer?.cancel();
    _remoteGesturePollTimer = null;
    _gestures.stopRemote();
    _remoteGesturePipelineActive = false;
    if (mounted && !_closing) {
      setState(() => _remoteGestureCaption = null);
    }
  }

  void _stopGesturePipeline() {
    _stopLocalGesturePipeline();
    _stopRemoteGesturePipeline();
  }

  Future<void> _startRemoteGesturePipeline() async {
    if (_closing) return;
    if (_remoteGesturePipelineActive) return;
    if (!_gestures.isSupported) return;
    final init = await _gestures.init();
    if (!mounted || _closing || !init.ready) return;

    GestureStartResult? start;
    var lastVideoId = '';
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted || _closing || !_call.isActive || !_call.hasRemoteVideo) {
        return;
      }
      lastVideoId = webrtcLocalVideoElementId(_call.remoteRenderer);
      start = _gestures.startRemoteOnVideoElementId(lastVideoId);
      if (start.ok) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (start == null || !start.ok) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted &&
            !_closing &&
            _call.isActive &&
            _call.hasRemoteVideo &&
            !_remoteGesturePipelineActive) {
          unawaited(_startRemoteGesturePipeline());
        }
      });
      return;
    }
    _remoteGesturePipelineActive = true;
    _remoteGesturePollTimer?.cancel();
    _remoteGesturePollTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _pollRemoteVideoGesture(),
    );
  }

  void _pollRemoteVideoGesture() {
    if (_closing) return;
    final det = _gestures.consumeRemoteLatest();
    if (det == null) return;
    if (det.status == 'tracking') {
      _remoteDetectReleaseArmed = true;
      _remoteDetectLatchedId = null;
      return;
    }
    if (!det.isRecognized || det.gesture == null) return;

    final caption = GestureDemoLabels.captionForMediaPipeGesture(det.gesture);
    if (caption == null) return;
    if (!_remoteDetectReleaseArmed && _remoteDetectLatchedId == det.gesture) {
      return;
    }

    final now = DateTime.now();
    if (_lastRemoteDetectCaption == caption &&
        _lastRemoteDetectAt != null &&
        now.difference(_lastRemoteDetectAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRemoteDetectCaption = caption;
    _lastRemoteDetectAt = now;
    _remoteDetectReleaseArmed = false;
    _remoteDetectLatchedId = det.gesture;
    unawaited(_applyPartnerCaption(caption));
  }

  void _pollLocalGesture() {
    if (_closing) return;
    final det = _gestures.consumeLatest();
    if (det == null) return;
    if (det.status == 'error' && det.message != null) {
      if (mounted && !_closing) {
        setState(() => _gestureStatus = 'Error — ${det.message}');
      }
      return;
    }
    if (det.status == 'tracking') {
      _gestureReleaseArmed = true;
      _latchedGestureId = null;
      if (mounted && !_closing) {
        setState(
          () => _gestureStatus =
              'Detecting — open palm, thumb up, or closed fist',
        );
      }
      return;
    }
    if (!det.isRecognized || det.gesture == null) return;

    final caption = GestureDemoLabels.captionForMediaPipeGesture(det.gesture);
    if (caption == null) {
      if (mounted && !_closing) {
        setState(
          () => _gestureStatus =
              'Detecting — only HELLO / YES / STOP are sent in this demo',
        );
      }
      return;
    }

    if (!_gestureReleaseArmed && _latchedGestureId == det.gesture) return;

    final now = DateTime.now();
    if (_lastSentGesture == det.gesture &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 2)) {
      return;
    }

    final sent = _call.sendGestureCaption(
      gesture: det.gesture!,
      label: caption,
      score: det.score,
    );
    if (!sent) {
      if (mounted && !_closing) {
        setState(
          () => _gestureStatus =
              'Error — signaling not joined (caption not sent)',
        );
      }
      return;
    }

    _lastSentGesture = det.gesture;
    _lastSentAt = now;
    _gestureReleaseArmed = false;
    _latchedGestureId = det.gesture;
    if (mounted && !_closing) {
      setState(() {
        _localGestureCaption = caption;
        _gestureStatus = 'Gesture recognized — $caption';
      });
    }
  }

  Future<void> _onRemoteGestureCaption(GestureCaptionMessage msg) async {
    final label = msg.label.trim();
    if (label.isEmpty || !mounted || _closing) return;
    await _applyPartnerCaption(label);
  }

  /// Partner caption on the main video + speak the word only (HELLO / YES / STOP).
  Future<void> _applyPartnerCaption(String label) async {
    if (!mounted || _closing) return;
    setState(() => _remoteGestureCaption = label);
    final now = DateTime.now();
    if (_lastSpokenRemoteLabel == label &&
        _lastSpokenRemoteAt != null &&
        now.difference(_lastSpokenRemoteAt!) < const Duration(seconds: 4)) {
      return;
    }
    _lastSpokenRemoteLabel = label;
    _lastSpokenRemoteAt = now;
    final prefs = SignTalkScope.preferencesOf(context);
    if (!prefs.spokenOutputEnabled) return;

    final tts = SignTalkScope.of(context).textToSpeech;
    await tts.setLanguage(prefs.speechLocale);
    // Do not call tts.stop() before caption speech — breaks Android speechSynthesis.

    final outcome = await tts.speak(label, enabled: true);
    if (outcome == SpeakOutcome.failed && kDebugMode) {
      debugPrint(
        '[SignTalk] Caption TTS failed for "$label" (caption still shown on screen).',
      );
    }
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
    super.deactivate();
  }

  @override
  void dispose() {
    _stopGesturePipeline();
    _call.removeListener(_syncGesturePipelineWithCall);
    unawaited(_remoteGestureSub?.cancel());
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
    SignTalkScope.of(context).textToSpeech.primeWebSpeechFromUserGesture();
    _connecting = true;
    setState(() {});
    await _releaseCameraPreviewForCall();
    await _call.requestLocalMediaPreview();
    _connecting = false;
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    if (_closing) return;
    try {
      await _call.setMicEnabled(!_call.micEnabled);
    } catch (error) {
      if (mounted && !_closing) {
        _showSnack('Could not change microphone state: $error');
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_closing) return;
    try {
      await _call.setCameraEnabled(!_call.cameraEnabled);
    } catch (error) {
      if (mounted && !_closing) {
        _showSnack('Could not change camera state: $error');
      }
    }
  }

  Future<void> _hostCall() async {
    if (_connecting) return;
    SignTalkScope.of(context).textToSpeech.primeWebSpeechFromUserGesture();
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
    SignTalkScope.of(context).textToSpeech.primeWebSpeechFromUserGesture();
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

  Future<void> _closeCall() async {
    if (_closing) return;
    _closing = true;
    final scope = SignTalkScope.of(context);
    widget.onClose();

    if (_call.isActive && !_callWasLogged) {
      _callWasLogged = true;
      await scope.activityLogs.addCall(
        ownerId: scope.authService.currentUser?.userId ?? AuthService.demoUserId,
        contactName: widget.contactName,
        roomId: _roomController.text.trim(),
      );
    }
    _call.removeListener(_syncGesturePipelineWithCall);
    await _remoteGestureSub?.cancel();
    _remoteGestureSub = null;
    _stopGesturePipeline();
    await _stopCaptions();
    await _call.hangUp();
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
    if (mounted && !_closing) {
      setState(() => _captionsListening = false);
    }
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
        final mediaConnected =
            _call.connectionState == CallConnectionState.connected;
        final islStatus = SignTalkScope.of(context)
            .islRecognition
            .rawAdapter
            .displayName;
        final inCall = _call.isActive;

        return ColoredBox(
          color: inCall ? const Color(0xFF0B0B0C) : SignTalkColors.background,
          child: SafeArea(
            child: Column(
              children: [
                _VideoCallTopBar(
                  onDark: inCall,
                  assistExpanded: _assistExpanded,
                  onClose: () => unawaited(_closeCall()),
                  onToggleAssist: () =>
                      setState(() => _assistExpanded = !_assistExpanded),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Column(
                    children: [
                      _EssentialStatusLine(
                        call: _call,
                        connecting: _connecting,
                        onDark: inCall,
                      ),
                      if (inCall) ...[
                        const SizedBox(height: 4),
                        Text(
                          _gestureStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: inCall
                                ? Colors.white60
                                : SignTalkColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
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
                                height: 300,
                                child: _CallVideoStack(
                                  call: _call,
                                  mediaConnected: mediaConnected,
                                  showRemotePlaceholder: true,
                                  localCaption: _localGestureCaption,
                                  remoteCaption: _remoteGestureCaption,
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
                          localCaption: _localGestureCaption,
                          remoteCaption: _remoteGestureCaption,
                        ),
                      ),
                    ),
                  ),
                _CallControls(
                  enabled: true,
                  micOn: _call.micEnabled,
                  cameraOn: _call.cameraEnabled,
                  onDark: inCall,
                  onToggleMic: () => unawaited(_toggleMic()),
                  onToggleCamera: () => unawaited(_toggleCamera()),
                  onEnd: () => unawaited(_closeCall()),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          IconButton(
            onPressed: onToggleAssist,
            icon: Icon(
              assistExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              color: fg,
            ),
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
        : (onDark
              ? Colors.white.withValues(alpha: 0.85)
              : SignTalkColors.secondaryText);

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: color,
      ),
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
      if (call.hasRemoteVideo || call.hasRemoteAudio) {
        return 'Connected — remote media active';
      }
      if (call.signalingState == CallSignalingState.joined) {
        return 'Signaling joined — waiting for remote camera/audio…';
      }
      return 'Waiting for remote media…';
    }
    if (call.signalingState == CallSignalingState.joined &&
        !call.hasRemoteVideo &&
        !call.hasRemoteAudio &&
        call.isActive) {
      return 'Signaling joined — waiting for WebRTC media…';
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
    this.localCaption,
    this.remoteCaption,
  });

  final WebRtcCallService call;
  final bool mediaConnected;
  final bool showRemotePlaceholder;
  final String? localCaption;
  final String? remoteCaption;

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
                            mediaConnected
                                ? 'Waiting for remote video…'
                                : 'Remote participant',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : null),
        ),
        if (remoteCaption != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: _GestureCaptionChip(
              text: remoteCaption!,
              tone: _CaptionTone.remote,
            ),
          ),
        Positioned(
          right: 10,
          top: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 92,
                height: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black54,
                      child: call.localRenderer.srcObject != null
                          ? RTCVideoView(call.localRenderer, mirror: true)
                          : const Center(
                              child: Icon(
                                Icons.videocam_off,
                                color: Colors.white54,
                                size: 26,
                              ),
                            ),
                    ),
                    if (localCaption != null)
                      Positioned(
                        left: 2,
                        right: 2,
                        bottom: 2,
                        child: _GestureCaptionChip(
                          text: localCaption!,
                          tone: _CaptionTone.local,
                          compact: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _CaptionTone { local, remote }

class _GestureCaptionChip extends StatelessWidget {
  const _GestureCaptionChip({
    required this.text,
    required this.tone,
    this.compact = false,
  });

  final String text;
  final _CaptionTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _CaptionTone.local
        ? SignTalkColors.primaryBlue.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.72);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 6 : 10),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 10,
          vertical: compact ? 3 : 6,
        ),
        child: Text(
          text,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 8 : 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
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
          if (WebRtcCallConfig.needsSeparateSignalingTunnel) ...[
            Text(
              WebRtcCallConfig.tunnelSignalingSetupHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: SignTalkColors.primaryBlue, height: 1.35),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: signalUrlController,
            decoration: InputDecoration(
              labelText: 'Signaling WebSocket URL',
              hintText: WebRtcCallConfig.needsSeparateSignalingTunnel
                  ? 'wss://your-signaling-tunnel.trycloudflare.com'
                  : 'wss:// or ws://…',
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
    final bg =
        color ??
        (disabled
            ? (onDark
                  ? Colors.white12
                  : SignTalkColors.border.withValues(alpha: 0.5))
            : (onDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : SignTalkColors.card));
    final iconColor = disabled
        ? SignTalkColors.secondaryText
        : (color != null
              ? Colors.white
              : (onDark ? Colors.white : SignTalkColors.primaryText));
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
          Text(
            label,
            style: TextStyle(fontSize: 11, color: labelColor),
            textAlign: TextAlign.center,
          ),
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
            const Text(
              'Assistance (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              'ISL: $islStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
                    onPressed: captionsListening
                        ? onStopCaptions
                        : onStartCaptions,
                    child: Text(
                      captionsListening ? 'Stop captions' : 'Captions',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onSpeak,
                    child: const Text('Speak'),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onTryIsl,
              child: const Text('ISL adapter status'),
            ),
          ],
        ),
      ),
    );
  }
}
