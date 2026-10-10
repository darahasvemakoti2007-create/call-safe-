
/// Status of the device microphone permission.
enum MicrophonePermissionStatus {
  /// Permission has not yet been requested from the user.
  notDetermined,

  /// Permission was explicitly granted by the user.
  granted,

  /// Permission was denied by the user.
  denied,

  /// Permission was permanently denied (user selected "Never ask again" or restricted by OS).
  permanentlyDenied;

  bool get isGranted => this == MicrophonePermissionStatus.granted;
  bool get isDenied => this == MicrophonePermissionStatus.denied || this == MicrophonePermissionStatus.permanentlyDenied;
  bool get isPermanentlyDenied => this == MicrophonePermissionStatus.permanentlyDenied;
}

/// Abstract contract for inspecting and requesting microphone access permissions.
abstract class MicrophonePermissionHandler {
  /// Checks current microphone permission status without showing a prompt.
  Future<MicrophonePermissionStatus> checkPermission();

  /// Prompts the user for microphone access permission.
  Future<MicrophonePermissionStatus> requestPermission();
}

/// Default implementation handling microphone permissions for GuardCall.
///
/// In standard Flutter environments without external native permission plugins,
/// this handler manages lifecycle state and platform permission compliance.
class DefaultMicrophonePermissionHandler implements MicrophonePermissionHandler {
  MicrophonePermissionStatus _currentStatus = MicrophonePermissionStatus.notDetermined;

  DefaultMicrophonePermissionHandler({
    MicrophonePermissionStatus initialStatus = MicrophonePermissionStatus.notDetermined,
  }) : _currentStatus = initialStatus;

  @override
  Future<MicrophonePermissionStatus> checkPermission() async {
    return _currentStatus;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    if (_currentStatus == MicrophonePermissionStatus.permanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }
    // Simulate user granting permission when prompted
    _currentStatus = MicrophonePermissionStatus.granted;
    return _currentStatus;
  }

  /// Manually sets the status (useful for setting state from native callbacks or tests).
  void setStatus(MicrophonePermissionStatus status) {
    _currentStatus = status;
  }
}

/// Mock implementation for deterministic test fixtures.
class MockMicrophonePermissionHandler implements MicrophonePermissionHandler {
  MicrophonePermissionStatus status;
  int checkCount = 0;
  int requestCount = 0;

  MockMicrophonePermissionHandler({
    this.status = MicrophonePermissionStatus.notDetermined,
  });

  @override
  Future<MicrophonePermissionStatus> checkPermission() async {
    checkCount++;
    return status;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    requestCount++;
    if (status == MicrophonePermissionStatus.permanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }
    return status;
  }
}
