import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central accessibility preferences controller for GuardCall.
///
/// Manages global accessibility states including [reduceMotion].
/// Ensures elderly and motion-sensitive users can disable bouncy scales,
/// 3D tilts, and pulsing effects across all screens.
class AccessibilityPreferences extends ChangeNotifier {
  AccessibilityPreferences._();
  static final AccessibilityPreferences instance = AccessibilityPreferences._();
  static const String _storageKey = 'guardcall_reduce_motion_v1';

  bool _reduceMotion = false;

  /// Whether the user has requested reduced motion across the application.
  bool get reduceMotion => _reduceMotion;

  /// Loads locally saved preferences from [SharedPreferences].
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _reduceMotion = prefs.getBool(_storageKey) ?? false;
      notifyListeners();
    } catch (_) {
      // Safe fallback
    }
  }

  /// Updates the reduce motion state, persists to storage, and notifies listeners.
  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion != value) {
      _reduceMotion = value;
      notifyListeners();
      await _saveToStorage(value);
    }
  }

  Future<void> _saveToStorage(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (_) {
      // Safe fallback
    }
  }

  /// Resets preferences to defaults (primarily for test isolation).
  void reset() {
    _reduceMotion = false;
    notifyListeners();
  }
}
