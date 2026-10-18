import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/sign_talk_scope.dart';
import '../../theme/sign_talk_colors.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({
    super.key,
    required this.onBack,
    required this.onSendToConversations,
    this.onOpenSettings,
  });

  final VoidCallback onBack;

  /// Kept for API compatibility with [MainShell]; not used in this screen.
  final void Function(String text) onSendToConversations;
  final VoidCallback? onOpenSettings;

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Transient / expected Web Speech API errors that should NOT show an error
// banner to the user.
// ─────────────────────────────────────────────────────────────────────────────
bool _isSilentError(String e) {
  final lower = e.toLowerCase();
  if (lower.contains('no-speech') || lower.contains('no speech detected')) return true;
  if (lower.contains('null') && lower.contains('bool')) return true;
  if (lower.contains('already started') || lower.contains('invalidstateerror')) return true;
  if (lower.contains('aborted')) return true;
  return false;
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  // ── Camera state ──────────────────────────────────────────────────────
  bool _cameraActive = false;
  bool _cameraBusy = false;
  String? _cameraError;

  // ── Speech recognition state ──────────────────────────────────────────
  bool _isListening = false;
  bool _speechAvailable = false;
  String _statusMessage = 'Ready';
  String? _visibleError;

  // ── Sentence-level live caption state ──────────────────────────────────
  /// Holds ONLY the current spoken sentence. Cleared after 2.5s of silence.
  String _currentCaption = '';

  /// The most recent raw transcript received from the speech engine in this session.
  String _lastRawTranscript = '';

  /// Normalized tokens representing the speech accumulated up to the most
  /// recent silence/inactivity clear. Used to identify newly spoken words
  /// from the engine's cumulative transcript without blindly stripping by string prefix.
  List<String> _consumedTokens = [];

  /// Inactivity timer: clears the displayed caption after 2.5 seconds without new speech.
  Timer? _inactivityTimer;
  static const _inactivityDuration = Duration(milliseconds: 2500);

  // ── Concurrency & restart guards ─────────────────────────────────────
  bool _wantListening = false;
  bool _isStarting = false;
  bool _restarting = false;

  final List<StreamSubscription<dynamic>> _subs = [];

  String get _language => SignTalkScope.preferencesOf(context).speechLanguageLabel;

  static List<String> _splitWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static String _normalizeToken(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    return clean.isNotEmpty ? clean : word.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSpeech());
  }

  Future<void> _bindSpeech() async {
    final scope = SignTalkScope.of(context);
    final speech = scope.speechRecognition;
    speech.setLocale(SignTalkScope.preferencesOf(context).speechLocale);

    _subs
      // Status updates
      ..add(speech.statusStream.listen((s) {
        if (!mounted) return;
        setState(() => _statusMessage = s);
      }))

      // Interim (partial) words
      ..add(speech.partialTranscriptStream.listen((p) {
        if (!mounted) return;
        final trimmed = p.trim();
        if (trimmed.isEmpty) return;
        _onSpeechResult(trimmed);
      }))

      // Finalized words
      ..add(speech.finalTranscriptStream.listen((f) {
        if (!mounted) return;
        final trimmed = f.trim();
        if (trimmed.isEmpty) return;
        _onSpeechResult(trimmed);
      }))

      // Error stream
      ..add(speech.errorStream.listen((e) {
        if (!mounted) return;
        if (_isSilentError(e)) {
          _scheduleRestart(500);
        } else {
          setState(() => _visibleError = e);
          _showSnack(e);
        }
      }))

      // Listening state changes
      ..add(speech.listeningStream.listen((listening) {
        if (!mounted) return;
        setState(() => _isListening = listening);
        if (!listening) {
          // When the engine genuinely stops listening, any subsequent session will start with a fresh cumulative buffer.
          _consumedTokens = [];
          _lastRawTranscript = '';
          if (_wantListening && _cameraActive) {
            _scheduleRestart(350);
          }
        }
      }));

    final ok = await speech.initialize();
    if (!mounted) return;
    setState(() {
      _speechAvailable = ok;
      if (!ok) _statusMessage = 'Speech recognition unavailable';
    });
  }

  /// Extracts only the newly spoken sentence from the engine's cumulative transcript.
  String _extractNewSpeech(String rawWords) {
    final rawWordsList = _splitWords(rawWords);
    if (rawWordsList.isEmpty) return '';

    final k = _consumedTokens.length;
    if (k > 0 && rawWordsList.length >= k) {
      // Check how many of the leading tokens match the consumed baseline
      int matchCount = 0;
      for (int i = 0; i < k; i++) {
        if (_normalizeToken(rawWordsList[i]) == _consumedTokens[i]) {
          matchCount++;
        }
      }
      final threshold = k <= 2 ? k : (k * 0.7).floor();
      if (matchCount >= threshold) {
        final newWords = rawWordsList.sublist(k);
        if (newWords.isEmpty) return '';
        return newWords.join(' ');
      }
    }

    // If it doesn't match the consumed tokens or has fewer words, the engine has restarted or started fresh.
    _consumedTokens = [];
    return rawWordsList.join(' ');
  }

  void _onSpeechResult(String rawWords) {
    final trimmed = rawWords.trim();
    if (trimmed.isEmpty) return;

    final sentence = _extractNewSpeech(trimmed);
    _lastRawTranscript = trimmed;

    if (sentence.isNotEmpty) {
      setState(() {
        _currentCaption = sentence;
      });
      _resetInactivityTimer();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      if (!mounted) return;
      setState(() {
        // Clear visible caption after 2.5s of silence
        _currentCaption = '';
      });
      // Mark the raw transcript up to this silence point as consumed
      if (_lastRawTranscript.isNotEmpty) {
        final words = _splitWords(_lastRawTranscript);
        _consumedTokens = words.map(_normalizeToken).toList();
      }
    });
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _scheduleRestart([int delayMs = 350]) {
    if (!_wantListening || !_cameraActive || !mounted) return;
    if (_restarting || _isStarting || _isListening) return;

    _restarting = true;
    Future.delayed(Duration(milliseconds: delayMs), () async {
      _restarting = false;
      if (!mounted || !_wantListening || !_cameraActive || _isListening) return;
      await _startListening();
      if (mounted && _wantListening && _cameraActive && !_isListening) {
        _scheduleRestart(700);
      }
    });
  }

  @override
  void deactivate() {
    _wantListening = false;
    _cancelInactivityTimer();
    SignTalkScope.of(context).cameraPreview.stop();
    unawaited(SignTalkScope.of(context).speechRecognition.stopListening());
    super.deactivate();
  }

  @override
  void dispose() {
    _cancelInactivityTimer();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  // ── Camera toggle ─────────────────────────────────────────────────────
  Future<void> _toggleCamera() async {
    final scope = SignTalkScope.of(context);
    final camera = scope.cameraPreview;
    if (_cameraBusy) return;

    setState(() => _cameraBusy = true);

    if (_cameraActive) {
      _wantListening = false;
      _cancelInactivityTimer();
      await scope.speechRecognition.stopListening();
      await camera.stop();
      scope.permissionStatus.reportCamera(
        granted: camera.lastPermissionGranted,
        detail: 'Camera stopped',
      );
      if (!mounted) return;
      setState(() {
        _cameraActive = false;
        _cameraError = null;
        _cameraBusy = false;
        _isListening = false;
        _currentCaption = '';
        _lastRawTranscript = '';
        _consumedTokens = [];
        _visibleError = null;
      });
      return;
    }

    if (!camera.isSupported) {
      if (!mounted) return;
      setState(() {
        _cameraError = camera.lastError;
        _cameraBusy = false;
      });
      _showSnack(
        camera.lastError ?? 'Camera preview is not supported in this browser.',
      );
      return;
    }

    final started = await camera.start();
    scope.permissionStatus.reportCamera(
      granted: camera.lastPermissionGranted ?? started,
      detail: started ? 'Live caption preview' : camera.lastError,
    );
    if (!mounted) return;

    if (!started) {
      setState(() {
        _cameraError = camera.lastError;
        _cameraBusy = false;
      });
      _showSnack(camera.lastError ?? 'Could not start camera.');
      return;
    }

    setState(() {
      _cameraActive = true;
      _cameraError = null;
      _cameraBusy = false;
      _visibleError = null;
      _currentCaption = '';
      _lastRawTranscript = '';
      _consumedTokens = [];
    });

    _wantListening = true;
    await _startListening();
  }

  // ── Speech start with mutex ───────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_speechAvailable || !_wantListening || !mounted) return;
    if (_isStarting || _isListening) return;

    _isStarting = true;
    setState(() => _visibleError = null);

    final speech = SignTalkScope.of(context).speechRecognition;
    try {
      await speech.startListening();
    } catch (e) {
      final msg = e.toString();
      if (!_isSilentError(msg)) {
        if (mounted) {
          setState(() => _visibleError = msg);
          _showSnack(msg);
        }
      } else {
        _scheduleRestart(500);
      }
    } finally {
      _isStarting = false;
    }

    if (mounted) {
      final granted = speech.lastPermissionGranted;
      if (granted != null) {
        SignTalkScope.of(context).permissionStatus.reportMicrophone(
          granted: granted,
          detail: granted ? 'Live captions' : 'Denied in browser',
        );
      }
      setState(() {});
    }
  }

  // ── Language picker ───────────────────────────────────────────────────
  Future<void> _onLanguageTap() async {
    final prefs = SignTalkScope.preferencesOf(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Caption language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en_US|English (US)'),
            child: const Text('English (US)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'en_IN|English (India)'),
            child: const Text('English (India)'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final parts = picked.split('|');
    await prefs.setSpeechLanguage(label: parts[1], locale: parts[0]);
    if (!mounted) return;
    _consumedTokens = [];
    _lastRawTranscript = '';
    _currentCaption = '';
    _cancelInactivityTimer();
    SignTalkScope.of(context).speechRecognition.setLocale(parts[0]);
    setState(() {});
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Status colour & label ─────────────────────────────────────────────
  Color get _statusColor {
    if (_visibleError != null && !_isListening) return SignTalkColors.callRed;
    if (_isListening) return SignTalkColors.successGreen;
    if (!_speechAvailable) return SignTalkColors.callRed;
    return SignTalkColors.secondaryText;
  }

  String get _statusText {
    if (_isListening) return 'Listening…';
    if (_visibleError != null) return 'Error — tap Start Camera';
    return _statusMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _ScreenHeader(onBack: widget.onBack),
        ),

    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            _ScreenHeader(
              onBack: widget.onBack,
              onSettings: widget.onOpenSettings ?? () => _showSnack('Open the Settings tab for speech preferences.'),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusPill(text: _statusText, color: _statusColor),
                  const SizedBox(width: 8),
                  _LanguageChip(
                    language: _language,
                    onTap: _onLanguageTap,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StartStopButton(
                cameraActive: _cameraActive,
                busy: _cameraBusy,
                onPressed: () => unawaited(_toggleCamera()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private UI components
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: SignTalkColors.primaryText,
              ),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Speech to Text',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SignTalkColors.primaryText,
            ),
          ),
        ),
        const SizedBox(width: 36),
      ],
    );
  }
}

class _CameraWithCaptions extends StatelessWidget {
  const _CameraWithCaptions({
    required this.cameraActive,
    required this.viewType,
    required this.errorMessage,
    required this.caption,
    required this.isListening,
  });

  final bool cameraActive;
  final String? viewType;
  final String? errorMessage;
  final String caption;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraActive && viewType != null)
            HtmlElementView(viewType: viewType!)
          else
            _CameraPlaceholder(errorMessage: errorMessage),

          const _ViewfinderCorners(),

          Positioned(
            top: 10,
            right: 10,
            child: _LiveBadge(
              cameraActive: cameraActive,
              isListening: isListening,
            ),
          ),

          // Live 1-2 line rolling caption overlay near the bottom of camera preview
          if (cameraActive && caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _CaptionOverlay(caption: caption),
            ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.errorMessage});
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1C1C1E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 44,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              errorMessage ?? 'Tap Start Camera to begin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Camera + live continuous speech captions',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamically trims text from the beginning if a single spoken sentence exceeds 2 lines,
/// ensuring the overlay remains strictly within 1–2 lines without covering the user.
String _truncateToFitTwoLines(String text, TextStyle style, double maxWidth) {
  if (maxWidth <= 0) return text;
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';

  int start = 0;
  while (start < words.length - 1) {
    final candidate = words.sublist(start).join(' ');
    final tp = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);

    final exceeds = tp.didExceedMaxLines;
    tp.dispose();

    if (!exceeds) {
      return candidate;
    }
    start++;
  }
  return words.sublist(start).join(' ');
}

/// Fixed caption overlay near bottom of camera preview displaying current sentence in 1-2 lines.
class _CaptionOverlay extends StatelessWidget {
  const _CaptionOverlay({required this.caption});
  final String caption;

  static const _captionStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textMaxWidth = constraints.maxWidth - 24;
        final visibleText = _truncateToFitTwoLines(caption, _captionStyle, textMaxWidth);

        return Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              visibleText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: _captionStyle,
            ),
          ),
        );
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.cameraActive, required this.isListening});
  final bool cameraActive;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final dotColor = cameraActive
        ? (isListening ? SignTalkColors.successGreen : SignTalkColors.primaryBlue)
        : SignTalkColors.secondaryText;

    final label = cameraActive
        ? (isListening ? 'Live captions' : 'Camera on')
        : 'Camera off';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language, required this.onTap});
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final micEnabled = available && !paused;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: listening ? 'Stop listening' : 'Start listening',
              child: Material(
                color: listening ? SignTalkColors.primaryBlue : SignTalkColors.tintBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onPrimaryMic,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(
                      listening ? Icons.stop_rounded : Icons.mic,
                      size: 32,
                      color: listening ? Colors.white : SignTalkColors.primaryBlue,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartStopButton extends StatelessWidget {
  const _StartStopButton({
    required this.cameraActive,
    required this.busy,
    required this.onPressed,
  });
  final bool cameraActive;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cameraActive ? SignTalkColors.callRed : SignTalkColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                cameraActive ? Icons.videocam_off_outlined : Icons.photo_camera_outlined,
                size: 22,
              ),
        label: Text(cameraActive ? 'Stop Camera' : 'Start Camera'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewfinder corner decorations
// ─────────────────────────────────────────────────────────────────────────────

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    Widget corner(Alignment alignment, {required bool top, required bool left}) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(
              painter: _CornerBracketPainter(
                top: top,
                left: left,
                color: const Color(0xF2FFFFFF),
                strokeWidth: 3.5,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: [
      corner(Alignment.topLeft, top: true, left: true),
      corner(Alignment.topRight, top: true, left: false),
      corner(Alignment.bottomLeft, top: false, left: true),
      corner(Alignment.bottomRight, top: false, left: false),
    ]);
  }
}

class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.strokeWidth,
  });

  final bool top;
  final bool left;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 8);
      path.quadraticBezierTo(0, 0, 8, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width - 8, 0);
      path.quadraticBezierTo(size.width, 0, size.width, 8);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - 8);
      path.quadraticBezierTo(0, size.height, 8, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - 8);
      path.quadraticBezierTo(size.width, size.height, size.width - 8, size.height);
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
