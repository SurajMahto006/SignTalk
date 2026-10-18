import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps platform speech recognition (Web Speech API on Chrome web).
///
/// See [../speech/BROWSER_SPEECH_LIMITATIONS.md] for browser constraints.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speechToText})
      : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;

  bool _initialized = false;
  bool _listening = false;
  bool _userPaused = false;
  String _localeId = 'en_US';

  final _statusController = StreamController<String>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _listeningController = StreamController<bool>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get partialTranscriptStream => _partialController.stream;
  Stream<String> get finalTranscriptStream => _finalController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;

  bool get isListening => _listening;
  bool get isPaused => _userPaused;
  bool get isAvailable => _initialized && _speech.isAvailable;
  bool? _lastPermissionGranted;

  bool? get lastPermissionGranted => _lastPermissionGranted;

  String get localeId => _localeId;

  Future<bool> initialize() async {
    if (_initialized) return _speech.isAvailable;
    try {
      _initialized = await _speech.initialize(
        onError: _onEngineError,
        onStatus: _onEngineStatus,
        debugLogging: kDebugMode,
      );
      if (!_initialized) {
        _emitStatus('Speech recognition is not available on this browser.');
      } else {
        _emitStatus('Ready');
      }
      return _speech.isAvailable;
    } catch (e) {
      _initialized = false;
      _emitError('Could not initialize speech recognition: $e');
      return false;
    }
  }

  Future<bool> ensurePermissions() async {
    await initialize();
    if (!_speech.isAvailable) return false;
    try {
      final granted = await _speech.hasPermission;
      _lastPermissionGranted = granted;
      if (!granted) {
        // Triggers browser permission prompt when starting listen on web.
        _emitStatus('Microphone permission required.');
      }
      return granted;
    } catch (e) {
      _lastPermissionGranted = false;
      _emitError('Microphone permission check failed: $e');
      return false;
    }
  }

  void setLocale(String localeId) {
    _localeId = localeId;
  }

  /// Starts listening unless paused or already listening.
  Future<void> startListening() async {
    if (_userPaused) {
      _emitStatus('Paused — tap Resume to listen again.');
      return;
    }
    await initialize();
    if (!_speech.isAvailable) {
      _emitError(
        kIsWeb
            ? 'Speech recognition is unavailable. Try Chrome or Edge on localhost/https.'
            : 'Speech recognition is unavailable on this platform.',
      );
      return;
    }

    if (_listening) return;

    try {
      final hasPermission = await _speech.hasPermission;
      _lastPermissionGranted = hasPermission;
    } catch (_) {
      // On Flutter web, speech_to_text may throw type 'Null' is not a 'bool' on hasPermission.
      // _speech.listen() prompts for microphone permission directly if needed.
    }

    try {
      final started = await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
      if (started) {
        _listening = true;
        _listeningController.add(true);
        _emitStatus('Listening…');
      } else {
        _listening = false;
        _listeningController.add(false);
        _emitError(
          'Could not start listening. Check microphone permission and try again.',
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('already started') || msg.contains('InvalidStateError')) {
        // Recognition is already active in the browser; keep listening flag true.
        _listening = true;
        _listeningController.add(true);
        _emitStatus('Listening…');
        return;
      }
      _listening = false;
      _listeningController.add(false);
      _lastPermissionGranted = false;
      _emitError('Failed to start speech recognition: $e');
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    _listeningController.add(false);
    try {
      await _speech.stop();
    } catch (_) {}
    _emitStatus('Stopped');
  }

  Future<void> toggleListening() async {
    if (_listening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void pauseUser() {
    _userPaused = true;
    unawaited(stopListening());
    _emitStatus('Paused');
  }

  void resumeUser() {
    _userPaused = false;
    _emitStatus('Ready to listen');
  }

  void clearSession() {
    _partialController.add('');
    _emitStatus(_userPaused ? 'Paused' : 'Ready to listen');
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    if (words.isEmpty) return;
    if (result.finalResult) {
      _finalController.add(words);
      _partialController.add('');
    } else {
      _partialController.add(words);
    }
  }

  void _onEngineError(SpeechRecognitionError error) {
    _listening = false;
    _listeningController.add(false);
    final message = switch (error.errorMsg) {
      'not-allowed' || 'denied' => 'Microphone permission was denied.',
      'no-speech' => 'No speech detected.',
      'audio-capture' => 'No microphone found or capture failed.',
      'network' => 'Speech recognition needs network access in this browser.',
      _ => error.errorMsg,
    };
    _emitError(message);
  }

  void _onEngineStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _listening = false;
      _listeningController.add(false);
      if (!_userPaused) {
        _emitStatus('Ready to listen');
      }
    } else if (status == 'listening') {
      _emitStatus('Listening…');
    }
  }

  void _emitStatus(String message) => _statusController.add(message);
  void _emitError(String message) => _errorController.add(message);

  void dispose() {
    unawaited(_speech.stop());
    _statusController.close();
    _partialController.close();
    _finalController.close();
    _errorController.close();
    _listeningController.close();
  }
}
