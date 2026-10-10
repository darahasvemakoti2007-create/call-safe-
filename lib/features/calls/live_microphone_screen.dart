import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/services/family_alert_service.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/section_header.dart';
import '../alerts/scam_warning_dialog.dart';
import '../detection/microphone_permission_handler.dart';
import 'live_microphone_controller.dart';

/// Screen managing real-time physical microphone audio analysis,
/// live speech recognition stream, progressive scam evaluation, and intervention warnings.
class LiveMicrophoneScreen extends StatefulWidget {
  final LiveMicrophoneController? controller;

  const LiveMicrophoneScreen({
    super.key,
    this.controller,
  });

  @override
  State<LiveMicrophoneScreen> createState() => _LiveMicrophoneScreenState();
}

class _LiveMicrophoneScreenState extends State<LiveMicrophoneScreen> {
  late final LiveMicrophoneController _controller;
  final TextEditingController _testTextController = TextEditingController();
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? LiveMicrophoneController();
    _controller.onWarningTriggered = _showWarningDialog;
    _controller.initialize();
  }

  @override
  void dispose() {
    _testTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showWarningDialog(dynamic analysis) {
    if (!mounted) return;
    ScamWarningDialog.show(
      context: context,
      analysis: analysis,
      onEndCall: () {
        _controller.stopListening();
        Navigator.of(context).pop();
      },
      onImSafe: () {
        _controller.dismissWarningModal();
      },
      onAlertFamily: () async {
        try {
          await FamilyAlertService.instance.createAlert(
            callSessionId: 'mic_session_${DateTime.now().millisecondsSinceEpoch}',
            familyContactId: 'default-caregiver',
            riskScore: analysis.riskScore,
            scenarioType: 'Live Microphone Shield',
            riskLevel: analysis.riskLevel.label,
            detectedSignals: analysis.detectedSignals.map((s) => s.title).toList(),
            explanation: analysis.summary,
            interventionStatus: 'Family alert requested from live mic shield',
          );
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.navyBackground,
        elevation: 0,
        title: const Text(
          'Microphone Shield',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          key: const Key('live_mic_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final permission = _controller.permissionStatus;
            final isCapturing = _controller.isCapturing;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Microphone Audio Analysis',
                    style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analyze speakerphone or in-person conversation audio for scam indicators',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Privacy & Android OS disclaimer banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.skyAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.skyAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.privacy_tip_outlined, color: AppTheme.skyAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Consent & Privacy Guarantee',
                              style: TextStyle(
                                color: AppTheme.skyAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Zero Audio Retention: Acoustic audio is processed in volatile memory for speech recognition and immediately discarded.\n'
                          '• Speakerphone / Ambient Capture Only: Operating system security prevents capturing internal cellular call audio directly. Place calls on speakerphone to analyze speech.\n'
                          '• Explicit Control: Microphone activates only when you tap Start and stops immediately on command.',
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status / Error message
                  if (_controller.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.riskCritical.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.riskCritical.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.riskCritical, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _controller.errorMessage!,
                              style: const TextStyle(color: AppTheme.riskCritical, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Permission card if not granted
                  if (!permission.isGranted) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.riskSuspicious.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mic_off_rounded,
                                    color: AppTheme.riskSuspicious, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      permission == MicrophonePermissionStatus.permanentlyDenied
                                          ? 'Microphone Permission Blocked'
                                          : 'Microphone Permission Needed',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      permission == MicrophonePermissionStatus.permanentlyDenied
                                          ? 'Enable microphone permissions in device settings.'
                                          : 'GuardCall requires microphone access to evaluate spoken phrases.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            key: const Key('grant_microphone_permission_button'),
                            text: 'Grant Microphone Access',
                            icon: Icons.mic_rounded,
                            onPressed: _controller.requestPermission,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pipeline Diagnostics Card
                  GlassCard(
                    key: const Key('pipeline_diagnostics_card'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.monitor_heart_outlined,
                                    color: AppTheme.skyAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Pipeline Diagnostics',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _controller.isLiveTranscriptionActive
                                    ? AppTheme.tealPrimary.withValues(alpha: 0.15)
                                    : AppTheme.navySurfaceLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _controller.isLiveTranscriptionActive
                                      ? AppTheme.tealPrimary.withValues(alpha: 0.4)
                                      : AppTheme.navyBorder,
                                ),
                              ),
                              child: Text(
                                _controller.isLiveTranscriptionActive
                                    ? 'LIVE RECOGNIZER ACTIVE'
                                    : (isCapturing ? 'ACOUSTIC ONLY' : 'STANDBY'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _controller.isLiveTranscriptionActive
                                      ? AppTheme.tealPrimary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDiagnosticRow(
                          context,
                          label: 'Microphone Permission',
                          value: permission.name.toUpperCase(),
                          isGood: permission.isGranted,
                        ),
                        const SizedBox(height: 6),
                        _buildDiagnosticRow(
                          context,
                          label: 'Audio Capture',
                          value: _controller.captureAvailabilityDescription,
                          isGood: isCapturing,
                        ),
                        const SizedBox(height: 6),
                        _buildDiagnosticRow(
                          context,
                          label: 'Speech Recognizer (ASR)',
                          value: _controller.sttStatusDescription,
                          isGood: _controller.isSttConfigured,
                        ),
                        const SizedBox(height: 6),
                        _buildDiagnosticRow(
                          context,
                          label: 'Last Transcription',
                          value: _controller.lastTranscriptionStatus,
                          isGood: _controller.transcriptSegments.isNotEmpty,
                        ),
                        const SizedBox(height: 6),
                        _buildDiagnosticRow(
                          context,
                          label: 'Scam Detection Engine',
                          value: _controller.riskEngineStatusDescription,
                          isGood: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Primary Microphone Control Area
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isCapturing
                                        ? AppTheme.riskSafe
                                        : AppTheme.textMuted,
                                    shape: BoxShape.circle,
                                    boxShadow: isCapturing
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.riskSafe.withValues(alpha: 0.6),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isCapturing
                                      ? (_controller.isLiveTranscriptionActive
                                          ? 'Microphone Active • ${_controller.sessionDurationSeconds}s'
                                          : 'Acoustic Monitoring • ${_controller.sessionDurationSeconds}s')
                                      : 'Microphone Idle',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isCapturing ? AppTheme.riskSafe : AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (isCapturing) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.navySurfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.navyBorder),
                                ),
                                child: Text(
                                  'Level: ${(_controller.audioLevel * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.tealLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Large Start / Stop Action Button
                        if (!isCapturing) ...[
                          PrimaryButton(
                            key: const Key('start_microphone_shield_button'),
                            text: 'Start Microphone Shield',
                            icon: Icons.mic_rounded,
                            onPressed: _controller.startListening,
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              key: const Key('stop_microphone_shield_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.riskCritical,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _controller.stopListening,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text(
                                'Stop Microphone Shield',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Real-time Risk Assessment Section
                  const SectionHeader(
                    title: 'Live Threat Evaluation',
                    subtitle: 'Heuristic scam score updated as speech is recognized',
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RiskBadge(
                              level: _controller.currentAnalysis.riskLevel,
                              score: _controller.currentAnalysis.riskScore,
                            ),
                            Text(
                              'Threat Score: ${_controller.currentAnalysis.riskScore}/100',
                              style: TextStyle(
                                color: _controller.currentAnalysis.riskLevel.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _controller.currentAnalysis.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                        ),
                        if (_controller.currentAnalysis.detectedSignals.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _controller.currentAnalysis.detectedSignals.map((signal) {
                              return Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.navySurfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.navyBorder),
                                ),
                                child: Text(
                                  signal.title,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.tealLight,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Live Transcription Stream Section
                  SectionHeader(
                    title: _controller.isSttConfigured
                        ? 'Live Transcript Stream'
                        : 'Spoken Transcript Stream',
                    subtitle: _controller.isSttConfigured
                        ? 'Real-time text recognized from microphone stream'
                        : 'Showing recognized dialogue and manual test utterances',
                    trailing: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.skyAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: Icon(
                        _showManualInput
                            ? Icons.keyboard_hide_rounded
                            : Icons.keyboard_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _showManualInput
                            ? 'Hide Input'
                            : (_controller.isSttConfigured ? 'Type Utterance' : 'Manual Test Input'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() => _showManualInput = !_showManualInput);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Manual Text Input Bar (for testing/accessibility)
                  if (_showManualInput) ...[
                    if (!_controller.isSttConfigured) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.navySurfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.navyBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppTheme.skyAccent, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Manual Speech Test: Type spoken phrases here to test scam heuristics without a live ASR backend.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.navySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.navyBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('manual_speech_input_field'),
                              controller: _testTextController,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: _controller.isSttConfigured
                                    ? 'Enter test spoken phrase (e.g. "urgent OTP code")...'
                                    : 'Enter spoken phrase manually (Simulated ASR)...',
                                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            key: const Key('submit_manual_speech_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.tealPrimary,
                              foregroundColor: AppTheme.navyBackground,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              minimumSize: const Size(60, 40),
                            ),
                            onPressed: () {
                              final text = _testTextController.text.trim();
                              if (text.isNotEmpty) {
                                _controller.addSpokenLine(text);
                                _testTextController.clear();
                              }
                            },
                            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Recognized speech segments list
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_controller.transcriptSegments.isEmpty &&
                            _controller.interimSegment == null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'No speech recognized yet.\nTap Start and speak clearly into the device microphone.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          ..._controller.transcriptSegments.map((segment) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.tealPrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'FINAL',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.tealPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      segment.text,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (_controller.interimSegment != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.skyAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'INTERIM',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.skyAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _controller.interimSegment!.text,
                                      style: const TextStyle(
                                        color: AppTheme.skyAccent,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool isGood,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isGood ? AppTheme.tealLight : AppTheme.skyAccent,
            ),
          ),
        ),
      ],
    );
  }
}
