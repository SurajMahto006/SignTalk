import 'isl_prediction_smoother.dart';

enum IslRecognitionAvailability {
  notConnected,
  unsupportedPlatform,
  error,
  ready,
}

class IslRecognitionResult {
  const IslRecognitionResult({
    required this.availability,
    this.label,
    this.confidence,
    this.message,
    this.uncertain = false,
  });

  final IslRecognitionAvailability availability;
  final String? label;
  final double? confidence;
  final String? message;
  final bool uncertain;

  bool get isSuccess =>
      availability == IslRecognitionAvailability.ready &&
      label != null &&
      label!.isNotEmpty &&
      !uncertain;
}

/// Pluggable ISL recognition (local model, sidecar HTTP, etc.).
abstract class IslRecognitionAdapter {
  String get displayName;

  IslRecognitionAvailability get availability;

  Future<IslRecognitionResult> recognizeClip({
    required List<List<int>> jpegFrames,
  });

  void dispose() {}
}

/// Default for Chrome web demo when no verified model is bundled.
class DisconnectedIslRecognitionAdapter implements IslRecognitionAdapter {
  @override
  String get displayName => 'Recognition model not connected';

  @override
  IslRecognitionAvailability get availability =>
      IslRecognitionAvailability.notConnected;

  @override
  Future<IslRecognitionResult> recognizeClip({
    required List<List<int>> jpegFrames,
  }) async {
    return const IslRecognitionResult(
      availability: IslRecognitionAvailability.notConnected,
      message:
          'No ISL model is bundled in this build. Camera preview works; connect a verified sidecar or TFLite model to enable live recognition.',
    );
  }

  @override
  void dispose() {}
}

/// Applies [IslPredictionSmoother] to raw adapter outputs.
class SmoothedIslRecognitionService {
  SmoothedIslRecognitionService(this.adapter, {IslPredictionSmoother? smoother})
      : _smoother = smoother ?? IslPredictionSmoother();

  final IslRecognitionAdapter adapter;
  final IslPredictionSmoother _smoother;

  IslRecognitionAdapter get rawAdapter => adapter;

  void resetSmoothing() => _smoother.reset();

  Future<IslRecognitionResult> recognizeClip({
    required List<List<int>> jpegFrames,
  }) async {
    final raw = await adapter.recognizeClip(jpegFrames: jpegFrames);
    if (raw.availability != IslRecognitionAvailability.ready ||
        raw.label == null ||
        raw.confidence == null) {
      return raw;
    }

    final stable = _smoother.ingest(label: raw.label!, confidence: raw.confidence!);
    if (stable == null) {
      return IslRecognitionResult(
        availability: IslRecognitionAvailability.ready,
        label: raw.label,
        confidence: raw.confidence,
        uncertain: true,
        message: 'Sign detected but confidence is too low — hold the sign steady.',
      );
    }

    return IslRecognitionResult(
      availability: IslRecognitionAvailability.ready,
      label: stable,
      confidence: raw.confidence,
    );
  }
}
