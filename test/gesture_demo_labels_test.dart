import 'package:flutter_test/flutter_test.dart';
import 'package:signtalk/services/gesture/gesture_demo_labels.dart';

void main() {
  test('maps demo MediaPipe gestures to captions', () {
    expect(GestureDemoLabels.captionForMediaPipeGesture('Open_Palm'), 'HELLO');
    expect(GestureDemoLabels.captionForMediaPipeGesture('Thumb_Up'), 'YES');
    expect(GestureDemoLabels.captionForMediaPipeGesture('Closed_Fist'), 'STOP');
    expect(GestureDemoLabels.captionForMediaPipeGesture('Victory'), isNull);
  });
}
