import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// Clean model representing a trusted caregiver contact record.
class FamilyContact {
  final String id;
  final String userId;
  final String name;
  final String? relationship;
  final String contactIdentifier;
  final bool enabled;
  final DateTime? createdAt;

  const FamilyContact({
    required this.id,
    required this.userId,
    required this.name,
    this.relationship,
    required this.contactIdentifier,
    this.enabled = true,
    this.createdAt,
  });

  factory FamilyContact.fromMap(Map<String, dynamic> map) {
    return FamilyContact(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      relationship: map['relationship'] as String?,
      contactIdentifier: map['contact_identifier'] as String,
      enabled: (map['enabled'] as bool?) ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'contact_identifier': contactIdentifier,
      'enabled': enabled,
    };
  }

  FamilyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? relationship,
    String? contactIdentifier,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return FamilyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      contactIdentifier: contactIdentifier ?? this.contactIdentifier,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'FamilyContact(id: $id, name: $name, rel: $relationship, enabled: $enabled)';
}

/// Service managing the user's trusted family circle contacts.
///
/// Designed with zero-trust isolation:
/// - Contacts are strictly scoped to the authenticated user's `auth.uid()`.
/// - Never allows arbitrary cross-user contact access.
/// - Falls back safely to placeholder demo contact in offline demo mode.
/// - Persists local demo contacts reliably across app restarts via [SharedPreferences].
class FamilyContactService {
  static final FamilyContactService instance = FamilyContactService._internal();
  static const String _storageKey = 'guardcall_family_contacts_v1';

  FamilyContactService._internal() {
    _initializeDemoContacts();
  }

  final List<FamilyContact> _inMemoryContacts = [];

  void _initializeDemoContacts() {
    _inMemoryContacts.clear();
    _inMemoryContacts.add(
      FamilyContact(
        id: 'demo-contact-sarah',
        userId: 'demo-user-offline',
        name: 'Sarah Jenkins',
        relationship: 'Daughter',
        contactIdentifier: '+1 (555) 234-5678',
        enabled: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Loads locally saved family contacts from [SharedPreferences].
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = <FamilyContact>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loaded.add(FamilyContact.fromMap(item));
            } else if (item is Map) {
              loaded.add(FamilyContact.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          if (loaded.isNotEmpty) {
            _inMemoryContacts.clear();
            _inMemoryContacts.addAll(loaded);
            return;
          }
        }
      }
    } catch (_) {
      // Safe fallback
    }
    _initializeDemoContacts();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _inMemoryContacts.map((c) => c.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {
      // Safe fallback
    }
  }

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Retrieves the list of family contacts for the current user.
  Future<List<FamilyContact>> getFamilyContacts() async {
    if (!isConfigured) {
      return List.unmodifiable(_inMemoryContacts);
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      return List.unmodifiable(_inMemoryContacts);
    }

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null) {
      return List.unmodifiable(_inMemoryContacts);
    }

    try {
      final res = await client
          .from('family_contacts')
          .select()
          .eq('user_id', currentAuthId)
          .order('created_at', ascending: true);

      final list = (res as List).map((m) => FamilyContact.fromMap(m)).toList();
      return list;
    } catch (e) {
      developer.log(
        'Failed to fetch family contacts: $e. Falling back to in-memory list.',
        name: 'FamilyContactService',
        error: e,
      );
      return List.unmodifiable(_inMemoryContacts);
    }
  }

  /// Adds a new family contact.
  Future<FamilyContact> addFamilyContact({
    required String name,
    String? relationship,
    required String contactIdentifier,
    bool enabled = true,
  }) async {
    final cleanName = name.trim();
    final cleanIdentifier = contactIdentifier.trim();

    if (!isConfigured) {
      final contact = FamilyContact(
        id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'demo-user-offline',
        name: cleanName,
        relationship: relationship?.trim(),
        contactIdentifier: cleanIdentifier,
        enabled: enabled,
        createdAt: DateTime.now(),
      );
      _inMemoryContacts.add(contact);
      await _saveToStorage();
      return contact;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw StateError('Supabase client unavailable.');
    }

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null) {
      throw StateError('Authentication required to add family contacts.');
    }

    try {
      final data = {
        'user_id': currentAuthId,
        'name': cleanName,
        'relationship': relationship?.trim(),
        'contact_identifier': cleanIdentifier,
        'enabled': enabled,
      };

      final res = await client.from('family_contacts').insert(data).select().single();
      final contact = FamilyContact.fromMap(res);
      _inMemoryContacts.add(contact);
      return contact;
    } catch (e) {
      developer.log('Failed to add family contact: $e', name: 'FamilyContactService', error: e);
      rethrow;
    }
  }

  /// Updates an existing family contact.
  Future<FamilyContact> updateFamilyContact(FamilyContact contact) async {
    if (!isConfigured) {
      final idx = _inMemoryContacts.indexWhere((c) => c.id == contact.id);
      if (idx != -1) {
        _inMemoryContacts[idx] = contact;
        await _saveToStorage();
      }
      return contact;
    }

    final client = SupabaseService.instance.client;
    if (client == null) throw StateError('Supabase client unavailable.');

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null || currentAuthId != contact.userId) {
      throw ArgumentError(
        'Security Violation: Cannot update contact belonging to another user.',
      );
    }

    try {
      final res = await client
          .from('family_contacts')
          .update(contact.toMap())
          .eq('id', contact.id)
          .eq('user_id', currentAuthId)
          .select()
          .single();

      return FamilyContact.fromMap(res);
    } catch (e) {
      developer.log('Failed to update family contact: $e', name: 'FamilyContactService', error: e);
      rethrow;
    }
  }

  /// Removes a family contact.
  Future<void> removeFamilyContact(String id) async {
    if (!isConfigured) {
      _inMemoryContacts.removeWhere((c) => c.id == id);
      await _saveToStorage();
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null) return;

    try {
      await client
          .from('family_contacts')
          .delete()
          .eq('id', id)
          .eq('user_id', currentAuthId);

      _inMemoryContacts.removeWhere((c) => c.id == id);
    } catch (e) {
      developer.log('Failed to remove family contact: $e', name: 'FamilyContactService', error: e);
      rethrow;
    }
  }

  /// Toggles enabled state of a family contact.
  Future<void> toggleContactEnabled(String id, bool enabled) async {
    if (!isConfigured) {
      final idx = _inMemoryContacts.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _inMemoryContacts[idx] = _inMemoryContacts[idx].copyWith(enabled: enabled);
        await _saveToStorage();
      }
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) return;

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null) return;

    try {
      await client
          .from('family_contacts')
          .update({'enabled': enabled})
          .eq('id', id)
          .eq('user_id', currentAuthId);
    } catch (e) {
      developer.log('Failed to toggle contact enabled: $e', name: 'FamilyContactService', error: e);
    }
  }

  /// Resets in-memory contacts for unit testing.
  void resetForTesting() {
    _initializeDemoContacts();
  }

  /// Clears in-memory contacts for testing empty state.
  void clearForTesting() {
    _inMemoryContacts.clear();
  }
}
