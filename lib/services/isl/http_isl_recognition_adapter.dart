import 'dart:convert';

import 'package:http/http.dart' as http;

import 'isl_recognition_adapter.dart';
import 'isl_sidecar_config.dart';

/// Sends JPEG clip frames to the INCLUDE sidecar (`tools/isl-sidecar`).
class HttpIslRecognitionAdapter implements IslRecognitionAdapter {
  HttpIslRecognitionAdapter({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? IslSidecarConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  bool? _sidecarReady;
  String? _sidecarDetail;

  @override
  String get displayName {
    if (_sidecarReady == true) {
      return 'ISL sidecar (INCLUDE pretrained) — $_sidecarDetail';
    }
    if (_sidecarReady == false) {
      return 'ISL sidecar unreachable — start tools/isl-sidecar';
    }
    return 'ISL sidecar (INCLUDE) — checking…';
  }

  @override
  IslRecognitionAvailability get availability {
    if (_sidecarReady == false) return IslRecognitionAvailability.notConnected;
    return IslRecognitionAvailability.ready;
  }

  Uri get _recognizeUri => Uri.parse('$_baseUrl/v1/recognize');

  Uri get _healthUri => Uri.parse('$_baseUrl/health');

  Future<void> refreshHealth() async {
    try {
      final res = await _client.get(_healthUri).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) {
        _sidecarReady = false;
        _sidecarDetail = 'HTTP ${res.statusCode}';
        return;
      }
      final body = jsonDecode(res.body);
      if (body is Map) {
        final loaded = body['model_loaded'] == true;
        _sidecarReady = loaded;
        _sidecarDetail = body['detail']?.toString() ?? body['model']?.toString() ?? '';
        if (!loaded) {
          _sidecarReady = false;
        }
      } else {
        _sidecarReady = false;
      }
    } catch (_) {
      _sidecarReady = false;
      _sidecarDetail = 'offline';
    }
  }

  @override
  Future<IslRecognitionResult> recognizeClip({
    required List<List<int>> jpegFrames,
  }) async {
    if (jpegFrames.isEmpty) {
      return const IslRecognitionResult(
        availability: IslRecognitionAvailability.ready,
        message: 'No camera frames — turn on camera and hold a sign steady.',
      );
    }

    final flatCount = jpegFrames.fold<int>(0, (n, f) => n + f.length);
    if (flatCount == 0) {
      return const IslRecognitionResult(
        availability: IslRecognitionAvailability.ready,
        message: 'Empty frames — wait for camera video dimensions.',
      );
    }

    await refreshHealth();
    if (_sidecarReady != true) {
      return IslRecognitionResult(
        availability: IslRecognitionAvailability.notConnected,
        message:
            'Start the INCLUDE sidecar: cd tools/isl-sidecar && pip install -r requirements.txt && python server.py',
      );
    }

    try {
      final payload = {
        'frames_base64': [
          for (final frame in jpegFrames) base64Encode(frame),
        ],
      };
      final res = await _client
          .post(
            _recognizeUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 503) {
        return IslRecognitionResult(
          availability: IslRecognitionAvailability.notConnected,
          message: _messageFromBody(res.body) ?? 'Sidecar model not loaded yet.',
        );
      }
      if (res.statusCode != 200) {
        return IslRecognitionResult(
          availability: IslRecognitionAvailability.error,
          message: 'Sidecar error HTTP ${res.statusCode}',
        );
      }

      final body = jsonDecode(res.body);
      if (body is! Map) {
        return const IslRecognitionResult(
          availability: IslRecognitionAvailability.error,
          message: 'Invalid sidecar response',
        );
      }

      final ok = body['ok'] == true;
      if (!ok) {
        return IslRecognitionResult(
          availability: IslRecognitionAvailability.error,
          message: body['error']?.toString() ?? 'Recognition failed',
        );
      }

      final label = body['label']?.toString();
      final confidence = (body['confidence'] as num?)?.toDouble();
      if (label == null || label.isEmpty) {
        return const IslRecognitionResult(
          availability: IslRecognitionAvailability.ready,
          uncertain: true,
          message: 'No sign detected — hold an INCLUDE-50 sign in frame.',
        );
      }

      return IslRecognitionResult(
        availability: IslRecognitionAvailability.ready,
        label: label,
        confidence: confidence ?? 0,
      );
    } catch (e) {
      return IslRecognitionResult(
        availability: IslRecognitionAvailability.error,
        message: 'Sidecar request failed: $e',
      );
    }
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded['detail']?.toString() ?? decoded['error']?.toString();
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _client.close();
  }
}
