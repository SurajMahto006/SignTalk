import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'camera_preview_service.dart';

CameraPreviewService createCameraPreviewService() => _CameraPreviewWeb();

class _CameraPreviewWeb implements CameraPreviewService {
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  String? _viewType;
  bool _active = false;
  bool _paused = false;
  String? _lastError;
  bool? _lastPermissionGranted;

  @override
  bool get isSupported => true;

  @override
  bool get isActive => _active;

  @override
  bool get isPaused => _paused;

  @override
  String? get viewType => _viewType;

  @override
  String? get lastError => _lastError;

  @override
  bool? get lastPermissionGranted => _lastPermissionGranted;

  @override
  Future<bool> start() async {
    _lastError = null;
    if (_active) return true;

    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      _stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
      _lastPermissionGranted = true;

      _video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..playsInline = true
        ..style.objectFit = 'cover'
        ..style.width = '100%'
        ..style.height = '100%';
      _video!.srcObject = _stream;

      await _video!.play().toDart;

      _viewType = 'signtalk-camera-${identityHashCode(this)}';
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType!,
        (int viewId) => _video!,
      );

      _active = true;
      _paused = false;
      return true;
    } catch (e) {
      _lastPermissionGranted = _isPermissionError(e);
      _lastError = _lastPermissionGranted == true
          ? 'Camera permission was denied.'
          : 'Could not start camera: $e';
      await stop();
      return false;
    }
  }

  bool _isPermissionError(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('notallowed') ||
        text.contains('permission') ||
        text.contains('denied');
  }

  @override
  Future<void> stop() async {
    _paused = false;
    _active = false;
    _viewType = null;

    if (_stream != null) {
      final tracks = _stream!.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      _stream = null;
    }

    _video?.srcObject = null;
    _video?.remove();
    _video = null;
  }

  @override
  void pausePreview() {
    if (!_active || _video == null) return;
    _paused = true;
    _video!.style.visibility = 'hidden';
    for (final track in _stream!.getVideoTracks().toDart) {
      track.enabled = false;
    }
  }

  @override
  void resumePreview() {
    if (!_active || _video == null) return;
    _paused = false;
    _video!.style.visibility = 'visible';
    for (final track in _stream!.getVideoTracks().toDart) {
      track.enabled = true;
    }
  }

  @override
  void dispose() {
    unawaited(stop());
  }
}
