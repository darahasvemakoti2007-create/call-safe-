import '../../core/widgets/risk_badge.dart';
import 'demo_scenario.dart';

/// Predefined repository of simulated demonstration scenarios.
class DemoScenarios {
  static const List<DemoScenario> all = [
    // Scenario 1: Fake KYC
    DemoScenario(
      id: 'fake_kyc',
      title: 'Fake KYC Update',
      shortDescription: 'Caller impersonates a bank official threatening account closure without OTP verification.',
      category: 'Banking Impersonation',
      callerRole: 'Fake Bank Representative',
      expectedRiskLevel: RiskLevel.critical,
      expectedSignals: [
        'Authority Impersonation',
        'Urgency',
        'Threat',
        'Sensitive Information Request',
      ],
      conversationLines: [
        ConversationLine(
          speaker: Speaker.caller,
          text: "I'm calling from your bank.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Hello? Which department is this?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your KYC expires today.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "I thought I updated my documents last month.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "If you don't complete it within 10 minutes, your account will be blocked.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Oh no, I need my account for pension payments! How do I fix it?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please tell me the OTP you just received.",
        ),
      ],
    ),

    // Scenario 2: Digital Arrest
    DemoScenario(
      id: 'digital_arrest',
      title: 'Digital Arrest Threat',
      shortDescription: 'Caller claims to be law enforcement demanding isolation and proof of identity payment.',
      category: 'Law Enforcement Fraud',
      callerRole: 'Fake Police Inspector',
      expectedRiskLevel: RiskLevel.critical,
      expectedSignals: [
        'Authority Impersonation',
        'Fear / Threat',
        'Isolation',
        'Financial Pressure',
        'Urgency',
      ],
      conversationLines: [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is a police investigation.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Police? What is this regarding?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your identity has been linked to a serious case.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "There must be a mistake! I haven't done anything wrong.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "You must stay on this call.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Do not tell your family.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "I'm getting scared, can I call my lawyer?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Transfer the requested money to prove your identity.",
        ),
      ],
    ),

    // Scenario 3: Grandchild Emergency
    DemoScenario(
      id: 'grandchild_emergency',
      title: 'Grandchild Emergency',
      shortDescription: 'Caller fabricates a distress scenario claiming hospital bills and urgent UPI payment.',
      category: 'Family Distress Phishing',
      callerRole: 'Impersonating Grandchild',
      expectedRiskLevel: RiskLevel.high,
      expectedSignals: [
        'Emotional Manipulation',
        'Urgency',
        'Financial Pressure',
        'Isolation',
        'Suspicious Payment Request',
      ],
      conversationLines: [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Grandma, I need your help.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Jamie? Is that you? Your voice sounds different.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "I had an accident.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "I'm at the hospital and I need money immediately.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Good heavens! Are your mom and dad with you?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please don't call my parents yet.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Send the money to this UPI ID.",
        ),
      ],
    ),

    // Scenario 4: Genuine Bank
    DemoScenario(
      id: 'genuine_bank',
      title: 'Legitimate Bank Alert',
      shortDescription: 'Genuine verification call directing the user to official channels with zero credential requests.',
      category: 'Routine Banking',
      callerRole: 'Bank Fraud Protection Service',
      expectedRiskLevel: RiskLevel.safe,
      expectedSignals: [],
      conversationLines: [
        ConversationLine(
          speaker: Speaker.caller,
          text: "We detected an unusual transaction on your account.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Did someone try to use my debit card?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "For your security, we will never ask for your OTP, PIN, CVV, or password.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please contact the official bank number printed on your card.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Thank you for letting me know. How do I lock it right now?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "We can help you block the card through the official banking app.",
        ),
      ],
    ),

    // Scenario 5: Genuine Hospital
    DemoScenario(
      id: 'genuine_hospital',
      title: 'Hospital Appointment Reschedule',
      shortDescription: 'Routine clinic rescheduling call requiring no payment or sensitive personal information.',
      category: 'Healthcare Service',
      callerRole: 'Hospital Clinic Receptionist',
      expectedRiskLevel: RiskLevel.safe,
      expectedSignals: [],
      conversationLines: [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Hello, I'm calling from the hospital.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "Hello, yes? I have an appointment with Dr. Robert tomorrow.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your appointment needs to be moved because the doctor has an emergency.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "We can reschedule your appointment for tomorrow.",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "That works for me. Do I need to pay any rescheduling fee?",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "No payment or sensitive information is required on this call.",
        ),
      ],
    ),
  ];

  /// Additional scenarios prepared for hackathon competition evaluations.
  static const List<DemoScenario> organizerScenarios = [
    hinglishDigitalArrest,
    midcallPivot,
  ];

  /// Combined list of all core and extended competition scenarios.
  static List<DemoScenario> get allWithExtended => [...all, ...organizerScenarios];

  // Scenario 6: Hinglish Digital Arrest (Multilingual Code-Mixed)
  static const DemoScenario hinglishDigitalArrest = DemoScenario(
    id: 'hinglish_digital_arrest',
    title: 'Digital Arrest (Hinglish)',
    shortDescription: 'Code-mixed Hindi-English extortion claiming illegal customs parcel and demanding immediate UPI fine.',
    category: 'Indian Law Enforcement Fraud',
    callerRole: 'Fake Cyber Cell Officer',
    expectedRiskLevel: RiskLevel.critical,
    expectedSignals: [
      'Authority Impersonation',
      'Fear / Threat',
      'Isolation',
      'Financial Pressure',
      'Urgency',
    ],
    conversationLines: [
      ConversationLine(
        speaker: Speaker.caller,
        text: "Hello, this is Inspector Rathore from Mumbai Crime Branch and Cyber Cell. Aapke Aadhar card par illegal parcel pakda gaya hai.",
      ),
      ConversationLine(
        speaker: Speaker.user,
        text: "Kya? Kaunsa parcel? Maine kuch nahi bheja.",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Parcel mein drugs aur fake passports hain. Aapke khilaf non-bailable arrest warrant issue ho gaya hai.",
      ),
      ConversationLine(
        speaker: Speaker.user,
        text: "Yeh galat hai sir! Main 68 saal ka retired pensioner hoon.",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Aap digital arrest mein hain. Phone disconnect mat karna aur kisi ko mat batana.",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Verification ke liye safe account mein transfer karo turant paise via UPI, nahi toh police bhej rahe hain.",
      ),
    ],
  );

  // Scenario 7: Mid-Call Pivot (Small Talk into Scam)
  static const DemoScenario midcallPivot = DemoScenario(
    id: 'midcall_pivot_scam',
    title: 'Mid-Call Pivot (Small Talk to Scam)',
    shortDescription: 'Starts as casual friendly neighborhood check-in and escalates into urgent account freeze and OTP harvesting.',
    category: 'Conversational Social Engineering',
    callerRole: 'Neighborhood committee imposter pivoting to Bank Caller',
    expectedRiskLevel: RiskLevel.critical,
    expectedSignals: [
      'Authority Impersonation',
      'Urgency',
      'Sensitive Information Request',
      'Threat',
    ],
    conversationLines: [
      ConversationLine(
        speaker: Speaker.caller,
        text: "Namaste Uncle ji, how are you feeling today? Weather has been so pleasant this week.",
      ),
      ConversationLine(
        speaker: Speaker.user,
        text: "Yes, beta, I was just doing some gardening. Who is speaking?",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Uncle, remember Ramesh from the society committee? I was talking with him about the upcoming festival arrangements.",
      ),
      ConversationLine(
        speaker: Speaker.user,
        text: "Ah, Ramesh! Yes, good to hear from you.",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Uncle, actually I am calling because the society bank portal is freezing all senior accounts today.",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "If we don't complete your verification right now, your account will be blocked within 30 minutes.",
      ),
      ConversationLine(
        speaker: Speaker.user,
        text: "Oh dear, my pension account? What do I need to do?",
      ),
      ConversationLine(
        speaker: Speaker.caller,
        text: "Please tell me the OTP you just received so we can clear your account right now.",
      ),
    ],
  );
}
