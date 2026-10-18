import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/sign_talk_scope.dart';
import '../../services/isl/text_to_sign_reference.dart';
import '../../services/speech/text_to_speech_service.dart';
import '../../theme/sign_talk_colors.dart';

class SignToTextScreen extends StatefulWidget {
  const SignToTextScreen({
    super.key,
    required this.onBack,
    required this.onSendToConversations,
    this.onOpenSettings,
  });

  final VoidCallback onBack;
  final void Function(String text, {bool asRecognizedSign}) onSendToConversations;
  final VoidCallback? onOpenSettings;

  @override
  State<SignToTextScreen> createState() => _SignToTextScreenState();
}

class _SignToTextScreenState extends State<SignToTextScreen> {
  static const _placeholder =
      'Sign recognition is not connected. Type or paste text here to use Speak Text.';

  final _textController = TextEditingController();
  bool _cameraActive = false;
  bool _isPaused = false;
  bool _cameraBusy = false;
  String? _cameraError;
  bool _recognitionBusy = false;
  String? _recognitionStatus;
  String? _textToSignHint;
  bool _lastTextFromModel = false;

  bool get _hasText => _textController.text.trim().isNotEmpty;

  String get _displayText => _hasText ? _textController.text : _placeholder;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _textToSignHint = TextToSignReference.hintForText(_textController.text);
      });
    });
  }

  @override
  void deactivate() {
    SignTalkScope.of(context).cameraPreview.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clearText() {
    _textController.clear();
    SignTalkScope.of(context).textToSpeech.stop();
  }

  void _copyText() {
    if (!_hasText) {
      _showSnack('Nothing to copy yet.');
      return;
    }
    Clipboard.setData(ClipboardData(text: _textController.text.trim()));
    _showSnack('Copied to clipboard.');
  }

  Future<void> _toggleCamera() async {
    final scope = SignTalkScope.of(context);
    final camera = scope.cameraPreview;
    if (_cameraBusy) return;
    setState(() => _cameraBusy = true);

    if (_cameraActive) {
      await camera.stop();
      scope.permissionStatus.reportCamera(granted: camera.lastPermissionGranted, detail: 'Camera stopped');
      setState(() {
        _cameraActive = false;
        _cameraError = null;
        _cameraBusy = false;
      });
      return;
    }

    if (!camera.isSupported) {
      setState(() {
        _cameraError = camera.lastError;
        _cameraBusy = false;
      });
      _showSnack(camera.lastError ?? 'Camera preview is not supported here.');
      return;
    }

    final started = await camera.start();
    scope.permissionStatus.reportCamera(
      granted: camera.lastPermissionGranted ?? started,
      detail: started ? 'Live preview (no sign recognition)' : camera.lastError,
    );
    if (!mounted) return;
    setState(() {
      _cameraActive = started;
      _cameraError = started ? null : camera.lastError;
      _cameraBusy = false;
      if (!started && camera.lastError != null) {
        _showSnack(camera.lastError!);
      }
    });
  }

  void _togglePause() {
    if (!_cameraActive) {
      _showSnack('Start the camera preview first to pause or resume.');
      return;
    }
    final camera = SignTalkScope.of(context).cameraPreview;
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      camera.pausePreview();
    } else {
      camera.resumePreview();
    }
  }

  Future<void> _tryRecognition() async {
    if (_recognitionBusy) return;
    setState(() {
      _recognitionBusy = true;
      _recognitionStatus = 'Checking recognition service…';
    });
    final isl = SignTalkScope.of(context).islRecognition;
    final result = await isl.recognizeClip(jpegFrames: const []);
    if (!mounted) return;
    setState(() {
      _recognitionBusy = false;
      _recognitionStatus = result.message ?? isl.rawAdapter.displayName;
      _lastTextFromModel = result.isSuccess;
      if (result.isSuccess && result.label != null) {
        _textController.text = result.label!;
      } else if (result.uncertain) {
        _recognitionStatus = result.message;
      }
    });
    if (result.isSuccess) {
      _showSnack('Recognized: ${result.label}');
    } else {
      _showSnack(_recognitionStatus ?? 'Recognition unavailable');
    }
  }

  void _sendToConversations() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnack('Enter or recognize text first.');
      return;
    }
    widget.onSendToConversations(text, asRecognizedSign: _lastTextFromModel);
    _showSnack(
      _lastTextFromModel
          ? 'Sent to Conversations (model-recognized sign).'
          : 'Sent to Conversations (typed text from Sign screen).',
    );
  }

  Future<void> _speakText() async {
    final prefs = SignTalkScope.preferencesOf(context);
    final tts = SignTalkScope.of(context).textToSpeech;
    if (!_hasText) {
      _showSnack('Enter text to speak. Sign recognition is not active.');
      return;
    }
    if (!prefs.spokenOutputEnabled) {
      _showSnack('Spoken output is off in Settings.');
      return;
    }
    await tts.setLanguage(prefs.speechLocale);
    final outcome = await tts.speak(_textController.text, enabled: prefs.spokenOutputEnabled);
    switch (outcome) {
      case SpeakOutcome.success:
        _showSnack('Speaking…');
      case SpeakOutcome.empty:
        _showSnack('Nothing to speak.');
      case SpeakOutcome.unavailable:
        _showSnack('Speech synthesis is unavailable in this browser.');
      case SpeakOutcome.failed:
        _showSnack('Could not speak text.');
      case SpeakOutcome.cancelled:
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tts = SignTalkScope.of(context).textToSpeech;
    final islAdapter = SignTalkScope.of(context).islRecognition.rawAdapter;

    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        _ScreenHeader(
          onBack: widget.onBack,
          onSettings: widget.onOpenSettings ?? () => _showSnack('Sign to Text settings are not available yet.'),
        ),
        const SizedBox(height: 8),
        _InfoPill(status: islAdapter.displayName),
        if (_recognitionStatus != null) ...[
          const SizedBox(height: 8),
          Text(_recognitionStatus!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        _ViewfinderArea(
          isPaused: _isPaused,
          cameraActive: _cameraActive,
          viewType: SignTalkScope.of(context).cameraPreview.viewType,
          errorMessage: _cameraError,
        ),
        const SizedBox(height: 14),
        _RecognizedTextPanel(
          controller: _textController,
          displayText: _displayText,
          isPlaceholder: !_hasText,
          onCopy: _copyText,
        ),
        const SizedBox(height: 14),
        _StartCameraButton(
          cameraActive: _cameraActive,
          busy: _cameraBusy,
          onPressed: () => unawaited(_toggleCamera()),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _recognitionBusy ? null : () => unawaited(_tryRecognition()),
          icon: _recognitionBusy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.back_hand_outlined),
          label: const Text('Try sign recognition (model adapter)'),
        ),
        const SizedBox(height: 10),
        _ControlRow(
          isPaused: _isPaused,
          isSpeaking: tts.isSpeaking,
          onPause: _togglePause,
          onClear: _clearText,
          onSpeak: () => unawaited(_speakText()),
          onStopSpeak: () => unawaited(tts.stop()),
        ),
        if (_textToSignHint != null) ...[
          const SizedBox(height: 12),
          _TextToSignReferenceCard(hint: _textToSignHint!),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _sendToConversations,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Send to Conversations'),
        ),
      ],
    );
      },
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.onBack, required this.onSettings});

  final VoidCallback onBack;
  final VoidCallback onSettings;

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
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: SignTalkColors.primaryText),
            ),
          ),
        ),
        const Expanded(
          child: Text(
            'Sign to Text',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: SignTalkColors.primaryText,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onSettings,
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.settings_outlined, size: 22, color: SignTalkColors.primaryText),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextToSignReferenceCard extends StatelessWidget {
  const _TextToSignReferenceCard({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SignTalkColors.tintBlueBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text-to-sign reference (glossary)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(TextToSignReference.limitationMessage, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(hint, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SignTalkColors.tintBlueBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          'Preview only · $status',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SignTalkColors.secondaryText,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ViewfinderArea extends StatelessWidget {
  const _ViewfinderArea({
    required this.isPaused,
    required this.cameraActive,
    required this.viewType,
    required this.errorMessage,
  });

  final bool isPaused;
  final bool cameraActive;
  final String? viewType;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraActive && viewType != null)
              HtmlElementView(viewType: viewType!)
            else
              ColoredBox(
                color: const Color(0xFF1C1C1E),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorMessage ?? 'Tap Start Camera for live preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Preview only — ISL sign recognition is not implemented',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0x80FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            const _ViewfinderCorners(),
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
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
                        decoration: BoxDecoration(
                          color: cameraActive
                              ? (isPaused ? SignTalkColors.secondaryText : SignTalkColors.successGreen)
                              : SignTalkColors.secondaryText,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cameraActive
                            ? (isPaused ? 'Live • Paused' : 'Live preview')
                            : 'Camera off',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCorners extends StatelessWidget {
  const _ViewfinderCorners();

  @override
  Widget build(BuildContext context) {
    const inset = 14.0;
    const size = 24.0;
    const stroke = 3.5;
    const color = Color(0xF2FFFFFF);

    Widget corner(Alignment alignment, {required bool top, required bool left}) {
      return Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerBracketPainter(
                top: top,
                left: left,
                color: color,
                strokeWidth: stroke,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(Alignment.topLeft, top: true, left: true),
        corner(Alignment.topRight, top: true, left: false),
        corner(Alignment.bottomLeft, top: false, left: true),
        corner(Alignment.bottomRight, top: false, left: false),
      ],
    );
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

class _RecognizedTextPanel extends StatelessWidget {
  const _RecognizedTextPanel({
    required this.controller,
    required this.displayText,
    required this.isPlaceholder,
    required this.onCopy,
  });

  final TextEditingController controller;
  final String displayText;
  final bool isPlaceholder;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recognized text',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 20),
              color: SignTalkColors.secondaryText,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Copy',
            ),
          ],
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: SignTalkColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SignTalkColors.border),
            boxShadow: const [SignTalkColors.cardShadow],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: _SignToTextScreenState._placeholder,
                  hintStyle: const TextStyle(color: SignTalkColors.secondaryText, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isPlaceholder ? SignTalkColors.secondaryText : SignTalkColors.primaryText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartCameraButton extends StatelessWidget {
  const _StartCameraButton({
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
      height: 48,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: SignTalkColors.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        icon: Icon(cameraActive ? Icons.videocam_off_outlined : Icons.photo_camera_outlined, size: 22),
        label: Text(cameraActive ? 'Stop Camera' : 'Start Camera'),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.isPaused,
    required this.isSpeaking,
    required this.onPause,
    required this.onClear,
    required this.onSpeak,
    required this.onStopSpeak,
  });

  final bool isPaused;
  final bool isSpeaking;
  final VoidCallback onPause;
  final VoidCallback onClear;
  final VoidCallback onSpeak;
  final VoidCallback onStopSpeak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryControlButton(
            icon: isPaused ? Icons.play_arrow_outlined : Icons.pause,
            label: isPaused ? 'Resume' : 'Pause',
            onPressed: onPause,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SecondaryControlButton(
            icon: Icons.delete_outline,
            label: 'Clear',
            onPressed: onClear,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SecondaryControlButton(
            icon: isSpeaking ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            label: isSpeaking ? 'Stop' : 'Speak',
            iconColor: SignTalkColors.primaryBlue,
            onPressed: isSpeaking ? onStopSpeak : onSpeak,
          ),
        ),
      ],
    );
  }
}

class _SecondaryControlButton extends StatelessWidget {
  const _SecondaryControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SignTalkColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SignTalkColors.border),
          ),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor ?? SignTalkColors.primaryText),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: SignTalkColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
