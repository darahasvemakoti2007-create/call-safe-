import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/risk_badge.dart';
import '../../core/widgets/risk_meter.dart';
import '../alerts/scam_intervention_state.dart';
import '../alerts/scam_warning_dialog.dart';
import '../alerts/simulated_family_alert.dart';
import '../detection/risk_analysis.dart';
import '../history/call_history_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/call_session_service.dart';
import '../../core/services/family_alert_service.dart';
import '../../core/services/risk_signal_service.dart';
import '../../core/services/supabase_service.dart';
import 'demo_scenario.dart';
import 'demo_session_controller.dart';

/// Screen managing progressive conversation playback and live dynamic risk analysis.
class DemoPlayerScreen extends StatefulWidget {
  final DemoScenario scenario;

  const DemoPlayerScreen({
    super.key,
    required this.scenario,
  });

  @override
  State<DemoPlayerScreen> createState() => _DemoPlayerScreenState();
}

class _DemoPlayerScreenState extends State<DemoPlayerScreen> {
  late final DemoSessionController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _historyLogged = false;
  bool _warningDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = DemoSessionController(scenario: widget.scenario);
    _controller.addListener(_handleControllerUpdate);
  }

  void _handleControllerUpdate() {
    if (!mounted) return;

    // Scroll to the bottom when new turns or explanations appear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Present high-prominence intervention dialog when threshold is reached
    if (_controller.interventionState == ScamInterventionState.warningShown &&
        !_warningDialogOpen) {
      _showWarningDialog();
    }

    // When simulation reaches completion or ends early, record to in-memory call history
    if (_controller.isCompleted && !_historyLogged) {
      _historyLogged = true;
      _logCompletedSimulation();
    }
  }

  Future<void> _showWarningDialog() async {
    _warningDialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await ScamWarningDialog.show(
        context: context,
        analysis: _controller.currentAnalysis,
        onEndCall: () {
          Navigator.of(context, rootNavigator: true).pop();
          _controller.endCallByWarning();
        },
        onImSafe: () {
          Navigator.of(context, rootNavigator: true).pop();
          _controller.dismissWarning();
        },
        onAlertFamily: () async {
          Navigator.of(context, rootNavigator: true).pop();
          _controller.requestFamilyAlert();

          bool isCloud = false;
          final analysis = _controller.currentAnalysis;
          FamilyAlertRecord? recordedAlert;

          try {
            recordedAlert = await FamilyAlertService.instance.createAlert(
              callSessionId: 'demo_${widget.scenario.id}',
              familyContactId: 'demo-contact-sarah',
              riskScore: analysis.riskScore,
              scenarioType: widget.scenario.title,
              riskLevel: analysis.riskLevel.label,
              detectedSignals: analysis.detectedSignals.map((s) => s.title).toList(),
              explanation: analysis.summary,
              interventionStatus: 'Family alert requested',
              victimName: 'Robert Jenkins (Father)',
              caregiverName: 'Sarah Jenkins (Daughter)',
            );
            if (SupabaseService.instance.isConfigured) {
              isCloud = true;
            }
          } catch (_) {
            // Non-blocking fallback
          }

          if (mounted) {
            SimulatedFamilyAlert.show(
              context: context,
              scenarioTitle: widget.scenario.title,
              analysis: analysis,
              isCloudRecorded: isCloud,
              interventionStatus: 'Family alert requested',
              caregiverName: 'Sarah Jenkins (Daughter)',
              seniorName: 'Robert Jenkins (Father)',
              notificationStatus: recordedAlert?.notificationStatus ?? 'SIMULATED',
              notificationMessage: recordedAlert?.notificationMessage,
            );
          }
        },
      );

      _warningDialogOpen = false;
    });
  }

  void _logCompletedSimulation() {
    final analysis = _controller.currentAnalysis;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final sessionId = 'demo_${now.millisecondsSinceEpoch}';

    final record = CallHistoryRecord(
      id: sessionId,
      title: '${widget.scenario.title} (Simulation)',
      subtitle: analysis.summary,
      timestamp: 'Today • $timeStr',
      duration: '${_controller.displayedLines.length * 2}s',
      riskScore: analysis.riskScore,
      riskLevel: analysis.riskLevel,
      signals: analysis.detectedSignals.map((s) => s.title).toList(),
      isSimulated: true,
      interventionStatus: _controller.interventionState.historyStatus,
    );

    CallHistoryRepository.instance.addRecord(record);

    // Local-first: Asynchronously synchronize structured metadata if Supabase is active
    if (SupabaseService.instance.isConfigured) {
      final authUser = AuthService.instance.getCurrentUser();
      if (authUser != null) {
        CallSessionService.instance.createCallSession(
          id: sessionId,
          userId: authUser.id,
          startedAt: now,
          durationSeconds: _controller.displayedLines.length * 2,
          riskScore: analysis.riskScore,
          riskLevel: analysis.riskLevel.name,
          scenarioType: widget.scenario.id,
          interventionStatus: _controller.interventionState.historyStatus,
        ).then((session) {
          final signalRecords = analysis.detectedSignals.map((s) {
            return RiskSignalRecord(
              callSessionId: session.id,
              signalType: s.type.name,
              severity: analysis.riskLevel.name,
              explanation: s.title,
              detectedAt: now,
            );
          }).toList();
          if (signalRecords.isNotEmpty) {
            RiskSignalService.instance.createRiskSignals(signalRecords);
          }
        }).catchError((_) {
          // Never crash the demo on sync error
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final analysis = _controller.currentAnalysis;
        final displayedLines = _controller.displayedLines;
        final isCompleted = _controller.isCompleted;
        final isRunning = _controller.isRunning;
        final isPaused = _controller.isPaused;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.navySurface,
            elevation: 0,
            title: Text(
              widget.scenario.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back to Demo Center',
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Meta & Live Risk Status Area
                _buildTopRiskStatus(analysis),

                // Main Transcript & Progressive Detection Content
                Expanded(
                  child: displayedLines.isEmpty && !isRunning
                      ? _buildReadyState(context)
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          children: [
                            // Conversation Turns
                            ...displayedLines.asMap().entries.map((entry) {
                              return _buildDialogueBubble(context, entry.value, entry.key);
                            }),

                            // Real-time Detected Signals Section
                            const SizedBox(height: 12),
                            _buildDetectedSignalsSection(context, analysis),

                            // "Why is GuardCall concerned?" Section
                            const SizedBox(height: 16),
                            _buildExplanationSection(context, analysis),

                            // Final Assessment (When simulation completes)
                            if (isCompleted) ...[
                              const SizedBox(height: 16),
                              _buildFinalAssessmentCard(context, analysis),
                            ],

                            const SizedBox(height: 24),
                          ],
                        ),
                ),

                // Bottom Action Controller
                _buildBottomControls(isRunning, isPaused, isCompleted),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopRiskStatus(RiskAnalysis analysis) {
    final signalCount = analysis.detectedSignals.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.navyBorder, width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.skyAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.skyAccent.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'SIMULATED CALL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.skyAccent,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Caller: ${widget.scenario.callerRole}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.navySurfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$signalCount ${signalCount == 1 ? 'signal' : 'signals'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RiskMeter(
            score: analysis.riskScore,
            level: analysis.riskLevel,
            barHeight: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.tealPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                color: AppTheme.tealPrimary,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ready for Live Analysis',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Press "Start Simulation" below. As each turn is spoken, GuardCall will evaluate behavioral signals and update the risk meter in real time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogueBubble(BuildContext context, ConversationLine line, int index) {
    final isCaller = line.speaker == Speaker.caller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isCaller ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCaller ? Icons.phone_forwarded_rounded : Icons.person_rounded,
                  size: 13,
                  color: isCaller ? AppTheme.riskHigh : AppTheme.tealPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  isCaller
                      ? 'Caller (${widget.scenario.callerRole})'
                      : 'User (You)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCaller ? AppTheme.riskHigh : AppTheme.tealPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCaller
                  ? AppTheme.navySurfaceLight
                  : AppTheme.tealPrimary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isCaller ? 4 : 18),
                bottomRight: Radius.circular(isCaller ? 18 : 4),
              ),
              border: Border.all(
                color: isCaller
                    ? AppTheme.navyBorder
                    : AppTheme.tealPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Text(
              line.text,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedSignalsSection(BuildContext context, RiskAnalysis analysis) {
    final signals = analysis.detectedSignals;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    signals.isEmpty
                        ? Icons.check_circle_outline_rounded
                        : Icons.radar_rounded,
                    size: 18,
                    color: signals.isEmpty ? AppTheme.riskSafe : analysis.riskLevel.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detected Signals',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
              Text(
                '${signals.length} active',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (signals.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.riskSafe.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.riskSafe.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'No scam or manipulation signals detected so far.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.riskSafe,
                ),
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: signals.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.navyBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: analysis.riskLevel.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.title,
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
          ],
        ],
      ),
    );
  }

  Widget _buildExplanationSection(BuildContext context, RiskAnalysis analysis) {
    final explanations = analysis.explanations;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: AppTheme.tealPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Why is GuardCall concerned?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: explanations.map((exp) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 8),
                      child: Icon(
                        Icons.fiber_manual_record,
                        size: 7,
                        color: AppTheme.tealPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        exp,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalAssessmentCard(BuildContext context, RiskAnalysis analysis) {
    final isScam = analysis.isScamLikely;
    final level = analysis.riskLevel;
    final endedByIntervention = _controller.isEndedByIntervention;
    final intervention = _controller.interventionState;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: level.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                endedByIntervention
                    ? Icons.phone_disabled_rounded
                    : (isScam ? Icons.gpp_bad_rounded : Icons.verified_user_rounded),
                size: 28,
                color: level.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endedByIntervention ? 'Simulation Ended' : 'Simulation Complete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: level.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      endedByIntervention
                          ? 'GuardCall intervention was triggered.'
                          : (isScam ? 'High Risk Scam Detected' : 'Verified Safe Call'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
              RiskBadge(level: level, score: analysis.riskScore),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            endedByIntervention
                ? 'The simulated call was terminated following user intervention. GuardCall detected dangerous manipulation patterns before credentials or funds could be compromised.'
                : analysis.summary,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.45,
            ),
          ),
          if (intervention == ScamInterventionState.familyAlertRequested) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.skyAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.skyAccent.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.family_restroom_rounded, size: 14, color: AppTheme.skyAccent),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Simulated family alert was requested for Sarah Jenkins.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.skyAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'This assessment has been logged to your local Call History.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isRunning, bool isPaused, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(
          top: BorderSide(color: AppTheme.navyBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRunning) ...[
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: isPaused ? 'Resume Simulation' : 'Pause Simulation',
                    icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    backgroundColor: AppTheme.navySurfaceLight,
                    textColor: AppTheme.textPrimary,
                    onPressed: isPaused ? _controller.resume : _controller.pause,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Material(
                    color: AppTheme.navySurfaceLight,
                    borderRadius: BorderRadius.circular(28),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimary),
                      tooltip: 'Restart',
                      onPressed: () {
                        setState(() {
                          _historyLogged = false;
                          _warningDialogOpen = false;
                        });
                        _controller.restart();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isCompleted) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Restart Simulation',
                    icon: Icons.refresh_rounded,
                    backgroundColor: AppTheme.navySurfaceLight,
                    textColor: AppTheme.textPrimary,
                    onPressed: () {
                      setState(() {
                        _historyLogged = false;
                        _warningDialogOpen = false;
                      });
                      _controller.restart();
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Back to Demo Center',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Start Simulation',
                icon: Icons.play_arrow_rounded,
                onPressed: () => _controller.start(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
