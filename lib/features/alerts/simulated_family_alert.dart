import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/accessibility_preferences.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../detection/risk_analysis.dart';

/// An accessible modal dialog representing a simulated family emergency notification.
///
/// In a live production deployment, this would trigger a push notification or SMS
/// through the caregiver backend. In this prototype, it demonstrates the exact
/// metadata payload without initiating network calls or notifications.
class SimulatedFamilyAlert extends StatelessWidget {
  final String scenarioTitle;
  final RiskAnalysis analysis;
  final VoidCallback onClose;
  final bool isCloudRecorded;
  final String? interventionStatus;
  final String? caregiverName;
  final String? seniorName;
  final String? notificationStatus;
  final String? notificationMessage;

  const SimulatedFamilyAlert({
    super.key,
    required this.scenarioTitle,
    required this.analysis,
    required this.onClose,
    this.isCloudRecorded = false,
    this.interventionStatus,
    this.caregiverName,
    this.seniorName,
    this.notificationStatus,
    this.notificationMessage,
  });

  /// Helper to display the dialog over the active context.
  static Future<void> show({
    required BuildContext context,
    required String scenarioTitle,
    required RiskAnalysis analysis,
    bool isCloudRecorded = false,
    String? interventionStatus,
    String? caregiverName,
    String? seniorName,
    String? notificationStatus,
    String? notificationMessage,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SimulatedFamilyAlert(
        scenarioTitle: scenarioTitle,
        analysis: analysis,
        onClose: () => Navigator.of(ctx).pop(),
        isCloudRecorded: isCloudRecorded,
        interventionStatus: interventionStatus,
        caregiverName: caregiverName,
        seniorName: seniorName,
        notificationStatus: notificationStatus,
        notificationMessage: notificationMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = analysis.riskLevel;
    final signals = analysis.detectedSignals;
    final reduceMotion = AccessibilityPreferences.instance.reduceMotion;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Semantics(
        label:
            'Simulated Family Alert. ${analysis.riskLevel.label} risk detected for scenario $scenarioTitle.',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.tealPrimary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: reduceMotion
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag: SIMULATED FAMILY ALERT
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.tealPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isCloudRecorded ? 'ALERT REQUEST RECORDED' : 'SIMULATED FAMILY ALERT',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.tealPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Row with Avatar/Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.skyAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        color: AppTheme.skyAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCloudRecorded ? 'Alert Request Recorded' : 'Family Alert Requested',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Target: ${caregiverName ?? "Sarah Jenkins (Daughter)"}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notification Delivery Status Card (Step 17)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (notificationStatus == 'UNAVAILABLE')
                        ? AppTheme.riskSuspicious.withValues(alpha: 0.1)
                        : AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (notificationStatus == 'UNAVAILABLE')
                          ? AppTheme.riskSuspicious.withValues(alpha: 0.4)
                          : AppTheme.navyBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            (notificationStatus == 'UNAVAILABLE')
                                ? Icons.block_rounded
                                : Icons.notifications_active_outlined,
                            size: 16,
                            color: (notificationStatus == 'UNAVAILABLE')
                                ? AppTheme.riskSuspicious
                                : AppTheme.tealPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (notificationStatus == 'UNAVAILABLE')
                                ? 'NOTIFICATION: UNAVAILABLE'
                                : 'SIMULATED FAMILY NOTIFICATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (notificationStatus == 'UNAVAILABLE')
                                  ? AppTheme.riskSuspicious
                                  : AppTheme.tealPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (notificationStatus == 'UNAVAILABLE')
                            ? (notificationMessage ??
                                'Family alerts are disabled in Settings. No alert request was dispatched.')
                            : '${caregiverName ?? "Sarah Jenkins"} would receive a ${level.label.toLowerCase()} GuardCall alert.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Demo only — no message was actually sent.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Call Metadata Card
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
                              scenarioTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          RiskBadge(level: level, score: analysis.riskScore),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Risk Score: ${analysis.riskScore} / 100 (${level.label})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: level.color,
                        ),
                      ),
                      if (analysis.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          analysis.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (interventionStatus != null && interventionStatus!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.navySurfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.navyBorder),
                          ),
                          child: Text(
                            'Action: $interventionStatus',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.tealLight,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Detected Threat Signals:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (signals.isEmpty) ...[
                        const Text(
                          'No signals detected.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: signals.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.navySurfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.navyBorder),
                              ),
                              child: Text(
                                s.title,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Prototype Notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.tealPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCloudRecorded
                              ? 'Cloud Sync: Alert record created in Supabase (status: pending) and published to Realtime subscribers. Outward SMS and push notifications will connect in a future release.'
                              : 'Simulation only: No real SMS, push notification, or internet request was dispatched.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Close',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
