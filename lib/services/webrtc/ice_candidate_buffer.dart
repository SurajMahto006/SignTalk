/// Buffers ICE candidates until the remote SDP is applied (unit-testable).
class IceCandidateBuffer {
  final List<Map<String, dynamic>> pending = [];
  bool remoteDescriptionSet = false;
  int queuedCount = 0;
  int appliedCount = 0;

  void reset() {
    pending.clear();
    remoteDescriptionSet = false;
    queuedCount = 0;
    appliedCount = 0;
  }

  void markRemoteDescriptionSet() {
    remoteDescriptionSet = true;
  }

  bool get canApply => remoteDescriptionSet;

  void enqueue(Map<String, dynamic> candidate) {
    pending.add(Map<String, dynamic>.from(candidate));
    queuedCount++;
  }

  /// Applies all pending candidates; returns applied and requeued counts.
  Future<({int applied, int requeued})> flush(
    Future<void> Function(Map<String, dynamic> candidate) apply,
  ) async {
    if (pending.isEmpty) {
      return (applied: 0, requeued: 0);
    }
    final copy = List<Map<String, dynamic>>.from(pending);
    pending.clear();
    var applied = 0;
    var requeued = 0;
    for (final cand in copy) {
      try {
        await apply(cand);
        appliedCount++;
        applied++;
      } catch (_) {
        pending.add(cand);
        requeued++;
      }
    }
    return (applied: applied, requeued: requeued);
  }
}
