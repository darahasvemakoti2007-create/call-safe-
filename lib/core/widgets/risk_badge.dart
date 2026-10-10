import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Supported risk tiers matching the GuardCall architecture specifications.
enum RiskLevel {
  safe,
  suspicious,
  high,
  critical;

  String get label {
    switch (this) {
      case RiskLevel.safe:
        return 'Safe';
      case RiskLevel.suspicious:
        return 'Suspicious';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical Threat';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.safe:
        return AppTheme.riskSafe;
      case RiskLevel.suspicious:
        return AppTheme.riskSuspicious;
      case RiskLevel.high:
        return AppTheme.riskHigh;
      case RiskLevel.critical:
        return AppTheme.riskCritical;
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.safe:
        return Icons.verified_user_rounded;
      case RiskLevel.suspicious:
        return Icons.info_outline_rounded;
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
      case RiskLevel.critical:
        return Icons.gpp_bad_rounded;
    }
  }
}

/// A presentational badge showing the assessed risk level.
///
/// Ensures accessibility by displaying a distinct icon and descriptive text,
/// avoiding reliance on color alone.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final int? score;
  final bool showIcon;

  const RiskBadge({
    super.key,
    required this.level,
    this.score,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = level.color;

    return Semantics(
      label: 'Risk Level: ${level.label}${score != null ? ' ($score of 100)' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: baseColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                level.icon,
                color: baseColor,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              score != null ? '${level.label} ($score)' : level.label,
              style: TextStyle(
                color: baseColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
