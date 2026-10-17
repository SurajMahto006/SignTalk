/// Prototype demo captions — **not** validated Indian Sign Language (ISL).
///
/// Maps MediaPipe Gesture Recognizer category names to short English labels
/// for judge demos. See `docs/JUDGE_DEMO_GUIDE.md` for poses.
class GestureDemoGesture {
  const GestureDemoGesture({
    required this.mediaPipeName,
    required this.caption,
    required this.poseHint,
  });

  final String mediaPipeName;
  final String caption;
  final String poseHint;
}

abstract final class GestureDemoLabels {
  static const prototypeDisclaimer =
      'Prototype gesture demo only — not a full ISL translator.';

  static const demoGestures = [
    GestureDemoGesture(
      mediaPipeName: 'Open_Palm',
      caption: 'HELLO',
      poseHint: 'Face the camera. Hold one open palm toward the lens, fingers spread.',
    ),
    GestureDemoGesture(
      mediaPipeName: 'Thumb_Up',
      caption: 'YES',
      poseHint: 'Thumb pointing up, other fingers closed into a fist.',
    ),
    GestureDemoGesture(
      mediaPipeName: 'Closed_Fist',
      caption: 'STOP',
      poseHint: 'Closed fist held steady at chest height in frame.',
    ),
  ];

  static String? captionForMediaPipeGesture(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) return null;
    for (final g in demoGestures) {
      if (g.mediaPipeName == categoryName) return g.caption;
    }
    return null;
  }

  static bool isDemoGesture(String? categoryName) =>
      captionForMediaPipeGesture(categoryName) != null;
}
