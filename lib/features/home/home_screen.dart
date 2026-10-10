import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/section_header.dart';
import '../demo/demo_center_screen.dart';

/// The primary dashboard of GuardCall.
///
/// Gives users immediate reassurance with an active protection badge,
/// family circle preview, privacy indicators, and a demo launcher.
class HomeScreen extends StatelessWidget {
  final VoidCallback? onNavigateToCalls;

  const HomeScreen({
    super.key,
    this.onNavigateToCalls,
  });

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
              // Top Bar & Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GuardCall',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.tealPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back, Eleanor',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const RiskBadge(
                    level: RiskLevel.safe,
                    showIcon: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main Protection Status Card
              GlassCard(
                borderColor: AppTheme.tealPrimary.withValues(alpha: 0.35),
                backgroundColor: AppTheme.navySurfaceLight.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.tealPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Protection Active',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.tealLight,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time conversation pattern shield',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'GuardCall is monitoring active conversation flows for manipulation, false urgency, and authority impersonation.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: 'Start Demo Call',
                        icon: Icons.phone_in_talk_rounded,
                        onPressed: () => _openDemoCenter(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Trusted Family Contact Summary
              const SectionHeader(
                title: 'Family Circle',
                subtitle: 'Your designated emergency contact',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.skyAccent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppTheme.skyAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sarah Jenkins (Daughter)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connected • Receives Critical Alerts',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.tealPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Recent Alert Summary
              const SectionHeader(
                title: 'Recent Activity',
                subtitle: 'Last 24 hours threat overview',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.riskSafe.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppTheme.riskSafe,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Scam Threats Detected',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All recent interactions were clear and safe.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Privacy Status Card
              const SectionHeader(
                title: 'Privacy & Storage',
                subtitle: 'Zero audio retention guarantee',
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.tealPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio is Never Recorded',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'GuardCall processes conversation patterns transiently in memory. Raw audio and transcripts are never stored.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.45,
                                ),
                          ),
                        ],
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
}
