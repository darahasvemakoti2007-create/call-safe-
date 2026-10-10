import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/services/accessibility_preferences.dart';
import 'core/services/family_contact_service.dart';
import 'core/services/family_relationship_service.dart';
import 'core/services/notification_preferences.dart';
import 'core/services/supabase_service.dart';
import 'features/history/call_history_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved local user settings, call history, and family circle data
  await Future.wait([
    AccessibilityPreferences.instance.loadFromStorage(),
    NotificationPreferences.instance.loadFromStorage(),
    CallHistoryRepository.instance.loadFromStorage(),
    FamilyContactService.instance.loadFromStorage(),
    FamilyRelationshipService.instance.loadFromStorage(),
  ]);

  // Initialize centralized environment configuration and Supabase service.
  // Defaults safely to offline demo mode if credentials are absent.
  await SupabaseService.instance.initialize(AppConfig.current);

  runApp(const GuardCallApp());
}

