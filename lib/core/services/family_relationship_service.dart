import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Domain model representing an authenticated relationship between an
/// elderly user (owner) and a designated caregiver account.
///
/// In GuardCall, this relationship is a cryptographically authenticated
/// authorization record (linking two distinct `auth.users` identities in Supabase).
/// It is NOT a raw contact string or address book entry.
class FamilyRelationship {
  final String id;
  final String ownerUserId;
  final String caregiverUserId;
  final String? relationship;
  final String? displayName;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FamilyRelationship({
    required this.id,
    required this.ownerUserId,
    required this.caregiverUserId,
    this.relationship,
    this.displayName,
    this.enabled = true,
    this.createdAt,
    this.updatedAt,
  });

  factory FamilyRelationship.fromMap(Map<String, dynamic> map) {
    return FamilyRelationship(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String,
      caregiverUserId: map['caregiver_user_id'] as String,
      relationship: map['relationship'] as String?,
      displayName: map['display_name'] as String?,
      enabled: (map['enabled'] as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'owner_user_id': ownerUserId,
      'caregiver_user_id': caregiverUserId,
      'relationship': relationship,
      'enabled': enabled,
    };
    if (id.isNotEmpty) map['id'] = id;
    if (displayName != null) map['display_name'] = displayName;
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    return map;
  }

  FamilyRelationship copyWith({
    String? id,
    String? ownerUserId,
    String? caregiverUserId,
    String? relationship,
    String? displayName,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyRelationship(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      caregiverUserId: caregiverUserId ?? this.caregiverUserId,
      relationship: relationship ?? this.relationship,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'FamilyRelationship(id: $id, owner: $ownerUserId, caregiver: $caregiverUserId, rel: $relationship, enabled: $enabled)';
}

/// Model representing a pending or finalized caregiver invitation.
///
/// NOTE: GuardCall does not send email or SMS directly from the mobile client.
/// This record establishes the authorization intent in PostgreSQL.
class FamilyInvitation {
  final String id;
  final String ownerUserId;
  final String invitedEmail;
  final String? relationship;
  final String? displayName;
  final String status; // 'pending', 'accepted', 'expired', 'revoked'
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const FamilyInvitation({
    required this.id,
    required this.ownerUserId,
    required this.invitedEmail,
    this.relationship,
    this.displayName,
    this.status = 'pending',
    this.createdAt,
    this.expiresAt,
  });

  factory FamilyInvitation.fromMap(Map<String, dynamic> map) {
    return FamilyInvitation(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String,
      invitedEmail: map['invited_email'] as String,
      relationship: map['relationship'] as String?,
      displayName: map['display_name'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'owner_user_id': ownerUserId,
      'invited_email': invitedEmail,
      'relationship': relationship,
      'status': status,
    };
    if (id.isNotEmpty) map['id'] = id;
    if (displayName != null) map['display_name'] = displayName;
    if (createdAt != null) map['created_at'] = createdAt!.toIso8601String();
    if (expiresAt != null) map['expires_at'] = expiresAt!.toIso8601String();
    return map;
  }

  FamilyInvitation copyWith({
    String? id,
    String? ownerUserId,
    String? invitedEmail,
    String? relationship,
    String? displayName,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return FamilyInvitation(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      relationship: relationship ?? this.relationship,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() =>
      'FamilyInvitation(id: $id, email: $invitedEmail, rel: $relationship, status: $status)';
}

/// Service managing the authenticated Family Circle relationships and invitations.
///
/// Security Guarantees:
/// - In offline demo mode: safely returns simulated mock relationships without network calls.
/// - In Supabase mode: relies strictly on Supabase Auth and PostgreSQL RLS.
/// - Never accepts an unverified user ID or attempts to bypass RLS.
/// - Does not crash on network errors; falls back gracefully to in-memory state.
/// - Persists local demo relationships and invitations across app restarts via [SharedPreferences].
class FamilyRelationshipService {
  static final FamilyRelationshipService instance = FamilyRelationshipService._internal();
  static const String _storageKeyRelationships = 'guardcall_family_relationships_v1';
  static const String _storageKeyInvitations = 'guardcall_family_invitations_v1';

  FamilyRelationshipService._internal() {
    _initDemoData();
  }

  final List<FamilyRelationship> _inMemoryRelationships = [];
  final List<FamilyInvitation> _inMemoryInvitations = [];

  void _initDemoData() {
    _inMemoryRelationships.clear();
    _inMemoryInvitations.clear();
    // Default simulated relationship for offline demo mode
    _inMemoryRelationships.add(
      FamilyRelationship(
        id: 'demo-rel-sarah',
        ownerUserId: 'demo-owner-id',
        caregiverUserId: 'demo-caregiver-sarah',
        relationship: 'Daughter (Primary Caregiver)',
        displayName: 'Sarah Jenkins',
        enabled: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );
  }

  /// Loads locally saved relationships and invitations from [SharedPreferences].
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final relStr = prefs.getString(_storageKeyRelationships);
      if (relStr != null && relStr.trim().isNotEmpty) {
        final decoded = jsonDecode(relStr);
        if (decoded is List) {
          final loadedRels = <FamilyRelationship>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loadedRels.add(FamilyRelationship.fromMap(item));
            } else if (item is Map) {
              loadedRels.add(FamilyRelationship.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          if (loadedRels.isNotEmpty) {
            _inMemoryRelationships.clear();
            _inMemoryRelationships.addAll(loadedRels);
          }
        }
      } else {
        _initDemoData();
      }

      final invStr = prefs.getString(_storageKeyInvitations);
      if (invStr != null && invStr.trim().isNotEmpty) {
        final decoded = jsonDecode(invStr);
        if (decoded is List) {
          final loadedInvs = <FamilyInvitation>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loadedInvs.add(FamilyInvitation.fromMap(item));
            } else if (item is Map) {
              loadedInvs.add(FamilyInvitation.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          _inMemoryInvitations.clear();
          _inMemoryInvitations.addAll(loadedInvs);
        }
      }
    } catch (_) {
      _initDemoData();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final relList = _inMemoryRelationships.map((r) => r.toMap()).toList();
      await prefs.setString(_storageKeyRelationships, jsonEncode(relList));
      final invList = _inMemoryInvitations.map((i) => i.toMap()).toList();
      await prefs.setString(_storageKeyInvitations, jsonEncode(invList));
    } catch (_) {
      // Safe fallback
    }
  }

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Retrieves the current user's relationships where they are the account owner.
  Future<List<FamilyRelationship>> getMyRelationships() async {
    if (!isConfigured) {
      return List.unmodifiable(_inMemoryRelationships);
    }

    final client = SupabaseService.instance.client;
    if (client == null) return List.unmodifiable(_inMemoryRelationships);

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return List.unmodifiable(_inMemoryRelationships);

    try {
      final res = await client
          .from('family_relationships')
          .select()
          .eq('owner_user_id', currentUserId)
          .order('created_at', ascending: true);

      final list = (res as List).map((m) => FamilyRelationship.fromMap(m)).toList();
      return list;
    } catch (e) {
      developer.log(
        'Failed to fetch relationships: $e. Falling back to in-memory.',
        name: 'FamilyRelationshipService',
        error: e,
      );
      return List.unmodifiable(_inMemoryRelationships);
    }
  }

  /// Retrieves relationships where the current user is designated as the caregiver.
  Future<List<FamilyRelationship>> getCaregiverRelationships() async {
    if (!isConfigured) {
      // In offline demo mode, provide an empty list or demo caregiver perspective
      return [];
    }

    final client = SupabaseService.instance.client;
    if (client == null) return [];

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final res = await client
          .from('family_relationships')
          .select()
          .eq('caregiver_user_id', currentUserId)
          .order('created_at', ascending: true);

      final list = (res as List).map((m) => FamilyRelationship.fromMap(m)).toList();
      return list;
    } catch (e) {
      developer.log(
        'Failed to fetch caregiver relationships: $e.',
        name: 'FamilyRelationshipService',
        error: e,
      );
      return [];
    }
  }

  /// Creates a new authenticated family relationship.
  Future<FamilyRelationship> createRelationship({
    required String caregiverUserId,
    String? relationship,
    bool enabled = true,
  }) async {
    if (!isConfigured) {
      final rel = FamilyRelationship(
        id: 'rel_${DateTime.now().millisecondsSinceEpoch}',
        ownerUserId: 'demo-owner-id',
        caregiverUserId: caregiverUserId.trim(),
        relationship: relationship?.trim(),
        enabled: enabled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _inMemoryRelationships.add(rel);
      await _saveToStorage();
      return rel;
    }

    final client = SupabaseService.instance.client;
    if (client == null) throw StateError('Supabase client unavailable.');

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Authentication required to create a family relationship.');
    }

    try {
      final data = {
        'owner_user_id': currentUserId,
        'caregiver_user_id': caregiverUserId.trim(),
        'relationship': relationship?.trim(),
        'enabled': enabled,
      };

      final res = await client
          .from('family_relationships')
          .insert(data)
          .select()
          .single();

      final created = FamilyRelationship.fromMap(res);
      _inMemoryRelationships.add(created);
      return created;
    } catch (e) {
      developer.log('Failed to create relationship: $e', name: 'FamilyRelationshipService', error: e);
      rethrow;
    }
  }

  /// Enables or disables a family relationship.
  Future<void> enableRelationship(String id, bool enabled) async {
    if (!isConfigured) {
      final idx = _inMemoryRelationships.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _inMemoryRelationships[idx] =
            _inMemoryRelationships[idx].copyWith(enabled: enabled, updatedAt: DateTime.now());
        await _saveToStorage();
      }
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await client
          .from('family_relationships')
          .update({
            'enabled': enabled,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('owner_user_id', currentUserId);

      final idx = _inMemoryRelationships.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _inMemoryRelationships[idx] =
            _inMemoryRelationships[idx].copyWith(enabled: enabled);
      }
    } catch (e) {
      developer.log('Failed to toggle relationship: $e', name: 'FamilyRelationshipService', error: e);
    }
  }

  /// Deletes a family relationship.
  Future<void> deleteRelationship(String id) async {
    if (!isConfigured) {
      _inMemoryRelationships.removeWhere((r) => r.id == id);
      await _saveToStorage();
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await client
          .from('family_relationships')
          .delete()
          .eq('id', id)
          .eq('owner_user_id', currentUserId);

      _inMemoryRelationships.removeWhere((r) => r.id == id);
    } catch (e) {
      developer.log('Failed to delete relationship: $e', name: 'FamilyRelationshipService', error: e);
      rethrow;
    }
  }

  /// Creates a pending caregiver invitation record.
  ///
  /// IMPORTANT: GuardCall records the authorization request in Supabase.
  /// Client-side SMS or email delivery is NOT implemented.
  Future<FamilyInvitation> createInvitation({
    required String invitedEmail,
    String? relationship,
    String? displayName,
  }) async {
    final cleanEmail = invitedEmail.trim().toLowerCase();
    final cleanRel = relationship?.trim();
    final cleanName = displayName?.trim();

    if (!isConfigured) {
      final inv = FamilyInvitation(
        id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
        ownerUserId: 'demo-owner-id',
        invitedEmail: cleanEmail,
        relationship: cleanRel,
        displayName: cleanName,
        status: 'pending',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      _inMemoryInvitations.insert(0, inv);
      await _saveToStorage();
      developer.log(
        'Offline Demo: Caregiver invitation recorded locally (delivery not connected).',
        name: 'FamilyRelationshipService',
      );
      return inv;
    }

    final client = SupabaseService.instance.client;
    if (client == null) throw StateError('Supabase client unavailable.');

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Authentication required to create invitations.');
    }

    try {
      final data = {
        'owner_user_id': currentUserId,
        'invited_email': cleanEmail,
        'relationship': cleanRel,
        'status': 'pending',
      };

      final res = await client
          .from('family_invitations')
          .insert(data)
          .select()
          .single();

      final created = FamilyInvitation.fromMap(res).copyWith(displayName: cleanName);
      _inMemoryInvitations.insert(0, created);
      return created;
    } catch (e) {
      developer.log('Failed to create invitation: $e', name: 'FamilyRelationshipService', error: e);
      rethrow;
    }
  }

  /// Retrieves invitations created by the current user.
  Future<List<FamilyInvitation>> getMyInvitations() async {
    if (!isConfigured) {
      return List.unmodifiable(_inMemoryInvitations);
    }

    final client = SupabaseService.instance.client;
    if (client == null) return List.unmodifiable(_inMemoryInvitations);

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return List.unmodifiable(_inMemoryInvitations);

    try {
      final res = await client
          .from('family_invitations')
          .select()
          .eq('owner_user_id', currentUserId)
          .order('created_at', ascending: false);

      return (res as List).map((m) => FamilyInvitation.fromMap(m)).toList();
    } catch (e) {
      developer.log(
        'Failed to fetch invitations: $e. Falling back to local cache.',
        name: 'FamilyRelationshipService',
        error: e,
      );
      return List.unmodifiable(_inMemoryInvitations);
    }
  }

  /// Revokes an existing pending invitation.
  Future<void> revokeInvitation(String id) async {
    if (!isConfigured) {
      final idx = _inMemoryInvitations.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _inMemoryInvitations[idx] =
            _inMemoryInvitations[idx].copyWith(status: 'revoked');
        await _saveToStorage();
      }
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await client
          .from('family_invitations')
          .update({'status': 'revoked'})
          .eq('id', id)
          .eq('owner_user_id', currentUserId);

      final idx = _inMemoryInvitations.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _inMemoryInvitations[idx] =
            _inMemoryInvitations[idx].copyWith(status: 'revoked');
      }
    } catch (e) {
      developer.log('Failed to revoke invitation: $e', name: 'FamilyRelationshipService', error: e);
      rethrow;
    }
  }

  /// Resets in-memory state for testing.
  void resetForTesting() {
    _initDemoData();
  }
}
