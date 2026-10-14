import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum CallConnectionState { idle, connecting, connected, failed, ended }

/// WebRTC peer session with WebSocket signaling (see tools/signaling-server).
class WebRtcCallService extends ChangeNotifier {
  WebRtcCallService();

  static const defaultSignalingUrl = 'ws://127.0.0.1:8765';

  static Map<String, dynamic> get _rtcConfig => {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  WebSocketChannel? _channel;
  StreamSubscription? _signalSub;
  String? _roomId;
  bool _isHost = false;
  bool _makingOffer = false;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  CallConnectionState connectionState = CallConnectionState.idle;
  String? statusMessage;
  String? errorMessage;
  bool micEnabled = true;
  bool cameraEnabled = true;
  int peersInRoom = 0;

  bool get isActive =>
      connectionState == CallConnectionState.connecting ||
      connectionState == CallConnectionState.connected;

  Future<void> ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Future<void> connectToRoom({
    required String signalingUrl,
    required String roomId,
    required bool asHost,
  }) async {
    await hangUp(notify: false);
    _roomId = roomId.trim();
    _isHost = asHost;
    errorMessage = null;
    statusMessage = 'Connecting to signaling…';
    connectionState = CallConnectionState.connecting;
    notifyListeners();

    try {
      await ensureRenderers();
      final uri = Uri.parse(signalingUrl.trim());
      _channel = WebSocketChannel.connect(uri);
      _signalSub = _channel!.stream.listen(
        _onSignalMessage,
        onError: (Object e) => _fail('Signaling error: $e'),
        onDone: () {
          if (connectionState != CallConnectionState.ended) {
            statusMessage = 'Signaling disconnected';
            notifyListeners();
          }
        },
      );
      _send({'type': 'join', 'room': _roomId});
      statusMessage = asHost ? 'Waiting for guest to join…' : 'Waiting for host offer…';
      notifyListeners();

      if (asHost) {
        await _preparePeerConnection();
      }
    } catch (e) {
      _fail('Could not connect signaling: $e');
    }
  }

  Future<void> _preparePeerConnection() async {
    await _ensureLocalMedia();
    _peerConnection = await createPeerConnection(_rtcConfig);
    _wirePeerConnection(_peerConnection!);
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
    localRenderer.srcObject = _localStream;
  }

  Future<void> _ensureLocalMedia() async {
    if (_localStream != null) return;
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
    });
    _localStream = stream;
    micEnabled = stream.getAudioTracks().every((t) => t.enabled);
    cameraEnabled = stream.getVideoTracks().every((t) => t.enabled);
  }

  void _wirePeerConnection(RTCPeerConnection pc) {
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send({
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };
    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      remoteRenderer.srcObject = _remoteStream;
      connectionState = CallConnectionState.connected;
      statusMessage = 'Connected';
      notifyListeners();
    };
    pc.onConnectionState = (state) {
      statusMessage = 'ICE: $state';
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _fail('Peer connection failed');
      }
      notifyListeners();
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;
    _makingOffer = true;
    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _send({'type': 'offer', 'sdp': offer.toMap()});
      statusMessage = 'Offer sent — waiting for answer…';
      notifyListeners();
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> sdpMap) async {
    try {
      if (_peerConnection == null) {
        await _preparePeerConnection();
      }
      final offer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(offer);
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _send({'type': 'answer', 'sdp': answer.toMap()});
      statusMessage = 'Answer sent';
      notifyListeners();
    } catch (e) {
      _fail('Failed to handle offer: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> sdpMap) async {
    try {
      final answer = RTCSessionDescription(sdpMap['sdp'], sdpMap['type']);
      await _peerConnection!.setRemoteDescription(answer);
      statusMessage = 'Remote answer applied';
      notifyListeners();
    } catch (e) {
      _fail('Failed to handle answer: $e');
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> candMap) async {
    try {
      if (_peerConnection == null) return;
      final candidate = RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      if (kDebugMode) debugPrint('ICE candidate error: $e');
    }
  }

  void _onSignalMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'joined':
          peersInRoom = (msg['peers'] as num?)?.toInt() ?? 0;
          statusMessage = 'In room $_roomId ($peersInRoom other peer(s))';
          notifyListeners();
        case 'peer_joined':
          peersInRoom += 1;
          statusMessage = 'Peer joined room $_roomId';
          notifyListeners();
          if (_isHost && !_makingOffer) {
            unawaited(_createAndSendOffer());
          }
        case 'offer':
          unawaited(_handleOffer(Map<String, dynamic>.from(msg['sdp'] as Map)));
        case 'answer':
          unawaited(_handleAnswer(Map<String, dynamic>.from(msg['sdp'] as Map)));
        case 'candidate':
          unawaited(_handleCandidate(Map<String, dynamic>.from(msg['candidate'] as Map)));
      }
    } catch (e) {
      _fail('Bad signaling message: $e');
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  /// Release WebRTC mic for browser speech recognition (exclusive access).
  Future<void> releaseMicForSpeechRecognition() async {
    await setMicEnabled(false);
  }

  Future<void> restoreMicAfterSpeechRecognition() async {
    if (connectionState == CallConnectionState.connected ||
        connectionState == CallConnectionState.connecting) {
      await setMicEnabled(true);
    }
  }

  Future<void> setMicEnabled(bool enabled) async {
    micEnabled = enabled;
    for (final track in _localStream?.getAudioTracks() ?? []) {
      track.enabled = enabled;
    }
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = enabled;
    for (final track in _localStream?.getVideoTracks() ?? []) {
      track.enabled = enabled;
    }
    notifyListeners();
  }

  void _fail(String message) {
    errorMessage = message;
    connectionState = CallConnectionState.failed;
    statusMessage = message;
    notifyListeners();
  }

  Future<void> hangUp({bool notify = true}) async {
    await _signalSub?.cancel();
    _signalSub = null;
    await _channel?.sink.close();
    _channel = null;
    await _peerConnection?.close();
    _peerConnection = null;
    await _localStream?.dispose();
    _localStream = null;
    _remoteStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    connectionState = CallConnectionState.ended;
    statusMessage = 'Call ended';
    peersInRoom = 0;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(hangUp(notify: false));
    unawaited(localRenderer.dispose());
    unawaited(remoteRenderer.dispose());
    super.dispose();
  }
}
