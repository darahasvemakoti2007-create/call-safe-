/// Centralized application configuration layer.
///
/// Ingests environment variables from `.env` or build-time definitions without
/// hard-coding secrets into Dart source files. Provides safe fallback to
/// offline-first demo mode whenever credentials are placeholder strings or empty.
class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String openaiApiKey;
  final String geminiApiKey;
  final String speechToTextApiKey;
  final String aiProvider; // 'mock', 'openai', 'gemini', 'edge_function'
  final String sttProvider; // 'mock', 'remote', 'edge_function'
  final String aiBackend; // 'mock', 'direct_dev', 'edge_function'
  final String sttBackend; // 'mock', 'direct_dev', 'edge_function'
  final bool useSupabase;
  final bool useRemoteAi;
  final bool useCloudStt;
  final bool enableFamilyAlerts;

  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.openaiApiKey = '',
    this.geminiApiKey = '',
    this.speechToTextApiKey = '',
    this.aiProvider = 'mock',
    this.sttProvider = 'mock',
    this.aiBackend = 'mock',
    this.sttBackend = 'mock',
    this.useSupabase = false,
    this.useRemoteAi = false,
    this.useCloudStt = false,
    this.enableFamilyAlerts = false,
  });

  /// Global shared configuration instance. Defaults to build environment if defined, else offline mode.
  static AppConfig current = const String.fromEnvironment('SUPABASE_URL').isNotEmpty
      ? AppConfig.fromEnvironment()
      : AppConfig.offlineDefault();

  /// Factory loading configuration from compile-time --dart-define definitions.
  factory AppConfig.fromEnvironment() {
    return AppConfig.fromMap({
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
      'USE_SUPABASE': const String.fromEnvironment('USE_SUPABASE', defaultValue: 'false'),
      'USE_REMOTE_AI': const String.fromEnvironment('USE_REMOTE_AI', defaultValue: 'false'),
      'USE_CLOUD_STT': const String.fromEnvironment('USE_CLOUD_STT', defaultValue: 'false'),
      'ENABLE_FAMILY_ALERTS': const String.fromEnvironment('ENABLE_FAMILY_ALERTS', defaultValue: 'false'),
      'AI_PROVIDER': const String.fromEnvironment('AI_PROVIDER', defaultValue: 'mock'),
      'STT_PROVIDER': const String.fromEnvironment('STT_PROVIDER', defaultValue: 'mock'),
      'AI_BACKEND': const String.fromEnvironment('AI_BACKEND', defaultValue: 'mock'),
      'STT_BACKEND': const String.fromEnvironment('STT_BACKEND', defaultValue: 'mock'),
      'OPENAI_API_KEY': const String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''),
      'GEMINI_API_KEY': const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
      'SPEECH_TO_TEXT_API_KEY': const String.fromEnvironment('SPEECH_TO_TEXT_API_KEY', defaultValue: ''),
    });
  }

  /// Default configuration for 100% offline hackathon demonstration.
  factory AppConfig.offlineDefault() {
    return const AppConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      openaiApiKey: '',
      geminiApiKey: '',
      speechToTextApiKey: '',
      aiProvider: 'mock',
      sttProvider: 'mock',
      aiBackend: 'mock',
      sttBackend: 'mock',
      useSupabase: false,
      useRemoteAi: false,
      useCloudStt: false,
      enableFamilyAlerts: false,
    );
  }

  /// Parses a key-value map into an [AppConfig] instance.
  factory AppConfig.fromMap(Map<String, String> map) {
    final rawUrl = (map['SUPABASE_URL'] ?? '').trim();
    final rawKey = (map['SUPABASE_ANON_KEY'] ?? '').trim();

    final rawUseSupabase = (map['USE_SUPABASE'] ?? 'false').toLowerCase().trim();
    final rawUseRemoteAi = (map['USE_REMOTE_AI'] ?? 'false').toLowerCase().trim();
    final rawUseCloudStt = (map['USE_CLOUD_STT'] ?? 'false').toLowerCase().trim();
    final rawEnableAlerts = (map['ENABLE_FAMILY_ALERTS'] ?? 'false').toLowerCase().trim();

    final rawAiProvider = (map['AI_PROVIDER'] ?? 'mock').toLowerCase().trim();
    final rawSttProvider = (map['STT_PROVIDER'] ?? 'mock').toLowerCase().trim();

    final rawAiBackend = (map['AI_BACKEND'] ?? '').toLowerCase().trim();
    final rawSttBackend = (map['STT_BACKEND'] ?? '').toLowerCase().trim();

    final useSupabase = rawUseSupabase == 'true' || rawUseSupabase == '1';
    final useRemoteAi = rawUseRemoteAi == 'true' || rawUseRemoteAi == '1';
    final useCloudStt = rawUseCloudStt == 'true' || rawUseCloudStt == '1';
    final enableFamilyAlerts = rawEnableAlerts == 'true' || rawEnableAlerts == '1';

    // Derive aiBackend if not explicitly set
    String resolvedAiBackend = rawAiBackend;
    if (resolvedAiBackend.isEmpty) {
      if (rawAiProvider == 'edge_function') {
        resolvedAiBackend = 'edge_function';
      } else if (useRemoteAi && (rawAiProvider == 'openai' || rawAiProvider == 'gemini')) {
        resolvedAiBackend = 'direct_dev';
      } else {
        resolvedAiBackend = 'mock';
      }
    }

    // Derive sttBackend if not explicitly set
    String resolvedSttBackend = rawSttBackend;
    if (resolvedSttBackend.isEmpty) {
      if (rawSttProvider == 'edge_function') {
        resolvedSttBackend = 'edge_function';
      } else if (useCloudStt && (rawSttProvider == 'remote')) {
        resolvedSttBackend = 'direct_dev';
      } else {
        resolvedSttBackend = 'mock';
      }
    }

    // Ensure sensible provider names when backend is set directly
    String resolvedAiProvider = rawAiProvider.isEmpty ? 'mock' : rawAiProvider;
    if (resolvedAiBackend == 'edge_function' && resolvedAiProvider == 'mock') {
      resolvedAiProvider = 'edge_function';
    } else if (resolvedAiBackend == 'direct_dev' && resolvedAiProvider == 'mock') {
      final geminiKey = (map['GEMINI_API_KEY'] ?? '').trim();
      final openaiKey = (map['OPENAI_API_KEY'] ?? '').trim();
      resolvedAiProvider = (geminiKey.isNotEmpty && openaiKey.isEmpty) ? 'gemini' : 'openai';
    }

    String resolvedSttProvider = rawSttProvider.isEmpty ? 'mock' : rawSttProvider;
    if (resolvedSttBackend == 'edge_function' && resolvedSttProvider == 'mock') {
      resolvedSttProvider = 'edge_function';
    } else if (resolvedSttBackend == 'direct_dev' && resolvedSttProvider == 'mock') {
      resolvedSttProvider = 'remote';
    }

    return AppConfig(
      supabaseUrl: rawUrl,
      supabaseAnonKey: rawKey,
      openaiApiKey: (map['OPENAI_API_KEY'] ?? '').trim(),
      geminiApiKey: (map['GEMINI_API_KEY'] ?? '').trim(),
      speechToTextApiKey: (map['SPEECH_TO_TEXT_API_KEY'] ?? '').trim(),
      aiProvider: resolvedAiProvider,
      sttProvider: resolvedSttProvider,
      aiBackend: resolvedAiBackend,
      sttBackend: resolvedSttBackend,
      useSupabase: useSupabase,
      useRemoteAi: useRemoteAi,
      useCloudStt: useCloudStt,
      enableFamilyAlerts: enableFamilyAlerts,
    );
  }

  /// Parses a multi-line `.env` string into an [AppConfig] instance.
  ///
  /// Ignores comments (lines starting with `#`) and empty lines.
  factory AppConfig.parseEnvString(String content) {
    final Map<String, String> map = {};
    final lines = content.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex == -1) {
        continue;
      }
      final key = trimmed.substring(0, separatorIndex).trim();
      var value = trimmed.substring(separatorIndex + 1).trim();

      // Strip surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }
      map[key] = value;
    }

    return AppConfig.fromMap(map);
  }

  /// Evaluates whether valid, usable Supabase credentials are configured.
  ///
  /// Returns false if either URL or key is empty, or remains set to placeholder text.
  bool get isSupabaseConfigured {
    if (!useSupabase) return false;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;

    // Reject obvious placeholders
    final urlLower = supabaseUrl.toLowerCase();
    final keyLower = supabaseAnonKey.toLowerCase();
    if (urlLower.contains('your-') || urlLower.contains('placeholder')) return false;
    if (keyLower.contains('your-') || keyLower.contains('placeholder')) return false;
    if (!supabaseUrl.startsWith('https://') && !supabaseUrl.startsWith('http://')) return false;

    return true;
  }

  /// Whether the app is operating in offline demonstration mode.
  bool get isOfflineDemoMode => !isSupabaseConfigured;

  /// Evaluates whether valid, usable Remote AI credentials are configured for direct dev.
  bool get isRemoteAiConfigured {
    if (!useRemoteAi && aiBackend != 'direct_dev') return false;
    if (aiProvider == 'mock') return false;
    if (aiProvider == 'openai') {
      if (openaiApiKey.isEmpty) return false;
      final k = openaiApiKey.toLowerCase();
      if (k.contains('your-') || k.contains('placeholder')) return false;
      return true;
    } else if (aiProvider == 'gemini') {
      if (geminiApiKey.isEmpty) return false;
      final k = geminiApiKey.toLowerCase();
      if (k.contains('your-') || k.contains('placeholder')) return false;
      return true;
    }
    return false;
  }

  /// Evaluates whether valid, usable Cloud Speech-to-Text credentials are configured for direct dev.
  bool get isCloudSttConfigured {
    if (!useCloudStt && sttBackend != 'direct_dev') return false;
    if (sttProvider == 'mock') return false;
    if (sttProvider == 'remote') {
      if (speechToTextApiKey.isEmpty) return false;
      final k = speechToTextApiKey.toLowerCase();
      if (k.contains('your-') || k.contains('placeholder')) return false;
      return true;
    }
    return false;
  }

  /// Evaluates whether the secure Supabase Edge Function AI backend is configured.
  bool get isEdgeFunctionAiConfigured {
    return isSupabaseConfigured && (aiBackend == 'edge_function' || aiProvider == 'edge_function');
  }

  /// Evaluates whether the secure Supabase Edge Function STT backend is configured.
  bool get isEdgeFunctionSttConfigured {
    return isSupabaseConfigured && (sttBackend == 'edge_function' || sttProvider == 'edge_function');
  }

  /// Returns the user-facing detection engine tier label ('OFFLINE', 'DIRECT DEV', or 'EDGE PROXY').
  String get detectionModeLabel {
    if (aiBackend == 'edge_function' || isEdgeFunctionAiConfigured) {
      return 'EDGE PROXY';
    }
    if (aiBackend == 'direct_dev' || isRemoteAiConfigured) {
      return 'DIRECT DEV';
    }
    return 'OFFLINE';
  }

  /// Returns the user-facing speech recognition tier label ('OFFLINE', 'DIRECT DEV', or 'EDGE PROXY').
  String get sttModeLabel {
    if (sttBackend == 'edge_function' || isEdgeFunctionSttConfigured) {
      return 'EDGE PROXY';
    }
    if (sttBackend == 'direct_dev' || isCloudSttConfigured) {
      return 'DIRECT DEV';
    }
    return 'OFFLINE';
  }
}
