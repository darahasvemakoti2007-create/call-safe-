import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/risk_badge.dart';
import 'call_history_repository.dart';

/// Modal dialog displaying comprehensive, privacy-respecting assessment details
/// for a selected call history record.
class AssessmentDetailDialog extends StatelessWidget {
  final CallHistoryRecord record;

  const AssessmentDetailDialog({
    super.key,
    required this.record,
  });

  /// Displays the dialog over the active navigation context.
  static Future<void> show(BuildContext context, CallHistoryRecord record) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AssessmentDetailDialog(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final riskColor = record.riskLevel.color;

    return Dialog(
      backgroundColor: AppTheme.navySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.navyBorder, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title, subtitle, and close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title.isNotEmpty
                              ? record.title
                              : 'Call Assessment',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.timestamp.isNotEmpty ? record.timestamp : 'Timestamp not recorded'} • ${record.duration}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('assessment_detail_close_icon_button'),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    tooltip: 'Close assessment details',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Risk Assessment summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: riskColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    RiskBadge(
                      level: record.riskLevel,
                      score: record.riskScore,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Threat Score: ${record.riskScore}/100',
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.isSimulated
                              ? 'Simulated Training Assessment'
                              : 'Live Call Session',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Intervention Status (if recorded)
              if (record.interventionStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 16,
                        color: riskColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Intervention Status: ${record.interventionStatus}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Assessment Explanation
              _buildSectionTitle(context, 'Assessment Explanation', Icons.psychology_outlined),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.navyBorder),
                ),
                child: Text(
                  _getExplanationText(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Detected Manipulation Signals
              _buildSectionTitle(context, 'Detected Signals', Icons.radar_rounded),
              const SizedBox(height: 8),
              if (record.signals.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: record.signals.map((signal) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.navyBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.navyBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.crisis_alert_rounded,
                            size: 14,
                            color: AppTheme.tealPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            signal,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.tealLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                Text(
                  'No manipulation signals recorded.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Recommended Protective Action
              _buildSectionTitle(context, 'Recommended Protective Action', Icons.shield_outlined),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: riskColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 20,
                      color: riskColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getRecommendedActionText(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Transcript Excerpt / Privacy Protection Notice
              _buildSectionTitle(context, 'Transcript Excerpt & Privacy', Icons.lock_outline_rounded),
              const SizedBox(height: 6),
              if (record.transcriptExcerpt != null &&
                  record.transcriptExcerpt!.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.transcriptExcerpt!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.navyBorder, height: 1),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: AppTheme.tealPrimary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sanitized demo transcript excerpt. No audio was stored.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.tealLight,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navyBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.privacy_tip_outlined,
                        size: 20,
                        color: AppTheme.skyAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Transcript not stored',
                              style: TextStyle(
                                color: AppTheme.skyAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GuardCall enforces a strict zero-retention privacy policy. Audio streams are evaluated in volatile memory and never retained on disk.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Close action button (min 48dp height)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  key: const Key('assessment_detail_dismiss_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.navyBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.tealPrimary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  String _getExplanationText() {
    if (record.explanation != null && record.explanation!.trim().isNotEmpty) {
      return record.explanation!;
    }
    if (record.subtitle.trim().isNotEmpty) {
      return record.subtitle;
    }
    return 'No detailed assessment explanation was recorded for this session.';
  }

  String _getRecommendedActionText() {
    if (record.recommendedAction != null &&
        record.recommendedAction!.trim().isNotEmpty) {
      return record.recommendedAction!;
    }
    return 'No specific protective action recorded.';
  }
}
