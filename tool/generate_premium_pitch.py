import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def build_premium_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # ========================================================
    # BESPOKE PALETTE: "GUARDIAN GOLD & CYBER SHIELD"
    # Combines Executive Trust (Gold/Amber) + Cyber AI (Teal/Emerald)
    # ========================================================
    BG_DARK = RGBColor(7, 10, 19)          # #070A13 Deep Obsidian
    CARD_BG = RGBColor(16, 24, 40)         # #101828 Rich Slate Container
    CARD_BG_LIGHT = RGBColor(23, 34, 56)   # #172238 Elevated Card Fill
    BORDER_DEFAULT = RGBColor(38, 51, 77)  # #26334D Subtle Outline

    # Distinct Accents
    GOLD_MAIN = RGBColor(245, 158, 11)     # #F59E0B Warm Guardian Gold
    GOLD_LIGHT = RGBColor(252, 211, 77)    # #FCD34D Champagne Shimmer
    TEAL_CYBER = RGBColor(20, 184, 166)    # #14B8A6 Electric Cyber Teal
    EMERALD_SAFE = RGBColor(16, 185, 129)  # #10B981 Verified Safe Jade
    ROSE_ALERT = RGBColor(225, 29, 72)     # #E11D48 Critical Threat Coral
    AMBER_WARN = RGBColor(249, 115, 22)    # #F97316 Suspicious Warning

    # Text Colors
    TEXT_WHITE = RGBColor(255, 255, 255)
    TEXT_OFFWHITE = RGBColor(241, 245, 249)
    TEXT_MUTED = RGBColor(156, 163, 175)
    TEXT_GOLD = RGBColor(254, 243, 199)

    def set_bg(slide):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = BG_DARK
        bg.line.fill.background()
        return bg

    def add_top_bar(slide, category, title, subtitle=None, accent_color=GOLD_MAIN):
        # Category Tag Badge (Pill)
        pill = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.38), Inches(3.2), Inches(0.32))
        pill.fill.solid()
        pill.fill.fore_color.rgb = CARD_BG_LIGHT
        pill.line.color.rgb = accent_color
        pill.line.width = Pt(1.2)
        ptf = pill.text_frame
        ptf.margin_left = ptf.margin_top = ptf.margin_right = ptf.margin_bottom = 0
        pp = ptf.paragraphs[0]
        pp.text = f"  ✦  {category.upper()}  ✦"
        pp.font.size = Pt(10.5)
        pp.font.bold = True
        pp.font.color.rgb = accent_color
        pp.alignment = PP_ALIGN.CENTER

        # Main Title
        tb = slide.shapes.add_textbox(Inches(0.8), Inches(0.78), Inches(11.7), Inches(0.65))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(25)
        p.font.bold = True
        p.font.color.rgb = TEXT_WHITE

        # Accent Line under title
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(1.48), Inches(2.2), Inches(0.04))
        line.fill.solid()
        line.fill.fore_color.rgb = accent_color
        line.line.fill.background()

        if subtitle:
            sb = slide.shapes.add_textbox(Inches(3.2), Inches(1.36), Inches(9.3), Inches(0.4))
            stf = sb.text_frame
            stf.word_wrap = True
            stf.margin_left = stf.margin_top = stf.margin_right = stf.margin_bottom = 0
            sp = stf.paragraphs[0]
            sp.text = subtitle
            sp.font.size = Pt(13)
            sp.font.color.rgb = TEXT_MUTED

    def create_card(slide, left, top, width, height, title, items=None, accent_bar_color=GOLD_MAIN, stat_num=None, stat_label=None):
        # Card Background
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        card.fill.solid()
        card.fill.fore_color.rgb = CARD_BG
        card.line.color.rgb = BORDER_DEFAULT
        card.line.width = Pt(1.2)

        # Top Highlight Border (Simulating premium glassmorphism top glow)
        top_bar = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, Inches(0.07))
        top_bar.fill.solid()
        top_bar.fill.fore_color.rgb = accent_bar_color
        top_bar.line.fill.background()

        content_top = top + Inches(0.2)
        content_height = height - Inches(0.3)

        # Optional Stat Callout at top of card
        if stat_num:
            stat_box = slide.shapes.add_textbox(left + Inches(0.25), content_top, width - Inches(0.5), Inches(0.75))
            stf = stat_box.text_frame
            stf.word_wrap = True
            stf.margin_left = stf.margin_top = stf.margin_right = stf.margin_bottom = 0
            sp1 = stf.paragraphs[0]
            sp1.text = stat_num
            sp1.font.size = Pt(28)
            sp1.font.bold = True
            sp1.font.color.rgb = accent_bar_color

            if stat_label:
                sp2 = stf.add_paragraph()
                sp2.text = stat_label.upper()
                sp2.font.size = Pt(9.5)
                sp2.font.bold = True
                sp2.font.color.rgb = TEXT_MUTED

            content_top += Inches(0.8)
            content_height -= Inches(0.8)

        tb = slide.shapes.add_textbox(left + Inches(0.25), content_top, width - Inches(0.5), content_height)
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        if title:
            p0 = tf.paragraphs[0]
            p0.text = title
            p0.font.size = Pt(15)
            p0.font.bold = True
            p0.font.color.rgb = TEXT_WHITE
            p0.space_after = Pt(8)

        if items:
            for i, it in enumerate(items):
                p = tf.add_paragraph() if (title or i > 0) else tf.paragraphs[0]
                p.text = it
                p.font.size = Pt(11.5)
                p.font.color.rgb = TEXT_OFFWHITE if it.startswith("•") or it.startswith("  ") else GOLD_LIGHT
                p.space_after = Pt(5)

        return card

    def add_notes(slide, text):
        slide.notes_slide.notes_text_frame.text = text

    # ========================================================
    # SLIDE 1: Title & Hero
    # ========================================================
    s1 = prs.slides.add_slide(blank_layout)
    set_bg(s1)

    # Decorative ambient glow shape on top left
    glow = s1.shapes.add_shape(MSO_SHAPE.OVAL, Inches(0.5), Inches(0.8), Inches(4.5), Inches(4.5))
    glow.fill.solid()
    glow.fill.fore_color.rgb = RGBColor(15, 23, 42)
    glow.line.fill.background()

    # Hero Text Block
    hb = s1.shapes.add_textbox(Inches(0.9), Inches(1.3), Inches(7.5), Inches(5.2))
    htf = hb.text_frame
    htf.word_wrap = True
    htf.margin_left = htf.margin_top = htf.margin_right = htf.margin_bottom = 0

    p_badge = htf.paragraphs[0]
    p_badge.text = "✦  HACKATHON INNOVATION TRACK: CYBER DEFENSE & SOCIAL IMPACT  ✦"
    p_badge.font.size = Pt(11)
    p_badge.font.bold = True
    p_badge.font.color.rgb = GOLD_MAIN
    p_badge.space_after = Pt(10)

    p_name = htf.add_paragraph()
    p_name.text = "GuardCall"
    p_name.font.size = Pt(46)
    p_name.font.bold = True
    p_name.font.color.rgb = TEXT_WHITE
    p_name.space_after = Pt(4)

    p_tag = htf.add_paragraph()
    p_tag.text = "The AI Phone Scam Shield for Vulnerable Seniors"
    p_tag.font.size = Pt(22)
    p_tag.font.bold = True
    p_tag.font.color.rgb = TEAL_CYBER
    p_tag.space_after = Pt(14)

    p_desc = htf.add_paragraph()
    p_desc.text = "Shifting scam defense from easily-spoofed Caller IDs to real-time psychological manipulation detection. Built with zero audio retention, zero transcript storage, and instant family escalation."
    p_desc.font.size = Pt(14)
    p_desc.font.color.rgb = TEXT_MUTED
    p_desc.space_after = Pt(22)

    # 4 Key Value Pillars (Grid of compact badges)
    pillars = [
        ("🔒 Zero-Audio Privacy", "Transient RAM analysis only"),
        ("🧠 Psychological Detection", "Urgency, threats & OTP requests"),
        ("👨‍👩‍👧 Family Circle Escalation", "Relays telemetry, never audio"),
        ("⚡ 100% Offline Demo Engine", "Deterministic judging execution")
    ]
    for icon_title, sub in pillars:
        pp = htf.add_paragraph()
        pp.text = f"{icon_title}  —  {sub}"
        pp.font.size = Pt(12)
        pp.font.bold = True
        pp.font.color.rgb = GOLD_LIGHT
        pp.space_after = Pt(6)

    # Hero Image Card on Right
    if os.path.exists("step19_home_ready.png"):
        img_card = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.7), Inches(0.9), Inches(3.8), Inches(5.8))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = CARD_BG
        img_card.line.color.rgb = GOLD_MAIN
        img_card.line.width = Pt(1.5)
        s1.shapes.add_picture("step19_home_ready.png", Inches(8.85), Inches(1.05), width=Inches(3.5))

    add_notes(s1, "Every 15 seconds, a senior is targeted by a phone scammer. Traditional spam blockers check caller IDs, but scammers spoof numbers in seconds. We built GuardCall: the first real-time conversational scam shield that protects seniors while preserving 100% privacy.")

    # ========================================================
    # SLIDE 2: The Problem (According to the PS)
    # ========================================================
    s2 = prs.slides.add_slide(blank_layout)
    set_bg(s2)
    add_top_bar(s2, "Problem Statement", "The Crisis: Psychological Manipulation Traps the Vulnerable",
                "Scammers do not hack phone operating systems—they hack human emotion and fear.", ROSE_ALERT)

    create_card(s2, Inches(0.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Devastating Financial Extortion",
                [
                    "• Digital Arrest & Fake KYC scams siphon billions globally.",
                    "• High-stress authority impersonation (Police, CBI, RBI, Customs).",
                    "• Victims' lifetime retirement savings drained in a single 15-minute call."
                ],
                ROSE_ALERT, "$10B+", "Global Annual Phone Fraud")

    create_card(s2, Inches(4.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Cognitive Overload on Seniors",
                [
                    "• Artificial Urgency: 'Your account will be terminated in 10 minutes!'",
                    "• Scammers weaponize legal threats to paralyze critical thinking.",
                    "• Elders living independently have zero real-time guidance when under duress."
                ],
                AMBER_WARN, "70%+", "Victims Are Elderly Citizens")

    create_card(s2, Inches(8.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Enforced Social Isolation",
                [
                    "• The Scammer's Rule: 'Stay on the line. Do not hang up or consult your children.'",
                    "• Victims are strictly isolated from their protective family circle.",
                    "• No existing tool offers a safe bridge to alert loved ones mid-call."
                ],
                GOLD_MAIN, "100%", "Isolated During Attack")

    add_notes(s2, "Scammers no longer rely on simple phishing links. They call victims directly, impersonate law enforcement, and induce severe panic. The senior is trapped alone on the call, isolated from their loved ones, until their money is transferred.")

    # ========================================================
    # SLIDE 3: Why Current Defenses Fail
    # ========================================================
    s3 = prs.slides.add_slide(blank_layout)
    set_bg(s3)
    add_top_bar(s3, "Competitive Deficit", "Why Status-Quo Solutions Consistently Fail",
                "Static phone number lookups and cloud recorders cannot defend against live social engineering.", AMBER_WARN)

    create_card(s3, Inches(0.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Static Caller ID Blacklists",
                [
                    "• Apps like Truecaller rely on crowdsourced spam reports.",
                    "• Ineffective against spoofed VoIP numbers and freshly bought SIMs.",
                    "• The first dozens of victims are defrauded before any number is marked as spam."
                ],
                ROSE_ALERT, "LATE", "Crowdsource Lag")

    create_card(s3, Inches(4.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Post-Mortem Bank Alerts",
                [
                    "• SMS transaction alerts arrive after the funds have already left the account.",
                    "• Scammers pressure victims to disclose OTPs within 60 seconds.",
                    "• Reactive bank account freezes cannot reverse instant wire transfers."
                ],
                AMBER_WARN, "POST", "Damage Already Done")

    create_card(s3, Inches(8.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Cloud Recording Privacy Risks",
                [
                    "• Recording call audio violates wiretapping laws and user dignity.",
                    "• Uploading conversation audio to cloud servers creates massive privacy risks.",
                    "• Seniors refuse surveillance tools that eavesdrop on personal family calls."
                ],
                TEAL_CYBER, "RISKY", "Privacy & Legal Violations")

    add_notes(s3, "Number-lookup apps only flag scammers after victims have already lost money. And recording phone calls to cloud servers creates massive privacy violations. We need a solution that analyzes conversational intent in real time without recording private audio.")

    # ========================================================
    # SLIDE 4: Proposed Solution
    # ========================================================
    s4 = prs.slides.add_slide(blank_layout)
    set_bg(s4)
    add_top_bar(s4, "Proposed Solution", "GuardCall: Behavioral Scam Shield & Caregiver Circle",
                "Flipping defense from 'Who is calling?' to 'What are they psychologically attempting to do?'", TEAL_CYBER)

    create_card(s4, Inches(0.8), Inches(2.2), Inches(7.5), Inches(4.6),
                "Core Innovations",
                [
                    "1. Real-Time Psychological Signal Detection:",
                    "   Detects authority impersonation, artificial urgency, coercion, and OTP/credential requests.",
                    "",
                    "2. Accessible Heads-Up Senior Intervention:",
                    "   Surfaces prominent, high-contrast warning cards with 1-tap 'END CALL' or 'ALERT FAMILY' actions.",
                    "",
                    "3. Zero-Audio Privacy Architecture:",
                    "   Audio streams are processed transiently in device RAM; zero audio or conversation transcripts are ever saved.",
                    "",
                    "4. Caregiver Telemetry Escalation:",
                    "   Transmits mathematical risk scores and threat tags to loved ones without exposing personal conversations.",
                    "",
                    "5. False-Positive Immunity Filter:",
                    "   Recognizes legitimate bank advisories ('We never ask for your OTP') and maintains 0/100 Safe score."
                ],
                TEAL_CYBER)

    if os.path.exists("sample_alert_detail.png"):
        img_card = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.7), Inches(1.8), Inches(3.8), Inches(5.0))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = CARD_BG
        img_card.line.color.rgb = TEAL_CYBER
        img_card.line.width = Pt(1.5)
        s4.shapes.add_picture("sample_alert_detail.png", Inches(8.85), Inches(1.95), width=Inches(3.5))

    add_notes(s4, "GuardCall acts like an intelligent guardian sitting right beside the senior. It listens to conversational tactics—urgency, threats, OTP demands—and displays clear, easy-to-read interventions, allowing the elder to end the call or immediately escalate to their family.")

    # ========================================================
    # SLIDE 5: Architecture & Pipeline
    # ========================================================
    s5 = prs.slides.add_slide(blank_layout)
    set_bg(s5)
    add_top_bar(s5, "System Architecture", "Transient Speech Intelligence Pipeline",
                "Strict decoupling of speech processing, threat intelligence, and user presentation.", GOLD_MAIN)

    create_card(s5, Inches(0.8), Inches(2.2), Inches(3.6), Inches(2.2),
                "1. Transient Audio Ingestion",
                [
                    "• Ingests transient audio chunks in device RAM.",
                    "• Zero raw audio files written to filesystem.",
                    "• Strict Android telephony boundary compliance."
                ], TEAL_CYBER)

    create_card(s5, Inches(4.8), Inches(2.2), Inches(3.6), Inches(2.2),
                "2. Streaming Speech-to-Text",
                [
                    "• Abstracted SpeechToTextService layer.",
                    "• Converts dialogue into transient conversation lines.",
                    "• In-memory buffer flushed after risk computation."
                ], TEAL_CYBER)

    create_card(s5, Inches(8.8), Inches(2.2), Inches(3.6), Inches(2.2),
                "3. Scam Detection Engine",
                [
                    "• Multi-turn heuristic rule & pattern engine.",
                    "• Identifies sequence escalation across turns.",
                    "• Protective banking context rules prevent false alarms."
                ], GOLD_MAIN)

    create_card(s5, Inches(0.8), Inches(4.7), Inches(5.6), Inches(2.2),
                "4. Canonical 4-Tier Risk Model (0–100)",
                [
                    "• 0–39   SAFE: Normal conversation (No action)",
                    "• 40–70  SUSPICIOUS: Ambient awareness badge",
                    "• 71–84  HIGH RISK: Senior Warning HUD dialog triggered",
                    "• 85–100 CRITICAL THREAT: Emergency alert & vibration"
                ], AMBER_WARN)

    create_card(s5, Inches(6.8), Inches(4.7), Inches(5.6), Inches(2.2),
                "5. Dual-Action Protection Response",
                [
                    "• Senior HUD: Direct high-contrast 'END CALL' safety exit.",
                    "• Family Escalation: Dispatches structured threat metadata.",
                    "• Zero transcripts shared; zero audio recorded."
                ], EMERALD_SAFE)

    add_notes(s5, "Our pipeline feeds transient audio chunks through speech recognition directly into a multi-turn heuristic engine. When compounding threats like urgency and OTP requests occur in sequence, the risk score surges past threshold, instantly triggering intervention dialogues.")

    # ========================================================
    # SLIDE 6: Live Demo & Scenarios
    # ========================================================
    s6 = prs.slides.add_slide(blank_layout)
    set_bg(s6)
    add_top_bar(s6, "Evaluator Demo Center", "100% Deterministic Offline Demo Engine",
                "Evaluators can immediately test realistic scams with zero network latency and zero cloud credentials.", EMERALD_SAFE)

    create_card(s6, Inches(0.8), Inches(2.2), Inches(7.5), Inches(4.6),
                "5 Scripted Multi-Turn Evaluation Scenarios",
                [
                    "1. Fake KYC Update (Banking Impersonation — HIGH RISK):",
                    "   Turn 1: Bank claim (10 Safe) ➔ Turn 2: Urgency ('Expires today') ➔ Turn 3: Threat ➔ Turn 4: OTP demand ➔ Surges to 75 / 100 High Risk.",
                    "",
                    "2. Digital Arrest Threat (Law Enforcement — CRITICAL THREAT):",
                    "   Impersonating CBI/Police claiming illegal parcel. Demands secret video interrogation ➔ Surges to 90 / 100 Critical Threat.",
                    "",
                    "3. Grandchild Emergency (Distress Phishing — HIGH RISK):",
                    "   Fabricates road accident emergency demanding urgent UPI hospital deposit.",
                    "",
                    "4. Legitimate Bank Alert (BENCHMARK — 0/100 SAFE):",
                    "   Bank advises: 'We never ask for your OTP/PIN/password' ➔ Stays firmly at 0/100 Safe (Proves zero false positives).",
                    "",
                    "5. Hospital Appointment Reschedule: Routine clinical call ➔ 0/100 Safe."
                ],
                EMERALD_SAFE)

    if os.path.exists("sample_2_scenarios.png"):
        img_card = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.7), Inches(1.8), Inches(3.8), Inches(5.0))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = CARD_BG
        img_card.line.color.rgb = EMERALD_SAFE
        img_card.line.width = Pt(1.5)
        s6.shapes.add_picture("sample_2_scenarios.png", Inches(8.85), Inches(1.95), width=Inches(3.5))

    add_notes(s6, "To prove reliability, we built a deterministic Demo Center with 5 diverse scenarios. In the KYC demo, notice how caller urgency elevates the risk to 75, triggering the intervention dialog. And crucially, legitimate bank calls remain at 0/100, proving zero false positives.")

    # ========================================================
    # SLIDE 7: Privacy by Design & Caregiver Boundary
    # ========================================================
    s7 = prs.slides.add_slide(blank_layout)
    set_bg(s7)
    add_top_bar(s7, "Privacy & Ethics Boundary", "Privacy by Design: Zero Audio, Zero Transcripts",
                "Safeguarding senior citizens from financial fraud without sacrificing personal dignity.", GOLD_MAIN)

    create_card(s7, Inches(0.8), Inches(2.2), Inches(4.3), Inches(4.6),
                "Protected Privacy Guarantees",
                [
                    "🔒 ZERO Audio Recorded or Shared:",
                    "   Microphone audio is transient in RAM only. Zero recordings on disk or cloud.",
                    "",
                    "🔒 ZERO Full Conversation Transcripts:",
                    "   Spoken words and personal dialogue are NEVER delivered to caregivers.",
                    "",
                    "🔒 ZERO Credential / PII Storage:",
                    "   OTPs, card digits, or passwords spoken are automatically scrubbed by AppLogger.",
                    "",
                    "🤝 Strict Mutual Dual Authorization:",
                    "   Caregivers must be explicitly invited and authenticated before receiving alerts."
                ],
                ROSE_ALERT)

    create_card(s7, Inches(5.4), Inches(2.2), Inches(4.0), Inches(4.6),
                "Structured Telemetry Only",
                [
                    "🛡️ Mathematical Threat Score:",
                    "   e.g. Risk Score: 75/100 (High Risk).",
                    "",
                    "🏷️ Behavioral Manipulation Tags:",
                    "   ['Authority Impersonation', 'Urgency', 'OTP Solicitation'].",
                    "",
                    "💡 Safe Actionable Recommendations:",
                    "   'Contact your parent immediately. Confirm they did not share banking OTPs.'",
                    "",
                    "✅ Senior Intervention Action:",
                    "   Logged: 'User selected End Call'."
                ],
                EMERALD_SAFE)

    if os.path.exists("sample_caregiver_view.png"):
        img_card = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(9.7), Inches(1.8), Inches(2.8), Inches(5.0))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = CARD_BG
        img_card.line.color.rgb = GOLD_MAIN
        img_card.line.width = Pt(1.5)
        s7.shapes.add_picture("sample_caregiver_view.png", Inches(9.8), Inches(1.95), width=Inches(2.6))

    add_notes(s7, "Privacy is our core architectural pillar. Caregivers never hear the conversation or read personal transcripts. They receive only structured threat metadata: the risk score, the detected signals, and the action taken.")

    # ========================================================
    # SLIDE 8: Technical Stack & Engineering Rigor
    # ========================================================
    s8 = prs.slides.add_slide(blank_layout)
    set_bg(s8)
    add_top_bar(s8, "Engineering Excellence", "Production-Hardened Mobile Tech Stack",
                "Engineered with clean layered architecture, accessible UI, and 223 automated tests.", TEAL_CYBER)

    create_card(s8, Inches(0.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Mobile Client (Frontend)",
                [
                    "• Framework: Flutter 3.x / Dart 3.x (Material 3).",
                    "• Elderly Accessibility: Large touch targets (48dp+), high-contrast badges.",
                    "• Native Reduce Motion: Disables pulsing glows for sensitive users.",
                    "• Custom Primitives: GlassCard, RiskBadge, AuthGate.",
                    "• Zero dangerous runtime permissions in AndroidManifest.xml."
                ],
                TEAL_CYBER, "FLUTTER", "Cross-Platform Client")

    create_card(s8, Inches(4.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "AI & Detection Pipeline",
                [
                    "• 3 Interchangeable Engine Modes:",
                    "  1. Offline Mock: 100% in-memory heuristic sequence engine.",
                    "  2. Edge Function Proxy: Supabase Edge Functions keeping API keys server-side.",
                    "  3. Direct Dev Mode: Gemini 1.5 Flash / GPT-4o-mini testing.",
                    "• Transient audio transcription abstraction.",
                    "• AppLogger automated credential scrubbing."
                ],
                GOLD_MAIN, "MODULAR", "3 Detection Modes")

    create_card(s8, Inches(8.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Backend & Quality Assurance",
                [
                    "• Backend: Supabase Auth, PostgreSQL, Row-Level Security (RLS).",
                    "• Provider-Neutral NotificationService: Pre-architected for FCM/APNs/SMS.",
                    "• Test Rigor: 223 / 223 automated unit, widget, and domain tests passing.",
                    "• Responsive mobile layout preventing horizontal overflow."
                ],
                EMERALD_SAFE, "223 / 223", "Automated Tests Passing")

    add_notes(s8, "Built with Flutter for smooth cross-platform delivery and Supabase for secure cloud synchronization. Our engine is completely modular, and our entire pipeline is backed by 223 passing automated tests.")

    # ========================================================
    # SLIDE 9: Viability & Future Roadmap
    # ========================================================
    s9 = prs.slides.add_slide(blank_layout)
    set_bg(s9)
    add_top_bar(s9, "Growth & Strategy", "Commercial Viability & Multi-Phase Roadmap",
                "Navigating operating system telephony boundaries to nationwide consumer protection.", GOLD_MAIN)

    create_card(s9, Inches(0.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Phase 1: Prototype (Today)",
                [
                    "• Flutter Android client prototype.",
                    "• 100% deterministic 5-scenario Demo Center.",
                    "• In-memory heuristic multi-turn engine.",
                    "• Privacy-first Caregiver Telemetry Circle.",
                    "• 223/223 automated tests passing.",
                    "• Complete privacy & architecture documentation."
                ],
                TEAL_CYBER, "TODAY", "Proven Hackathon MVP")

    create_card(s9, Inches(4.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Phase 2: On-Device SLMs",
                [
                    "• MediaPipe / ONNX quantization for on-device Small Language Models (SLMs).",
                    "• Zero-latency, 100% offline inference on mobile chips (NPU).",
                    "• Regional Indian language models: Hindi, Telugu, Tamil, Marathi.",
                    "• Synthetic voice clone detection algorithms."
                ],
                AMBER_WARN, "6-12 MOS", "Local Neural Inference")

    create_card(s9, Inches(8.8), Inches(2.2), Inches(3.6), Inches(4.6),
                "Phase 3: Telco Partnerships",
                [
                    "• Direct integration with telecom carriers (Airtel, Jio, etc.).",
                    "• Network-level audio stream analysis with carrier consent.",
                    "• Native dialer companion app integration.",
                    "• Automated 1-tap reporting to National Cybercrime Reporting Portal (NCRP 1930)."
                ],
                EMERALD_SAFE, "SCALE", "Nationwide Telecom Impact")

    add_notes(s9, "We engineered GuardCall with accessibility at the center, including native reduce-motion toggles. While we demonstrate this today with controlled audio inputs, our roadmap includes deploying lightweight on-device SLMs and partnering directly with telecom carriers.")

    # ========================================================
    # SLIDE 10: Conclusion & Call to Action
    # ========================================================
    s10 = prs.slides.add_slide(blank_layout)
    set_bg(s10)

    # Hero Box
    cb = s10.shapes.add_textbox(Inches(1.2), Inches(0.9), Inches(10.9), Inches(1.8))
    ctf = cb.text_frame
    ctf.word_wrap = True
    ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0

    cp1 = ctf.paragraphs[0]
    cp1.text = "GuardCall: Restoring Trust in Every Phone Call"
    cp1.font.size = Pt(32)
    cp1.font.bold = True
    cp1.font.color.rgb = GOLD_MAIN
    cp1.alignment = PP_ALIGN.CENTER

    cp2 = ctf.add_paragraph()
    cp2.text = "Elderly citizens deserve to stay connected without fear. Families deserve to live without anxiety."
    cp2.font.size = Pt(16)
    cp2.font.color.rgb = TEXT_MUTED
    cp2.alignment = PP_ALIGN.CENTER
    cp2.space_before = Pt(8)

    # 3 Summary Cards
    create_card(s10, Inches(1.2), Inches(2.8), Inches(3.3), Inches(2.8),
                "Proactive Shield",
                [
                    "Detects psychological coercion and manipulators before any money or credentials are lost."
                ],
                TEAL_CYBER, "INTENT", "Real-Time Detection")

    create_card(s10, Inches(5.0), Inches(2.8), Inches(3.3), Inches(2.8),
                "Uncompromising Privacy",
                [
                    "Zero audio recorded. Zero transcripts logged. Privacy by design with strict mutual consent."
                ],
                EMERALD_SAFE, "ZERO", "Audio Retention")

    create_card(s10, Inches(8.8), Inches(2.8), Inches(3.3), Inches(2.8),
                "Family Care Circle",
                [
                    "Bridges the isolation gap by relaying threat telemetry instantly to authorized caregivers."
                ],
                GOLD_MAIN, "TRUST", "Family Circle")

    # Bottom Call to Action Banner
    call_banner = s10.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(1.2), Inches(6.0), Inches(10.9), Inches(0.85))
    call_banner.fill.solid()
    call_banner.fill.fore_color.rgb = CARD_BG
    call_banner.line.color.rgb = GOLD_MAIN
    call_banner.line.width = Pt(1.5)

    cbtf = call_banner.text_frame
    cbtf.margin_left = cbtf.margin_top = cbtf.margin_right = cbtf.margin_bottom = 0
    cbp = cbtf.paragraphs[0]
    cbp.text = "✨ READY FOR LIVE DEMONSTRATION IN THE DEMO CENTER — THANK YOU! ✨"
    cbp.font.size = Pt(15)
    cbp.font.bold = True
    cbp.font.color.rgb = TEXT_WHITE
    cbp.alignment = PP_ALIGN.CENTER

    add_notes(s10, "GuardCall gives seniors the independence they deserve, and gives families peace of mind. Thank you, and we invite you to experience the live multi-turn simulation right now!")

    output_path = "GuardCall_Premium_Pitch.pptx"
    prs.save(output_path)
    print(f"Successfully generated Premium PowerPoint presentation at: {os.path.abspath(output_path)}")

if __name__ == "__main__":
    build_premium_deck()
