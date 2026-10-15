import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/webrtc/ice_candidate_buffer.dart';

void main() {
  test('queues until remote description then flushes', () async {
    final buffer = IceCandidateBuffer();
    buffer.enqueue({'candidate': 'c1'});
    buffer.enqueue({'candidate': 'c2'});
    expect(buffer.canApply, isFalse);

    buffer.markRemoteDescriptionSet();
    expect(buffer.canApply, isTrue);

    final applied = <String>[];
    final result = await buffer.flush((c) async {
      applied.add(c['candidate'] as String);
    });

    expect(result.applied, 2);
    expect(result.requeued, 0);
    expect(applied, ['c1', 'c2']);
    expect(buffer.pending, isEmpty);
  });

  test('requeues failed candidates', () async {
    final buffer = IceCandidateBuffer()..markRemoteDescriptionSet();
    buffer.enqueue({'candidate': 'bad'});

    final result = await buffer.flush((_) async {
      throw StateError('not ready');
    });

    expect(result.applied, 0);
    expect(result.requeued, 1);
    expect(buffer.pending.length, 1);
  });
}
