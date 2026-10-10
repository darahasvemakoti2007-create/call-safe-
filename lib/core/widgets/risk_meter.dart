import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../services/accessibility_preferences.dart';
import 'risk_badge.dart';

/// An animated, accessible visual risk gauge displaying current threat score
/// and risk tier with smooth progression.
class RiskMeter extends StatelessWidget {
  final int score;
  final RiskLevel level;
  final bool? reduceMotion;
  final bool showLabel;
  final double barHeight;

  const RiskMeter({
    super.key,
    required this.score,
    required this.level,
    this.reduceMotion,
    this.showLabel = true,
    this.barHeight = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100);
    final progress = clampedScore / 100.0;
    final levelColor = level.color;

    final effectiveReduceMotion =
        reduceMotion ?? AccessibilityPreferences.instance.reduceMotion;

    return Semantics(
      label: 'Risk score $clampedScore of 100, ${level.label}',
      value: '$clampedScore percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(level.icon, size: 16, color: levelColor),
                    const SizedBox(width: 6),
                    Text(
                      level.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: levelColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$clampedScore / 100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(barHeight / 2),
            child: Container(
              height: barHeight,
              width: double.infinity,
              color: AppTheme.navySurfaceLight,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: effectiveReduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: levelColor,
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        boxShadow: effectiveReduceMotion
                            ? null
                            : [
                                BoxShadow(
                                  color: levelColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
