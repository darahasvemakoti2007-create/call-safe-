import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/accessibility_preferences.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/risk_meter.dart';
import '../detection/risk_analysis.dart';

/// High-visibility call intervention modal dialog triggered when a conversation
/// crosses the High or Critical risk threshold.
///
/// Provides three distinct user actions:
/// 1. "End Call" - Terminates the simulated call and records the intervention.
/// 2. "I'm Safe" - Dismisses the warning while retaining the threat analysis.
/// 3. "Alert Family" - Triggers a simulated notification to the designated caregiver.
class ScamWarningDialog extends StatelessWidget {
  final RiskAnalysis analysis;
  final VoidCallback onEndCall;
  final VoidCallback onImSafe;
  final VoidCallback onAlertFamily;

  const ScamWarningDialog({
    super.key,
    required this.analysis,
    required this.onEndCall,
    required this.onImSafe,
    required this.onAlertFamily,
  });

  /// Displays the modal intervention dialog with a smooth entrance animation.
  static Future<void> show({
    required BuildContext context,
    required RiskAnalysis analysis,
    required VoidCallback onEndCall,
    required VoidCallback onImSafe,
    required VoidCallback onAlertFamily,
  }) {
    final reduceMotion = AccessibilityPreferences.instance.reduceMotion;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Scam Warning',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: reduceMotion
          ? const Duration(milliseconds: 50)
          : const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return ScamWarningDialog(
          analysis: analysis,
          onEndCall: onEndCall,
          onImSafe: onImSafe,
          onAlertFamily: onAlertFamily,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        if (reduceMotion) {
          return FadeTransition(opacity: anim, child: child);
        }
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = analysis.riskLevel;
    final signals = analysis.detectedSignals;
    final explanations = analysis.explanations;
    final isCritical = level == RiskLevel.critical;

    return Semantics(
      label:
          'Possible Scam. ${level.label} risk. Score ${analysis.riskScore} out of 100.',
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: level.color.withValues(alpha: 0.8),
              width: 2.0,
            ),
            boxShadow: AccessibilityPreferences.instance.reduceMotion
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: level.color.withValues(alpha: 0.35),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag: SIMULATED CALL INTERVENTION
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: level.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: level.color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'SIMULATED INTERVENTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: level.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Main Warning Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: level.color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(
                        isCritical ? Icons.gpp_bad_rounded : Icons.warning_rounded,
                        color: level.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Possible Scam',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'This conversation shows signs of manipulation.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Risk Meter & Score
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            level.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: level.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${analysis.riskScore} / 100',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: level.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RiskMeter(
                        score: analysis.riskScore,
                        level: level,
                        barHeight: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Detected Signals Section
                const Text(
                  'Detected Threat Signals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (signals.isEmpty) ...[
                  const Text(
                    'No signals detected.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ] else ...[
                  Column(
                    children: signals.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 8),
                              child: Icon(
                                Icons.fiber_manual_record,
                                size: 8,
                                color: level.color,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                s.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),

                // Why is GuardCall concerned?
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Why is GuardCall concerned?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.tealPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'GuardCall detected patterns that may indicate a scam:',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...explanations.map((exp) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3, right: 6),
                                child: Icon(
                                  Icons.arrow_right,
                                  size: 14,
                                  color: AppTheme.tealPrimary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  exp,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ACTIONS
                // 1. PRIMARY: End Call (High prominence, red/critical button)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'End Call',
                    icon: Icons.call_end_rounded,
                    backgroundColor: AppTheme.riskCritical,
                    textColor: Colors.white,
                    height: 48,
                    onPressed: onEndCall,
                  ),
                ),
                const SizedBox(height: 8),

                // 2. SECONDARY: I'm Safe (Outlined / dismiss)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: "I'm Safe",
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: AppTheme.navySurfaceLight,
                    textColor: AppTheme.textPrimary,
                    height: 48,
                    onPressed: onImSafe,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. TERTIARY: Alert Family (Notify trusted circle)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Alert Family',
                    icon: Icons.family_restroom_rounded,
                    backgroundColor: AppTheme.skyAccent.withValues(alpha: 0.2),
                    textColor: AppTheme.skyAccent,
                    height: 48,
                    onPressed: onAlertFamily,
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
