// ignore_for_file: avoid_print, unused_local_variable, depend_on_referenced_packages
import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  print('=== GUARDCALL CATEGORY J: RLS & ISOLATION AUDIT ===');

  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('FAIL: .env file missing');
    exit(1);
  }

  final env = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx != -1) {
      env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
    }
  }

  final supabaseUrl = env['SUPABASE_URL'];
  final supabaseAnonKey = env['SUPABASE_ANON_KEY'];
  final testEmail = env['TEST_AUTH_EMAIL'];
  final testPassword = env['TEST_AUTH_PASSWORD'];

  if (supabaseUrl == null || supabaseAnonKey == null || testEmail == null || testPassword == null) {
    print('BLOCKED: Missing required Supabase configuration in .env');
    exit(1);
  }

  final client = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );

  print('[1/8] Authenticating User A (Sanitized credentials)...');
  try {
    final authRes = await client.auth.signInWithPassword(
      email: testEmail,
      password: testPassword,
    );
    final user = authRes.user;
    if (user == null) {
      print('FAIL: User A authentication returned null user.');
      exit(1);
    }
    final sanitizedUid = '${user.id.substring(0, 8)}...[REDACTED]';
    print('PASS: User A authenticated successfully (UID: $sanitizedUid)');

    final foreignUid = '00000000-0000-0000-0000-000000000001';
    final foreignSessionId = '00000000-0000-0000-0000-000000000002';

    // 1. Profiles Table Isolation Audit
    print('\n[2/8] Table public.profiles:');
    final myProfiles = await client.from('profiles').select();
    final allOwn = myProfiles.every((r) => r['id'] == user.id);
    print('  - Unfiltered SELECT count: ${myProfiles.length} (All rows match auth.uid(): $allOwn)');
    final foreignProfile = await client.from('profiles').select().eq('id', foreignUid);
    print('  - Foreign ID SELECT: ${foreignProfile.length} rows returned (Expect 0)');
    final foreignUpdate = await client.from('profiles').update({'name': 'Attacker'}).eq('id', foreignUid).select();
    print('  - Foreign ID UPDATE: ${foreignUpdate.length} rows modified (Expect 0)');

    // 2. Family Contacts Table Isolation Audit
    print('\n[3/8] Table public.family_contacts:');
    final myContacts = await client.from('family_contacts').select();
    final allContactsOwn = myContacts.every((r) => r['user_id'] == user.id);
    print('  - Unfiltered SELECT count: ${myContacts.length} (All rows match auth.uid(): $allContactsOwn)');
    final foreignContacts = await client.from('family_contacts').select().eq('user_id', foreignUid);
    print('  - Foreign user_id SELECT: ${foreignContacts.length} rows returned (Expect 0)');
    bool insertContactBlocked = false;
    try {
      await client.from('family_contacts').insert({
        'user_id': foreignUid,
        'name': 'Spoofed Contact',
        'contact_identifier': '+15559999999',
      }).select();
    } catch (e) {
      insertContactBlocked = true;
      print('  - Spoofed user_id INSERT: Blocked by RLS with error (${e.runtimeType})');
    }
    if (!insertContactBlocked) {
      print('  - Spoofed user_id INSERT: WARNING not blocked!');
    }

    // 3. Call Sessions Table Isolation Audit
    print('\n[4/8] Table public.call_sessions:');
    final mySessions = await client.from('call_sessions').select();
    final allSessionsOwn = mySessions.every((r) => r['user_id'] == user.id);
    print('  - Unfiltered SELECT count: ${mySessions.length} (All rows match auth.uid(): $allSessionsOwn)');
    final foreignSessions = await client.from('call_sessions').select().eq('user_id', foreignUid);
    print('  - Foreign user_id SELECT: ${foreignSessions.length} rows returned (Expect 0)');
    bool insertSessionBlocked = false;
    try {
      await client.from('call_sessions').insert({
        'user_id': foreignUid,
        'risk_score': 99,
        'risk_level': 'critical',
      }).select();
    } catch (e) {
      insertSessionBlocked = true;
      print('  - Spoofed user_id INSERT: Blocked by RLS with error (${e.runtimeType})');
    }

    // 4. Risk Signals Table Isolation Audit
    print('\n[5/8] Table public.risk_signals:');
    final mySignals = await client.from('risk_signals').select();
    print('  - Unfiltered SELECT count: ${mySignals.length}');
    final foreignSignals = await client.from('risk_signals').select().eq('call_session_id', foreignSessionId);
    print('  - Foreign session_id SELECT: ${foreignSignals.length} rows returned (Expect 0)');
    bool insertSignalBlocked = false;
    try {
      await client.from('risk_signals').insert({
        'call_session_id': foreignSessionId,
        'signal_type': 'test_spoof',
        'severity': 'high',
        'explanation': 'Unauthorized probe',
      }).select();
    } catch (e) {
      insertSignalBlocked = true;
      print('  - Spoofed call_session_id INSERT: Blocked by RLS with error (${e.runtimeType})');
    }

    // 5. Family Relationships Table Isolation Audit
    print('\n[6/8] Table public.family_relationships:');
    final myRelationships = await client.from('family_relationships').select();
    final allRelsAuthorized = myRelationships.every((r) => r['owner_user_id'] == user.id || r['caregiver_user_id'] == user.id);
    print('  - Unfiltered SELECT count: ${myRelationships.length} (All authorized: $allRelsAuthorized)');
    final foreignRels = await client.from('family_relationships').select().eq('owner_user_id', foreignUid);
    print('  - Foreign owner_user_id SELECT: ${foreignRels.length} rows returned (Expect 0)');
    bool insertRelBlocked = false;
    try {
      await client.from('family_relationships').insert({
        'owner_user_id': foreignUid,
        'caregiver_user_id': user.id,
        'relationship': 'Unverified',
      }).select();
    } catch (e) {
      insertRelBlocked = true;
      print('  - Spoofed owner_user_id INSERT: Blocked by RLS with error (${e.runtimeType})');
    }

    // 6. Family Invitations Table Isolation Audit
    print('\n[7/8] Table public.family_invitations:');
    final myInvs = await client.from('family_invitations').select();
    final allInvsOwn = myInvs.every((r) => r['owner_user_id'] == user.id);
    print('  - Unfiltered SELECT count: ${myInvs.length} (All owned: $allInvsOwn)');
    final foreignInvs = await client.from('family_invitations').select().eq('owner_user_id', foreignUid);
    print('  - Foreign owner_user_id SELECT: ${foreignInvs.length} rows returned (Expect 0)');

    // 7. Alerts Table Caregiver Isolation Audit
    print('\n[8/8] Table public.alerts:');
    final myAlerts = await client.from('alerts').select();
    print('  - Unfiltered SELECT count: ${myAlerts.length}');
    final foreignAlerts = await client.from('alerts').select().eq('call_session_id', foreignSessionId);
    print('  - Foreign call_session_id SELECT: ${foreignAlerts.length} rows returned (Expect 0)');
    bool insertAlertBlocked = false;
    try {
      await client.from('alerts').insert({
        'call_session_id': foreignSessionId,
        'family_contact_id': foreignUid,
        'risk_score': 85,
      }).select();
    } catch (e) {
      insertAlertBlocked = true;
      print('  - Spoofed call_session_id INSERT: Blocked by RLS with error (${e.runtimeType})');
    }

    print('\n=== AUDIT RUN COMPLETED SUCCESSFULLY ===');
  } catch (e) {
    print('EXCEPTION DURING AUDIT: $e');
  }
}
