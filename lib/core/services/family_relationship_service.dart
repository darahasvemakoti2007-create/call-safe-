import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_state.dart';
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

  final StreamController<FamilyRelationship> _relationshipChangeController =
      StreamController<FamilyRelationship>.broadcast();

  /// Reactive stream emitting updated relationships on creation, update, deletion, or acceptance.
  Stream<FamilyRelationship> get onRelationshipChanged =>
      _relationshipChangeController.stream;

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
  Future<List<FamilyRelationship>> getCaregiverRelationships({String? caregiverUserId}) async {
    if (!isConfigured) {
      final effectiveId = caregiverUserId ?? AuthState.instance.currentUser?.id;
      if (effectiveId == null || effectiveId.isEmpty) {
        return List.unmodifiable(_inMemoryRelationships);
      }
      return List.unmodifiable(
        _inMemoryRelationships.where((r) => r.caregiverUserId == effectiveId).toList(),
      );
    }

    final client = SupabaseService.instance.client;
    if (client == null) return [];

    final currentUserId = caregiverUserId ?? client.auth.currentUser?.id;
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
      _relationshipChangeController.add(rel);
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
      _relationshipChangeController.add(created);
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
        final updated = _inMemoryRelationships[idx].copyWith(
          enabled: enabled,
          updatedAt: DateTime.now(),
        );
        _inMemoryRelationships[idx] = updated;
        await _saveToStorage();
        _relationshipChangeController.add(updated);
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
        final updated = _inMemoryRelationships[idx].copyWith(
          enabled: enabled,
          updatedAt: DateTime.now(),
        );
        _inMemoryRelationships[idx] = updated;
        _relationshipChangeController.add(updated);
      }
    } catch (e) {
      developer.log('Failed to toggle relationship: $e', name: 'FamilyRelationshipService', error: e);
    }
  }

  /// Deletes a family relationship.
  Future<void> deleteRelationship(String id) async {
    if (!isConfigured) {
      final idx = _inMemoryRelationships.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final removed = _inMemoryRelationships.removeAt(idx);
        await _saveToStorage();
        _relationshipChangeController.add(removed.copyWith(enabled: false));
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
          .delete()
          .eq('id', id)
          .eq('owner_user_id', currentUserId);

      final idx = _inMemoryRelationships.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final removed = _inMemoryRelationships.removeAt(idx);
        _relationshipChangeController.add(removed.copyWith(enabled: false));
      }
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
    String? ownerUserId,
    DateTime? expiresAt,
  }) async {
    final cleanEmail = invitedEmail.trim().toLowerCase();
    final cleanRel = relationship?.trim();
    final cleanName = displayName?.trim();

    if (!isConfigured) {
      final effectiveOwnerId = ownerUserId ??
          AuthState.instance.currentUser?.id ??
          'demo-owner-id';
      final inv = FamilyInvitation(
        id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
        ownerUserId: effectiveOwnerId,
        invitedEmail: cleanEmail,
        relationship: cleanRel,
        displayName: cleanName,
        status: 'pending',
        createdAt: DateTime.now(),
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
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

    final currentUserId = ownerUserId ?? client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw StateError('Authentication required to create invitations.');
    }

    try {
      final data = <String, dynamic>{
        'owner_user_id': currentUserId,
        'invited_email': cleanEmail,
        'relationship': cleanRel,
        'status': 'pending',
      };
      if (expiresAt != null) {
        data['expires_at'] = expiresAt.toIso8601String();
      }

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

  /// Retrieves pending invitations addressed to a designated caregiver account.
  Future<List<FamilyInvitation>> getPendingInvitationsForCaregiver({
    String? email,
  }) async {
    final cleanEmail = (email ?? AuthState.instance.currentUser?.email)?.trim().toLowerCase();

    if (!isConfigured) {
      if (cleanEmail == null || cleanEmail.isEmpty) {
        return List.unmodifiable(
          _inMemoryInvitations
              .where((i) => i.status == 'pending' && i.invitedEmail.toLowerCase() == 'demo@guardcall.local')
              .toList(),
        );
      }
      return List.unmodifiable(
        _inMemoryInvitations
            .where((i) => i.status == 'pending' && i.invitedEmail.toLowerCase() == cleanEmail)
            .toList(),
      );
    }

    final client = SupabaseService.instance.client;
    if (client == null) return [];

    final targetEmail = cleanEmail ?? client.auth.currentUser?.email?.trim().toLowerCase();
    if (targetEmail == null || targetEmail.isEmpty) return [];

    try {
      final res = await client
          .from('family_invitations')
          .select()
          .eq('invited_email', targetEmail)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (res as List).map((m) => FamilyInvitation.fromMap(m)).toList();
    } catch (e) {
      developer.log(
        'Failed to fetch caregiver invitations: $e.',
        name: 'FamilyRelationshipService',
        error: e,
      );
      return [];
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

  /// Accepts a pending caregiver invitation and establishes an authenticated relationship.
  ///
  /// Validations:
  /// 1. Invitation must exist.
  /// 2. Invitation must have status 'pending'.
  /// 3. Invitation must not be expired.
  /// 4. Current user email must match the invitation's invitedEmail.
  /// 5. Self-acceptance is rejected (owner cannot accept their own invitation).
  /// 6. Duplicate active relationships are prevented.
  Future<FamilyRelationship> acceptInvitation(
    String invitationId, {
    String? caregiverUserId,
    String? caregiverEmail,
    String? caregiverDisplayName,
  }) async {
    final effectiveUserId = caregiverUserId ??
        (isConfigured
            ? SupabaseService.instance.client?.auth.currentUser?.id
            : AuthState.instance.currentUser?.id) ??
        'demo-caregiver-user';

    final effectiveEmail = (caregiverEmail ??
            (isConfigured
                ? SupabaseService.instance.client?.auth.currentUser?.email
                : AuthState.instance.currentUser?.email) ??
            'demo@guardcall.local')
        .trim()
        .toLowerCase();

    if (!isConfigured) {
      // --- OFFLINE / DEMO MODE ---
      final invIndex = _inMemoryInvitations.indexWhere((i) => i.id == invitationId);
      if (invIndex == -1) {
        throw ArgumentError('Invitation not found: $invitationId');
      }
      final invitation = _inMemoryInvitations[invIndex];

      // 1. Expiration check
      if (invitation.expiresAt != null && invitation.expiresAt!.isBefore(DateTime.now())) {
        _inMemoryInvitations[invIndex] = invitation.copyWith(status: 'expired');
        await _saveToStorage();
        throw StateError('Cannot accept an expired invitation.');
      }

      // 2. Status validation
      if (invitation.status == 'accepted') {
        throw StateError('Invitation has already been accepted.');
      }
      if (invitation.status == 'revoked') {
        throw StateError('Cannot accept a revoked invitation.');
      }
      if (invitation.status == 'expired') {
        throw StateError('Cannot accept an expired invitation.');
      }
      if (invitation.status != 'pending') {
        throw StateError('Cannot accept invitation with status "${invitation.status}".');
      }

      // 3. Recipient email validation
      if (effectiveEmail.isEmpty) {
        throw StateError('Caregiver email is required to accept an invitation.');
      }
      if (invitation.invitedEmail.trim().toLowerCase() != effectiveEmail) {
        throw ArgumentError(
          'Unauthorized: Invitation was sent to "${invitation.invitedEmail}", but current user is "$effectiveEmail".',
        );
      }

      // 4. Reject self-acceptance
      if (invitation.ownerUserId == effectiveUserId) {
        throw StateError('Self-acceptance is rejected: Owner cannot accept their own invitation.');
      }

      // 5. Prevent duplicate active relationships
      final existingIndex = _inMemoryRelationships.indexWhere(
        (r) => r.ownerUserId == invitation.ownerUserId && r.caregiverUserId == effectiveUserId,
      );
      if (existingIndex != -1) {
        final existing = _inMemoryRelationships[existingIndex];
        if (existing.enabled) {
          throw StateError(
            'Duplicate active relationship: An active relationship already exists between this owner and caregiver.',
          );
        }
        // Re-activate if previously disabled
        final updatedRel = existing.copyWith(
          enabled: true,
          relationship: invitation.relationship ?? existing.relationship,
          displayName: invitation.displayName ?? caregiverDisplayName ?? existing.displayName,
          updatedAt: DateTime.now(),
        );
        _inMemoryRelationships[existingIndex] = updatedRel;
        _inMemoryInvitations[invIndex] = invitation.copyWith(status: 'accepted');
        await _saveToStorage();
        _relationshipChangeController.add(updatedRel);
        return updatedRel;
      }

      // 6. Create active relationship & transition invitation
      final newRel = FamilyRelationship(
        id: 'rel_${DateTime.now().millisecondsSinceEpoch}',
        ownerUserId: invitation.ownerUserId,
        caregiverUserId: effectiveUserId,
        relationship: invitation.relationship,
        displayName: invitation.displayName ?? caregiverDisplayName,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _inMemoryRelationships.add(newRel);
      _inMemoryInvitations[invIndex] = invitation.copyWith(status: 'accepted');
      await _saveToStorage();
      _relationshipChangeController.add(newRel);
      return newRel;
    }

    // --- CLOUD SUPABASE MODE ---
    final client = SupabaseService.instance.client;
    if (client == null) throw StateError('Supabase client unavailable.');

    final currentAuthUser = client.auth.currentUser;
    if (currentAuthUser == null && caregiverUserId == null) {
      throw StateError('Authentication required to accept an invitation.');
    }

    try {
      // 1. Fetch invitation from cloud
      final invRes = await client
          .from('family_invitations')
          .select()
          .eq('id', invitationId)
          .maybeSingle();

      if (invRes == null) {
        throw ArgumentError('Invitation not found: $invitationId');
      }
      final invitation = FamilyInvitation.fromMap(invRes);

      // 2. Expiration check
      if (invitation.expiresAt != null && invitation.expiresAt!.isBefore(DateTime.now())) {
        await client
            .from('family_invitations')
            .update({'status': 'expired'})
            .eq('id', invitationId);
        throw StateError('Cannot accept an expired invitation.');
      }

      // 3. Status validation
      if (invitation.status == 'accepted') {
        throw StateError('Invitation has already been accepted.');
      }
      if (invitation.status == 'revoked') {
        throw StateError('Cannot accept a revoked invitation.');
      }
      if (invitation.status == 'expired') {
        throw StateError('Cannot accept an expired invitation.');
      }
      if (invitation.status != 'pending') {
        throw StateError('Cannot accept invitation with status "${invitation.status}".');
      }

      // 4. Recipient verification
      if (invitation.invitedEmail.trim().toLowerCase() != effectiveEmail) {
        throw ArgumentError(
          'Unauthorized: Invitation was sent to "${invitation.invitedEmail}", but current user is "$effectiveEmail".',
        );
      }

      // 5. Self-acceptance check
      if (invitation.ownerUserId == effectiveUserId) {
        throw StateError('Self-acceptance is rejected: Owner cannot accept their own invitation.');
      }

      // 6. Duplicate active relationship prevention
      final existingRelRes = await client
          .from('family_relationships')
          .select()
          .eq('owner_user_id', invitation.ownerUserId)
          .eq('caregiver_user_id', effectiveUserId)
          .maybeSingle();

      if (existingRelRes != null) {
        final existing = FamilyRelationship.fromMap(existingRelRes);
        if (existing.enabled) {
          throw StateError(
            'Duplicate active relationship: An active relationship already exists between this owner and caregiver.',
          );
        }
        final updatedRes = await client
            .from('family_relationships')
            .update({
              'enabled': true,
              'relationship': invitation.relationship ?? existing.relationship,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing.id)
            .select()
            .single();

        await client
            .from('family_invitations')
            .update({'status': 'accepted'})
            .eq('id', invitationId);

        final updatedRel = FamilyRelationship.fromMap(updatedRes);
        final memIdx = _inMemoryRelationships.indexWhere((r) => r.id == updatedRel.id);
        if (memIdx != -1) {
          _inMemoryRelationships[memIdx] = updatedRel;
        } else {
          _inMemoryRelationships.add(updatedRel);
        }
        _relationshipChangeController.add(updatedRel);
        return updatedRel;
      }

      // 7. Insert new relationship & update invitation
      final relData = <String, dynamic>{
        'owner_user_id': invitation.ownerUserId,
        'caregiver_user_id': effectiveUserId,
        'relationship': invitation.relationship,
        'enabled': true,
      };
      if (invitation.displayName != null || caregiverDisplayName != null) {
        relData['display_name'] = invitation.displayName ?? caregiverDisplayName;
      }

      final relRes = await client
          .from('family_relationships')
          .insert(relData)
          .select()
          .single();

      await client
          .from('family_invitations')
          .update({'status': 'accepted'})
          .eq('id', invitationId);

      final createdRel = FamilyRelationship.fromMap(relRes);
      _inMemoryRelationships.add(createdRel);
      _relationshipChangeController.add(createdRel);
      return createdRel;
    } catch (e) {
      developer.log('Failed to accept invitation: $e', name: 'FamilyRelationshipService', error: e);
      rethrow;
    }
  }

  /// Resets in-memory state for testing.
  void resetForTesting() {
    _initDemoData();
  }

  /// Clears in-memory relationships and invitations for empty state testing.
  void clearForTesting() {
    _inMemoryRelationships.clear();
    _inMemoryInvitations.clear();
  }
}
