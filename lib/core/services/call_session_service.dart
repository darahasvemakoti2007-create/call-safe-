import 'dart:developer' as developer;
import 'supabase_service.dart';

/// Clean model representing a recorded call session metadata row.
///
/// Designed with zero-audio, zero-transcript privacy:
/// - Never contains raw audio or speech streams.
/// - Never contains full conversation text.
/// - Strictly stores high-level telemetry and risk scoring.
class CallSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final int durationSeconds;
  final int riskScore;
  final String riskLevel;
  final String? scenarioType;
  final String? interventionStatus;
  final DateTime? createdAt;

  const CallSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.durationSeconds,
    required this.riskScore,
    required this.riskLevel,
    this.scenarioType,
    this.interventionStatus,
    this.createdAt,
  });

  factory CallSession.fromMap(Map<String, dynamic> map) {
    return CallSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      startedAt: DateTime.tryParse(map['started_at'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      riskScore: (map['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: (map['risk_level'] as String?) ?? 'safe',
      scenarioType: map['scenario_type'] as String?,
      interventionStatus: map['intervention_status'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'scenario_type': scenarioType,
      'intervention_status': interventionStatus ?? 'none',
    };
  }

  @override
  String toString() =>
      'CallSession(id: $id, userId: $userId, score: $riskScore, level: $riskLevel)';
}

/// Service managing persistence and synchronization of call sessions with Supabase.
///
/// Ensures offline resiliency:
/// - Uses remote Supabase client ONLY when `USE_SUPABASE=true` and client is configured.
/// - Falls back to local in-memory persistence in offline demo mode.
/// - Never crashes the UI if network synchronization fails.
/// - Enforces zero-trust ID checks matching `auth.uid()`.
class CallSessionService {
  static final CallSessionService instance = CallSessionService._internal();

  CallSessionService._internal();

  final List<CallSession> _inMemorySessions = [];

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Creates and records a call session record.
  ///
  /// In cloud mode, validates that [userId] matches the authenticated Supabase user.
  /// In offline demo mode, stores the record in memory without network calls.
  Future<CallSession> createCallSession({
    String? id,
    required String userId,
    required DateTime startedAt,
    required int durationSeconds,
    required int riskScore,
    required String riskLevel,
    String? scenarioType,
    String? interventionStatus,
  }) async {
    final sessionId = id ?? 'call_${DateTime.now().millisecondsSinceEpoch}';

    final session = CallSession(
      id: sessionId,
      userId: userId,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      riskScore: riskScore.clamp(0, 100),
      riskLevel: riskLevel,
      scenarioType: scenarioType,
      interventionStatus: interventionStatus ?? 'none',
      createdAt: DateTime.now(),
    );

    if (!isConfigured) {
      _inMemorySessions.insert(0, session);
      return session;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      _inMemorySessions.insert(0, session);
      return session;
    }

    // Zero-trust client validation: caller must match authenticated user
    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId != null && currentAuthId != userId) {
      throw ArgumentError(
        'Security Violation: Cannot create call session for a user ID different from auth.uid().',
      );
    }

    try {
      final data = session.toMap();
      // If sessionId is not a valid UUID, omit id so Postgres generates gen_random_uuid()
      final isValidUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(sessionId);

      if (!isValidUuid) {
        data.remove('id');
      }

      final res = await client.from('call_sessions').insert(data).select().single();
      final persisted = CallSession.fromMap(res);
      _inMemorySessions.insert(0, persisted);
      return persisted;
    } catch (e) {
      developer.log(
        'Warning: Call session cloud sync failed: $e. Retaining local copy.',
        name: 'CallSessionService',
        error: e,
      );
      _inMemorySessions.insert(0, session);
      return session;
    }
  }

  /// Updates an existing call session (e.g. updating intervention status).
  Future<CallSession?> updateCallSession({
    required String id,
    required String userId,
    String? interventionStatus,
    int? riskScore,
    String? riskLevel,
  }) async {
    final updates = <String, dynamic>{};
    if (interventionStatus != null) updates['intervention_status'] = interventionStatus;
    if (riskScore != null) updates['risk_score'] = riskScore.clamp(0, 100);
    if (riskLevel != null) updates['risk_level'] = riskLevel;

    if (!isConfigured) {
      final index = _inMemorySessions.indexWhere((s) => s.id == id);
      if (index != -1) {
        final existing = _inMemorySessions[index];
        final updated = CallSession(
          id: existing.id,
          userId: existing.userId,
          startedAt: existing.startedAt,
          durationSeconds: existing.durationSeconds,
          riskScore: riskScore ?? existing.riskScore,
          riskLevel: riskLevel ?? existing.riskLevel,
          scenarioType: existing.scenarioType,
          interventionStatus: interventionStatus ?? existing.interventionStatus,
          createdAt: existing.createdAt,
        );
        _inMemorySessions[index] = updated;
        return updated;
      }
      return null;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return null;

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId != null && currentAuthId != userId) {
      throw ArgumentError(
        'Security Violation: Cannot update call session for a user ID different from auth.uid().',
      );
    }

    try {
      final res = await client
          .from('call_sessions')
          .update(updates)
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .maybeSingle();

      if (res != null) {
        return CallSession.fromMap(res);
      }
    } catch (e) {
      developer.log('Call session update error: $e', name: 'CallSessionService', error: e);
    }
    return null;
  }

  /// Retrieves recent call sessions for the current user.
  Future<List<CallSession>> getRecentCallSessions({int limit = 20}) async {
    if (!isConfigured) {
      return List.unmodifiable(_inMemorySessions.take(limit));
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return List.unmodifiable(_inMemorySessions.take(limit));
    }

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null) {
      return List.unmodifiable(_inMemorySessions.take(limit));
    }

    try {
      final res = await client
          .from('call_sessions')
          .select()
          .eq('user_id', currentAuthId)
          .order('started_at', ascending: false)
          .limit(limit);

      final list = (res as List).map((m) => CallSession.fromMap(m)).toList();
      return list;
    } catch (e) {
      developer.log(
        'Failed to fetch cloud call sessions: $e. Falling back to local cache.',
        name: 'CallSessionService',
        error: e,
      );
      return List.unmodifiable(_inMemorySessions.take(limit));
    }
  }

  /// Resets in-memory cache for unit testing.
  void resetForTesting() {
    _inMemorySessions.clear();
  }
}
