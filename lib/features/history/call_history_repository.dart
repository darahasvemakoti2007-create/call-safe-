import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/call_session_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/risk_badge.dart';

/// Provenance of a recorded risk assessment.
enum AssessmentSource {
  demoCall,
  microphoneAudio,
  manualSms,
  incomingSms;

  String get label {
    switch (this) {
      case AssessmentSource.demoCall:
        return 'Demo Simulation';
      case AssessmentSource.microphoneAudio:
        return 'Microphone Audio Analysis';
      case AssessmentSource.manualSms:
        return 'Manual SMS Analysis';
      case AssessmentSource.incomingSms:
        return 'Incoming SMS Detection';
    }
  }

  String get badgeLabel {
    switch (this) {
      case AssessmentSource.demoCall:
        return 'DEMO';
      case AssessmentSource.microphoneAudio:
        return 'MIC SHIELD';
      case AssessmentSource.manualSms:
        return 'MANUAL SMS';
      case AssessmentSource.incomingSms:
        return 'INCOMING SMS';
    }
  }
}

/// Represents a single recorded call or message risk assessment.
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
  final AssessmentSource? source;
  final String? interventionStatus;
  final String? explanation;
  final String? transcriptExcerpt;
  final String? recommendedAction;

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
    this.source,
    this.interventionStatus,
    this.explanation,
    this.transcriptExcerpt,
    this.recommendedAction,
  });

  CallHistoryRecord copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timestamp,
    String? duration,
    int? riskScore,
    RiskLevel? riskLevel,
    List<String>? signals,
    bool? isSimulated,
    AssessmentSource? source,
    String? interventionStatus,
    String? explanation,
    String? transcriptExcerpt,
    String? recommendedAction,
  }) {
    return CallHistoryRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      signals: signals ?? this.signals,
      isSimulated: isSimulated ?? this.isSimulated,
      source: source ?? this.source,
      interventionStatus: interventionStatus ?? this.interventionStatus,
      explanation: explanation ?? this.explanation,
      transcriptExcerpt: transcriptExcerpt ?? this.transcriptExcerpt,
      recommendedAction: recommendedAction ?? this.recommendedAction,
    );
  }

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
      if (source != null) 'source': source!.name,
      if (interventionStatus != null) 'interventionStatus': interventionStatus,
      if (explanation != null) 'explanation': explanation,
      if (transcriptExcerpt != null) 'transcriptExcerpt': transcriptExcerpt,
      if (recommendedAction != null) 'recommendedAction': recommendedAction,
    };
  }

  factory CallHistoryRecord.fromMap(Map<String, dynamic> map) {
    final levelName = map['riskLevel'] as String? ?? 'safe';
    final level = RiskLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == levelName.toLowerCase(),
      orElse: () => RiskLevel.safe,
    );

    AssessmentSource? parsedSource;
    if (map['source'] != null) {
      final sourceStr = map['source'].toString().toLowerCase();
      parsedSource = AssessmentSource.values.firstWhere(
        (s) => s.name.toLowerCase() == sourceStr,
        orElse: () => AssessmentSource.demoCall,
      );
    } else {
      final titleStr = (map['title'] as String? ?? '').toLowerCase();
      if (titleStr.contains('sms')) {
        parsedSource = AssessmentSource.manualSms;
      } else if (titleStr.contains('microphone')) {
        parsedSource = AssessmentSource.microphoneAudio;
      } else {
        final isSim = map['isSimulated'] as bool? ?? true;
        parsedSource = isSim ? AssessmentSource.demoCall : AssessmentSource.microphoneAudio;
      }
    }

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
      source: parsedSource,
      interventionStatus: map['interventionStatus'] as String?,
      explanation: map['explanation'] as String?,
      transcriptExcerpt: map['transcriptExcerpt'] as String?,
      recommendedAction: map['recommendedAction'] as String?,
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
          isSimulated: true,
          source: AssessmentSource.demoCall,
          explanation:
              'Caller posed as an attorney claiming a family member was detained abroad and urgently demanded \$4,500 via non-reversible wire transfer.',
          transcriptExcerpt:
              '"Grandma, it\'s me! Please don\'t tell mom, I was arrested in Mexico and need \$4,500 wire transfer right now..."',
          recommendedAction:
              'Hang up immediately. Contact your family member directly on their known personal phone number. Never wire emergency funds without independent verification.',
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
          isSimulated: true,
          source: AssessmentSource.demoCall,
          explanation:
              'Caller impersonated a fraud prevention officer from First Federal Bank demanding a 6-digit one-time passcode to unfreeze an account.',
          transcriptExcerpt:
              '"This is Officer Bradley from Fraud Prevention. We detected an unauthorized transaction. Read back the 6-digit code sent to your phone to cancel it."',
          recommendedAction:
              'Never share one-time authentication codes or card PINs. Call your bank using the official number on the back of your card.',
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
          isSimulated: true,
          source: AssessmentSource.manualSms,
          explanation:
              'Automated message claiming a package delivery failed and requested opening an external link to pay re-delivery fees.',
          transcriptExcerpt:
              '"Your parcel delivery failed due to an incomplete address. Tap the link sent via text to verify your details and avoid package return."',
          recommendedAction:
              'Do not click links from unexpected delivery notices. Check package tracking numbers directly on official postal or courier websites.',
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
          isSimulated: true,
          source: AssessmentSource.demoCall,
          explanation:
              'Automated notification confirming a routine prescription refill is ready for pickup. No personal credentials or payments were requested.',
          transcriptExcerpt:
              '"Hello, this is a reminder from Community Pharmacy that your monthly prescription is ready for pickup at the counter."',
          recommendedAction:
              'Routine notification. No protective action required.',
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
