import 'dart:async';
import 'dart:developer' as developer;
import 'notification_service.dart';
import 'supabase_service.dart';

/// Clean model representing a family alert dispatch record in Supabase.
///
/// IMPORTANT ARCHITECTURAL DISTINCTION:
/// - Creating this row records that an alert was requested by the user.
/// - It publishes an event over Supabase Realtime for listening clients/backends.
/// - It DOES NOT itself deliver SMS, WhatsApp, or OS-level push notifications.
/// - Outward delivery is abstracted via [NotificationService].
class FamilyAlertRecord {
  final String? id;
  final String callSessionId;
  final String familyContactId;
  final int riskScore;
  final String status; // 'pending', 'sent', 'delivered', 'dismissed', 'reviewed'
  final DateTime? createdAt;
  final String? scenarioType;
  final String? riskLevel;
  final List<String>? detectedSignals;
  final String? explanation;
  final String? interventionStatus;
  final String? victimName;
  final String? notificationStatus;
  final String? notificationMessage;

  const FamilyAlertRecord({
    this.id,
    required this.callSessionId,
    required this.familyContactId,
    required this.riskScore,
    this.status = 'pending',
    this.createdAt,
    this.scenarioType,
    this.riskLevel,
    this.detectedSignals,
    this.explanation,
    this.interventionStatus,
    this.victimName,
    this.notificationStatus,
    this.notificationMessage,
  });

  factory FamilyAlertRecord.fromMap(Map<String, dynamic> map) {
    return FamilyAlertRecord(
      id: map['id'] as String?,
      callSessionId: map['call_session_id'] as String,
      familyContactId: map['family_contact_id'] as String,
      riskScore: (map['risk_score'] as num?)?.toInt() ?? 0,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      scenarioType: map['scenario_type'] as String?,
      riskLevel: map['risk_level'] as String?,
      detectedSignals: (map['detected_signals'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      explanation: map['explanation'] as String?,
      interventionStatus: map['intervention_status'] as String?,
      victimName: map['victim_name'] as String?,
      notificationStatus: map['notification_status'] as String?,
      notificationMessage: map['notification_message'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'call_session_id': callSessionId,
      'family_contact_id': familyContactId,
      'risk_score': riskScore,
      'status': status,
    };
    if (id != null) map['id'] = id;
    if (scenarioType != null) map['scenario_type'] = scenarioType;
    if (riskLevel != null) map['risk_level'] = riskLevel;
    if (detectedSignals != null) map['detected_signals'] = detectedSignals;
    if (explanation != null) map['explanation'] = explanation;
    if (interventionStatus != null) map['intervention_status'] = interventionStatus;
    if (victimName != null) map['victim_name'] = victimName;
    if (notificationStatus != null) map['notification_status'] = notificationStatus;
    if (notificationMessage != null) map['notification_message'] = notificationMessage;
    return map;
  }

  FamilyAlertRecord copyWith({
    String? id,
    String? callSessionId,
    String? familyContactId,
    int? riskScore,
    String? status,
    DateTime? createdAt,
    String? scenarioType,
    String? riskLevel,
    List<String>? detectedSignals,
    String? explanation,
    String? interventionStatus,
    String? victimName,
    String? notificationStatus,
    String? notificationMessage,
  }) {
    return FamilyAlertRecord(
      id: id ?? this.id,
      callSessionId: callSessionId ?? this.callSessionId,
      familyContactId: familyContactId ?? this.familyContactId,
      riskScore: riskScore ?? this.riskScore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      scenarioType: scenarioType ?? this.scenarioType,
      riskLevel: riskLevel ?? this.riskLevel,
      detectedSignals: detectedSignals ?? this.detectedSignals,
      explanation: explanation ?? this.explanation,
      interventionStatus: interventionStatus ?? this.interventionStatus,
      victimName: victimName ?? this.victimName,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      notificationMessage: notificationMessage ?? this.notificationMessage,
    );
  }

  @override
  String toString() =>
      'FamilyAlertRecord(id: $id, call: $callSessionId, status: $status, score: $riskScore, type: $scenarioType)';
}

/// Service managing family alert persistence and audit tracking.
///
/// Transparently reflects the alert pipeline:
/// - In offline demo mode: safely logs and simulates the alert event in memory.
/// - In cloud mode: inserts a row into `public.alerts`, transitioning status to `pending`.
/// - Explicitly does NOT claim that SMS or push notifications were delivered.
class FamilyAlertService {
  static final FamilyAlertService instance = FamilyAlertService._internal();

  FamilyAlertService._internal();

  final List<FamilyAlertRecord> _inMemoryAlerts = [];
  final StreamController<FamilyAlertRecord> _alertStreamController =
      StreamController<FamilyAlertRecord>.broadcast();

  /// Stream of newly created or updated alerts for local UI reactivity.
  Stream<FamilyAlertRecord> get onAlertCreated => _alertStreamController.stream;

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Creates a new alert record associated with a call session and contact.
  ///
  /// Returns the persisted [FamilyAlertRecord] with an initial status of 'pending'.
  Future<FamilyAlertRecord> createAlert({
    String? id,
    required String callSessionId,
    required String familyContactId,
    required int riskScore,
    String status = 'pending',
    String? scenarioType,
    String? riskLevel,
    List<String>? detectedSignals,
    String? explanation,
    String? interventionStatus,
    String? victimName,
    String? caregiverName,
    String? notificationStatus,
    String? notificationMessage,
  }) async {
    final alertId = id ?? 'alert_${DateTime.now().millisecondsSinceEpoch}';
    final senior = victimName ?? 'Robert Jenkins (Father)';
    final caregiver = caregiverName ?? 'Sarah Jenkins (Daughter)';

    // Step 17 Architecture: Pass alert through NotificationService abstraction
    final notifRequest = NotificationRequest(
      alertId: alertId,
      caregiverId: familyContactId,
      caregiverDisplayName: caregiver,
      seniorDisplayName: senior,
      riskScore: riskScore.clamp(0, 100),
      riskLevel: riskLevel ?? 'High',
      scenarioType: scenarioType ?? 'Scam Threat',
      detectedSignals: detectedSignals ?? const [],
      explanation: explanation ?? '',
      interventionStatus: interventionStatus ?? 'User requested Family Alert',
      timestamp: DateTime.now(),
    );

    final notifResult =
        await NotificationService.instance.sendFamilyAlert(notifRequest);

    final alert = FamilyAlertRecord(
      id: alertId,
      callSessionId: callSessionId,
      familyContactId: familyContactId,
      riskScore: riskScore.clamp(0, 100),
      status: status,
      createdAt: DateTime.now(),
      scenarioType: scenarioType,
      riskLevel: riskLevel,
      detectedSignals: detectedSignals,
      explanation: explanation,
      interventionStatus: interventionStatus,
      victimName: senior,
      notificationStatus: notificationStatus ?? notifResult.status.label,
      notificationMessage: notificationMessage ?? notifResult.message,
    );

    if (!isConfigured) {
      _inMemoryAlerts.insert(0, alert);
      _alertStreamController.add(alert);
      developer.log(
        'Offline Demo: Family alert recorded locally (notification status: ${alert.notificationStatus}).',
        name: 'FamilyAlertService',
      );
      return alert;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      _inMemoryAlerts.insert(0, alert);
      _alertStreamController.add(alert);
      return alert;
    }

    try {
      final dbData = <String, dynamic>{
        'call_session_id': alert.callSessionId,
        'family_contact_id': alert.familyContactId,
        'risk_score': alert.riskScore,
        'status': alert.status,
      };
      final isValidUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(alert.id ?? '');

      if (isValidUuid) {
        dbData['id'] = alert.id!;
      }

      final res = await client.from('alerts').insert(dbData).select().single();
      final persisted = FamilyAlertRecord.fromMap(res).copyWith(
        scenarioType: scenarioType,
        riskLevel: riskLevel,
        detectedSignals: detectedSignals,
        explanation: explanation,
        interventionStatus: interventionStatus,
        victimName: senior,
        notificationStatus: alert.notificationStatus,
        notificationMessage: alert.notificationMessage,
      );
      _inMemoryAlerts.insert(0, persisted);
      _alertStreamController.add(persisted);
      developer.log(
        'Cloud: Family alert recorded in Supabase (status: pending, notif: ${persisted.notificationStatus}). Realtime event published.',
        name: 'FamilyAlertService',
      );
      return persisted;
    } catch (e) {
      developer.log(
        'Warning: Family alert cloud persistence failed: $e. Retaining local copy.',
        name: 'FamilyAlertService',
        error: e,
      );
      _inMemoryAlerts.insert(0, alert);
      _alertStreamController.add(alert);
      return alert;
    }
  }

  /// Retrieves alerts associated with a specific call session.
  Future<List<FamilyAlertRecord>> getAlertsForCall(String callSessionId) async {
    if (!isConfigured) {
      return _inMemoryAlerts
          .where((a) => a.callSessionId == callSessionId)
          .toList();
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return _inMemoryAlerts
          .where((a) => a.callSessionId == callSessionId)
          .toList();
    }

    try {
      final res = await client
          .from('alerts')
          .select()
          .eq('call_session_id', callSessionId)
          .order('created_at', ascending: false);

      return (res as List).map((m) => FamilyAlertRecord.fromMap(m)).toList();
    } catch (e) {
      developer.log('Failed to fetch alerts for call: $e', name: 'FamilyAlertService', error: e);
      return _inMemoryAlerts
          .where((a) => a.callSessionId == callSessionId)
          .toList();
    }
  }

  /// Updates status of an alert record (e.g. marked dismissed or reviewed).
  Future<FamilyAlertRecord?> updateAlertStatus(String alertId, String newStatus) async {
    final idx = _inMemoryAlerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      final existing = _inMemoryAlerts[idx];
      final updated = existing.copyWith(status: newStatus);
      _inMemoryAlerts[idx] = updated;
      _alertStreamController.add(updated);

      if (!isConfigured) {
        return updated;
      }
    }

    final client = SupabaseService.instance.client;
    if (client == null) return null;

    try {
      final res = await client
          .from('alerts')
          .update({'status': newStatus})
          .eq('id', alertId)
          .select()
          .maybeSingle();

      if (res != null) {
        return FamilyAlertRecord.fromMap(res);
      }
    } catch (e) {
      developer.log('Failed to update alert status: $e', name: 'FamilyAlertService', error: e);
    }
    return null;
  }

  /// Retrieves alerts accessible to the current user as an authorized caregiver.
  ///
  /// Protected by PostgreSQL RLS:
  /// Only alerts belonging to active relationships where caregiver_user_id = auth.uid()
  /// are returned by the database.
  Future<List<FamilyAlertRecord>> getCaregiverAlerts() async {
    if (!isConfigured) {
      // In offline demo mode, return simulated alerts for preview
      if (_inMemoryAlerts.isEmpty) {
        return [
          FamilyAlertRecord(
            id: 'demo-caregiver-alert-1',
            callSessionId: 'demo-session-kyc',
            familyContactId: 'demo-contact-sarah',
            riskScore: 92,
            status: 'pending',
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
            scenarioType: 'Fake KYC Verification Scam',
            riskLevel: 'Critical',
            detectedSignals: const [
              'Authority impersonation',
              'Urgency or time pressure',
              'Sensitive information request',
            ],
            explanation:
                'Caller impersonated a bank official threatening account closure without OTP verification.',
            interventionStatus: 'User selected End Call',
            victimName: 'Robert Jenkins (Father)',
          ),
        ];
      }
      return List.unmodifiable(_inMemoryAlerts);
    }

    final client = SupabaseService.instance.client;
    if (client == null) return [];

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final res = await client
          .from('alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      return (res as List).map((m) => FamilyAlertRecord.fromMap(m)).toList();
    } catch (e) {
      developer.log(
        'Failed to fetch caregiver alerts: $e. Returning empty list.',
        name: 'FamilyAlertService',
        error: e,
      );
      return [];
    }
  }

  /// Resets in-memory alerts for unit testing.
  void resetForTesting() {
    _inMemoryAlerts.clear();
  }
}
