import 'dart:developer' as developer;
import 'supabase_service.dart';

/// Application user profile representation.
class UserProfile {
  final String id;
  final String name;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'GuardCall User',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserProfile(id: $id, name: $name)';
}

/// Service managing user profiles and initial user settings in Supabase.
///
/// Ensures strict ID validation:
/// - In cloud mode, verifies that profile operations match the authenticated user ID
/// - Never allows arbitrary cross-user profile modification
/// - Gracefully falls back to in-memory profile in offline/demo mode
class ProfileService {
  static final ProfileService instance = ProfileService._internal();

  ProfileService._internal();

  UserProfile? _demoProfile;

  /// Whether Supabase is active.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Creates a new profile row in `public.profiles` and initializes `public.user_settings`.
  Future<UserProfile> createProfile({
    required String id,
    required String name,
  }) async {
    final cleanName = name.trim().isEmpty ? 'GuardCall User' : name.trim();

    if (!isConfigured) {
      _demoProfile = UserProfile(
        id: id,
        name: cleanName,
        createdAt: DateTime.now(),
      );
      return _demoProfile!;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw StateError('Supabase client is not available.');
    }

    // Verify caller is operating on their own authenticated identity
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId != id) {
      throw ArgumentError(
        'Security Violation: Cannot create profile for a user ID different from auth.uid().',
      );
    }

    try {
      // 1. Insert into public.profiles
      final profileData = {
        'id': id,
        'name': cleanName,
      };
      await client.from('profiles').upsert(profileData);

      // 2. Initialize default public.user_settings
      try {
        await client.from('user_settings').upsert({
          'user_id': id,
          'family_alerts': true,
          'transcript_retention': false,
          'reduce_motion': false,
        });
      } catch (settingsErr) {
        developer.log(
          'Warning: user_settings initialization error: $settingsErr',
          name: 'ProfileService',
        );
      }

      return UserProfile(
        id: id,
        name: cleanName,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      developer.log('Error creating profile: $e', name: 'ProfileService', error: e);
      rethrow;
    }
  }

  /// Retrieves the profile for the given user ID.
  Future<UserProfile?> getProfile(String id) async {
    if (!isConfigured) {
      return _demoProfile ??
          const UserProfile(
            id: 'demo-user-offline',
            name: 'Demo User',
          );
    }

    final client = SupabaseService.instance.client;
    if (client == null) return null;

    try {
      final res = await client
          .from('profiles')
          .select('id, name, created_at')
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;
      return UserProfile.fromMap(res);
    } catch (e) {
      developer.log('Error fetching profile: $e', name: 'ProfileService', error: e);
      return null;
    }
  }

  /// Updates an existing profile's display name.
  Future<UserProfile> updateProfile({
    required String id,
    required String name,
  }) async {
    final cleanName = name.trim();

    if (!isConfigured) {
      _demoProfile = UserProfile(
        id: id,
        name: cleanName,
        createdAt: _demoProfile?.createdAt ?? DateTime.now(),
      );
      return _demoProfile!;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw StateError('Supabase client is not available.');
    }

    // Verify caller is updating their own profile
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId != id) {
      throw ArgumentError(
        'Security Violation: Cannot update profile for a user ID different from auth.uid().',
      );
    }

    try {
      await client
          .from('profiles')
          .update({'name': cleanName})
          .eq('id', id);

      return UserProfile(
        id: id,
        name: cleanName,
      );
    } catch (e) {
      developer.log('Error updating profile: $e', name: 'ProfileService', error: e);
      rethrow;
    }
  }

  /// Resets demo profile state for unit tests.
  void resetForTesting() {
    _demoProfile = null;
  }
}
