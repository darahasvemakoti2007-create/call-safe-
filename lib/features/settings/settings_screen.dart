import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/accessibility_preferences.dart';
import '../../core/services/auth_state.dart';
import '../../core/services/notification_preferences.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../auth/login_screen.dart';
import '../history/call_history_repository.dart';

/// Settings screen providing accessibility, privacy, and system configuration.
///
/// Features that depend on future backend or device services use clear
/// disabled/placeholder states to ensure honesty with the user.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    _reduceMotion = AccessibilityPreferences.instance.reduceMotion;
  }

  void _showComingSoonNotice(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be configurable in a future release.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Accessibility, privacy, and protection preferences',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              // Account & Cloud Authentication Section
              const SectionHeader(
                title: 'Account & Sync',
                subtitle: 'Cloud protection and profile status',
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: AuthState.instance,
                builder: (context, _) {
                  final auth = AuthState.instance;
                  if (auth.isAuthenticated) {
                    return GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.riskSafe.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: AppTheme.riskSafe,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.displayName,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.riskSafe,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Signed In',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppTheme.riskSafe,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.navySurface,
                                  title: const Text(
                                    'Sign Out?',
                                    style: TextStyle(color: AppTheme.textPrimary),
                                  ),
                                  content: const Text(
                                    'Are you sure you want to sign out of your GuardCall account?',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Sign Out',
                                        style: TextStyle(color: AppTheme.riskCritical, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await auth.signOut();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.navyBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppTheme.riskCritical,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Offline / Demo Mode
                  return GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.offline_bolt_rounded,
                                color: AppTheme.tealPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Demo Mode',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Operating offline. Sign in to sync alerts.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text(
                              'Sign In / Create Account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.tealPrimary,
                              foregroundColor: AppTheme.navyBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Accessibility Section
              const SectionHeader(
                title: 'Accessibility & Motion',
                subtitle: 'Visual comfort and readability',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.motion_photos_off_rounded,
                          color: AppTheme.tealPrimary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Reduce Motion',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      subtitle: Text(
                        'Minimize animations and dynamic scaling effects across screens.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      value: _reduceMotion,
                      activeThumbColor: AppTheme.tealPrimary,
                      onChanged: (val) {
                        setState(() => _reduceMotion = val);
                        AccessibilityPreferences.instance.setReduceMotion(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Security Section
              const SectionHeader(
                title: 'Privacy & Data Protection',
                subtitle: 'Local-first architecture and audio safety',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.mic_off_rounded,
                      title: 'Zero-Audio Policy',
                      subtitle: 'Audio streams are processed transiently; nothing is uploaded or recorded.',
                      trailingText: 'Guaranteed',
                      trailingTextColor: AppTheme.riskSafe,
                      onTap: () => _showComingSoonNotice(context, 'Zero-Audio Policy Details'),
                    ),
                    const Divider(color: AppTheme.navyBorder, height: 24),
                    _buildSettingsTile(
                      context,
                      icon: Icons.delete_sweep_rounded,
                      title: 'Clear Local History',
                      subtitle: 'Delete locally cached demo and risk assessment logs.',
                      trailingIcon: Icons.chevron_right_rounded,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.navySurface,
                            title: const Text(
                              'Clear Call History?',
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                            content: const Text(
                              'This will permanently delete all cached call risk assessments from this device.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Clear History',
                                  style: TextStyle(color: AppTheme.riskCritical, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          CallHistoryRepository.instance.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Call history cleared successfully.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Family Alerts & Notifications Section (Step 17 Architecture)
              const SectionHeader(
                title: 'Alerts & Notifications',
                subtitle: 'Caregiver notification preferences & delivery mode',
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: NotificationPreferences.instance,
                builder: (context, _) {
                  final notifPrefs = NotificationPreferences.instance;
                  return GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSettingsTile(
                          context,
                          icon: Icons.family_restroom_rounded,
                          title: 'Family Alerts',
                          subtitle: notifPrefs.familyAlertsEnabled
                              ? 'Enabled. You can request family alerts when scams are detected.'
                              : 'Disabled. GuardCall will not dispatch alerts to family members.',
                          trailingWidget: Switch(
                            value: notifPrefs.familyAlertsEnabled,
                            activeThumbColor: AppTheme.tealPrimary,
                            onChanged: (val) {
                              notifPrefs.setFamilyAlertsEnabled(val);
                            },
                          ),
                        ),
                        const Divider(color: AppTheme.navyBorder, height: 24),
                        _buildSettingsTile(
                          context,
                          icon: Icons.cell_tower_rounded,
                          title: 'Notification Mode',
                          subtitle: notifPrefs.deliveryModeDescription,
                          trailingText: 'SIMULATED',
                          trailingTextColor: AppTheme.tealPrimary,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.navySurfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.navyBorder),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppTheme.tealPrimary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Family notifications are simulated in hackathon prototype mode. No SMS, WhatsApp, or push notifications are dispatched.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // AI & Speech Providers Section (Steps 12 & 13 Architecture)
              const SectionHeader(
                title: 'AI & Speech Engines',
                subtitle: 'Detection provider configuration & status',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.psychology_outlined,
                      title: 'Detection Engine',
                      subtitle: AppConfig.current.detectionModeLabel == 'EDGE PROXY'
                          ? 'Secure Edge AI Proxy (Cloud-shielded)'
                          : AppConfig.current.detectionModeLabel == 'DIRECT DEV'
                              ? 'Direct Dev AI (${AppConfig.current.aiProvider.toUpperCase()}) (Development Only)'
                              : 'Offline Heuristic Engine (Deterministic on-device)',
                      trailingText: AppConfig.current.detectionModeLabel,
                      trailingTextColor: AppConfig.current.detectionModeLabel == 'EDGE PROXY'
                          ? AppTheme.tealPrimary
                          : AppConfig.current.detectionModeLabel == 'DIRECT DEV'
                              ? AppTheme.riskSuspicious
                              : AppTheme.textSecondary,
                    ),
                    const Divider(color: AppTheme.navyBorder, height: 24),
                    _buildSettingsTile(
                      context,
                      icon: Icons.mic_none_rounded,
                      title: 'Speech Recognition',
                      subtitle: AppConfig.current.sttModeLabel == 'EDGE PROXY'
                          ? 'Secure Edge Speech Recognition (Cloud-shielded)'
                          : AppConfig.current.sttModeLabel == 'DIRECT DEV'
                              ? 'Direct Dev Speech-to-Text (Development Only)'
                              : 'Mock / Demo Audio Pipeline (Zero network)',
                      trailingText: AppConfig.current.sttModeLabel,
                      trailingTextColor: AppConfig.current.sttModeLabel == 'EDGE PROXY'
                          ? AppTheme.tealPrimary
                          : AppConfig.current.sttModeLabel == 'DIRECT DEV'
                              ? AppTheme.riskSuspicious
                              : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.navySurface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.navyBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppTheme.tealPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'GuardCall analyzes conversation audio from explicit demo audio inputs and test fixtures. It does not monitor or intercept cellular phone calls.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About GuardCall Section
              const SectionHeader(
                title: 'About GuardCall',
                subtitle: 'System version & mission',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: AppTheme.tealPrimary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GuardCall v1.0.0-foundation',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'AI-Powered Scam Shield & Caregiver Network',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.tealLight,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'GuardCall analyzes conversation and social engineering patterns in real time to protect vulnerable individuals from financial and emotional scams.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    IconData? trailingIcon,
    String? trailingText,
    Color? trailingTextColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.navySurfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.tealPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            ?trailingWidget,
            if (trailingText != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  trailingText,
                  style: TextStyle(
                    color: trailingTextColor ?? AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            if (trailingIcon != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(trailingIcon, color: AppTheme.textMuted, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
