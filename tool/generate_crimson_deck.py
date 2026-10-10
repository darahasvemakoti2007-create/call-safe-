import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def build_crimson_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # ========================================================
    # EXACT REFERENCE COLOR PALETTE:
    # Deep Crimson Burgundy + Warm Sand/Ivory + Crisp White + Deep Slate
    # ========================================================
    CRIMSON = RGBColor(142, 28, 48)       # #8E1C30 (Signature Burgundy Red)
    CRIMSON_DARK = RGBColor(115, 20, 38)  # #731426 (Deep Wine)
    CRIMSON_LIGHT = RGBColor(180, 50, 72) # #B43248
    WARM_SAND = RGBColor(245, 243, 238)   # #F5F3EE (Editorial Off-White / Beige)
    PURE_WHITE = RGBColor(255, 255, 255)
    SLATE_NAVY = RGBColor(27, 38, 59)     # #1B263B (Deep Charcoal Slate from ref)
    SLATE_CARD = RGBColor(38, 53, 80)     # #263550
    TEXT_DARK = RGBColor(24, 30, 42)      # #181E2A (Rich Charcoal for readable text)
    TEXT_MUTED = RGBColor(107, 114, 128)  # #6B7280
    BORDER_LIGHT = RGBColor(226, 222, 213)
    PILL_BG = RGBColor(233, 229, 221)

    def set_slide_background(slide, color=WARM_SAND):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = color
        bg.line.fill.background()
        return bg

    def add_year_badge(slide, year="2026", color=SLATE_NAVY):
        badge = slide.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE, Inches(11.6), Inches(6.6), Inches(1.1), Inches(0.45)
        )
        badge.fill.solid()
        badge.fill.fore_color.rgb = PILL_BG
        badge.line.fill.background()
        tf = badge.text_frame
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = year
        p.font.size = Pt(13)
        p.font.bold = True
        p.font.color.rgb = color
        p.alignment = PP_ALIGN.CENTER

    def add_standard_header(slide, kicker, title, subtitle=None):
        # Kicker / Category
        kb = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.7), Inches(0.3))
        ktf = kb.text_frame
        ktf.word_wrap = True
        ktf.margin_left = ktf.margin_top = ktf.margin_right = ktf.margin_bottom = 0
        kp = ktf.paragraphs[0]
        kp.text = kicker.upper()
        kp.font.size = Pt(10.5)
        kp.font.bold = True
        kp.font.color.rgb = CRIMSON

        # Main Title
        tb = slide.shapes.add_textbox(Inches(0.8), Inches(0.7), Inches(11.7), Inches(0.6))
        ttf = tb.text_frame
        ttf.word_wrap = True
        ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0
        tp = ttf.paragraphs[0]
        tp.text = title
        tp.font.size = Pt(25)
        tp.font.bold = True
        tp.font.color.rgb = TEXT_DARK

        # Crimson accent line
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(1.35), Inches(1.8), Inches(0.04))
        line.fill.solid()
        line.fill.fore_color.rgb = CRIMSON
        line.line.fill.background()

        if subtitle:
            sb = slide.shapes.add_textbox(Inches(2.8), Inches(1.24), Inches(9.5), Inches(0.4))
            stf = sb.text_frame
            stf.word_wrap = True
            stf.margin_left = stf.margin_top = stf.margin_right = stf.margin_bottom = 0
            sp = stf.paragraphs[0]
            sp.text = subtitle
            sp.font.size = Pt(12.5)
            sp.font.color.rgb = TEXT_MUTED

    def add_notes(slide, notes):
        slide.notes_slide.notes_text_frame.text = notes

    # ========================================================
    # SLIDE 1: Title & Hero (Matches Ref: Corporate Presentation Slide 1)
    # ========================================================
    s1 = prs.slides.add_slide(blank_layout)
    set_slide_background(s1, PURE_WHITE)

    # Large Crimson Hero Panel with bottom-right rounded corner (Exact Reference match!)
    hero = s1.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.6), Inches(7.5), Inches(5.4)
    )
    hero.fill.solid()
    hero.fill.fore_color.rgb = CRIMSON
    hero.line.fill.background()

    htf = hero.text_frame
    htf.word_wrap = True
    htf.margin_left = Inches(0.6)
    htf.margin_top = Inches(0.6)
    htf.margin_right = Inches(0.6)

    hp0 = htf.paragraphs[0]
    hp0.text = "HACKATHON INNOVATION 2026"
    hp0.font.size = Pt(11)
    hp0.font.bold = True
    hp0.font.color.rgb = PURE_WHITE
    hp0.space_after = Pt(14)

    hp1 = htf.add_paragraph()
    hp1.text = "GUARDCALL"
    hp1.font.size = Pt(44)
    hp1.font.bold = True
    hp1.font.color.rgb = PURE_WHITE
    hp1.space_after = Pt(6)

    hp2 = htf.add_paragraph()
    hp2.text = "AI-Powered Phone Scam Shield"
    hp2.font.size = Pt(22)
    hp2.font.bold = True
    hp2.font.color.rgb = PURE_WHITE
    hp2.space_after = Pt(18)

    hp3 = htf.add_paragraph()
    hp3.text = "Real-time conversational manipulation defense for vulnerable seniors — engineered with zero audio retention, zero transcript storage, and proactive family escalation."
    hp3.font.size = Pt(13)
    hp3.font.color.rgb = PURE_WHITE
    hp3.space_after = Pt(20)

    hp4 = htf.add_paragraph()
    hp4.text = "✦ Zero-Audio Privacy  •  ✦ Behavioral Detection  •  ✦ 100% Offline Demo"
    hp4.font.size = Pt(12)
    hp4.font.bold = True
    hp4.font.color.rgb = WARM_SAND

    # Right Image Card with clean frame
    if os.path.exists("step19_home_ready.png"):
        img_card = s1.shapes.add_shape(
            MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.6), Inches(0.6), Inches(4.0), Inches(5.4)
        )
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = WARM_SAND
        img_card.line.color.rgb = BORDER_LIGHT
        img_card.line.width = Pt(1.5)
        s1.shapes.add_picture("step19_home_ready.png", Inches(8.8), Inches(0.8), width=Inches(3.6))

    add_year_badge(s1, "2026")
    add_notes(s1, "Every 15 seconds, a senior is targeted by a phone scammer. Traditional spam blockers check caller IDs, but scammers spoof numbers in seconds. We built GuardCall: the first real-time conversational scam shield that protects seniors while preserving 100% privacy.")

    # ========================================================
    # SLIDE 2: The Problem (Matches Ref: About Us / Chapter 01)
    # ========================================================
    s2 = prs.slides.add_slide(blank_layout)
    set_slide_background(s2, WARM_SAND)
    add_standard_header(s2, "Problem Statement", "The Crisis: Psychological Coercion Bypasses Firewalls",
                        "Scammers do not hack phone systems—they hack human fear, trust, and authority.")

    # 3 Distinct Problem Cards with Crimson Header Ribbons (Ref style!)
    cards_data = [
        ("01", "Devastating Financial Extortion", "$10B+", "Annual Global Losses", [
            "• Digital Arrest & Fake KYC scams siphon seniors' life savings in minutes.",
            "• Authority Impersonation: Callers pretend to be Police, CBI, or Bank Managers.",
            "• High cognitive overload prevents elders from verifying claims."
        ]),
        ("02", "Artificial Urgency & Coercion", "70%+", "Victims Are Elderly", [
            "• Scammers engineer acute panic: 'Your account is blocked in 10 minutes!'",
            "• Fear of arrest and legal penalty paralyses critical decision-making.",
            "• Independent elders have zero real-time guidance when under duress."
        ]),
        ("03", "Enforced Social Isolation", "100%", "Isolated During Call", [
            "• Scammer command: 'Stay on the line. Do not hang up or tell family.'",
            "• The victim is intentionally isolated from their support network.",
            "• Existing tools provide no safe mechanism to alert relatives mid-call."
        ])
    ]

    for i, (num, title, stat, stat_lbl, bullets) in enumerate(cards_data):
        left = Inches(0.8 + i * 4.0)
        # Main white card
        c = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(2.0), Inches(3.7), Inches(4.8))
        c.fill.solid()
        c.fill.fore_color.rgb = PURE_WHITE
        c.line.color.rgb = BORDER_LIGHT
        c.line.width = Pt(1.2)

        # Header Pill with number
        pill = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.3), Inches(2.3), Inches(0.8), Inches(0.45))
        pill.fill.solid()
        pill.fill.fore_color.rgb = CRIMSON
        pill.line.fill.background()
        ptf = pill.text_frame
        ptf.margin_left = ptf.margin_top = ptf.margin_right = ptf.margin_bottom = 0
        pp = ptf.paragraphs[0]
        pp.text = num
        pp.font.size = Pt(14)
        pp.font.bold = True
        pp.font.color.rgb = PURE_WHITE
        pp.alignment = PP_ALIGN.CENTER

        # Stat text
        stb = s2.shapes.add_textbox(left + Inches(1.3), Inches(2.2), Inches(2.1), Inches(0.65))
        stf = stb.text_frame
        stf.word_wrap = True
        stf.margin_left = stf.margin_top = stf.margin_right = stf.margin_bottom = 0
        sp1 = stf.paragraphs[0]
        sp1.text = stat
        sp1.font.size = Pt(20)
        sp1.font.bold = True
        sp1.font.color.rgb = CRIMSON
        sp2 = stf.add_paragraph()
        sp2.text = stat_lbl.upper()
        sp2.font.size = Pt(9)
        sp2.font.bold = True
        sp2.font.color.rgb = TEXT_MUTED

        # Card Title & Body
        tb = s2.shapes.add_textbox(left + Inches(0.3), Inches(3.0), Inches(3.1), Inches(3.6))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        p_t = tf.paragraphs[0]
        p_t.text = title
        p_t.font.size = Pt(14)
        p_t.font.bold = True
        p_t.font.color.rgb = TEXT_DARK
        p_t.space_after = Pt(10)

        for b in bullets:
            pb = tf.add_paragraph()
            pb.text = b
            pb.font.size = Pt(11)
            pb.font.color.rgb = TEXT_DARK
            pb.space_after = Pt(6)

    add_year_badge(s2, "2026")
    add_notes(s2, "Scammers no longer rely on simple phishing links. They call victims directly, impersonate law enforcement, and induce severe panic. The senior is trapped alone on the call, isolated from their loved ones, until their money is transferred.")

    # ========================================================
    # SLIDE 3: Status Quo Failures (Matches Ref: S.W.O.T. / Defenses)
    # ========================================================
    s3 = prs.slides.add_slide(blank_layout)
    set_slide_background(s3, WARM_SAND)
    add_standard_header(s3, "Market Gap", "Why Existing Defenses Consistently Fail",
                        "Static lookup databases and cloud recorders cannot protect seniors in real time.")

    gap_data = [
        ("01", "Caller ID Lookups (Truecaller)", "Crowdsource Lag",
         [
             "• Relies on historical user reports.",
             "• Completely blind to newly bought SIMs, VoIP spoofing, and virtual numbers.",
             "• First dozens of victims are defrauded before any number is flagged as spam."
         ]),
        ("02", "Post-Mortem Bank SMS Alerts", "Damage Already Done",
         [
             "• SMS arrives after the money has already left the account.",
             "• Victims are pressured to divulge OTPs within 60 seconds under duress.",
             "• Bank freezes cannot reverse instant UPI or cryptocurrency transfers."
         ]),
        ("03", "Cloud Audio Recorders", "Privacy & Legal Barrier",
         [
             "• Recording telephone calls violates two-party wiretapping consent laws.",
             "• Storing private audio on cloud servers creates severe liability risks.",
             "• Seniors refuse intrusive spyware that listens into personal family chats."
         ])
    ]

    for i, (num, title, subtitle, bullets) in enumerate(gap_data):
        left = Inches(0.8 + i * 4.0)
        c = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(2.0), Inches(3.7), Inches(4.8))
        c.fill.solid()
        c.fill.fore_color.rgb = PURE_WHITE
        c.line.color.rgb = BORDER_LIGHT
        c.line.width = Pt(1.2)

        # Slate header box for contrast
        top_hdr = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.25), Inches(2.25), Inches(3.2), Inches(0.85))
        top_hdr.fill.solid()
        top_hdr.fill.fore_color.rgb = SLATE_NAVY
        top_hdr.line.fill.background()

        htf = top_hdr.text_frame
        htf.margin_left = Inches(0.2)
        htf.margin_top = Inches(0.12)
        hp1 = htf.paragraphs[0]
        hp1.text = f"{num}  •  {subtitle.upper()}"
        hp1.font.size = Pt(9.5)
        hp1.font.bold = True
        hp1.font.color.rgb = WARM_SAND

        hp2 = htf.add_paragraph()
        hp2.text = title
        hp2.font.size = Pt(12)
        hp2.font.bold = True
        hp2.font.color.rgb = PURE_WHITE

        # Body bullets
        tb = s3.shapes.add_textbox(left + Inches(0.25), Inches(3.3), Inches(3.2), Inches(3.2))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        for b in bullets:
            pb = tf.add_paragraph()
            pb.text = b
            pb.font.size = Pt(11.5)
            pb.font.color.rgb = TEXT_DARK
            pb.space_after = Pt(8)

    add_year_badge(s3, "2026")
    add_notes(s3, "Number-lookup apps only flag scammers after victims have already lost money. And recording phone calls to cloud servers creates massive privacy violations. We need a solution that analyzes conversational intent in real time without recording private audio.")

    # ========================================================
    # SLIDE 4: Proposed Solution (Matches Ref: Services / Product Showcase)
    # ========================================================
    s4 = prs.slides.add_slide(blank_layout)
    set_slide_background(s4, WARM_SAND)

    # Top Crimson Banner (Ref style!)
    top_banner = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.6), Inches(11.7), Inches(1.3))
    top_banner.fill.solid()
    top_banner.fill.fore_color.rgb = CRIMSON
    top_banner.line.fill.background()

    btf = top_banner.text_frame
    btf.margin_left = Inches(0.4)
    btf.margin_top = Inches(0.2)
    bp0 = btf.paragraphs[0]
    bp0.text = "PROPOSED SOLUTION"
    bp0.font.size = Pt(10.5)
    bp0.font.bold = True
    bp0.font.color.rgb = WARM_SAND

    bp1 = btf.add_paragraph()
    bp1.text = "GuardCall: Behavioral Scam Detection & Caregiver Shield"
    bp1.font.size = Pt(22)
    bp1.font.bold = True
    bp1.font.color.rgb = PURE_WHITE

    # Left: White Card with Features
    feat_card = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(2.1), Inches(7.5), Inches(4.7))
    feat_card.fill.solid()
    feat_card.fill.fore_color.rgb = PURE_WHITE
    feat_card.line.color.rgb = BORDER_LIGHT
    feat_card.line.width = Pt(1.2)

    ftb = s4.shapes.add_textbox(Inches(1.1), Inches(2.3), Inches(6.9), Inches(4.3))
    ftf = ftb.text_frame
    ftf.word_wrap = True
    ftf.margin_left = ftf.margin_top = ftf.margin_right = ftf.margin_bottom = 0

    sol_bullets = [
        ("1. Real-Time Psychological Signal Detection", "Analyzes conversation dynamics (authority impersonation, urgency, coercion, OTP demands) rather than caller IDs."),
        ("2. Accessible Heads-Up Senior Intervention", "Prominent high-contrast warning dialog automatically interrupts coercive calls with 1-tap 'END CALL'."),
        ("3. Zero-Audio, Zero-Transcript Privacy", "Transient RAM analysis only. Audio is never recorded to disk; conversations are never stored or shared."),
        ("4. Proactive Family Circle Escalation", "Seniors can tap 'Alert Family' to send structured threat telemetry to authorized caregivers without sharing audio."),
        ("5. False-Positive Immunity Benchmark", "Distinguishes legitimate bank advisories ('We never ask for OTP') from fraud, preserving user trust.")
    ]

    for title, desc in sol_bullets:
        p_t = ftf.add_paragraph()
        p_t.text = title
        p_t.font.size = Pt(12.5)
        p_t.font.bold = True
        p_t.font.color.rgb = CRIMSON

        p_d = ftf.add_paragraph()
        p_d.text = desc
        p_d.font.size = Pt(11)
        p_d.font.color.rgb = TEXT_DARK
        p_d.space_after = Pt(6)

    # Right: Screenshot Card
    if os.path.exists("sample_alert_detail.png"):
        img_card = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.6), Inches(2.1), Inches(3.9), Inches(4.7))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = PURE_WHITE
        img_card.line.color.rgb = BORDER_LIGHT
        img_card.line.width = Pt(1.2)
        s4.shapes.add_picture("sample_alert_detail.png", Inches(8.75), Inches(2.25), width=Inches(3.6))

    add_year_badge(s4, "2026")
    add_notes(s4, "GuardCall acts like an intelligent guardian sitting right beside the senior. It listens to conversational tactics—urgency, threats, OTP demands—and displays clear, easy-to-read interventions, allowing the elder to end the call or immediately escalate to their family.")

    # ========================================================
    # SLIDE 5: Architecture (Matches Ref: "THE PROCESS - 01 02 03 04 05")
    # ========================================================
    s5 = prs.slides.add_slide(blank_layout)
    set_slide_background(s5, WARM_SAND)
    add_standard_header(s5, "Architecture Pipeline", "THE PROCESS: Transient Intelligence Flow",
                        "Strict decoupling of speech processing, threat intelligence, and user presentation.")

    # 5 Process Steps Horizontal (EXACT MATCH TO REFERENCE "THE PROCESS" SLIDE!)
    steps_data = [
        ("01", "INGESTION", "Audio Ingestion", [
            "Transient audio chunks in device RAM only.",
            "Zero disk storage of raw voice."
        ]),
        ("02", "TRANSCRIBE", "Transient STT", [
            "Abstracted SpeechToText service.",
            "Flushed immediately after inference."
        ]),
        ("03", "ANALYSIS", "Detection Engine", [
            "Multi-turn sequence heuristic rules.",
            "Tracks compounding threat signals."
        ]),
        ("04", "SCORING", "Risk Tiering", [
            "0-39: Safe",
            "40-70: Suspicious",
            "71-84: High Risk",
            "85-100: Critical"
        ]),
        ("05", "INTERVENE", "Dual Delivery", [
            "Senior: High-contrast Warning HUD.",
            "Caregiver: Telemetry alert without audio."
        ])
    ]

    for i, (num, tag, title, bullets) in enumerate(steps_data):
        left = Inches(0.8 + i * 2.4)
        # Top Crimson Tab with Number (Ref style!)
        tab = s5.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(2.1), Inches(2.2), Inches(0.8))
        tab.fill.solid()
        tab.fill.fore_color.rgb = CRIMSON
        tab.line.fill.background()

        ttf = tab.text_frame
        ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0
        tp1 = ttf.paragraphs[0]
        tp1.text = num
        tp1.font.size = Pt(16)
        tp1.font.bold = True
        tp1.font.color.rgb = PURE_WHITE
        tp1.alignment = PP_ALIGN.CENTER

        tp2 = ttf.add_paragraph()
        tp2.text = tag
        tp2.font.size = Pt(9)
        tp2.font.bold = True
        tp2.font.color.rgb = WARM_SAND
        tp2.alignment = PP_ALIGN.CENTER

        # Bottom White Card
        card = s5.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(3.0), Inches(2.2), Inches(3.7))
        card.fill.solid()
        card.fill.fore_color.rgb = PURE_WHITE
        card.line.color.rgb = BORDER_LIGHT
        card.line.width = Pt(1.2)

        ctb = s5.shapes.add_textbox(left + Inches(0.15), Inches(3.2), Inches(1.9), Inches(3.3))
        ctf = ctb.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0

        cp_t = ctf.paragraphs[0]
        cp_t.text = title
        cp_t.font.size = Pt(12)
        cp_t.font.bold = True
        cp_t.font.color.rgb = TEXT_DARK
        cp_t.space_after = Pt(8)

        for b in bullets:
            cp_b = ctf.add_paragraph()
            cp_b.text = f"• {b}"
            cp_b.font.size = Pt(10.5)
            cp_b.font.color.rgb = TEXT_MUTED
            cp_b.space_after = Pt(6)

    add_year_badge(s5, "2026")
    add_notes(s5, "Our pipeline feeds transient audio chunks through speech recognition directly into a multi-turn heuristic engine. When compounding threats like urgency and OTP requests occur in sequence, the risk score surges past threshold, instantly triggering intervention dialogues.")

    # ========================================================
    # SLIDE 6: Demo Center & Numbers (Matches Ref: "LET'S SEE THE NUMBERS")
    # ========================================================
    s6 = prs.slides.add_slide(blank_layout)
    set_slide_background(s6, WARM_SAND)
    add_standard_header(s6, "Evaluator Demo Center", "100% Deterministic Offline Evaluation",
                        "Judges can test realistic scam scenarios with zero network latency or cloud credentials.")

    # Left: White Card with Scenarios
    scen_card = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(2.1), Inches(6.8), Inches(4.7))
    scen_card.fill.solid()
    scen_card.fill.fore_color.rgb = PURE_WHITE
    scen_card.line.color.rgb = BORDER_LIGHT
    scen_card.line.width = Pt(1.2)

    stb = s6.shapes.add_textbox(Inches(1.1), Inches(2.3), Inches(6.2), Inches(4.3))
    stf = stb.text_frame
    stf.word_wrap = True
    stf.margin_left = stf.margin_top = stf.margin_right = stf.margin_bottom = 0

    p_th = stf.paragraphs[0]
    p_th.text = "5 Scripted Multi-Turn Evaluation Scenarios"
    p_th.font.size = Pt(15)
    p_th.font.bold = True
    p_th.font.color.rgb = CRIMSON
    p_th.space_after = Pt(10)

    scenarios = [
        ("1. Fake KYC Update (High Risk):", "Turn 1: Bank claim (10) ➔ Turn 2: Urgency ('Expires today') ➔ Turn 3: Threat ➔ Turn 4: OTP demand ➔ Surges to 75 / 100 High Risk."),
        ("2. Digital Arrest Threat (Critical Threat):", "Impersonating police claiming contraband parcel. Demands isolation ➔ Surges to 90 / 100."),
        ("3. Grandchild Emergency (High Risk):", "Fabricated hospital distress demanding urgent UPI deposit ➔ High Risk."),
        ("4. Legitimate Bank Alert (BENCHMARK - 0/100 Safe):", "Bank rep: 'We never ask for your OTP/PIN/password' ➔ Stays at 0 / 100 Safe (Proves zero false positives)."),
        ("5. Hospital Appointment Reschedule:", "Routine clinical appointment call ➔ Benchmark 0 / 100 Safe.")
    ]

    for title, desc in scenarios:
        pt = stf.add_paragraph()
        pt.text = title
        pt.font.size = Pt(11.5)
        pt.font.bold = True
        pt.font.color.rgb = TEXT_DARK
        pd = stf.add_paragraph()
        pd.text = desc
        pd.font.size = Pt(10.5)
        pd.font.color.rgb = TEXT_MUTED
        pd.space_after = Pt(4)

    # Right: Crimson Numbers Block (EXACT MATCH TO REFERENCE "LET'S SEE THE NUMBERS" SLIDE!)
    num_box = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(7.9), Inches(2.1), Inches(4.6), Inches(4.7))
    num_box.fill.solid()
    num_box.fill.fore_color.rgb = CRIMSON
    num_box.line.fill.background()

    ntf = num_box.text_frame
    ntf.word_wrap = True
    ntf.margin_left = Inches(0.5)
    ntf.margin_top = Inches(0.4)

    np0 = ntf.paragraphs[0]
    np0.text = "THE NUMBERS"
    np0.font.size = Pt(13)
    np0.font.bold = True
    np0.font.color.rgb = WARM_SAND
    np0.space_after = Pt(14)

    stats = [
        ("0 / 100", "SAFE SCORE ON BENCHMARK CALLS"),
        ("75 / 100", "HIGH RISK INTERVENTION TRIGGER"),
        ("5", "REALISTIC OFFLINE SCENARIOS"),
        ("0ms", "NETWORK LATENCY DURING DEMO")
    ]
    for num, lbl in stats:
        p1 = ntf.add_paragraph()
        p1.text = num
        p1.font.size = Pt(24)
        p1.font.bold = True
        p1.font.color.rgb = PURE_WHITE
        p2 = ntf.add_paragraph()
        p2.text = lbl
        p2.font.size = Pt(8.5)
        p2.font.bold = True
        p2.font.color.rgb = WARM_SAND
        p2.space_after = Pt(8)

    add_year_badge(s6, "2026", PURE_WHITE)
    add_notes(s6, "To prove reliability, we built a deterministic Demo Center with 5 diverse scenarios. In the KYC demo, notice how caller urgency elevates the risk to 75, triggering the intervention dialog. And crucially, legitimate bank calls remain at 0/100, proving zero false positives.")

    # ========================================================
    # SLIDE 7: Privacy by Design & Caregiver Boundary
    # ========================================================
    s7 = prs.slides.add_slide(blank_layout)
    set_slide_background(s7, WARM_SAND)
    add_standard_header(s7, "Privacy Architecture", "Privacy-by-Design: Zero Audio, Zero Transcripts",
                        "Protecting elderly citizens from financial exploitation without sacrificing their dignity.")

    # Left: Crimson Privacy Shield Card
    c_priv = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(2.1), Inches(4.3), Inches(4.7))
    c_priv.fill.solid()
    c_priv.fill.fore_color.rgb = CRIMSON
    c_priv.line.fill.background()

    ptf = c_priv.text_frame
    ptf.word_wrap = True
    ptf.margin_left = Inches(0.35)
    ptf.margin_top = Inches(0.35)

    p0 = ptf.paragraphs[0]
    p0.text = "100% PRIVATE TO SENIOR"
    p0.font.size = Pt(15)
    p0.font.bold = True
    p0.font.color.rgb = PURE_WHITE
    p0.space_after = Pt(14)

    priv_points = [
        ("🔒 ZERO Audio Recorded or Shared", "Microphone audio is transient in RAM only. Zero recordings on disk or cloud."),
        ("🔒 ZERO Full Transcripts", "Spoken words and personal dialogue are NEVER stored or sent to caregivers."),
        ("🔒 ZERO Credential Storage", "OTPs, card numbers, or passwords spoken are automatically scrubbed by AppLogger."),
        ("🤝 Mutual Dual Authorization", "Caregivers must be explicitly invited and authenticated before alerts activate.")
    ]
    for title, desc in priv_points:
        p1 = ptf.add_paragraph()
        p1.text = title
        p1.font.size = Pt(11.5)
        p1.font.bold = True
        p1.font.color.rgb = WARM_SAND
        p2 = ptf.add_paragraph()
        p2.text = desc
        p2.font.size = Pt(10)
        p2.font.color.rgb = PURE_WHITE
        p2.space_after = Pt(8)

    # Middle: White Structured Telemetry Card
    c_tel = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(5.4), Inches(2.1), Inches(4.0), Inches(4.7))
    c_tel.fill.solid()
    c_tel.fill.fore_color.rgb = PURE_WHITE
    c_tel.line.color.rgb = BORDER_LIGHT
    c_tel.line.width = Pt(1.2)

    ttf = c_tel.text_frame
    ttf.word_wrap = True
    ttf.margin_left = Inches(0.3)
    ttf.margin_top = Inches(0.35)

    tp0 = ttf.paragraphs[0]
    tp0.text = "STRUCTURED TELEMETRY ONLY"
    tp0.font.size = Pt(14)
    tp0.font.bold = True
    tp0.font.color.rgb = CRIMSON
    tp0.space_after = Pt(14)

    tel_points = [
        ("🛡️ Mathematical Threat Score", "Caregivers receive risk tier: 'Score: 75/100 (High Risk)'."),
        ("🏷️ Behavioral Manipulation Tags", "['Authority Impersonation', 'Urgency', 'OTP Solicitation']."),
        ("💡 Safe Recommended Action", "'Call your parent immediately. Confirm no OTP was shared.'"),
        ("✅ Senior Intervention Action", "Logged: 'Senior selected: Alert Family / End Call'.")
    ]
    for title, desc in tel_points:
        p1 = ttf.add_paragraph()
        p1.text = title
        p1.font.size = Pt(11.5)
        p1.font.bold = True
        p1.font.color.rgb = TEXT_DARK
        p2 = ttf.add_paragraph()
        p2.text = desc
        p2.font.size = Pt(10)
        p2.font.color.rgb = TEXT_MUTED
        p2.space_after = Pt(8)

    # Right: Caregiver Screenshot
    if os.path.exists("sample_caregiver_view.png"):
        img_card = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(9.7), Inches(2.1), Inches(2.8), Inches(4.7))
        img_card.fill.solid()
        img_card.fill.fore_color.rgb = PURE_WHITE
        img_card.line.color.rgb = BORDER_LIGHT
        img_card.line.width = Pt(1.2)
        s7.shapes.add_picture("sample_caregiver_view.png", Inches(9.8), Inches(2.25), width=Inches(2.6))

    add_year_badge(s7, "2026")
    add_notes(s7, "Privacy is our core architectural pillar. Caregivers never hear the conversation or read personal transcripts. They receive only structured threat metadata: the risk score, the detected signals, and the action taken.")

    # ========================================================
    # SLIDE 8: Tech Stack & Quality (Matches Ref: Strategy Cards)
    # ========================================================
    s8 = prs.slides.add_slide(blank_layout)
    set_slide_background(s8, WARM_SAND)
    add_standard_header(s8, "Engineering Excellence", "Production-Hardened Mobile Tech Stack",
                        "Clean layered architecture, elderly accessibility, and 223 automated tests.")

    tech_cards = [
        ("01", "MOBILE CLIENT", "Flutter 3.x / Dart 3.x", [
            "• Material 3 UI with custom accessible primitives (GlassCard, RiskBadge).",
            "• Large touch targets (48dp+) & high contrast for seniors.",
            "• Native Reduce Motion toggle disabling dynamic glows.",
            "• Zero dangerous permissions in AndroidManifest.xml."
        ]),
        ("02", "AI DETECTION PIPELINE", "3 Modular Engines", [
            "• 1. Offline Mock: 100% in-memory heuristic engine.",
            "• 2. Edge Function Proxy: Supabase serverless protecting API keys.",
            "• 3. Direct Dev: Gemini 1.5 Flash / GPT-4o-mini testing.",
            "• AppLogger scrubbing credentials automatically."
        ]),
        ("03", "QUALITY ASSURANCE", "223 / 223 Tests Passing", [
            "• 223 automated unit, widget, and domain tests passing.",
            "• Supabase Auth & PostgreSQL Row-Level Security (RLS).",
            "• Provider-neutral NotificationService architecture.",
            "• Zero horizontal overflow mobile safety layout."
        ])
    ]

    for i, (num, tag, title, bullets) in enumerate(tech_cards):
        left = Inches(0.8 + i * 4.0)
        c = s8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(2.1), Inches(3.7), Inches(4.7))
        c.fill.solid()
        c.fill.fore_color.rgb = PURE_WHITE
        c.line.color.rgb = BORDER_LIGHT
        c.line.width = Pt(1.2)

        # Crimson Tag Pill
        pill = s8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.25), Inches(2.35), Inches(3.2), Inches(0.55))
        pill.fill.solid()
        pill.fill.fore_color.rgb = CRIMSON
        pill.line.fill.background()

        ptf = pill.text_frame
        ptf.margin_left = ptf.margin_top = ptf.margin_right = ptf.margin_bottom = 0
        pp = ptf.paragraphs[0]
        pp.text = f"{num}  •  {tag}"
        pp.font.size = Pt(10)
        pp.font.bold = True
        pp.font.color.rgb = PURE_WHITE
        pp.alignment = PP_ALIGN.CENTER

        tb = s8.shapes.add_textbox(left + Inches(0.25), Inches(3.1), Inches(3.2), Inches(3.5))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        p_t = tf.paragraphs[0]
        p_t.text = title
        p_t.font.size = Pt(14)
        p_t.font.bold = True
        p_t.font.color.rgb = TEXT_DARK
        p_t.space_after = Pt(10)

        for b in bullets:
            pb = tf.add_paragraph()
            pb.text = b
            pb.font.size = Pt(11)
            pb.font.color.rgb = TEXT_DARK
            pb.space_after = Pt(7)

    add_year_badge(s8, "2026")
    add_notes(s8, "Built with Flutter for smooth cross-platform delivery and Supabase for secure cloud synchronization. Our engine is completely modular, and our entire pipeline is backed by 223 passing automated tests.")

    # ========================================================
    # SLIDE 9: Project Timeline & Roadmap (Matches Ref: Project Timeline)
    # ========================================================
    s9 = prs.slides.add_slide(blank_layout)
    set_slide_background(s9, WARM_SAND)
    add_standard_header(s9, "Growth Strategy", "PROJECT TIMELINE: Commercial Viability & Scale",
                        "From working hackathon prototype to nationwide telecom and consumer protection.")

    roadmap_data = [
        ("PHASE 01", "TODAY", "Hackathon Working Prototype", [
            "• Standalone Flutter Android client.",
            "• Deterministic 5-scenario Demo Center.",
            "• Multi-turn heuristic scam engine.",
            "• Privacy-first Caregiver Telemetry Circle.",
            "• 223/223 automated tests passing."
        ]),
        ("PHASE 02", "6–12 MOS", "On-Device SLMs (MediaPipe/ONNX)", [
            "• Local Small Language Models for 100% offline neural inference.",
            "• Zero cloud latency and air-gapped privacy.",
            "• Multi-lingual Indian dialect coverage: Hindi, Telugu, Tamil, Marathi.",
            "• Voice biometrics for synthetic voice clone detection."
        ]),
        ("PHASE 03", "SCALE", "Telecom Carrier Integration", [
            "• Direct partnerships with mobile carriers (Airtel, Jio, etc.).",
            "• Carrier-level call stream inspection with user consent.",
            "• Native companion dialer app integration.",
            "• Automated 1-tap reporting to National Cybercrime Portal (NCRP 1930)."
        ])
    ]

    for i, (phase, timing, title, bullets) in enumerate(roadmap_data):
        left = Inches(0.8 + i * 4.0)
        c = s9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, Inches(2.1), Inches(3.7), Inches(4.7))
        c.fill.solid()
        c.fill.fore_color.rgb = PURE_WHITE
        c.line.color.rgb = BORDER_LIGHT
        c.line.width = Pt(1.2)

        # Header with Crimson bar
        top_bar = s9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.25), Inches(2.35), Inches(3.2), Inches(0.7))
        top_bar.fill.solid()
        top_bar.fill.fore_color.rgb = CRIMSON if i == 0 else SLATE_NAVY
        top_bar.line.fill.background()

        btf = top_bar.text_frame
        btf.margin_left = Inches(0.2)
        btf.margin_top = Inches(0.1)
        bp1 = btf.paragraphs[0]
        bp1.text = f"{phase}  •  {timing}"
        bp1.font.size = Pt(9.5)
        bp1.font.bold = True
        bp1.font.color.rgb = WARM_SAND

        bp2 = btf.add_paragraph()
        bp2.text = title
        bp2.font.size = Pt(11)
        bp2.font.bold = True
        bp2.font.color.rgb = PURE_WHITE

        tb = s9.shapes.add_textbox(left + Inches(0.25), Inches(3.2), Inches(3.2), Inches(3.4))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        for b in bullets:
            pb = tf.add_paragraph()
            pb.text = b
            pb.font.size = Pt(11)
            pb.font.color.rgb = TEXT_DARK
            pb.space_after = Pt(7)

    add_year_badge(s9, "2026")
    add_notes(s9, "We engineered GuardCall with accessibility at the center, including native reduce-motion toggles. While we demonstrate this today with controlled audio inputs, our roadmap includes deploying lightweight on-device SLMs and partnering directly with telecom carriers.")

    # ========================================================
    # SLIDE 10: Conclusion (Matches Ref: "THANK YOU!" Slide)
    # ========================================================
    s10 = prs.slides.add_slide(blank_layout)
    set_slide_background(s10, PURE_WHITE)

    # Large Crimson Hero Panel with bottom-right rounded corner (Exact Reference match!)
    ty_hero = s10.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.8), Inches(11.7), Inches(5.0)
    )
    ty_hero.fill.solid()
    ty_hero.fill.fore_color.rgb = CRIMSON
    ty_hero.line.fill.background()

    ytf = ty_hero.text_frame
    ytf.word_wrap = True
    ytf.margin_left = Inches(0.8)
    ytf.margin_top = Inches(0.8)
    ytf.margin_right = Inches(0.8)

    yp0 = ytf.paragraphs[0]
    yp0.text = "GUARDCALL — RESTORING CONFIDENCE IN PHONE CALLS"
    yp0.font.size = Pt(12)
    yp0.font.bold = True
    yp0.font.color.rgb = WARM_SAND
    yp0.space_after = Pt(12)

    yp1 = ytf.add_paragraph()
    yp1.text = "THANK YOU!"
    yp1.font.size = Pt(46)
    yp1.font.bold = True
    yp1.font.color.rgb = PURE_WHITE
    yp1.space_after = Pt(12)

    yp2 = ytf.add_paragraph()
    yp2.text = "Seniors should never have to fear answering their phones, and families shouldn't have to live with anxiety."
    yp2.font.size = Pt(16)
    yp2.font.color.rgb = PURE_WHITE
    yp2.space_after = Pt(24)

    yp3 = ytf.add_paragraph()
    yp3.text = "✦ Proactive Fraud Defense  •  ✦ 100% Zero-Audio Privacy  •  ✦ Connected Family Circle"
    yp3.font.size = Pt(14)
    yp3.font.bold = True
    yp3.font.color.rgb = WARM_SAND
    yp3.space_after = Pt(20)

    yp4 = ytf.add_paragraph()
    yp4.text = "👉 WE INVITE YOU TO EXPERIENCE THE LIVE SIMULATION IN OUR DEMO CENTER NOW!"
    yp4.font.size = Pt(13)
    yp4.font.bold = True
    yp4.font.color.rgb = PURE_WHITE

    add_year_badge(s10, "2026")
    add_notes(s10, "GuardCall gives seniors the independence they deserve, and gives families peace of mind. Thank you, and we invite you to experience the live multi-turn simulation right now!")

    # Save to both target names
    out1 = "GuardCall_Executive_Pitch.pptx"
    out2 = "GuardCall_Premium_Pitch.pptx"
    prs.save(out1)
    try:
        prs.save(out2)
    except Exception:
        pass
    print(f"Successfully generated: {os.path.abspath(out1)}")

if __name__ == "__main__":
    build_crimson_deck()
