import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import 'demo_player_screen.dart';
import 'demo_scenario.dart';
import 'demo_scenarios.dart';

/// Interactive sandbox screen showcasing predefined scam and safe conversation scenarios.
class DemoCenterScreen extends StatelessWidget {
  const DemoCenterScreen({super.key});

  void _openPlayer(BuildContext context, DemoScenario scenario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DemoPlayerScreen(scenario: scenario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = DemoScenarios.all;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        title: const Text(
          'Demo Center',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Return to previous screen',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Demo Center',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Practice how GuardCall detects manipulation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 18),

            // Introductory privacy/demo notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.tealPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'These conversations are simulated. No real phone call is being monitored.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scenario Cards List
            ...scenarios.map((scenario) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildScenarioCard(context, scenario),
              );
            }),

            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildScenarioCard(BuildContext context, DemoScenario scenario) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${scenario.category}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.tealLight,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RiskBadge(
                level: scenario.expectedRiskLevel,
                showIcon: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            scenario.shortDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),

          // Expected signals tags if any
          if (scenario.expectedSignals.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: scenario.expectedSignals.map((signal) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Text(
                    signal,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.riskSafe.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.riskSafe.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Safe • No Scam Indicators',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.riskSafe,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Play Scenario button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Play Scenario',
              icon: Icons.play_arrow_rounded,
              height: 48,
              borderRadius: 24,
              onPressed: () => _openPlayer(context, scenario),
            ),
          ),
        ],
      ),
    );
  }
}
