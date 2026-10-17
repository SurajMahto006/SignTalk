import 'include_gloss_phrases.dart';

/// Builds a running sentence from stable ISL **word** recognitions during video call.
///
/// Each confirmed word is separated by a pause (user lowers hands / sign changes).
/// You can later swap [IncludeGlossPhrases] for an LLM gloss-to-sentence step.
class IslSentenceComposer {
  IslSentenceComposer({
    this.wordCommitPause = const Duration(milliseconds: 1400),
    this.minWordGap = const Duration(milliseconds: 800),
    this.utteranceSilence = const Duration(milliseconds: 3500),
  });

  final Duration wordCommitPause;
  final Duration minWordGap;
  final Duration utteranceSilence;

  final List<String> _committedGlosses = [];
  String? _pendingGloss;
  DateTime? _pendingSince;
  String? _lastCommittedGloss;
  DateTime? _lastCommitAt;
  DateTime? _lastSignActivityAt;

  List<String> get glosses => List.unmodifiable(_committedGlosses);

  String? get pendingGloss => _pendingGloss;

  String get glossSentence => _committedGlosses.join(' ');

  String get readableSentence => IncludeGlossPhrases.toTemplateSentence(_committedGlosses);

  String get liveWordLabel {
    if (_pendingGloss != null && _pendingGloss!.isNotEmpty) {
      return IncludeGlossPhrases.glossToReadable(_pendingGloss!);
    }
    if (_committedGlosses.isNotEmpty) {
      return IncludeGlossPhrases.glossToReadable(_committedGlosses.last);
    }
    return '';
  }

  String get displayText {
    final base = readableSentence.isNotEmpty ? readableSentence : glossSentence;
    if (_pendingGloss != null && _pendingGloss!.isNotEmpty) {
      if (base.isEmpty) return _pendingGloss!;
      return '$base … $_pendingGloss';
    }
    return base;
  }

  void reset() {
    _committedGlosses.clear();
    _pendingGloss = null;
    _pendingSince = null;
    _lastCommittedGloss = null;
    _lastCommitAt = null;
    _lastSignActivityAt = null;
  }

  /// Ends the current utterance after silence — next signs start a fresh sentence.
  bool finalizeUtteranceOnSilence([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (_lastSignActivityAt == null) return false;
    if (t.difference(_lastSignActivityAt!) < utteranceSilence) return false;
    final hadContent = _committedGlosses.isNotEmpty || (_pendingGloss?.isNotEmpty ?? false);
    reset();
    return hadContent;
  }

  void markSignActivity([DateTime? now]) {
    _lastSignActivityAt = now ?? DateTime.now();
  }

  /// Feed a temporally stable label from [IslPredictionSmoother].
  void observeStableWord(String gloss) {
    final normalized = gloss.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final now = DateTime.now();
    markSignActivity(now);
    if (_pendingGloss == normalized) {
      if (_pendingSince != null && now.difference(_pendingSince!) >= wordCommitPause) {
        _commitWord(normalized, now);
      }
      return;
    }

    if (_pendingGloss != null && _pendingSince != null) {
      if (now.difference(_pendingSince!) >= wordCommitPause) {
        _commitWord(_pendingGloss!, now);
      }
    }

    _pendingGloss = normalized;
    _pendingSince = now;
  }

  /// Call on a timer when the signer may have finished a word (hands down).
  /// Returns true when an utterance was cleared after prolonged silence.
  bool tick([DateTime? now]) {
    final t = now ?? DateTime.now();
    final ended = finalizeUtteranceOnSilence(t);
    if (_pendingGloss == null || _pendingSince == null) return ended;
    if (t.difference(_pendingSince!) >= wordCommitPause) {
      _commitWord(_pendingGloss!, t);
      _pendingGloss = null;
      _pendingSince = null;
    }
    return ended;
  }

  void _commitWord(String gloss, DateTime now) {
    if (_lastCommittedGloss == gloss &&
        _lastCommitAt != null &&
        now.difference(_lastCommitAt!) < minWordGap) {
      return;
    }
    _committedGlosses.add(gloss);
    _lastCommittedGloss = gloss;
    _lastCommitAt = now;
    _pendingGloss = null;
    _pendingSince = null;
  }
}
