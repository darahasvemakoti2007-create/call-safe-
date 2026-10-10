import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/call_session_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/risk_badge.dart';

/// Represents a single recorded call risk assessment.
class CallHistoryRecord {
  final String id;
  final String title;
  final String subtitle;
  final String timestamp;
  final String duration;
  final int riskScore;
  final RiskLevel riskLevel;
  final List<String> signals;
  final bool isSimulated;
  final String? interventionStatus;

  const CallHistoryRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.duration,
    required this.riskScore,
    required this.riskLevel,
    required this.signals,
    this.isSimulated = true,
    this.interventionStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp,
      'duration': duration,
      'riskScore': riskScore,
      'riskLevel': riskLevel.name,
      'signals': signals,
      'isSimulated': isSimulated,
      if (interventionStatus != null) 'interventionStatus': interventionStatus,
    };
  }

  factory CallHistoryRecord.fromMap(Map<String, dynamic> map) {
    final levelName = map['riskLevel'] as String? ?? 'safe';
    final level = RiskLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == levelName.toLowerCase(),
      orElse: () => RiskLevel.safe,
    );
    return CallHistoryRecord(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Call Assessment',
      subtitle: map['subtitle'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
      duration: map['duration'] as String? ?? '0s',
      riskScore: (map['riskScore'] as num?)?.toInt() ?? 0,
      riskLevel: level,
      signals: (map['signals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isSimulated: map['isSimulated'] as bool? ?? true,
      interventionStatus: map['interventionStatus'] as String?,
    );
  }
}

/// In-memory & locally persisted repository managing call risk assessment records.
///
/// Refactored to allow dynamically logging simulated calls from the Demo Center,
/// persisting locally via [SharedPreferences], and maintaining seed demo entries.
class CallHistoryRepository extends ChangeNotifier {
  static final CallHistoryRepository instance = CallHistoryRepository._();
  static const String _storageKey = 'guardcall_call_history_v1';

  CallHistoryRepository._() {
    _records = _defaultSeedRecords();
  }

  static List<CallHistoryRecord> _defaultSeedRecords() => [
        const CallHistoryRecord(
          id: 'initial_1',
          title: 'Emergency Impersonation Call',
          subtitle: 'Caller claimed family arrest and demanded instant wire transfer.',
          timestamp: 'Yesterday at 3:15 PM',
          duration: '1m 45s',
          riskScore: 92,
          riskLevel: RiskLevel.critical,
          signals: ['Fear / Threat', 'Financial Demand', 'Urgency'],
        ),
        const CallHistoryRecord(
          id: 'initial_2',
          title: 'Bank Verification Department',
          subtitle: 'Caller requested urgent 6-digit OTP code to unfreeze card.',
          timestamp: '3 days ago • 11:42 AM',
          duration: '2m 10s',
          riskScore: 78,
          riskLevel: RiskLevel.high,
          signals: ['Authority Impersonation', 'OTP Request', 'Urgency'],
        ),
        const CallHistoryRecord(
          id: 'initial_3',
          title: 'Delivery Courier Inquiry',
          subtitle: 'Asked to click a tracking link to confirm an unexpected parcel.',
          timestamp: 'Last Friday • 4:20 PM',
          duration: '0m 58s',
          riskScore: 55,
          riskLevel: RiskLevel.suspicious,
          signals: ['Suspicious Link', 'Unverified Sender'],
        ),
        const CallHistoryRecord(
          id: 'initial_4',
          title: 'Local Pharmacy Reminder',
          subtitle: 'Routine automated reminder regarding monthly prescription refill.',
          timestamp: 'Sep 15 • 10:00 AM',
          duration: '0m 40s',
          riskScore: 12,
          riskLevel: RiskLevel.safe,
          signals: ['No Scam Indicators'],
        ),
      ];

  factory CallHistoryRepository() => instance;

  late List<CallHistoryRecord> _records;

  List<CallHistoryRecord> get records => List.unmodifiable(_records);

  /// Loads locally saved history records from [SharedPreferences].
  ///
  /// Safely falls back to default seed records if storage is missing,
  /// empty, or corrupted.
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = <CallHistoryRecord>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loaded.add(CallHistoryRecord.fromMap(item));
            } else if (item is Map) {
              loaded.add(CallHistoryRecord.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          _records = loaded;
          notifyListeners();
          return;
        }
      }
    } catch (_) {
      // Safe fallback on invalid data
    }
    _records = _defaultSeedRecords();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _records.map((r) => r.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {
      // Non-blocking fallback
    }
  }

  /// Inserts a newly completed demo simulation assessment at the top of the log
  /// and persists it to local device storage.
  Future<void> addRecord(CallHistoryRecord record) async {
    _records.insert(0, record);
    notifyListeners();
    await _saveToStorage();
  }

  /// Attempts to synchronize recent call history from Supabase if active.
  Future<void> syncCloudHistory() async {
    if (!SupabaseService.instance.isConfigured) return;

    try {
      final sessions = await CallSessionService.instance.getRecentCallSessions();
      if (sessions.isEmpty) return;

      bool changed = false;
      for (final s in sessions) {
        final exists = _records.any((r) => r.id == s.id);
        if (!exists) {
          final level = RiskLevel.values.firstWhere(
            (l) => l.name.toLowerCase() == s.riskLevel.toLowerCase(),
            orElse: () => RiskLevel.safe,
          );
          final record = CallHistoryRecord(
            id: s.id,
            title: s.scenarioType != null
                ? '${s.scenarioType} (Cloud)'
                : 'Call Risk Assessment',
            subtitle: 'Risk score ${s.riskScore}/100. Status: ${s.interventionStatus ?? "none"}',
            timestamp: '${s.startedAt.month}/${s.startedAt.day} • ${s.startedAt.hour.toString().padLeft(2, '0')}:${s.startedAt.minute.toString().padLeft(2, '0')}',
            duration: '${s.durationSeconds}s',
            riskScore: s.riskScore,
            riskLevel: level,
            signals: [s.riskLevel.toUpperCase()],
            isSimulated: s.scenarioType != null,
            interventionStatus: s.interventionStatus,
          );
          _records.add(record);
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
        await _saveToStorage();
      }
    } catch (_) {
      // Non-blocking fallback
    }
  }

  /// Clears all recorded entries and updates local storage.
  Future<void> clear() async {
    _records.clear();
    notifyListeners();
    await _saveToStorage();
  }

  /// Resets repository back to default seed records (for test isolation).
  void resetForTesting() {
    _records = _defaultSeedRecords();
    notifyListeners();
  }
}
