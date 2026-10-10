import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/family_alert_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/risk_meter.dart';
import '../detection/risk_analysis.dart';

/// Modal dialog presenting detailed threat telemetry for an authorized caregiver.
///
/// Clearly explains:
/// 1. WHAT HAPPENED — The threat scenario detected.
/// 2. WHY IT WAS FLAGGED — The behavioral manipulation signals observed.
/// 3. WHAT THE SENIOR DID — The intervention choice made by the user.
/// 4. WHAT THE CAREGIVER CAN DO — Safe informational actions (simulated call, mark reviewed).
///
/// Privacy Guarantee:
/// Raw audio and conversation transcripts are NEVER shared with caregivers.
/// Only structured risk signals and scores are displayed.
class CaregiverAlertDetailDialog extends StatelessWidget {
  final FamilyAlertRecord alert;
  final VoidCallback onReviewed;

  const CaregiverAlertDetailDialog({
    super.key,
    required this.alert,
    required this.onReviewed,
  });

  /// Helper to display the dialog over active context.
  static Future<void> show({
    required BuildContext context,
    required FamilyAlertRecord alert,
    required VoidCallback onReviewed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CaregiverAlertDetailDialog(
        alert: alert,
        onReviewed: onReviewed,
      ),
    );
  }

  RiskLevel _getRiskLevel(int score) {
    return RiskLevelScore.fromScore(score);
  }

  void _showSimulatedCallPrompt(BuildContext context) {
    final victim = alert.victimName ?? 'Robert Jenkins (Father)';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.navyBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: AppTheme.tealPrimary),
            const SizedBox(width: 10),
            Text(
              'Contact Family Member',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Call $victim?',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'In this hackathon prototype, phone calls are simulated. In production, this would open your phone dialer to verify your family member\'s safety.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Simulated call to $victim connected.'),
                  backgroundColor: AppTheme.tealPrimary,
                ),
              );
            },
            child: const Text('Simulate Call', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _getRiskLevel(alert.riskScore);
    final signals = alert.detectedSignals ?? const ['Authority impersonation', 'Urgency or time pressure'];
    final victim = alert.victimName ?? 'Robert Jenkins (Father)';
    final scenario = alert.scenarioType ?? 'Suspicious Conversation Scam';
    final explanation = alert.explanation ??
        'GuardCall detected behavioral patterns consistent with social engineering manipulation.';
    final action = alert.interventionStatus ?? 'User requested Family Alert';
    final isReviewed = alert.status == 'reviewed';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: level.color.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: level.color.withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.skyAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.skyAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'CAREGIVER PERSPECTIVE • DEMO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.skyAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title and Victim Header
              Text(
                'Scam Escalation Alert',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined, size: 16, color: AppTheme.tealPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Protected Senior: $victim',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.tealLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Risk Meter Card
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            scenario,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RiskBadge(level: level, score: alert.riskScore),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Threat Assessment: ${alert.riskScore} / 100 (${level.label})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: level.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RiskMeter(
                      score: alert.riskScore,
                      level: level,
                      barHeight: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. WHAT HAPPENED
              _buildSectionHeader(
                icon: Icons.info_outline_rounded,
                title: 'WHAT HAPPENED',
                color: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.navyBorder),
                ),
                child: Text(
                  'GuardCall detected a high-risk scam conversation targeting $victim. $explanation',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. WHY IT WAS FLAGGED
              _buildSectionHeader(
                icon: Icons.radar_rounded,
                title: 'WHY IT WAS FLAGGED (DETECTED SIGNALS)',
                color: level.color,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: signals.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.navyBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: level.color),
                        const SizedBox(width: 6),
                        Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 3. WHAT THE USER DID
              _buildSectionHeader(
                icon: Icons.touch_app_outlined,
                title: 'WHAT THE USER DID',
                color: AppTheme.skyAccent,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.navyBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.tealPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Step 17 Architecture: NOTIFICATION LIFECYCLE
              _buildSectionHeader(
                icon: Icons.cell_tower_rounded,
                title: 'NOTIFICATION LIFECYCLE',
                color: AppTheme.skyAccent,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.navyBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.tealPrimary),
                            SizedBox(width: 6),
                            Text(
                              'Alert: Created',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (alert.notificationStatus == 'UNAVAILABLE')
                                  ? AppTheme.riskSuspicious.withValues(alpha: 0.15)
                                  : AppTheme.tealPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Notification: ${alert.notificationStatus ?? "SIMULATED"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (alert.notificationStatus == 'UNAVAILABLE')
                                    ? AppTheme.riskSuspicious
                                    : AppTheme.tealPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.notificationMessage ?? 'Demo only — no external message was sent.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. WHAT THE CAREGIVER CAN DO
              _buildSectionHeader(
                icon: Icons.shield_outlined,
                title: 'WHAT YOU CAN DO (CAREGIVER ACTIONS)',
                color: AppTheme.tealPrimary,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Contact $victim',
                  icon: Icons.phone_in_talk_rounded,
                  backgroundColor: AppTheme.tealPrimary,
                  textColor: Colors.black,
                  height: 46,
                  onPressed: () => _showSimulatedCallPrompt(context),
                ),
              ),
              const SizedBox(height: 8),
              if (!isReviewed) ...[
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Mark as Reviewed',
                    icon: Icons.done_all_rounded,
                    backgroundColor: AppTheme.navySurfaceLight,
                    textColor: AppTheme.tealLight,
                    height: 46,
                    onPressed: () async {
                      if (alert.id != null) {
                        await FamilyAlertService.instance.updateAlertStatus(alert.id!, 'reviewed');
                      }
                      onReviewed();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alert marked as reviewed.'),
                            backgroundColor: AppTheme.tealPrimary,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Privacy & Emergency Disclaimer
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Privacy & Safety Guarantee: GuardCall shares risk telemetry only. Raw audio and full transcripts are never sent to caregivers. Emergency services and authorities are not automatically contacted.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
