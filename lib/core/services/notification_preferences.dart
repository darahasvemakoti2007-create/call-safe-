import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-controlled notification preferences for family escalation alerts.
///
/// Ensures the senior user remains in full control over whether family
/// members may be alerted upon scam detection.
class NotificationPreferences extends ChangeNotifier {
  static final NotificationPreferences instance = NotificationPreferences._internal();
  static const String _storageKey = 'guardcall_family_alerts_enabled_v1';

  NotificationPreferences._internal();

  bool _familyAlertsEnabled = true;

  /// Whether family alerts can be requested by the senior.
  bool get familyAlertsEnabled => _familyAlertsEnabled;

  /// Current delivery mode label (always clearly marked as demo/simulated).
  String get deliveryModeLabel => 'Simulated / Local Demo';

  /// Plain-language description of delivery behavior.
  String get deliveryModeDescription =>
      'Family notifications are simulated in hackathon prototype mode. No SMS, WhatsApp, or push notifications are dispatched.';

  /// Loads locally saved preferences from [SharedPreferences].
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _familyAlertsEnabled = prefs.getBool(_storageKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Safe fallback
    }
  }

  /// Toggles family alert capability on or off, persists to storage, and notifies listeners.
  Future<void> setFamilyAlertsEnabled(bool enabled) async {
    if (_familyAlertsEnabled != enabled) {
      _familyAlertsEnabled = enabled;
      notifyListeners();
      await _saveToStorage(enabled);
    }
  }

  Future<void> _saveToStorage(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, enabled);
    } catch (_) {
      // Safe fallback
    }
  }

  /// Resets preferences to default state (enabled).
  void reset() {
    _familyAlertsEnabled = true;
    notifyListeners();
  }
}
