import 'isl_recognition_adapter.dart';
import 'isl_sidecar_config.dart';
import 'http_isl_recognition_adapter.dart';

IslRecognitionAdapter createIslRecognitionAdapter() {
  if (IslSidecarConfig.enabled) {
    return HttpIslRecognitionAdapter();
  }
  return DisconnectedIslRecognitionAdapter();
}
