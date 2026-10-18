import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../services/speech/speech_transcript_controller.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../services/webrtc/call_media_state.dart';
import '../../services/webrtc/webrtc_call_config.dart';
import '../../services/gesture/gesture_demo_labels.dart';
import '../../services/gesture/gesture_recognizer_service.dart';
import '../../services/isl/http_isl_recognition_adapter.dart';
import '../../services/isl/isl_browser_recognizer.dart';
import '../../services/isl/isl_live_recognition.dart';
import '../../services/isl/isl_sentence_composer.dart';
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
  bool _connectionDetailsExpanded = false;
  bool _connecting = false;
  bool _closing = false;
  bool _callWasLogged = false;
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
  bool _gestureHelpExpanded = false;
  final _islLive = IslLiveRecognition();
  final _islBrowser = createIslBrowserRecognizer();
  bool _islBrowserActive = false;
  final _islComposer = IslSentenceComposer();
  Timer? _islPollTimer;
  Timer? _islComposerTickTimer;
  StreamSubscription<IslCaptionMessage>? _islCaptionSub;
  StreamSubscription<SpeechCaptionMessage>? _speechCaptionSub;
  Timer? _speechRelayTimer;
  String _lastSentSpeech = '';
  String? _partnerSpeech;
  bool _islPipelineActive = false;
  bool _islRecognizeBusy = false;
  String _islStatus = 'ISL idle';
  String? _localIslSentence;
  String? _remoteIslSentence;
  String _lastSentIslSentence = '';
  String? _islLiveWord;

  @override
  void initState() {
    super.initState();
    _signalUrlController = TextEditingController(text: WebRtcCallConfig.signalingUrlForPage());
    _call.addListener(_syncGesturePipelineWithCall);
    _remoteGestureSub = _call.gestureCaptions.listen(_onRemoteGestureCaption);
    _islCaptionSub = _call.islCaptions.listen(_onRemoteIslCaption);
    _speechCaptionSub = _call.speechCaptions.listen(_onRemoteSpeechCaption);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SignTalkScope.of(context).cameraPreview.stop();
      await _call.ensureRenderers();
      if (mounted) setState(() {});
      _syncGesturePipelineWithCall();
    });
    _captions.addListener(_syncCaptionsToField);
  }

  void _syncGesturePipelineWithCall() {
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

    _syncIslPipelineWithCall();
  }

  void _syncIslPipelineWithCall() {
    final should = _call.isActive && _call.hasLocalVideo && _islLive.isSupported;
    if (should && !_islPipelineActive) {
      unawaited(_startIslPipeline());
    } else if (!should && _islPipelineActive) {
      _stopIslPipeline();
    }
  }

  Future<void> _startIslPipeline() async {
    if (_islPipelineActive) return;
    _islPipelineActive = true;
    _islComposer.reset();
    SignTalkScope.of(context).islRecognition.resetSmoothing();
    _islPollTimer?.cancel();
    _islPollTimer = null;
    _islComposerTickTimer?.cancel();
    _islComposerTickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final utteranceEnded = _islComposer.tick();
      if (utteranceEnded && mounted) {
        _localIslSentence = null;
        _islLiveWord = null;
        _lastSentIslSentence = '';
        SignTalkScope.of(context).islRecognition.resetSmoothing();
        setState(() => _islStatus = 'ISL — ready for next sentence');
      } else {
        _syncIslSentenceToUi();
      }
    });
    if (_islBrowser.isSupported) {
      final ready = await _islBrowser.init();
      var started = false;
      if (ready) {
        for (var attempt = 0; attempt < 24; attempt++) {
          if (!mounted || !_call.isActive || !_islPipelineActive) return;
          final videoId = webrtcLocalVideoElementId(_call.localRenderer);
          if (_islBrowser.start(videoId)) {
            started = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      if (started) {
        _islBrowserActive = true;
        _stopLocalGesturePipeline();
        _islPollTimer?.cancel();
        _islPollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _pollBrowserIsl());
        if (mounted) {
          setState(() => _islStatus = 'ISL — INCLUDE model, 263 words. Hold each sign about 2 seconds.');
        }
        return;
      }
    }

    _islPollTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) => unawaited(_pollIslFromLocalVideo()));
    if (mounted) {
      setState(() => _islStatus = 'ISL — hold signs; pauses build a sentence');
    }
    unawaited(_pollIslFromLocalVideo());
  }

  void _stopIslPipeline() {
    _islPollTimer?.cancel();
    _islPollTimer = null;
    if (_islBrowserActive) {
      _islBrowser.stop();
      _islBrowserActive = false;
    }
    _islComposerTickTimer?.cancel();
    _islComposerTickTimer = null;
    _islPipelineActive = false;
    if (mounted) {
      setState(() {
        _islStatus = 'ISL stopped';
        _localIslSentence = null;
      });
    }
  }

  void _pollBrowserIsl() {
    if (!_islBrowserActive || !_call.isActive) return;
    final hit = _islBrowser.consume();
    if (hit == null) return;
    if (hit.status == 'error' && hit.message != null) {
      if (mounted) setState(() => _islStatus = 'ISL — ${hit.message}');
      return;
    }
    if (!hit.isRecognized) return;
    _islComposer.observeStableWord(hit.word!);
    _islLiveWord = _islComposer.liveWordLabel;
    _syncIslSentenceToUi();
    _maybeRelayIslCaption(
      word: hit.word!,
      confidence: hit.score,
    );
    if (mounted) setState(() => _islStatus = 'ISL: ${_islComposer.liveWordLabel}');
  }

  Future<void> _pollIslFromLocalVideo() async {
    if (!_islPipelineActive || _islRecognizeBusy || !_call.isActive) return;
    _islRecognizeBusy = true;
    final videoId = webrtcLocalVideoElementId(_call.localRenderer);
    final isl = SignTalkScope.of(context).islRecognition;
    final result = await _islLive.recognizeFromVideo(isl: isl, videoElementId: videoId, frameCount: 8);
    if (!mounted) return;
    _islRecognizeBusy = false;

    if (result.isSuccess && result.label != null) {
      _islComposer.observeStableWord(result.label!);
      _islLiveWord = _islComposer.liveWordLabel;
      _syncIslSentenceToUi();
      _maybeRelayIslCaption(
        word: _islComposer.glosses.isNotEmpty ? _islComposer.glosses.last : result.label!,
        confidence: result.confidence ?? 0,
      );
      setState(() => _islStatus = 'ISL word: ${result.label}');
    } else if (result.uncertain) {
      setState(() => _islStatus = result.message ?? 'ISL detecting…');
    }
  }

  void _maybeRelayIslCaption({required String word, required double confidence}) {
    final sentence = _islComposer.readableSentence.isNotEmpty
        ? _islComposer.readableSentence
        : _islComposer.liveWordLabel;
    if (sentence.isEmpty) return;
    if (sentence == _lastSentIslSentence) return;
    _lastSentIslSentence = sentence;
    _call.sendIslCaption(word: word, sentence: sentence, confidence: confidence);
  }

  void _syncIslSentenceToUi() {
    _islLiveWord = _islComposer.liveWordLabel.isNotEmpty ? _islComposer.liveWordLabel : _islLiveWord;
    final text = _islComposer.readableSentence.isNotEmpty
        ? _islComposer.readableSentence
        : _islComposer.displayText;
    if (text.isEmpty) return;
    _localIslSentence = text;
    _assistController.text = text;
    _assistController.selection = TextSelection.collapsed(offset: text.length);
    if (mounted) setState(() {});
  }

  void _onRemoteIslCaption(IslCaptionMessage msg) {
    if (!mounted) return;
    setState(() {
      _remoteIslSentence = msg.sentence.isNotEmpty ? msg.sentence : msg.word;
    });
    final prefs = SignTalkScope.preferencesOf(context);
    if (prefs.spokenOutputEnabled && msg.sentence.isNotEmpty) {
      unawaited(SignTalkScope.of(context).textToSpeech.speak(
            msg.sentence,
            enabled: true,
          ));
    }
  }

  Future<void> _startGesturePipeline() async {
    if (_gesturePipelineActive) return;
    if (!_gestures.isSupported) {
      setState(() => _gestureStatus = 'Gestures: Chrome/web only');
      return;
    }
    setState(() => _gestureStatus = 'Loading gesture model…');
    final init = await _gestures.init();
    if (!mounted) return;
    if (!init.ready) {
      setState(() => _gestureStatus = 'Gesture model failed: ${init.error ?? 'unknown'}');
      return;
    }
    GestureStartResult? start;
    String lastVideoId = '';
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted || !_call.isActive) return;
      lastVideoId = webrtcLocalVideoElementId(_call.localRenderer);
      start = _gestures.startOnVideoElementId(lastVideoId);
      if (start.ok) break;
      if (attempt == 0 || attempt % 4 == 0) {
        setState(() => _gestureStatus = 'Waiting for your camera preview… (${attempt + 1}/24)');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (start == null || !start.ok) {
      setState(
        () => _gestureStatus =
            'Gesture camera hook failed: ${start?.error ?? lastVideoId}. Retrying…',
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _call.isActive && _call.hasLocalVideo && !_gesturePipelineActive) {
          unawaited(_startGesturePipeline());
        }
      });
      return;
    }
    _gesturePipelineActive = true;
    _gesturePollTimer?.cancel();
    _gesturePollTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => _pollLocalGesture());
    setState(() => _gestureStatus = 'Detecting — show HELLO, YES, or STOP pose');
  }

  void _stopLocalGesturePipeline() {
    _gesturePollTimer?.cancel();
    _gesturePollTimer = null;
    _gestures.stop();
    _gesturePipelineActive = false;
    if (mounted) {
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
    if (mounted) {
      setState(() => _remoteGestureCaption = null);
    }
  }

  void _stopGesturePipeline() {
    _stopLocalGesturePipeline();
    _stopRemoteGesturePipeline();
  }

  Future<void> _startRemoteGesturePipeline() async {
    if (_remoteGesturePipelineActive) return;
    if (!_gestures.isSupported) return;
    final init = await _gestures.init();
    if (!mounted || !init.ready) return;

    GestureStartResult? start;
    var lastVideoId = '';
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!mounted || !_call.isActive || !_call.hasRemoteVideo) return;
      lastVideoId = webrtcLocalVideoElementId(_call.remoteRenderer);
      start = _gestures.startRemoteOnVideoElementId(lastVideoId);
      if (start.ok) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (start == null || !start.ok) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _call.isActive && _call.hasRemoteVideo && !_remoteGesturePipelineActive) {
          unawaited(_startRemoteGesturePipeline());
        }
      });
      return;
    }
    _remoteGesturePipelineActive = true;
    _remoteGesturePollTimer?.cancel();
    _remoteGesturePollTimer =
        Timer.periodic(const Duration(milliseconds: 150), (_) => _pollRemoteVideoGesture());
  }

  void _pollRemoteVideoGesture() {
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
    if (!_remoteDetectReleaseArmed && _remoteDetectLatchedId == det.gesture) return;

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
    final det = _gestures.consumeLatest();
    if (det == null) return;
    if (det.status == 'error' && det.message != null) {
      if (mounted) setState(() => _gestureStatus = 'Error — ${det.message}');
      return;
    }
    if (det.status == 'tracking') {
      _gestureReleaseArmed = true;
      _latchedGestureId = null;
      if (mounted) {
        setState(() => _gestureStatus = 'Detecting — open palm, thumb up, or closed fist');
      }
      return;
    }
    if (!det.isRecognized || det.gesture == null) return;

    final caption = GestureDemoLabels.captionForMediaPipeGesture(det.gesture);
    if (caption == null) {
      if (mounted) {
        setState(
          () => _gestureStatus = 'Detecting — only HELLO / YES / STOP are sent in this demo',
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
      if (mounted) setState(() => _gestureStatus = 'Error — signaling not joined (caption not sent)');
      return;
    }

    _lastSentGesture = det.gesture;
    _lastSentAt = now;
    _gestureReleaseArmed = false;
    _latchedGestureId = det.gesture;
    if (mounted) {
      setState(() {
        _localGestureCaption = caption;
        _gestureStatus = 'Gesture recognized — $caption';
      });
    }
  }

  Future<void> _onRemoteGestureCaption(GestureCaptionMessage msg) async {
    final label = msg.label.trim();
    if (label.isEmpty || !mounted) return;
    await _applyPartnerCaption(label);
  }

  /// Partner caption on the main video + speak the word only (HELLO / YES / STOP).
  Future<void> _applyPartnerCaption(String label) async {
    if (!mounted) return;
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
      debugPrint('[SignTalk] Caption TTS failed for "$label" (caption still shown on screen).');
    }
  }

  void _syncCaptionsToField() {
    final t = _captions.text;
    if (_assistController.text != t) {
      _assistController.text = t;
      _assistController.selection = TextSelection.collapsed(offset: t.length);
    }
    _scheduleSpeechRelay();
    if (mounted) setState(() {});
  }

  void _scheduleSpeechRelay() {
    _speechRelayTimer?.cancel();
    _speechRelayTimer = Timer(const Duration(milliseconds: 350), () {
      final text = _captions.text.trim();
      if (text.isEmpty || text == _lastSentSpeech) return;
      final clipped = text.length > 240 ? text.substring(text.length - 240) : text;
      if (_call.sendSpeechCaption(clipped)) {
        _lastSentSpeech = clipped;
      }
    });
  }

  void _onRemoteSpeechCaption(SpeechCaptionMessage msg) {
    final text = msg.text.trim();
    if (text.isEmpty || !mounted) return;
    setState(() => _partnerSpeech = text);
  }

  @override
  void deactivate() {
    _stopGesturePipeline();
    _stopIslPipeline();
    unawaited(_stopCaptions());
    unawaited(_call.hangUp());
    super.deactivate();
  }

  @override
  void dispose() {
    _stopGesturePipeline();
    _stopIslPipeline();
    _call.removeListener(_syncGesturePipelineWithCall);
    unawaited(_remoteGestureSub?.cancel());
    unawaited(_islCaptionSub?.cancel());
    unawaited(_speechCaptionSub?.cancel());
    _speechRelayTimer?.cancel();
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

  Future<void> _recordCallIfNeeded() async {
    if (_callWasLogged || !_call.isActive) return;
    _callWasLogged = true;
    await SignTalkScope.of(context).activityLogs.addCall(
      contactName: widget.contactName,
      roomId: _roomController.text.trim(),
    );
  }

  Future<void> _closeCall() async {
    if (_closing) return;
    _closing = true;
    await _recordCallIfNeeded();
    if (mounted) widget.onClose();
  }

  Future<void> _endCall() async {
    await _recordCallIfNeeded();
    _stopGesturePipeline();
    _stopIslPipeline();
    await _stopCaptions();
    await _call.hangUp();
    if (mounted) {
      setState(() {
        _remoteGestureCaption = null;
        _remoteIslSentence = null;
        _partnerSpeech = null;
      });
    }
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
    final raw = isl.rawAdapter;
    if (raw is HttpIslRecognitionAdapter) {
      await raw.refreshHealth();
    }
    final videoId = webrtcLocalVideoElementId(_call.localRenderer);
    final result = await _islLive.recognizeFromVideo(isl: isl, videoElementId: videoId);
    _showSnack(result.message ?? isl.rawAdapter.displayName);
    if (result.isSuccess && result.label != null) {
      _islComposer.observeStableWord(result.label!);
      _syncIslSentenceToUi();
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
                  contactName: widget.contactName,
                  onClose: () => unawaited(_closeCall()),
                  onToggleAssist: () => setState(() => _assistExpanded = !_assistExpanded),
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
                            color: inCall ? Colors.white60 : SignTalkColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _islStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: inCall ? Colors.white54 : SignTalkColors.secondaryText,
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
                                height: 200,
                                child: _CallVideoStack(
                                  call: _call,
                                  mediaConnected: mediaConnected,
                                  showRemotePlaceholder: true,
                                  localCaption: _localGestureCaption,
                                  remoteCaption: _remoteGestureCaption,
                                  islLocalSentence: _localIslSentence,
                                  islLocalLiveWord: _islLiveWord,
                                  islPartnerSentence: _remoteIslSentence,
                          partnerSpeech: _partnerSpeech,
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
                          islLocalSentence: _localIslSentence,
                          islLocalLiveWord: _islLiveWord,
                          islPartnerSentence: _remoteIslSentence,
                          partnerSpeech: _partnerSpeech,
                        ),
                      ),
                    ),
                  ),
                _CallControls(
                  enabled: _call.localMediaReady || _call.isActive,
                  micOn: _call.micEnabled,
                  cameraOn: _call.cameraEnabled,
                  captionsOn: _captionsListening,
                  onDark: inCall,
                  onToggleMic: () => unawaited(_call.setMicEnabled(!_call.micEnabled)),
                  onToggleCamera: () => unawaited(_call.setCameraEnabled(!_call.cameraEnabled)),
                  onToggleCaptions: () => unawaited(
                    _captionsListening ? _stopCaptions() : _startCaptions(),
                  ),
                  onEnd: () => unawaited(_endCall()),
                ),
                if (!inCall || MediaQuery.sizeOf(context).height >= 700) ...[
                  _ConnectionDetailsSection(
                    call: _call,
                    connecting: _connecting,
                    initiallyExpanded: _connectionDetailsExpanded,
                    onExpansionChanged: (v) => setState(() => _connectionDetailsExpanded = v),
                  ),
                  _GestureDemoHelpSection(
                    initiallyExpanded: _gestureHelpExpanded,
                    onExpansionChanged: (v) => setState(() => _gestureHelpExpanded = v),
                  ),
                ],
                if (_assistExpanded)
                  _AssistancePanel(
                    controller: _assistController,
                    captionsListening: _captionsListening,
                    islStatus: islStatus,
                    islSentenceHint: _localIslSentence ?? _islComposer.displayText,
                    remoteIslSentence: _remoteIslSentence,
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
    required this.contactName,
    required this.onClose,
    required this.onToggleAssist,
  });

  final bool onDark;
  final bool assistExpanded;
  final String contactName;
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
              contactName,
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
    this.islLocalSentence,
    this.islLocalLiveWord,
    this.islPartnerSentence,
    this.partnerSpeech,
  });

  final WebRtcCallService call;
  final bool mediaConnected;
  final bool showRemotePlaceholder;
  final String? localCaption;
  final String? remoteCaption;
  final String? islLocalSentence;
  final String? islLocalLiveWord;
  final String? islPartnerSentence;
  final String? partnerSpeech;

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
        if (partnerSpeech != null && partnerSpeech!.isNotEmpty)
          Positioned(
            left: 10,
            right: 110,
            top: 10,
            child: _SpeechBanner(text: partnerSpeech!),
          ),
        if (islPartnerSentence != null && islPartnerSentence!.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _IslVideoSubtitleBar(
              title: 'Partner',
              liveWord: null,
              sentence: islPartnerSentence!,
            ),
          )
        else if (remoteCaption != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: _GestureCaptionChip(text: remoteCaption!, tone: _CaptionTone.remote),
          ),
        if (islLocalSentence != null && islLocalSentence!.isNotEmpty)
          Positioned(
            left: 0,
            right: 96,
            bottom: islPartnerSentence != null && islPartnerSentence!.isNotEmpty ? 52 : 0,
            child: _IslVideoSubtitleBar(
              title: 'You',
              liveWord: islLocalLiveWord,
              sentence: islLocalSentence!,
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
                BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
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
                              child: Icon(Icons.videocam_off, color: Colors.white54, size: 26),
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

class _IslVideoSubtitleBar extends StatelessWidget {
  const _IslVideoSubtitleBar({
    required this.title,
    required this.sentence,
    this.liveWord,
  });

  final String title;
  final String? liveWord;
  final String sentence;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.82),
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (liveWord != null && liveWord!.isNotEmpty)
              Text(
                '$title · signing: $liveWord',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            Text(
              sentence,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10, vertical: compact ? 3 : 6),
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
            'Gesture captions use the signaling WebSocket (type gesture_caption) when a data channel is not configured.',
            style: TextStyle(fontSize: 11, color: SignTalkColors.secondaryText, height: 1.35),
          ),
          const SizedBox(height: 4),
          const Text(
            'Run the signaling server on your PC (port 8765). Use ws://127.0.0.1:8765 on this device or your LAN IP / wss:// when the app is served over HTTPS. Allow inbound TCP 8765 on Private networks in Windows Firewall if needed.',
            style: TextStyle(fontSize: 11, color: SignTalkColors.secondaryText, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _GestureDemoHelpSection extends StatelessWidget {
  const _GestureDemoHelpSection({
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

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
          'Demo gestures (prototype)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SignTalkColors.primaryText),
        ),
        subtitle: Text(
          GestureDemoLabels.prototypeDisclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          for (final g in GestureDemoLabels.demoGestures) ...[
            Text(
              g.caption,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SignTalkColors.primaryText),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(g.poseHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35)),
            ),
          ],
          Text(
            'The call uses the INCLUDE Indian Sign Language model (263 words, including Hello, '
            'family, colours, places, and everyday words). Hold a sign for about two seconds. '
            'The word shows on the video and is spoken on the other side. '
            'This is isolated-word recognition, not a full interpreter of every ISL sentence.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            'After each caption, lower your hand briefly before repeating the same gesture.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.35),
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
          if (WebRtcCallConfig.needsSeparateSignalingTunnel) ...[
            Text(
              WebRtcCallConfig.tunnelSignalingSetupHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SignTalkColors.primaryBlue,
                    height: 1.35,
                  ),
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

class _SpeechBanner extends StatelessWidget {
  const _SpeechBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF0143D36),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  const _CallControls({
    required this.enabled,
    required this.micOn,
    required this.cameraOn,
    required this.captionsOn,
    required this.onDark,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleCaptions,
    required this.onEnd,
  });

  final bool enabled;
  final bool micOn;
  final bool cameraOn;
  final bool captionsOn;
  final bool onDark;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleCaptions;
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
            icon: captionsOn ? Icons.closed_caption : Icons.closed_caption_disabled,
            label: captionsOn ? 'Captions on' : 'Captions',
            onDark: onDark,
            onTap: enabled ? onToggleCaptions : null,
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
    required this.islSentenceHint,
    required this.remoteIslSentence,
    required this.onStartCaptions,
    required this.onStopCaptions,
    required this.onSpeak,
    required this.onTryIsl,
  });

  final TextEditingController controller;
  final bool captionsListening;
  final String islStatus;
  final String islSentenceHint;
  final String? remoteIslSentence;
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
            if (islSentenceHint.isNotEmpty)
              Text('Your sentence: $islSentenceHint', style: Theme.of(context).textTheme.bodySmall),
            if (remoteIslSentence != null && remoteIslSentence!.isNotEmpty)
              Text('Partner: $remoteIslSentence', style: Theme.of(context).textTheme.bodySmall),
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
