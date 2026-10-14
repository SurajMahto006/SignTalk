import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/isl/isl_prediction_smoother.dart';

void main() {
  test('smoother requires agreement and confidence', () {
    final smoother = IslPredictionSmoother(
      windowSize: 5,
      minAgreement: 3,
      minConfidence: 0.6,
    );

    expect(smoother.ingest(label: 'hello', confidence: 0.9), isNull);
    expect(smoother.ingest(label: 'hello', confidence: 0.9), isNull);
    expect(smoother.ingest(label: 'hello', confidence: 0.9), 'hello');
  });

  test('smoother rejects low confidence average', () {
    final smoother = IslPredictionSmoother(minAgreement: 2, minConfidence: 0.8);
    expect(smoother.ingest(label: 'a', confidence: 0.5), isNull);
    expect(smoother.ingest(label: 'a', confidence: 0.5), isNull);
  });
}
