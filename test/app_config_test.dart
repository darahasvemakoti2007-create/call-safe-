import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/supabase_service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 8 Environment Configuration & SupabaseService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      SupabaseService.instance.resetForTesting();
    });

    test('1. Default AppConfig defaults safely to offline demo mode', () {
      final config = AppConfig.offlineDefault();

      expect(config.isOfflineDemoMode, isTrue);
      expect(config.isSupabaseConfigured, isFalse);
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.useSupabase, isFalse);
    });

    test('2. Placeholder credentials in .env are rejected as unconfigured', () {
      const sampleEnv = '''
# Sample environment file
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
USE_SUPABASE=true
''';

      final config = AppConfig.parseEnvString(sampleEnv);

      expect(config.useSupabase, isTrue);
      // Because URL and Key contain 'your-', isSupabaseConfigured must be false
      expect(config.isSupabaseConfigured, isFalse);
      expect(config.isOfflineDemoMode, isTrue);
    });

    test('3. AppConfig accurately parses quoted values and ignores comments', () {
      const envWithComments = '''
# Header comment
OPENAI_API_KEY="sk-test-key-123"
GEMINI_API_KEY='gemini-test-key-456'
USE_REMOTE_AI=true
USE_CLOUD_STT=1
ENABLE_FAMILY_ALERTS=false
''';

      final config = AppConfig.parseEnvString(envWithComments);

      expect(config.openaiApiKey, equals('sk-test-key-123'));
      expect(config.geminiApiKey, equals('gemini-test-key-456'));
      expect(config.useRemoteAi, isTrue);
      expect(config.useCloudStt, isTrue);
      expect(config.enableFamilyAlerts, isFalse);
    });

    test('4. Valid format enables isSupabaseConfigured', () {
      const validEnv = '''
SUPABASE_URL=https://abcxyz123.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.validkey
USE_SUPABASE=true
''';

      final config = AppConfig.parseEnvString(validEnv);

      expect(config.useSupabase, isTrue);
      expect(config.isSupabaseConfigured, isTrue);
      expect(config.isOfflineDemoMode, isFalse);
      expect(config.supabaseUrl, equals('https://abcxyz123.supabase.co'));
    });

    test('5. SupabaseService initializes safely in offline demo mode when unconfigured', () async {
      final service = SupabaseService.instance;
      final config = AppConfig.offlineDefault();

      await service.initialize(config);

      expect(service.isInitialized, isTrue);
      expect(service.state, equals(SupabaseBackendState.offlineDemo));
      expect(service.isOffline, isTrue);
      expect(service.isConfigured, isFalse);
      expect(service.client, isNull);
      expect(service.lastError, isNull);
    });

    test('6. SupabaseService handles invalid credentials without crashing', () async {
      final service = SupabaseService.instance;
      // Synthesize config with non-placeholder but unreachable domain to test safety
      const invalidEnv = '''
SUPABASE_URL=https://invalid-nonexistent-domain-12345.supabase.co
SUPABASE_ANON_KEY=invalid_key_for_testing
USE_SUPABASE=true
''';
      final config = AppConfig.parseEnvString(invalidEnv);

      // Must complete without unhandled exceptions
      await service.initialize(config);

      expect(service.isInitialized, isTrue);
      // Either configured or unavailable, but never crashes
      expect(
        service.state == SupabaseBackendState.configured ||
            service.state == SupabaseBackendState.unavailable,
        isTrue,
      );
    });

    test('7. Centralized config provides single source of truth for runtime', () {
      expect(AppConfig.current, isNotNull);
      expect(AppConfig.current.isOfflineDemoMode, isTrue);
    });
  });
}
