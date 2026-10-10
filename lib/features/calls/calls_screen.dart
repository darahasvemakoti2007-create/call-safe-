import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/section_header.dart';
import '../demo/demo_center_screen.dart';

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
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
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        text: 'Open Demo Center',
                        icon: Icons.play_circle_outline_rounded,
                        onPressed: () => _openDemoCenter(context),
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
