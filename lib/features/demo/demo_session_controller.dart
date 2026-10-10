import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/widgets/risk_badge.dart';
import '../alerts/scam_intervention_state.dart';
import '../detection/conversation_pipeline.dart';
import '../detection/detection_provider_factory.dart';
import '../detection/risk_analysis.dart';
import '../detection/scam_detection_engine.dart';
import 'demo_scenario.dart';

/// State controller managing sequential conversation playback and progressive
/// scam risk detection for a single simulated scenario.
class DemoSessionController extends ChangeNotifier {
  final DemoScenario scenario;
  final ScamDetectionEngine detectionEngine;
  final Duration stepInterval;

  int _currentIndex = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _warningShown = false;
  bool _endedByIntervention = false;
  ScamInterventionState _interventionState = ScamInterventionState.none;
  Timer? _playbackTimer;

  late RiskAnalysis _currentAnalysis;

  DemoSessionController({
    required this.scenario,
    ScamDetectionEngine? detectionEngine,
    ConversationPipeline? pipeline,
    this.stepInterval = const Duration(milliseconds: 1800),
  }) : detectionEngine = detectionEngine ??
            pipeline?.detectionEngine ??
            DetectionProviderFactory.getDetectionEngine() {
    _currentAnalysis = RiskAnalysis(
      riskScore: 0,
      riskLevel: RiskLevel.safe,
      detectedSignals: const [],
      explanations: const ['Simulation has not started yet.'],
      confidence: 0.0,
    );
  }

  /// All conversation lines displayed so far in the simulation.
  List<ConversationLine> get displayedLines =>
      scenario.conversationLines.take(_currentIndex).toList();

  /// Current assessed threat analysis for the conversation up to this moment.
  RiskAnalysis get currentAnalysis => _currentAnalysis;

  /// Whether the simulation is actively advancing through dialogue turns.
  bool get isRunning => _isRunning;

  /// Whether the playback is temporarily paused by the user or warning.
  bool get isPaused => _isPaused;

  /// Whether all conversation turns have been delivered or the call was ended by intervention.
  bool get isCompleted =>
      _currentIndex >= scenario.conversationLines.length || _endedByIntervention;

  /// Total number of conversation turns in this scenario.
  int get totalLines => scenario.conversationLines.length;

  /// Current line index (0 to totalLines).
  int get currentLineIndex => _currentIndex;

  /// Whether the current risk assessment meets or exceeds the High threshold.
  bool get isWarningThresholdCrossed =>
      _currentAnalysis.riskLevel == RiskLevel.high ||
      _currentAnalysis.riskLevel == RiskLevel.critical;

  /// Whether an intervention warning has already been presented during this run.
  bool get warningShown => _warningShown;

  /// Current intervention lifecycle state.
  ScamInterventionState get interventionState => _interventionState;

  /// Whether the simulation was terminated early by user intervention.
  bool get isEndedByIntervention => _endedByIntervention;

  /// Starts or begins the simulation from the beginning or current turn.
  Future<void> start() async {
    if (isCompleted) {
      restart();
    }

    _isRunning = true;
    _isPaused = false;
    notifyListeners();

    // If starting fresh, advance the first line immediately
    if (_currentIndex == 0) {
      await advanceNextLine();
    }

    _scheduleNextStep();
  }

  /// Advances to the next conversation turn and runs the detection engine.
  Future<void> advanceNextLine() async {
    if (_currentIndex < scenario.conversationLines.length && !_endedByIntervention) {
      _currentIndex++;

      // Run detection on the conversation revealed up to this point
      final updatedLines = displayedLines;
      _currentAnalysis = await detectionEngine.analyzeConversation(updatedLines);

      // Check if dangerous warning threshold was just crossed
      if (isWarningThresholdCrossed && !_warningShown) {
        _warningShown = true;
        _interventionState = ScamInterventionState.warningShown;
        _isPaused = true;
        _playbackTimer?.cancel();
        notifyListeners();
        return;
      }

      notifyListeners();

      if (isCompleted) {
        _isRunning = false;
        _playbackTimer?.cancel();
        notifyListeners();
      }
    }
  }

  /// User selected "I'm Safe" on the warning modal.
  ///
  /// Dismisses the warning and resumes simulation without lowering risk score
  /// or removing any detected threat signals.
  void dismissWarning() {
    _interventionState = ScamInterventionState.userDismissed;
    _isPaused = false;
    notifyListeners();

    if (_isRunning && !isCompleted) {
      _scheduleNextStep();
    }
  }

  /// User selected "End Call" on the warning modal.
  ///
  /// Immediately terminates the simulated call, marking it as ended by intervention
  /// while preserving all accumulated risk analysis telemetry.
  void endCallByWarning() {
    _interventionState = ScamInterventionState.userEnded;
    _endedByIntervention = true;
    _isRunning = false;
    _isPaused = false;
    _playbackTimer?.cancel();
    notifyListeners();
  }

  /// Records that the user requested a simulated family alert.
  void requestFamilyAlert() {
    _interventionState = ScamInterventionState.familyAlertRequested;
    notifyListeners();
  }

  /// Temporarily pauses the simulation timer.
  void pause() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      _playbackTimer?.cancel();
      notifyListeners();
    }
  }

  /// Resumes playback from a paused state.
  void resume() {
    if (_isRunning && _isPaused && !isCompleted) {
      _isPaused = false;
      notifyListeners();
      _scheduleNextStep();
    }
  }

  void _scheduleNextStep() {
    _playbackTimer?.cancel();

    if (!_isRunning || _isPaused || isCompleted) return;

    _playbackTimer = Timer(stepInterval, () async {
      if (!_isRunning || _isPaused || isCompleted) return;

      await advanceNextLine();

      if (!isCompleted && _isRunning && !_isPaused) {
        _scheduleNextStep();
      }
    });
  }

  /// Resets the conversation and detection states back to turn 0.
  void restart() {
    _playbackTimer?.cancel();
    _currentIndex = 0;
    _isRunning = false;
    _isPaused = false;
    _warningShown = false;
    _endedByIntervention = false;
    _interventionState = ScamInterventionState.none;
    _currentAnalysis = RiskAnalysis(
      riskScore: 0,
      riskLevel: RiskLevel.safe,
      detectedSignals: const [],
      explanations: const ['Simulation has not started yet.'],
      confidence: 0.0,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
