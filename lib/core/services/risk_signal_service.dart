import 'dart:developer' as developer;
import 'supabase_service.dart';

/// Clean model representing a persisted threat signal record.
///
/// Designed with zero-transcript privacy:
/// - Never stores conversation lines or raw dialogue text.
/// - Stores explainable pattern classifications and behavioral indicators only.
class RiskSignalRecord {
  final String? id;
  final String callSessionId;
  final String signalType;
  final String severity;
  final String explanation;
  final DateTime detectedAt;

  const RiskSignalRecord({
    this.id,
    required this.callSessionId,
    required this.signalType,
    required this.severity,
    required this.explanation,
    required this.detectedAt,
  });

  factory RiskSignalRecord.fromMap(Map<String, dynamic> map) {
    return RiskSignalRecord(
      id: map['id'] as String?,
      callSessionId: map['call_session_id'] as String,
      signalType: map['signal_type'] as String,
      severity: map['severity'] as String? ?? 'medium',
      explanation: map['explanation'] as String? ?? '',
      detectedAt: DateTime.tryParse(map['detected_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'call_session_id': callSessionId,
      'signal_type': signalType,
      'severity': severity,
      'explanation': explanation,
      'detected_at': detectedAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  @override
  String toString() =>
      'RiskSignalRecord(type: $signalType, severity: $severity, call: $callSessionId)';
}

/// Service managing persistence and synchronization of threat signals with Supabase.
///
/// Operates with offline-first resiliency:
/// - Uses remote Supabase client ONLY when `USE_SUPABASE=true` and client is configured.
/// - Falls back safely to in-memory persistence in offline demo mode.
/// - Never crashes the application if network synchronization fails.
class RiskSignalService {
  static final RiskSignalService instance = RiskSignalService._internal();

  RiskSignalService._internal();

  final List<RiskSignalRecord> _inMemorySignals = [];

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Persists a single risk signal.
  Future<RiskSignalRecord> createRiskSignal(RiskSignalRecord signal) async {
    if (!isConfigured) {
      _inMemorySignals.add(signal);
      return signal;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      _inMemorySignals.add(signal);
      return signal;
    }

    try {
      final res = await client.from('risk_signals').insert(signal.toMap()).select().single();
      final persisted = RiskSignalRecord.fromMap(res);
      _inMemorySignals.add(persisted);
      return persisted;
    } catch (e) {
      developer.log(
        'Warning: Risk signal cloud sync failed: $e. Retaining local copy.',
        name: 'RiskSignalService',
        error: e,
      );
      _inMemorySignals.add(signal);
      return signal;
    }
  }

  /// Batch persists multiple risk signals.
  Future<List<RiskSignalRecord>> createRiskSignals(List<RiskSignalRecord> signals) async {
    if (signals.isEmpty) return [];

    if (!isConfigured) {
      _inMemorySignals.addAll(signals);
      return signals;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      _inMemorySignals.addAll(signals);
      return signals;
    }

    try {
      final data = signals.map((s) => s.toMap()).toList();
      final res = await client.from('risk_signals').insert(data).select();
      final persisted = (res as List).map((m) => RiskSignalRecord.fromMap(m)).toList();
      _inMemorySignals.addAll(persisted);
      return persisted;
    } catch (e) {
      developer.log(
        'Warning: Batch risk signals cloud sync failed: $e. Retaining local copies.',
        name: 'RiskSignalService',
        error: e,
      );
      _inMemorySignals.addAll(signals);
      return signals;
    }
  }

  /// Retrieves persisted risk signals for a specific call session.
  Future<List<RiskSignalRecord>> getSignalsForCall(String callSessionId) async {
    if (!isConfigured) {
      return _inMemorySignals
          .where((s) => s.callSessionId == callSessionId)
          .toList();
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return _inMemorySignals
          .where((s) => s.callSessionId == callSessionId)
          .toList();
    }

    try {
      final res = await client
          .from('risk_signals')
          .select()
          .eq('call_session_id', callSessionId)
          .order('detected_at', ascending: true);

      return (res as List).map((m) => RiskSignalRecord.fromMap(m)).toList();
    } catch (e) {
      developer.log(
        'Failed to fetch signals for call: $e',
        name: 'RiskSignalService',
        error: e,
      );
      return _inMemorySignals
          .where((s) => s.callSessionId == callSessionId)
          .toList();
    }
  }

  /// Resets in-memory cache for unit testing.
  void resetForTesting() {
    _inMemorySignals.clear();
  }
}
