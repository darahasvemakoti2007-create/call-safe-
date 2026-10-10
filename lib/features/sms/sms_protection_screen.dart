import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../core/services/family_alert_service.dart';
import '../../core/services/family_relationship_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/risk_meter.dart';
import '../../core/widgets/section_header.dart';
import '../history/assessment_detail_dialog.dart';
import 'sms_protection_controller.dart';
import 'sms_scam_analysis_service.dart';

/// Screen providing user-initiated SMS & text message scam evaluation,
/// tactic breakdown, safe action checklists, and privacy transparency.
class SmsProtectionScreen extends StatefulWidget {
  final SmsProtectionController? controller;

  const SmsProtectionScreen({
    super.key,
    this.controller,
  });

  @override
  State<SmsProtectionScreen> createState() => _SmsProtectionScreenState();
}

class _SmsProtectionScreenState extends State<SmsProtectionScreen> {
  late final SmsProtectionController _controller;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = SmsProtectionController();
      _internalController = true;
    }
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    if (_internalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _controller.textController.text = data.text!;
      setState(() {});
    }
  }

  bool _isAlerting = false;
  String? _lastAlertedFingerprint;

  Future<void> _alertFamily(SmsAnalysisResult result) async {
    if (_isAlerting) return;
    final fingerprint = '${result.rawMessage.hashCode}_${result.riskScore}';
    if (_lastAlertedFingerprint == fingerprint) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.navySurfaceLight,
            content: Text(
              'An alert has already been recorded for this message.',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        );
      }
      return;
    }

    _isAlerting = true;
    try {
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      final activeRel = rels.where((r) => r.enabled).firstOrNull;
      final caregiverId = activeRel?.caregiverUserId ?? 'default-caregiver';
      final caregiverName = activeRel?.displayName ?? 'Sarah Jenkins (Daughter)';

      await FamilyAlertService.instance.createAlert(
        callSessionId: 'sms_alert_${DateTime.now().millisecondsSinceEpoch}',
        familyContactId: caregiverId,
        caregiverName: caregiverName,
        riskScore: result.riskScore,
        scenarioType: 'Suspicious SMS Message',
        riskLevel: result.riskLevel.label,
        detectedSignals: result.detectedSignals.map((s) => s.title).toList(),
        explanation: result.analysis.summary,
        interventionStatus: 'Family notified regarding suspicious text message',
      );
      _lastAlertedFingerprint = fingerprint;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.navySurfaceLight,
            content: Text(
              'Family circle notified regarding this suspicious message.',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.riskCritical,
            content: Text('Failed to record family alert.'),
          ),
        );
      }
    } finally {
      _isAlerting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _controller.currentResult;

    return Scaffold(
      backgroundColor: AppTheme.navyBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.navyBackground,
        elevation: 0,
        title: const Text(
          'SMS Scam Shield',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safe Message Analysis',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Evaluate suspicious text messages and verify manipulation tactics without sharing private inbox access.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Zero Inbox Snooping Privacy Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.tealPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.tealPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zero Inbox Snooping',
                            style: TextStyle(
                              color: AppTheme.tealLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'GuardCall never reads your private SMS inbox automatically. Paste any message below for 100% on-device, private analysis.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sample Presets Bar
              const Text(
                'Try a Sample Message',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: SmsProtectionController.presets.map((preset) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: Key('sms_preset_${preset.title.replaceAll(" ", "_").toLowerCase()}'),
                        backgroundColor: AppTheme.navySurfaceLight,
                        side: const BorderSide(color: AppTheme.navyBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        label: Text(
                          preset.title,
                          style: const TextStyle(
                            color: AppTheme.skyAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _controller.loadPreset(preset.text),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Message Input Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('sms_input_text_field'),
                      controller: _controller.textController,
                      maxLines: 6,
                      minLines: 3,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Paste suspicious text message or SMS content here...',
                        hintStyle: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const Divider(color: AppTheme.navyBorder, height: 24),
                    Row(
                      children: [
                        Text(
                          '${_controller.textController.text.length} characters',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          key: const Key('sms_paste_clipboard_button'),
                          icon: const Icon(Icons.paste_rounded, size: 16),
                          label: const Text('Paste'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.skyAccent,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _pasteFromClipboard,
                        ),
                        if (_controller.textController.text.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            key: const Key('sms_clear_input_button'),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: AppTheme.textSecondary,
                            tooltip: 'Clear message text',
                            onPressed: _controller.clear,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      key: const Key('sms_analyze_button'),
                      text: 'Analyze Message',
                      icon: Icons.manage_search_rounded,
                      isLoading: _controller.isAnalyzing,
                      onPressed: _controller.analyze,
                    ),
                  ],
                ),
              ),

              // Error Banner
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const Key('sms_validation_error'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.riskHigh.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.riskHigh.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.riskHigh,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.riskHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Analysis Results Section
              if (result != null) ...[
                const SizedBox(height: 28),
                _buildResultsSection(context, result),
              ],

              const SizedBox(height: 28),

              // Platform Transparency Section
              _buildAndroidLimitationsSection(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, SmsAnalysisResult result) {
    final riskColor = result.riskLevel.color;

    return GlassCard(
      key: const Key('sms_analysis_results_card'),
      borderColor: riskColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RiskBadge(
                level: result.riskLevel,
                score: result.riskScore,
              ),
              Text(
                'Threat Score: ${result.riskScore} / 100',
                style: TextStyle(
                  color: riskColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RiskMeter(
            score: result.riskScore,
            level: result.riskLevel,
            barHeight: 12,
            showLabel: false,
          ),
          const SizedBox(height: 18),

          // Transparency Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.navyBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.disclaimer,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Detected Tactics Badges
          if (result.detectedTactics.isNotEmpty) ...[
            const Text(
              'Identified Scam Tactics',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedTactics.map((tactic) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    tactic,
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Detected Threat Signals List
          const SectionHeader(
            title: 'Behavioral Signals',
            subtitle: 'Manipulation dynamics detected in text',
          ),
          const SizedBox(height: 10),
          if (result.detectedSignals.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.riskSafe.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.riskSafe.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.riskSafe, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No manipulative pressure patterns detected in this message.',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: result.detectedSignals.map((signal) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: riskColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              signal.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              signal.explanation,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // Safe Action Checklist
          const SectionHeader(
            title: 'Safe Action Checklist',
            subtitle: 'Recommended protective steps before responding',
          ),
          const SizedBox(height: 10),
          Column(
            children: result.actionChecklist.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.isCrucial
                      ? AppTheme.riskCritical.withValues(alpha: 0.08)
                      : AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isCrucial
                        ? AppTheme.riskCritical.withValues(alpha: 0.3)
                        : AppTheme.navyBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.icon,
                      color: item.isCrucial ? AppTheme.riskCritical : AppTheme.tealPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: item.isCrucial
                                  ? AppTheme.riskCritical
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Persistence & Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.tealPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.tealPrimary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Saved to Risk History (Manual SMS Analysis)',
                    style: TextStyle(
                      color: AppTheme.tealLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_controller.savedRecord != null)
                  TextButton(
                    onPressed: () {
                      AssessmentDetailDialog.show(context, _controller.savedRecord!);
                    },
                    child: const Text('View Details', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Alert Family Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('sms_alert_family_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.skyAccent,
                side: const BorderSide(color: AppTheme.skyAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.family_restroom_rounded, size: 20),
              label: const Text(
                'Alert Family Circle',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: () => _alertFamily(result),
            ),
          ),
          const SizedBox(height: 10),

          // Analyze Another Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const Key('sms_reset_button'),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Analyze Another Message'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              onPressed: _controller.clear,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidLimitationsSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.skyAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Why manual message scanning?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Modern Android OS (Android 10 through 15) and Google Play policy strictly limit background SMS interception to the device\'s Default SMS Handler. '
            'GuardCall does not seek to replace your default SMS app, ensuring zero unnecessary access to your private conversations or bank messages. '
            'Manual analysis provides 100% on-device scam evaluation while respecting your privacy.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
