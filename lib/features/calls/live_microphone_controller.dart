import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/widgets/risk_badge.dart';
import '../demo/demo_scenario.dart';
import '../detection/detection_provider_factory.dart';
import '../detection/live_speech_recognition_service.dart';
import '../detection/microphone_audio_capture_service.dart';
import '../detection/microphone_permission_handler.dart';
import '../detection/mock_scam_detection_engine.dart';
import '../detection/risk_analysis.dart';
import '../detection/scam_detection_engine.dart';
import '../history/call_history_repository.dart';

/// State controller managing real-time microphone audio capture,
/// live speech recognition, progressive scam risk analysis, and warning interventions.
class LiveMicrophoneController extends ChangeNotifier {
  final MicrophonePermissionHandler _permissionHandler;
  final MicrophoneAudioCaptureService _audioCaptureService;
  final LiveSpeechRecognitionService _speechRecognitionService;
  final ScamDetectionEngine _detectionEngine;

  MicrophonePermissionStatus _permissionStatus = MicrophonePermissionStatus.notDetermined;
  AudioCaptureState _captureState = AudioCaptureState.idle;
  double _audioLevel = 0.0;
  String? _statusMessage;
  String? _errorMessage;

  final List<LiveSpeechSegment> _transcriptSegments = [];
  LiveSpeechSegment? _interimSegment;
  RiskAnalysis _currentAnalysis = RiskAnalysis.safe();

  Timer? _sessionTimer;
  int _sessionDurationSeconds = 0;

  // Warning deduplication
  RiskLevel? _lastWarnedTier;
  bool _warningModalActive = false;
  void Function(RiskAnalysis analysis)? onWarningTriggered;

  StreamSubscription<AudioCaptureState>? _captureStateSub;
  StreamSubscription<double>? _audioLevelSub;
  StreamSubscription<LiveSpeechSegment>? _segmentSub;
  StreamSubscription<List<int>>? _audioDataSub;

  LiveMicrophoneController({
    MicrophonePermissionHandler? permissionHandler,
    MicrophoneAudioCaptureService? audioCaptureService,
    LiveSpeechRecognitionService? speechRecognitionService,
    ScamDetectionEngine? detectionEngine,
  })  : _permissionHandler = permissionHandler ?? DefaultMicrophonePermissionHandler(),
        _audioCaptureService = audioCaptureService ?? DefaultMicrophoneAudioCaptureService(),
        _speechRecognitionService = speechRecognitionService ??
            DefaultLiveSpeechRecognitionService(bufferThresholdBytes: 48000),
        _detectionEngine = detectionEngine ?? DetectionProviderFactory.getDetectionEngine();

  // Getters
  MicrophonePermissionStatus get permissionStatus => _permissionStatus;
  AudioCaptureState get captureState => _captureState;
  double get audioLevel => _audioLevel;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;

  List<LiveSpeechSegment> get transcriptSegments => List.unmodifiable(_transcriptSegments);
  LiveSpeechSegment? get interimSegment => _interimSegment;
  RiskAnalysis get currentAnalysis => _currentAnalysis;
  int get sessionDurationSeconds => _sessionDurationSeconds;
  bool get isCapturing => _captureState == AudioCaptureState.capturing;
  bool get isWarningActive => _warningModalActive;

  // Diagnostics Getters
  bool get isSttConfigured => _speechRecognitionService.isConfigured;
  String get sttProviderName => _speechRecognitionService.providerName;
  DateTime? get lastTranscriptionTime => _speechRecognitionService.lastTranscriptionTime;
  bool get isLiveTranscriptionActive =>
      isCapturing && isSttConfigured && _speechRecognitionService.lastError == null;

  String get audioCaptureDetails =>
      '${_audioCaptureService.sampleRate}Hz • ${_audioCaptureService.channelCount == 1 ? "Mono" : "Stereo"} • ${_audioCaptureService.bitDepth}-bit';

  String get captureAvailabilityDescription {
    if (_captureState == AudioCaptureState.capturing) {
      return _audioCaptureService.isHardwareBound
          ? 'Capturing Live Audio ($audioCaptureDetails)'
          : 'Active Capture ($audioCaptureDetails, Volatile Buffer)';
    } else if (_captureState == AudioCaptureState.interrupted) {
      return 'Interrupted (Audio Focus Lost)';
    } else if (_captureState == AudioCaptureState.error) {
      return 'Capture Error';
    }
    return 'Idle / Standby';
  }

  String get sttStatusDescription {
    if (isSttConfigured) {
      return '$sttProviderName (Ready)';
    }
    return '$sttProviderName (Unconfigured)';
  }

  String get lastTranscriptionStatus {
    if (_transcriptSegments.isNotEmpty) {
      final lastTime = lastTranscriptionTime;
      final timeLabel = lastTime != null
          ? '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}:${lastTime.second.toString().padLeft(2, '0')}'
          : 'Active';
      return '${_transcriptSegments.length} utterances recorded (Last: $timeLabel)';
    }
    return 'No speech transcribed yet';
  }

  String get riskEngineStatusDescription {
    if (_detectionEngine is MockScamDetectionEngine) {
      return 'On-Device Heuristic Engine (6 Signal Categories)';
    }
    return 'Remote / Edge AI Engine (Active)';
  }

  /// Initializes permission and subscribes to audio and transcription streams.
  Future<void> initialize() async {
    _permissionStatus = await _permissionHandler.checkPermission();

    _captureStateSub = _audioCaptureService.stateStream.listen((state) {
      _captureState = state;
      if (state == AudioCaptureState.interrupted) {
        _statusMessage = 'Microphone capture paused: audio focus interrupted.';
      } else if (state == AudioCaptureState.stopped) {
        _statusMessage = 'Microphone shield stopped.';
      } else if (state == AudioCaptureState.capturing) {
        _statusMessage = isSttConfigured
            ? 'Microphone active: monitoring ambient speech patterns...'
            : 'Microphone active: acoustic levels only (ASR unconfigured).';
      }
      notifyListeners();
    });

    _audioLevelSub = _audioCaptureService.audioLevelStream.listen((level) {
      _audioLevel = level;
      notifyListeners();
    });

    _segmentSub = _speechRecognitionService.segmentStream.listen((segment) {
      processSpeechSegment(segment);
    });

    // Pipe PCM chunks directly to speech recognition service
    _audioDataSub = _audioCaptureService.audioDataStream.listen((bytes) {
      _speechRecognitionService.processAudioBytes(bytes).catchError((_) {});
    });

    notifyListeners();
  }

  /// Prompts the user to grant microphone permissions.
  Future<void> requestPermission() async {
    _errorMessage = null;
    _permissionStatus = await _permissionHandler.requestPermission();
    if (_permissionStatus == MicrophonePermissionStatus.denied) {
      _errorMessage = 'Microphone permission denied. Speech analysis cannot proceed without audio access.';
    } else if (_permissionStatus == MicrophonePermissionStatus.permanentlyDenied) {
      _errorMessage =
          'Microphone permission is permanently disabled. Please grant microphone access in your device settings.';
    }
    notifyListeners();
  }

  /// Starts physical audio capture and live speech recognition.
  Future<void> startListening() async {
    _errorMessage = null;

    // 1. Ensure permission is granted
    if (!_permissionStatus.isGranted) {
      await requestPermission();
      if (!_permissionStatus.isGranted) return;
    }

    try {
      _sessionDurationSeconds = 0;
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _sessionDurationSeconds++;
        notifyListeners();
      });

      // 2. Start hardware audio capture
      await _audioCaptureService.startCapture();

      // 3. Start live speech transcription
      await _speechRecognitionService.startListening(
        onSegment: (_) {},
        onError: (err) {
          _errorMessage = err;
          notifyListeners();
        },
      );

      if (isSttConfigured) {
        _statusMessage = 'Microphone active: listening and evaluating speech...';
      } else {
        _statusMessage =
            'Microphone active: monitoring acoustic levels (ASR unconfigured; use manual test input below).';
      }
    } catch (e) {
      _errorMessage = 'Failed to start microphone capture: $e';
      await _audioCaptureService.stopCapture();
    }
    notifyListeners();
  }

  /// Stops physical microphone capture and halts speech recognition.
  Future<void> stopListening() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;

    await _speechRecognitionService.stopListening();
    await _audioCaptureService.stopCapture();
    _captureState = _audioCaptureService.state;

    _interimSegment = null;
    _statusMessage = 'Microphone stopped. Capture stream closed.';
    notifyListeners();

    // Log assessment if genuine speech was evaluated
    if (_transcriptSegments.isNotEmpty) {
      await logAssessmentToHistory();
    }
  }

  /// Handles incoming audio interruption events (e.g. cellular phone call takes focus).
  Future<void> handleInterruption() async {
    await _audioCaptureService.interrupt();
    await _speechRecognitionService.stopListening();
    _statusMessage = 'Microphone interrupted by phone call or OS audio manager.';
    notifyListeners();
  }

  /// Processes an incoming recognized speech segment (interim or final)
  /// and feeds the updated transcript into the scam detection engine.
  Future<void> processSpeechSegment(LiveSpeechSegment segment) async {
    if (segment.text.trim().isEmpty) return;

    if (segment.isFinal) {
      _transcriptSegments.add(segment);
      _interimSegment = null;
    } else {
      _interimSegment = segment;
    }

    // Build chronological ConversationLine entries for analysis
    final lines = <ConversationLine>[];
    for (final seg in _transcriptSegments) {
      lines.add(ConversationLine(
        speaker: Speaker.caller,
        text: seg.text,
      ));
    }
    if (_interimSegment != null && _interimSegment!.text.trim().isNotEmpty) {
      lines.add(ConversationLine(
        speaker: Speaker.caller,
        text: _interimSegment!.text,
      ));
    }

    // Evaluate threats using existing detection engine
    if (lines.isNotEmpty) {
      _currentAnalysis = await _detectionEngine.analyzeConversation(lines);
      _evaluateWarningTrigger(_currentAnalysis);
    }

    notifyListeners();
  }

  /// Feeds a custom or manual spoken line directly into the pipeline.
  ///
  /// Useful for live device dictation, accessibility keyboards, and test fixtures.
  Future<void> addSpokenLine(String text, {bool isFinal = true}) async {
    final segment = LiveSpeechSegment(
      text: text,
      isFinal: isFinal,
      timestamp: DateTime.now(),
      speaker: 'Caller',
    );
    await processSpeechSegment(segment);
  }

  /// Evaluates risk score against warning thresholds and handles deduplication.
  void _evaluateWarningTrigger(RiskAnalysis analysis) {
    final tier = analysis.riskLevel;
    final isScamLikely = tier == RiskLevel.high || tier == RiskLevel.critical;

    if (!isScamLikely) return;

    // Deduplication check:
    // Only trigger if:
    // 1. We haven't warned yet, OR
    // 2. Risk escalated from High to Critical Threat.
    final shouldTrigger = _lastWarnedTier == null ||
        (_lastWarnedTier == RiskLevel.high && tier == RiskLevel.critical);

    if (shouldTrigger && !_warningModalActive) {
      _warningModalActive = true;
      _lastWarnedTier = tier;
      onWarningTriggered?.call(analysis);
    }
  }

  /// Acknowledges a warning dialog without re-triggering for the same tier.
  void dismissWarningModal() {
    _warningModalActive = false;
    notifyListeners();
  }

  /// Persists the completed live microphone evaluation to [CallHistoryRepository].
  Future<void> logAssessmentToHistory() async {
    if (_transcriptSegments.isEmpty) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final sessionId = 'mic_${now.millisecondsSinceEpoch}';

    final fullTranscript = _transcriptSegments.map((s) => s.text).join(' ');
    final excerpt = _transcriptSegments.take(3).map((s) => '"${s.text}"').join('\n');

    final recommendedAction = _currentAnalysis.riskLevel == RiskLevel.critical
        ? 'Hang up immediately. Caller demonstrated critical manipulation signals. Notify your family circle.'
        : _currentAnalysis.riskLevel == RiskLevel.high
            ? 'Exercise high caution. Verify caller identity using an official callback number.'
            : _currentAnalysis.riskLevel == RiskLevel.suspicious
                ? 'Stay alert. Do not click links or share confidential information.'
                : 'No protective action needed. Conversation assessed as safe.';

    final record = CallHistoryRecord(
      id: sessionId,
      title: 'Microphone Audio Analysis',
      subtitle: _currentAnalysis.summary,
      timestamp: 'Today • $timeStr',
      duration: '${_sessionDurationSeconds}s',
      riskScore: _currentAnalysis.riskScore,
      riskLevel: _currentAnalysis.riskLevel,
      signals: _currentAnalysis.detectedSignals.map((s) => s.title).toList(),
      isSimulated: false,
      source: AssessmentSource.microphoneAudio,
      explanation: _currentAnalysis.explanations.isNotEmpty
          ? _currentAnalysis.explanations.join('\n• ')
          : _currentAnalysis.summary,
      transcriptExcerpt: excerpt.isNotEmpty ? excerpt : fullTranscript,
      recommendedAction: recommendedAction,
    );

    await CallHistoryRepository.instance.addRecord(record);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _captureStateSub?.cancel();
    _audioLevelSub?.cancel();
    _segmentSub?.cancel();
    _audioDataSub?.cancel();

    _speechRecognitionService.dispose();
    _audioCaptureService.release();
    super.dispose();
  }
}
