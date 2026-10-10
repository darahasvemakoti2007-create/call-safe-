/// Typed categories of scam detection engine errors.
enum DetectionErrorType {
  missingApiKey,
  timeout,
  networkFailure,
  invalidJson,
  invalidOutput,
  unknownSignalType,
  providerUnavailable,
  unauthorized,
  invalidConfiguration,
}

/// Typed exception representing an error during conversation risk analysis.
class DetectionException implements Exception {
  final DetectionErrorType errorType;
  final String message;

  const DetectionException(this.errorType, this.message);

  /// Convenient alias for [errorType].
  DetectionErrorType get type => errorType;

  @override
  String toString() => 'DetectionException(${errorType.name}): $message';
}
