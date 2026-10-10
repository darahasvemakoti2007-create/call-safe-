import 'package:flutter/material.dart';
import '../history/call_history_repository.dart';
import 'sms_scam_analysis_service.dart';

/// A preset sample message for testing and interactive evaluation.
class SmsPreset {
  final String title;
  final String text;
  final String tag;

  const SmsPreset({
    required this.title,
    required this.text,
    required this.tag,
  });
}

/// Controller managing the state and operations of the SMS Protection screen.
class SmsProtectionController extends ChangeNotifier {
  final SmsScamAnalysisService _service;
  final TextEditingController textController = TextEditingController();

  bool _isAnalyzing = false;
  SmsAnalysisResult? _currentResult;
  String? _errorMessage;
  CallHistoryRecord? _savedRecord;

  SmsProtectionController({
    SmsScamAnalysisService? service,
  }) : _service = service ?? SmsScamAnalysisService.instance;

  bool get isAnalyzing => _isAnalyzing;
  SmsAnalysisResult? get currentResult => _currentResult;
  String? get errorMessage => _errorMessage;
  CallHistoryRecord? get savedRecord => _savedRecord;
  bool get hasResult => _currentResult != null;

  /// High-yield test presets for demonstration and verification.
  static const List<SmsPreset> presets = [
    SmsPreset(
      title: 'Bank OTP Scam',
      tag: 'Critical Threat',
      text:
          'URGENT: Calling from the bank fraud department. Your account will be blocked within 10 minutes. Tell me the OTP immediately to prevent arrest.',
    ),
    SmsPreset(
      title: 'Package Delivery Link',
      tag: 'Suspicious Link',
      text:
          'USPS Notice: Your parcel delivery failed due to address issues. Urgent: click this link https://usps-redelivery-fees.com/pay to update immediately.',
    ),
    SmsPreset(
      title: 'Police / Legal Threat',
      tag: 'Digital Arrest',
      text:
          'Police investigation notice: Legal action is registered against you. Your account will be blocked. Transfer money immediately via UPI payment to avoid arrest.',
    ),
    SmsPreset(
      title: 'Safe Appointment',
      tag: 'Safe Notification',
      text:
          'Reminder: Your appointment with Dr. Henderson is confirmed for tomorrow at 2:00 PM. Reschedule your appointment by calling the clinic. No payment or sensitive information is required.',
    ),
    SmsPreset(
      title: 'Safe Family Text',
      tag: 'Routine Message',
      text:
          'Hi Grandma! Just checking in to see if you need anything from the grocery store today. See you tonight at 6 PM!',
    ),
  ];

  /// Loads a sample preset text into the editor.
  void loadPreset(String text) {
    textController.text = text;
    _errorMessage = null;
    _currentResult = null;
    _savedRecord = null;
    notifyListeners();
  }

  /// Evaluates the current text in [textController] and persists the assessment.
  Future<void> analyze() async {
    final text = textController.text;
    if (text.trim().isEmpty) {
      _errorMessage = 'Please enter or paste message text to analyze.';
      _currentResult = null;
      notifyListeners();
      return;
    }

    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.analyzeMessage(text);
      _currentResult = result;
      _savedRecord = await _service.saveToHistory(result);
    } on SmsEmptyMessageException catch (e) {
      _errorMessage = e.message;
      _currentResult = null;
    } catch (e) {
      _errorMessage = 'Analysis error: $e';
      _currentResult = null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Clears the message text and active analysis result.
  void clear() {
    textController.clear();
    _currentResult = null;
    _errorMessage = null;
    _savedRecord = null;
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}
