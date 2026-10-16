import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../gesture/gesture_detection.dart';
import 'call_media_state.dart';
import 'ice_candidate_buffer.dart';
import 'webrtc_call_config.dart';

enum CallConnectionState { idle, connecting, connected, failed, ended }

/// WebRTC peer session with WebSocket signaling (see tools/signaling-server).
class WebRtcCallService extends ChangeNotifier {
  WebRtcCallService();

  static String get defaultSignalingUrl => WebRtcCallConfig.signalingUrlForPage();

  static final _idRandom = Random();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  WebSocketChannel? _channel;
  StreamSubscription? _signalSub;
  String? _roomId;
  String? _participantId;
  bool _isHost = false;
  bool _makingOffer = false;
  int _signalingGeneration = 0;
  bool _signalingJoined = false;
  bool _mediaRequestInFlight = false;

  final IceCandidateBuffer _iceBuffer = IceCandidateBuffer();
  Future<void> _signalingChain = Future<void>.value();
  Timer? _negotiationTimeout;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  CallConnectionState connectionState = CallConnectionState.idle;
  CallMediaAccessState mediaAccessState = CallMediaAccessState.idle;
  CallSignalingState signalingState = CallSignalingState.idle;
  CallMediaPathState mediaPathState = CallMediaPathState.idle;

  String? statusMessage;
  String? errorMessage;
  String? mediaAccessDetail;
  bool micEnabled = true;
  bool cameraEnabled = true;
  int peersInRoom = 0;
  bool hasRemoteAudio = false;
  bool hasRemoteVideo = false;
  bool hasLocalAudio = false;
  bool hasLocalVideo = false;
  String lastIceConnectionState = 'new';
  String lastPeerConnectionState = 'new';
  int remoteTracksReceived = 0;

  final StreamController<GestureCaptionMessage> _gestureCaptionController =
      StreamController<GestureCaptionMessage>.broadcast();

  /// Remote peer gesture captions relayed over signaling WebSocket.
  Stream<GestureCaptionMessage> get gestureCaptions => _gestureCaptionController.stream;

  bool get isActive =>
      connectionState == CallConnectionState.connecting ||
      connectionState == CallConnectionState.connected;

  bool get localMediaReady => _localStream != null;

  Map<String, dynamic> get rtcConfiguration => {
        'iceServers': WebRtcCallConfig.iceServers(),
      };

  Future<void> ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  /// User-triggered permission probe (lobby) — does not start signaling.
  Future<void> requestLocalMediaPreview() async {
    if (_mediaRequestInFlight) return;
    _mediaRequestInFlight = true;
    mediaAccessState = CallMediaAccessState.requesting;
    mediaAccessDetail = null;
    errorMessage = null;
    notifyListeners();
    try {
      await _ensureLocalMedia(disposeExisting: true);
      mediaAccessState = CallMediaAccessState.granted;
      mediaAccessDetail = _localMediaSummary();
      localRenderer.srcObject = _localStream;
      notifyListeners();
    } catch (e) {
      _setMediaAccessError(e);
    } finally {
      _mediaRequestInFlight = false;
      notifyListeners();
    }
  }

  Future<void> connectToRoom({
    required String signalingUrl,
    required String roomId,
    required bool asHost,
  }) async {
    if (_mediaRequestInFlight) return;
    await hangUp(notify: false);
    final session = _signalingGeneration;
    try {
      _roomId = _normalizeRoomId(roomId);
    } on ArgumentError catch (e) {
      _failSignaling(e.message?.toString() ?? e.toString());
      return;
    }
    _participantId = _newParticipantId();
    _isHost = asHost;
    _signalingJoined = false;
    errorMessage = null;
    mediaAccessDetail = null;
    statusMessage = 'Connecting to signaling…';
    connectionState = CallConnectionState.connecting;
    signalingState = CallSignalingState.connecting;
    mediaPathState = CallMediaPathState.negotiating;
    notifyListeners();

    final trimmedUrl = signalingUrl.trim();
    if (trimmedUrl.isEmpty) {
      _failSignaling(
        'Signaling WebSocket URL is empty. For Cloudflare demos, open the public app URL or set SIGNALING_URL / sign_talk_public_demo_config.dart.',
      );
      return;
    }

    try {
      await ensureRenderers();
      final uri = Uri.parse(trimmedUrl);
      _logSignaling('connect uri=$uri room=$_roomId host=$asHost id=$_participantId');
      _channel = WebSocketChannel.connect(uri);
      try {
        await _channel!.ready;
      } catch (e) {
        if (session != _signalingGeneration) return;
        _failSignaling(
          'Signaling unreachable at $uri. '
          'Check server, Wi‑Fi, and Windows Firewall (TCP ${uri.port}). Error: $e',
        );
        return;
      }
      if (session != _signalingGeneration) return;
      _logSignaling('websocket open');

      _signalSub = _channel!.stream.listen(
        _onSignalMessage,
        onError: (Object e) {
          if (session != _signalingGeneration) return;
          _failSignaling('Signaling error: $e');
        },
        onDone: () {
          if (session != _signalingGeneration) return;
          if (connectionState == CallConnectionState.ended) return;
          signalingState = CallSignalingState.disconnected;
          final detail = _formatCloseDetail(_channel?.closeCode, _channel?.closeReason);
          if (!_signalingJoined) {
            _failSignaling(
              'Signaling closed before joining$detail. '
              'Use your PC LAN IP in the signaling URL on the phone.',
            );
          } else {
            statusMessage = 'Signaling disconnected$detail — you can leave and rejoin.';
            mediaPathState = CallMediaPathState.reconnecting;
            notifyListeners();
          }
        },
      );

      _send({
        'type': 'join',
        'room': _roomId,
        'participantId': _participantId,
        'role': asHost ? 'host' : 'guest',
      });
      statusMessage = asHost ? 'Waiting for guest…' : 'Waiting for host…';
      notifyListeners();

      if (asHost) {
        try {
          mediaPathState = CallMediaPathState.preparingLocalMedia;
          notifyListeners();
          await _preparePeerConnection();
          _startNegotiationTimeout(session);
        } catch (e) {
          if (session != _signalingGeneration) return;
          _failMedia('Could not access camera/microphone: $e');
        }
      }
    } catch (e) {
      if (session != _signalingGeneration) return;
      _failSignaling('Could not connect signaling: $e');
    }
  }

  String _normalizeRoomId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 2 || trimmed.length > 64) {
      throw ArgumentError('Room ID must be 2–64 characters.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      throw ArgumentError('Room ID may only use letters, numbers, _ and -.');
    }
    return trimmed;
  }

  String _newParticipantId() =>
      'p-${DateTime.now().millisecondsSinceEpoch}-${_idRandom.nextInt(1 << 20)}';

  void _startNegotiationTimeout(int session) {
    _negotiationTimeout?.cancel();
    _negotiationTimeout = Timer(const Duration(seconds: 45), () {
      if (session != _signalingGeneration) return;
      if (connectionState == CallConnectionState.connected) return;
      _failMedia(
        'Call setup timed out. Check ICE/TURN, firewall, and that both sides granted camera/mic.',
      );
    });
  }

  void _clearNegotiationTimeout() {
    _negotiationTimeout?.cancel();
    _negotiationTimeout = null;
  }

  static String _formatCloseDetail(int? code, String? reason) {
    if (code == null && (reason == null || reason.isEmpty)) return '';
    final parts = <String>[];
    if (code != null) parts.add('code=$code');
    if (reason != null && reason.isNotEmpty) parts.add('reason=$reason');
    return ' (${parts.join(', ')})';
  }

  void _logSignaling(String message) {
    if (kDebugMode) debugPrint('[SignTalk signaling] $message');
  }

  void _logMedia(String message) {
    if (kDebugMode) debugPrint('[SignTalk media] $message');
  }

  Future<void> _preparePeerConnection() async {
    await _ensureLocalMedia();
    if (_peerConnection != null) return;
    _peerConnection = await createPeerConnection(rtcConfiguration);
    _wirePeerConnection(_peerConnection!);
    var trackCount = 0;
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      trackCount++;
    }
    _logMedia('addTrack count=$trackCount');
    localRenderer.srcObject = _localStream;
    notifyListeners();
  }

  Future<void> _ensureLocalMedia({bool disposeExisting = false}) async {
    if (_localStream != null && !disposeExisting) {
      _refreshLocalTrackFlags();
      return;
    }
    if (_localStream != null && disposeExisting) {
      await _localStream!.dispose();
      _localStream = null;
      localRenderer.srcObject = null;
    }
    if (!WebRtcCallConfig.pageIsSecureContext) {
      throw StateError(WebRtcCallConfig.secureContextHint);
    }
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });
      _localStream = stream;
      _refreshLocalTrackFlags();
      micEnabled = stream.getAudioTracks().every((t) => t.enabled);
      cameraEnabled = stream.getVideoTracks().every((t) => t.enabled);
      mediaAccessState = CallMediaAccessState.granted;
      _logMedia(
        'getUserMedia ok audio=${stream.getAudioTracks().length} '
        'video=${stream.getVideoTracks().length}',
      );
      if (!hasLocalAudio && !hasLocalVideo) {
        throw StateError('No audio or video tracks returned from the device.');
      }
    } catch (e) {
      _logMedia('getUserMedia failed: $e');
      rethrow;
    }
  }

  void _refreshLocalTrackFlags() {
    final stream = _localStream;
    hasLocalAudio = stream?.getAudioTracks().isNotEmpty ?? false;
    hasLocalVideo = stream?.getVideoTracks().isNotEmpty ?? false;
  }

  void _refreshRemoteTrackFlags() {
    final stream = _remoteStream;
    hasRemoteAudio = stream?.getAudioTracks().isNotEmpty ?? false;
    hasRemoteVideo = stream?.getVideoTracks().isNotEmpty ?? false;
  }

  String _localMediaSummary() {
    return 'Camera: ${hasLocalVideo ? (cameraEnabled ? 'on' : 'muted') : 'none'}, '
        'Mic: ${hasLocalAudio ? (micEnabled ? 'on' : 'muted') : 'none'}';
  }

  void _setMediaAccessError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('notallowed') || text.contains('permission') || text.contains('denied')) {
      mediaAccessState = CallMediaAccessState.denied;
      mediaAccessDetail =
          'Permission denied. In Chrome: tap the lock icon → Site settings → allow Camera and Microphone, then retry.';
    } else if (text.contains('notfound') || text.contains('devicesnotfound')) {
      mediaAccessState = CallMediaAccessState.unavailable;
      mediaAccessDetail = 'No camera or microphone found on this device.';
    } else {
      mediaAccessState = CallMediaAccessState.error;
      mediaAccessDetail = 'Media error: $e';
    }
    errorMessage = mediaAccessDetail;
  }

  void _wirePeerConnection(RTCPeerConnection pc) {
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send({
        'type': 'candidate',
        'candidate': candidate.toMap(),
        'from': _participantId,
      });
    };
    pc.onTrack = (event) {
      unawaited(_onRemoteTrack(event));
    };
    pc.onIceConnectionState = (state) {
      lastIceConnectionState = state.name;
      _logMedia('iceConnectionState=$state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _maybeMarkConnected('ICE $state');
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          mediaPathState = CallMediaPathState.reconnecting;
          statusMessage = 'Connection interrupted — attempting recovery…';
          notifyListeners();
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _failMedia('ICE connection failed — try same Wi‑Fi or configure TURN.');
        default:
          statusMessage = 'ICE: $state';
          notifyListeners();
      }
    };
    pc.onConnectionState = (state) {
      lastPeerConnectionState = state.name;
      _logMedia('connectionState=$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _failMedia('Peer connection failed');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _maybeMarkConnected('Peer $state');
      } else {
        statusMessage = 'Peer: $state';
        notifyListeners();
      }
    };
  }

  void _maybeMarkConnected(String reason) {
    if (!hasRemoteVideo && !hasRemoteAudio) {
      statusMessage = '$reason — waiting for remote media…';
      notifyListeners();
      return;
    }
    _clearNegotiationTimeout();
    connectionState = CallConnectionState.connected;
    mediaPathState = CallMediaPathState.connected;
    statusMessage = 'Connected — audio and video active when tracks are present.';
    notifyListeners();
  }

  Future<void> _onRemoteTrack(RTCTrackEvent event) async {
    _logMedia('onTrack streams=${event.streams.length} kind=${event.track.kind}');
    event.track.enabled = true;
    MediaStream? stream;
    if (event.streams.isNotEmpty) {
      stream = event.streams.first;
    } else {
      _remoteStream ??= await createLocalMediaStream('remote-${_roomId ?? 'call'}');
      await _remoteStream!.addTrack(event.track);
      stream = _remoteStream;
    }
    _remoteStream = stream;
    remoteTracksReceived++;
    _refreshRemoteTrackFlags();
    remoteRenderer.srcObject = stream;
    for (final t in stream?.getAudioTracks() ?? []) {
      t.enabled = true;
    }
    _logMedia(
      'remote tracks total=$remoteTracksReceived '
      'audio=$hasRemoteAudio video=$hasRemoteVideo',
    );
    _maybeMarkConnected('Remote ${event.track.kind} track');
  }

  Future<void> _clearRemoteMedia() async {
    _remoteStream = null;
    hasRemoteAudio = false;
    hasRemoteVideo = false;
    remoteRenderer.srcObject = null;
    if (connectionState == CallConnectionState.connected) {
      connectionState = CallConnectionState.connecting;
    }
  }

  /// Host resets peer connection so a new guest can complete offer/answer.
  Future<void> _prepareForPeerRejoin() async {
    await _clearRemoteMedia();
    _iceBuffer.reset();
    await _peerConnection?.close();
    _peerConnection = null;
    if (_isHost && _localStream != null) {
      await _preparePeerConnection();
    }
    mediaPathState = CallMediaPathState.reconnecting;
    statusMessage = 'Waiting for participant to rejoin…';
    notifyListeners();
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null || !_isHost) return;
    _makingOffer = true;
    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _logMedia('setLocalDescription offer');
      _send({'type': 'offer', 'sdp': offer.toMap(), 'from': _participantId});
      statusMessage = 'Offer sent — waiting for answer…';
      notifyListeners();
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> sdpMap, {String? from}) async {
    if (_isHost) {
      _logSignaling('ignore offer (local role is host)');
      return;
    }
    try {
      if (_peerConnection == null) {
        mediaPathState = CallMediaPathState.preparingLocalMedia;
        notifyListeners();
        try {
          await _preparePeerConnection();
        } catch (e) {
          _failMedia('Could not access camera/microphone: $e');
          return;
        }
      }
      final offer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(offer);
      _iceBuffer.markRemoteDescriptionSet();
      _logMedia('setRemoteDescription offer from=${from ?? '?'}');
      await _flushIceCandidates();
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _logMedia('setLocalDescription answer');
      _send({'type': 'answer', 'sdp': answer.toMap(), 'from': _participantId});
      statusMessage = 'Answer sent';
      notifyListeners();
    } catch (e) {
      _failMedia('Failed to handle offer: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> sdpMap) async {
    if (!_isHost) {
      _logSignaling('ignore answer (local role is guest)');
      return;
    }
    try {
      final answer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(answer);
      _iceBuffer.markRemoteDescriptionSet();
      _logMedia('setRemoteDescription answer');
      await _flushIceCandidates();
      statusMessage = 'Remote answer applied';
      notifyListeners();
    } catch (e) {
      _failMedia('Failed to handle answer: $e');
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> candMap) async {
    if (_peerConnection == null || !_iceBuffer.canApply) {
      _iceBuffer.enqueue(candMap);
      _logMedia('ice queued total=${_iceBuffer.queuedCount}');
      return;
    }
    await _applyIceCandidate(candMap);
  }

  Future<void> _applyIceCandidate(Map<String, dynamic> candMap) async {
    final pc = _peerConnection;
    if (pc == null) return;
    try {
      final candidate = RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      );
      await pc.addCandidate(candidate);
      _iceBuffer.appliedCount++;
    } catch (e) {
      _iceBuffer.enqueue(candMap);
      _logMedia('ice apply failed, re-queued: $e');
    }
  }

  Future<void> _flushIceCandidates() async {
    final result = await _iceBuffer.flush(_applyIceCandidateImmediate);
    _logMedia('ice flush applied=${result.applied} requeued=${result.requeued}');
  }

  Future<void> _applyIceCandidateImmediate(Map<String, dynamic> candMap) async {
    if (_peerConnection == null || !_iceBuffer.canApply) {
      throw StateError('not ready');
    }
    final candidate = RTCIceCandidate(
      candMap['candidate'],
      candMap['sdpMid'],
      candMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
    _iceBuffer.appliedCount++;
  }

  void _onSignalMessage(dynamic raw) {
    _signalingChain = _signalingChain.then((_) => _processSignalMessage(raw));
  }

  Future<void> _processSignalMessage(dynamic raw) async {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type']?.toString() ?? 'unknown';
      _logSignaling('recv type=$type');
      switch (type) {
        case 'joined':
          _signalingJoined = true;
          signalingState = CallSignalingState.joined;
          peersInRoom = (msg['peers'] as num?)?.toInt() ?? 0;
          statusMessage = 'In room $_roomId ($peersInRoom other peer(s))';
          notifyListeners();
        case 'peer_joined':
          _signalingJoined = true;
          peersInRoom += 1;
          statusMessage = 'Peer joined';
          notifyListeners();
          if (_isHost && !_makingOffer && _peerConnection != null) {
            await _createAndSendOffer();
          }
        case 'peer_left':
          peersInRoom = (msg['peers'] as num?)?.toInt() ?? max(0, peersInRoom - 1);
          await _prepareForPeerRejoin();
        case 'error':
          _failSignaling(msg['message']?.toString() ?? 'Signaling error');
        case 'offer':
          await _handleOffer(
            Map<String, dynamic>.from(msg['sdp'] as Map),
            from: msg['from']?.toString(),
          );
        case 'answer':
          await _handleAnswer(Map<String, dynamic>.from(msg['sdp'] as Map));
        case 'candidate':
          await _handleCandidate(Map<String, dynamic>.from(msg['candidate'] as Map));
        case 'gesture_caption':
          _handleGestureCaption(msg);
      }
    } catch (e) {
      _failSignaling('Bad signaling message: $e');
    }
  }

  void sendGestureCaption({
    required String gesture,
    required String label,
    required double score,
  }) {
    if (!_signalingJoined || _participantId == null) return;
    _send({
      'type': 'gesture_caption',
      'from': _participantId,
      'gesture': gesture,
      'label': label,
      'score': score,
    });
  }

  void _handleGestureCaption(Map<String, dynamic> msg) {
    final from = msg['from']?.toString();
    if (from != null && from == _participantId) return;
    final label = msg['label']?.toString() ?? msg['gesture']?.toString() ?? '';
    if (label.isEmpty) return;
    final gesture = msg['gesture']?.toString() ?? label;
    final score = (msg['score'] as num?)?.toDouble() ?? 0;
    _gestureCaptionController.add(
      GestureCaptionMessage(
        fromParticipantId: from,
        gesture: gesture,
        label: label,
        score: score,
      ),
    );
    notifyListeners();
  }

  void _send(Map<String, dynamic> message) {
    _logSignaling('send type=${message['type']}');
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> releaseMicForSpeechRecognition() async {
    await setMicEnabled(false);
  }

  Future<void> restoreMicAfterSpeechRecognition() async {
    if (isActive) await setMicEnabled(true);
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (_localStream == null) {
      statusMessage = 'Microphone not active — join the call or tap “Check camera & mic” first.';
      notifyListeners();
      return;
    }
    if (!hasLocalAudio) {
      statusMessage = 'No microphone track on this device.';
      notifyListeners();
      return;
    }
    micEnabled = enabled;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = enabled;
    }
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (_localStream == null) {
      statusMessage = 'Camera not active — join the call or tap “Check camera & mic” first.';
      notifyListeners();
      return;
    }
    if (!hasLocalVideo) {
      statusMessage = 'No camera track on this device.';
      notifyListeners();
      return;
    }
    cameraEnabled = enabled;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = enabled;
    }
    notifyListeners();
  }

  void _failSignaling(String message) {
    errorMessage = message;
    connectionState = CallConnectionState.failed;
    signalingState = CallSignalingState.failed;
    statusMessage = message;
    _clearNegotiationTimeout();
    notifyListeners();
  }

  void _failMedia(String message) {
    errorMessage = message;
    connectionState = CallConnectionState.failed;
    mediaPathState = CallMediaPathState.failed;
    statusMessage = message;
    _clearNegotiationTimeout();
    notifyListeners();
  }

  Future<void> hangUp({bool notify = true}) async {
    _signalingGeneration++;
    _signalingJoined = false;
    _signalingChain = Future<void>.value();
    _clearNegotiationTimeout();
    _iceBuffer.reset();
    await _signalSub?.cancel();
    _signalSub = null;
    await _channel?.sink.close();
    _channel = null;
    await _peerConnection?.close();
    _peerConnection = null;
    await _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
    hasLocalAudio = false;
    hasLocalVideo = false;
    hasRemoteAudio = false;
    hasRemoteVideo = false;
    remoteTracksReceived = 0;
    lastIceConnectionState = 'new';
    lastPeerConnectionState = 'new';
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    connectionState = CallConnectionState.ended;
    signalingState = CallSignalingState.idle;
    mediaPathState = CallMediaPathState.idle;
    if (mediaAccessState != CallMediaAccessState.denied) {
      mediaAccessState = CallMediaAccessState.idle;
    }
    statusMessage = 'Call ended';
    peersInRoom = 0;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(hangUp(notify: false));
    unawaited(localRenderer.dispose());
    unawaited(remoteRenderer.dispose());
    unawaited(_gestureCaptionController.close());
    super.dispose();
  }
}

/// HTML video element id used by flutter_webrtc on web (`video_RTCVideoRenderer-*`).
String webrtcLocalVideoElementId(RTCVideoRenderer renderer) =>
    'video_RTCVideoRenderer-${renderer.textureId}';
