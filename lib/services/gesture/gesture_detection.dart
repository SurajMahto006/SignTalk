class GestureDetection {
  const GestureDetection({
    required this.status,
    this.gesture,
    this.label,
    this.score = 0,
    this.message,
  });

  final String status;
  final String? gesture;
  final String? label;
  final double score;
  final String? message;

  bool get isRecognized => status == 'recognized' && (label?.isNotEmpty ?? false);
}

class GestureCaptionMessage {
  const GestureCaptionMessage({
    required this.fromParticipantId,
    required this.gesture,
    required this.label,
    required this.score,
  });

  final String? fromParticipantId;
  final String gesture;
  final String label;
  final double score;
}

class IslCaptionMessage {
  const IslCaptionMessage({
    required this.fromParticipantId,
    required this.word,
    required this.sentence,
    required this.confidence,
  });

  final String? fromParticipantId;
  final String word;
  final String sentence;
  final double confidence;
}

class SpeechCaptionMessage {
  const SpeechCaptionMessage({
    required this.fromParticipantId,
    required this.text,
  });

  final String? fromParticipantId;
  final String text;
}
