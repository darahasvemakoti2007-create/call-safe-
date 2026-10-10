import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../demo/demo_center_screen.dart';
import '../sms/sms_protection_screen.dart';
import 'live_microphone_screen.dart';

/// The active call monitoring view.
///
/// Displays an empty state when no call is active and provides an
/// entry point to the Demo Center simulator.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  void _openDemoCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DemoCenterScreen(),
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
                'Calls',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Real-time call shield & scam monitoring',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 28),

              // Active Call Area (Empty state)
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.navySurfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.phone_disabled_rounded,
                          color: AppTheme.tealPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Active Call',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your device is fully protected. When an incoming call connects or a simulation starts, live pattern analysis will stream here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        key: const Key('open_live_mic_shield_button'),
                        text: 'Start Microphone Shield',
                        icon: Icons.mic_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const LiveMicrophoneScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          key: const Key('open_demo_center_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.skyAccent,
                            side: const BorderSide(color: AppTheme.navyBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                          label: const Text('Open Demo Center', style: TextStyle(fontWeight: FontWeight.w600)),
                          onPressed: () => _openDemoCenter(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          key: const Key('open_sms_protection_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.tealPrimary,
                            side: const BorderSide(color: AppTheme.navyBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.sms_outlined, size: 20),
                          label: const Text('Analyze Suspicious SMS / Text',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SmsProtectionScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Protection Status Notice
              const SectionHeader(
                title: 'How Active Protection Works',
                subtitle: 'Continuous manipulation pattern detection',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      context,
                      icon: Icons.graphic_eq_rounded,
                      title: 'Live Pattern Recognition',
                      description: 'Inspects conversation dynamics for urgency, threats, and impersonation.',
                    ),
                    const Divider(color: AppTheme.navyBorder, height: 28),
                    _buildFeatureItem(
                      context,
                      icon: Icons.warning_rounded,
                      title: 'Instant Heads-Up Alert',
                      description: 'Displays large, clear warnings if escalation passes safety thresholds.',
                    ),
                    const Divider(color: AppTheme.navyBorder, height: 28),
                    _buildFeatureItem(
                      context,
                      icon: Icons.family_restroom_rounded,
                      title: 'Caregiver Relay',
                      description: 'Silently alerts trusted family members during critical scam events.',
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

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.tealPrimary.withValues(alpha: 0.12),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
