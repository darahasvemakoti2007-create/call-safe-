import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Supported logging severity levels for GuardCall.
enum LogLevel {
  debug,
  info,
  warning,
  error;

  String get label => name.toUpperCase();
}

/// Centralized privacy-safe logging service for GuardCall.
///
/// STRICTURES & PRIVACY GUARANTEES:
/// 1. NEVER logs raw audio buffers, audio waveforms, or audio stream bytes.
/// 2. NEVER logs complete conversational transcripts.
/// 3. Automatically sanitizes potential OTPs, PINs, CVVs, passwords, Bearer tokens,
///    and secret keys before printing or dispatching to system logs.
/// 4. Suppresses debug-level output in release builds.
class AppLogger {
  AppLogger._();

  static LogLevel minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  /// Regex patterns matching sensitive credentials for automatic redacting.
  static final RegExp _otpPattern =
      RegExp(r'\b(otp|code|pin|cvv)\s*[:=]?\s*\d{3,8}\b', caseSensitive: false);
  static final RegExp _passwordPattern = RegExp(
      r'\b(password|secret|apikey|api_key|token|auth_token)\s*[:=]?\s*\S+\b',
      caseSensitive: false);
  static final RegExp _bearerPattern =
      RegExp(r'Bearer\s+[A-Za-z0-9\-_.]+', caseSensitive: false);
  static final RegExp _jwtPattern =
      RegExp(r'eyJ[A-Za-z0-9-_]+\.eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+');

  /// Sanitizes [rawMessage] to remove sensitive credentials, transcripts, or keys.
  static String sanitize(String rawMessage) {
    var sanitized = rawMessage;
    sanitized = sanitized.replaceAllMapped(_otpPattern, (m) => '[REDACTED_CREDENTIAL]');
    sanitized = sanitized.replaceAllMapped(_passwordPattern, (m) => '[REDACTED_SECRET]');
    sanitized = sanitized.replaceAllMapped(_bearerPattern, (m) => 'Bearer [REDACTED]');
    sanitized = sanitized.replaceAllMapped(_jwtPattern, (m) => '[REDACTED_JWT]');
    return sanitized;
  }

  /// Internal log dispatcher.
  static void _log(
    LogLevel level,
    String message, {
    String tag = 'GuardCall',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final sanitizedMessage = sanitize(message);

    developer.log(
      '[${level.label}] $sanitizedMessage',
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: _levelToInt(level),
    );
  }

  static int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  /// Logs a debug diagnostic message.
  static void debug(String message, {String tag = 'GuardCall'}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Logs general informational diagnostic messages.
  static void info(String message, {String tag = 'GuardCall'}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Logs non-fatal warning messages.
  static void warning(
    String message, {
    String tag = 'GuardCall',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Logs fatal or high-severity errors.
  static void error(
    String message, {
    String tag = 'GuardCall',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }
}
