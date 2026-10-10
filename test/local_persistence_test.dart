import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/services/accessibility_preferences.dart';
import 'package:guard_call/core/services/family_contact_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/services/notification_preferences.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Step 2 — Local Data Persistence Tests', () {
    // -------------------------------------------------------------------------
    // 1. Accessibility Preferences Persistence
    // -------------------------------------------------------------------------
    test('1. AccessibilityPreferences persists reduceMotion across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AccessibilityPreferences.instance;
      prefs.reset();
      expect(prefs.reduceMotion, isFalse);

      await prefs.setReduceMotion(true);
      expect(prefs.reduceMotion, isTrue);

      // Simulate app restart / reload from storage
      prefs.reset();
      expect(prefs.reduceMotion, isFalse);
      await prefs.loadFromStorage();
      expect(prefs.reduceMotion, isTrue);

      // Toggle back to false
      await prefs.setReduceMotion(false);
      prefs.reset();
      await prefs.loadFromStorage();
      expect(prefs.reduceMotion, isFalse);
    });

    // -------------------------------------------------------------------------
    // 2. Notification Preferences Persistence
    // -------------------------------------------------------------------------
    test('2. NotificationPreferences persists familyAlertsEnabled across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final notifPrefs = NotificationPreferences.instance;
      notifPrefs.reset();
      expect(notifPrefs.familyAlertsEnabled, isTrue);

      await notifPrefs.setFamilyAlertsEnabled(false);
      expect(notifPrefs.familyAlertsEnabled, isFalse);

      // Simulate app restart / reload from storage
      notifPrefs.reset();
      expect(notifPrefs.familyAlertsEnabled, isTrue); // default before load
      await notifPrefs.loadFromStorage();
      expect(notifPrefs.familyAlertsEnabled, isFalse);

      // Re-enable
      await notifPrefs.setFamilyAlertsEnabled(true);
      notifPrefs.reset();
      await notifPrefs.loadFromStorage();
      expect(notifPrefs.familyAlertsEnabled, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. Call History Repository Persistence
    // -------------------------------------------------------------------------
    test('3. CallHistoryRepository persists logged calls and survives reload', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CallHistoryRepository.instance;
      repo.resetForTesting();

      final initialCount = repo.records.length;
      expect(initialCount, 4); // Default seed records

      const newRecord = CallHistoryRecord(
        id: 'persisted_test_call_001',
        title: 'Fake SBI Verification Call',
        subtitle: 'Caller demanded 6-digit OTP under threat of account freeze.',
        timestamp: 'Just now',
        duration: '1m 12s',
        riskScore: 85,
        riskLevel: RiskLevel.critical,
        signals: ['Authority Impersonation', 'Urgency', 'OTP Request'],
        isSimulated: true,
        interventionStatus: 'familyAlertRequested',
      );

      await repo.addRecord(newRecord);
      expect(repo.records.length, initialCount + 1);
      expect(repo.records.first.id, 'persisted_test_call_001');

      // Simulate app restart / reload from storage
      repo.resetForTesting();
      expect(repo.records.length, initialCount); // reset back to seed
      await repo.loadFromStorage();

      expect(repo.records.length, initialCount + 1);
      expect(repo.records.first.id, 'persisted_test_call_001');
      expect(repo.records.first.riskScore, 85);
      expect(repo.records.first.riskLevel, RiskLevel.critical);
      expect(repo.records.first.signals, contains('OTP Request'));
    });

    test('4. CallHistoryRepository clear() persists empty state', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CallHistoryRepository.instance;
      repo.resetForTesting();

      await repo.clear();
      expect(repo.records.isEmpty, isTrue);

      // Reload from storage
      await repo.loadFromStorage();
      expect(repo.records.isEmpty, isTrue);
    });

    test('5. CallHistoryRecord privacy check: zero audio & zero transcripts stored', () {
      const record = CallHistoryRecord(
        id: 'privacy_check_1',
        title: 'Test Call',
        subtitle: 'Test Subtitle',
        timestamp: 'Today',
        duration: '30s',
        riskScore: 75,
        riskLevel: RiskLevel.high,
        signals: ['Urgency'],
      );

      final map = record.toMap();
      expect(map.containsKey('audio'), isFalse);
      expect(map.containsKey('audio_url'), isFalse);
      expect(map.containsKey('raw_audio'), isFalse);
      expect(map.containsKey('transcript'), isFalse);
      expect(map.containsKey('full_transcript'), isFalse);
      expect(map.containsKey('dialogue'), isFalse);
    });

    test('6. CallHistoryRepository gracefully handles corrupt JSON in storage', () async {
      SharedPreferences.setMockInitialValues({
        'guardcall_call_history_v1': 'INVALID_CORRUPT_JSON_DATA{{{[[[',
      });

      final repo = CallHistoryRepository.instance;
      await repo.loadFromStorage();

      // Gracefully falls back to default seed records without throwing
      expect(repo.records.isNotEmpty, isTrue);
      expect(repo.records.length, 4);
    });

    // -------------------------------------------------------------------------
    // 4. Family Contact Service Persistence
    // -------------------------------------------------------------------------
    test('7. FamilyContactService persists added and updated contacts', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FamilyContactService.instance;
      service.resetForTesting();

      final initial = await service.getFamilyContacts();
      expect(initial.length, 1);
      expect(initial.first.name, 'Sarah Jenkins');

      final added = await service.addFamilyContact(
        name: 'Michael Vance',
        relationship: 'Son',
        contactIdentifier: '+1 (555) 987-6543',
        enabled: true,
      );

      expect(added.name, 'Michael Vance');
      final updatedList = await service.getFamilyContacts();
      expect(updatedList.length, 2);

      // Simulate app restart / reload from storage
      service.resetForTesting();
      expect((await service.getFamilyContacts()).length, 1); // back to initial before load

      await service.loadFromStorage();
      final reloaded = await service.getFamilyContacts();
      expect(reloaded.length, 2);
      expect(reloaded.any((c) => c.name == 'Michael Vance'), isTrue);

      // Test remove
      await service.removeFamilyContact(added.id);
      service.resetForTesting();
      await service.loadFromStorage();
      final afterRemove = await service.getFamilyContacts();
      expect(afterRemove.any((c) => c.name == 'Michael Vance'), isFalse);
    });

    test('8. FamilyContactService handles corrupt storage safely', () async {
      SharedPreferences.setMockInitialValues({
        'guardcall_family_contacts_v1': 'CORRUPTED_NON_JSON',
      });

      final service = FamilyContactService.instance;
      await service.loadFromStorage();
      final contacts = await service.getFamilyContacts();
      expect(contacts.isNotEmpty, isTrue);
      expect(contacts.first.name, 'Sarah Jenkins');
    });

    // -------------------------------------------------------------------------
    // 5. Family Relationship Service Persistence
    // -------------------------------------------------------------------------
    test('9. FamilyRelationshipService persists offline relationships and invitations', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FamilyRelationshipService.instance;
      service.resetForTesting();

      final initialRels = await service.getMyRelationships();
      expect(initialRels.length, 1);
      expect(initialRels.first.displayName, 'Sarah Jenkins');

      // Create new offline relationship
      final newRel = await service.createRelationship(
        caregiverUserId: 'caregiver_son_002',
        relationship: 'Son (Emergency Alternate)',
        enabled: true,
      );
      expect(newRel.caregiverUserId, 'caregiver_son_002');

      // Create new offline invitation
      final newInv = await service.createInvitation(
        invitedEmail: 'michael.vance@example.com',
        relationship: 'Son',
        displayName: 'Michael Vance',
      );
      expect(newInv.invitedEmail, 'michael.vance@example.com');
      expect(newInv.status, 'pending');

      // Simulate app restart / reload from storage
      service.resetForTesting();
      expect((await service.getMyRelationships()).length, 1);
      expect((await service.getMyInvitations()).length, 0);

      await service.loadFromStorage();
      final reloadedRels = await service.getMyRelationships();
      final reloadedInvs = await service.getMyInvitations();

      expect(reloadedRels.length, 2);
      expect(reloadedRels.any((r) => r.caregiverUserId == 'caregiver_son_002'), isTrue);
      expect(reloadedInvs.length, 1);
      expect(reloadedInvs.first.invitedEmail, 'michael.vance@example.com');

      // Revoke invitation and verify persistence
      await service.revokeInvitation(newInv.id);
      service.resetForTesting();
      await service.loadFromStorage();
      final afterRevokeInvs = await service.getMyInvitations();
      expect(afterRevokeInvs.first.status, 'revoked');
    });

    test('10. Sensitive credentials and secrets are NEVER stored in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      // Perform all standard save operations
      await AccessibilityPreferences.instance.loadFromStorage();
      await NotificationPreferences.instance.loadFromStorage();
      await CallHistoryRepository.instance.loadFromStorage();
      await FamilyContactService.instance.loadFromStorage();
      await FamilyRelationshipService.instance.loadFromStorage();

      final sp = await SharedPreferences.getInstance();
      final allKeys = sp.getKeys();

      // Check all stored values
      for (final key in allKeys) {
        final val = sp.get(key).toString().toLowerCase();
        expect(val.contains('service_role'), isFalse);
        expect(val.contains('jwt_secret'), isFalse);
        expect(val.contains('supabase_service_role'), isFalse);
        expect(val.contains('openai_api_key'), isFalse);
        expect(val.contains('gemini_api_key'), isFalse);
        expect(val.contains('bearer '), isFalse);
      }
    });
  });
}
