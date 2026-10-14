/// Temporal smoothing for ISL classifier outputs (majority vote + confidence gate).
class IslPredictionSmoother {
  IslPredictionSmoother({
    this.windowSize = 5,
    this.minAgreement = 3,
    this.minConfidence = 0.55,
  });

  final int windowSize;
  final int minAgreement;
  final double minConfidence;

  final List<({String label, double confidence})> _window = [];

  void reset() => _window.clear();

  /// Returns a stable label, or null if uncertain / insufficient evidence.
  String? ingest({required String label, required double confidence}) {
    if (label.isEmpty) return null;
    _window.add((label: label, confidence: confidence));
    while (_window.length > windowSize) {
      _window.removeAt(0);
    }

    final counts = <String, int>{};
    final confSum = <String, double>{};
    for (final item in _window) {
      counts[item.label] = (counts[item.label] ?? 0) + 1;
      confSum[item.label] = (confSum[item.label] ?? 0) + item.confidence;
    }

    String? bestLabel;
    var bestCount = 0;
    counts.forEach((label, count) {
      if (count > bestCount) {
        bestCount = count;
        bestLabel = label;
      }
    });

    if (bestLabel == null || bestCount < minAgreement) return null;
    final avgConf = confSum[bestLabel!]! / bestCount;
    if (avgConf < minConfidence) return null;
    return bestLabel;
  }
}
