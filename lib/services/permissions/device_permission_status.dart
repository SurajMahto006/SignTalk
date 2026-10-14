import 'package:flutter/foundation.dart';

/// Runtime permission hints updated when features are used (not stored).
class DevicePermissionStatus extends ChangeNotifier {
  bool? microphoneGranted;
  bool? cameraGranted;
  String? microphoneDetail;
  String? cameraDetail;

  void reportMicrophone({required bool? granted, String? detail}) {
    microphoneGranted = granted;
    microphoneDetail = detail;
    notifyListeners();
  }

  void reportCamera({required bool? granted, String? detail}) {
    cameraGranted = granted;
    cameraDetail = detail;
    notifyListeners();
  }

  String microphoneStatusLabel() {
    return switch (microphoneGranted) {
      true => 'In use / granted',
      false => 'Denied',
      null => kIsWeb ? 'Not requested yet' : 'Unknown',
    };
  }

  String cameraStatusLabel() {
    return switch (cameraGranted) {
      true => 'In use / granted',
      false => 'Denied',
      null => kIsWeb ? 'Not requested yet' : 'Unknown',
    };
  }
}
