import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/isl/isl_recognition_adapter.dart';

void main() {
  test('disconnected adapter does not claim success', () async {
    final adapter = DisconnectedIslRecognitionAdapter();
    final result = await adapter.recognizeClip(jpegFrames: const []);
    expect(result.isSuccess, isFalse);
    expect(result.availability, IslRecognitionAvailability.notConnected);
  });
}
