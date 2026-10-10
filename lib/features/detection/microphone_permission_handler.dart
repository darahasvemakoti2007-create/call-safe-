import 'package:flutter/services.dart';

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
/// Communicates with native platform channels on Android and maintains
/// graceful fallback state in automated test and desktop environments.
class DefaultMicrophonePermissionHandler implements MicrophonePermissionHandler {
  final MethodChannel _channel;
  MicrophonePermissionStatus _currentStatus = MicrophonePermissionStatus.notDetermined;

  DefaultMicrophonePermissionHandler({
    MicrophonePermissionStatus initialStatus = MicrophonePermissionStatus.notDetermined,
    MethodChannel? channel,
  })  : _currentStatus = initialStatus,
        _channel = channel ?? const MethodChannel('guardcall/audio_capture');

  @override
  Future<MicrophonePermissionStatus> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('checkPermission');
      if (result != null) {
        _currentStatus = _parseStatus(result);
        return _currentStatus;
      }
    } catch (_) {
      // Fallback to local state if native platform channel is not active
    }
    return _currentStatus;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      if (result != null) {
        _currentStatus = _parseStatus(result);
        return _currentStatus;
      }
    } catch (_) {
      // Fallback
    }
    if (_currentStatus == MicrophonePermissionStatus.permanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }
    // Simulate user granting permission when prompted in fallback environment
    _currentStatus = MicrophonePermissionStatus.granted;
    return _currentStatus;
  }

  static MicrophonePermissionStatus _parseStatus(String str) {
    switch (str) {
      case 'granted':
        return MicrophonePermissionStatus.granted;
      case 'denied':
        return MicrophonePermissionStatus.denied;
      case 'permanentlyDenied':
        return MicrophonePermissionStatus.permanentlyDenied;
      default:
        return MicrophonePermissionStatus.notDetermined;
    }
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
