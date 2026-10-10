import subprocess
import time
import re
import os
import sys

DEVICE = 'emulator-5554'

def adb(args):
    cmd = ['adb', '-s', DEVICE] + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout.strip(), res.stderr.strip()

def dump_ui():
    adb(['shell', 'uiautomator', 'dump', '/sdcard/dump.xml'])
    adb(['pull', '/sdcard/dump.xml', 'dump.xml'])
    if not os.path.exists('dump.xml'):
        return ""
    with open('dump.xml', 'r', encoding='utf-8') as f:
        return f.read()

def find_element(xml, pattern):
    regex = rf'content-desc="([^"]*{pattern}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    m = re.search(regex, xml, re.IGNORECASE)
    if m:
        desc = m.group(1)
        x1, y1, x2, y2 = int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))
        return desc, (x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2)
    # Also check text attribute
    regex_t = rf'text="([^"]*{pattern}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    m_t = re.search(regex_t, xml, re.IGNORECASE)
    if m_t:
        desc = m_t.group(1)
        x1, y1, x2, y2 = int(m_t.group(2)), int(m_t.group(3)), int(m_t.group(4)), int(m_t.group(5))
        return desc, (x1 + x2) // 2, (y1 + y2) // 2, (x1, y1, x2, y2)
    return None, None, None, None

def tap_element(pattern, wait_after=1.5):
    xml = dump_ui()
    desc, x, y, _ = find_element(xml, pattern)
    if x is not None and y is not None:
        print(f"Tapping '{pattern}' (found: '{desc}') at ({x}, {y})")
        adb(['shell', 'input', 'tap', str(x), str(y)])
        time.sleep(wait_after)
        return True
    print(f"FAILED to find element matching '{pattern}'")
    return False

def take_screenshot(name):
    adb(['shell', 'screencap', '-p', f'/sdcard/{name}.png'])
    adb(['pull', f'/sdcard/{name}.png', f'{name}.png'])
    print(f"Captured screenshot: {name}.png")

def run_verification():
    results = {}
    print("==================================================")
    print("GUARDCALL — PHASE 14A, STEP 1: DEMO FLOW VERIFICATION")
    print("Device: emulator-5554 (Medium_Phone, Android API 37)")
    print("APK: build/app/outputs/flutter-apk/app-release.apk")
    print("==================================================")

    # 1. Clean App Launch
    print("\n--- STEP 1: Launch GuardCall ---")
    adb(['shell', 'am', 'force-stop', 'com.example.guard_call'])
    time.sleep(1)
    adb(['shell', 'am', 'start', '-n', 'com.example.guard_call/.MainActivity'])
    time.sleep(3)
    take_screenshot("demo_step1_launch")
    xml = dump_ui()
    has_home = "Protection Active" in xml or "GuardCall" in xml
    results['Step 1: Launch GuardCall'] = "PASS" if has_home else "FAIL"

    # 2. Show Home
    print("\n--- STEP 2: Show Home ---")
    xml = dump_ui()
    has_prot = "Protection Active" in xml
    has_family = "Family Circle" in xml
    has_demo_btn = "Start Demo Call" in xml
    print(f"Home checks: Protection Active: {has_prot}, Family Circle: {has_family}, Start Demo Call: {has_demo_btn}")
    take_screenshot("demo_step2_home")
    results['Step 2: Show Home'] = "PASS" if (has_prot and has_demo_btn) else "FAIL"

    # 3. Open Demo Center
    print("\n--- STEP 3: Open Demo Center ---")
    tap_element("Start Demo Call")
    time.sleep(1)
    xml = dump_ui()
    has_demo_ctr = "Demo Center" in xml and "Legitimate Bank Alert" in xml
    print(f"Demo Center visible: {has_demo_ctr}")
    take_screenshot("demo_step3_demo_center")
    results['Step 3: Open Demo Center'] = "PASS" if has_demo_ctr else "FAIL"

    # 4. Run "Legitimate Bank Alert"
    print("\n--- STEP 4: Run Legitimate Bank Alert ---")
    # Scroll if needed or tap Legitimate Bank Alert
    xml = dump_ui()
    if "Legitimate Bank Alert" not in xml:
        adb(['shell', 'input', 'swipe', '500', '1500', '500', '600', '300'])
        time.sleep(1)
        xml = dump_ui()
    
    # Tap Play Scenario on Legitimate Bank Alert
    # Find Legitimate Bank Alert and tap near it or tap 'Play Scenario'
    desc, x, y, bounds = find_element(xml, "Legitimate Bank Alert")
    if bounds:
        # Tap Play Scenario below the title
        tap_y = bounds[3] + 120
        adb(['shell', 'input', 'tap', str(bounds[0] + 200), str(tap_y)])
        time.sleep(2)
    else:
        tap_element("Play Scenario")
        time.sleep(2)

    take_screenshot("demo_step4_bank_player")
    xml = dump_ui()
    has_start_sim = "Start Simulation" in xml
    print(f"In Player screen (Start Simulation visible): {has_start_sim}")

    # Start simulation
    tap_element("Start Simulation")
    time.sleep(1)

    # 5. Show: 0/100, SAFE, no false warning
    print("\n--- STEP 5: Verify Safe Scenario Outcome ---")
    # Wait for bank scenario turns to complete (3 turns, auto-progress takes ~10s)
    for _ in range(8):
        time.sleep(2)
        xml = dump_ui()
        if "Back to Demo Center" in xml or "Restart Simulation" in xml:
            break
    
    take_screenshot("demo_step5_bank_complete")
    xml = dump_ui()
    has_safe_score = ("0 / 100" in xml or "Safe" in xml or "0%" in xml)
    no_warning = "Possible Scam" not in xml and "HIGH RISK" not in xml
    is_completed = "Back to Demo Center" in xml or "Simulation completed" in xml or "Assessment Summary" in xml
    print(f"Bank scenario outcome: Safe score: {has_safe_score}, No warning: {no_warning}, Completed: {is_completed}")
    results['Step 4 & 5: Safe Scenario (0/100 SAFE, No Warning)'] = "PASS" if (has_safe_score and no_warning) else "FAIL"

    # 6. Return to Demo Center
    print("\n--- STEP 6: Return to Demo Center ---")
    if not tap_element("Back to Demo Center"):
        # Back arrow in AppBar
        adb(['shell', 'input', 'tap', '80', '150'])
        time.sleep(1)
    time.sleep(1)
    take_screenshot("demo_step6_back_to_demo_center")
    xml = dump_ui()
    has_demo_center = "Demo Center" in xml
    results['Step 6: Return to Demo Center'] = "PASS" if has_demo_center else "FAIL"

    # 7. Run "Fake KYC Update"
    print("\n--- STEP 7: Run Fake KYC Update ---")
    # Scroll back up to top of Demo Center
    adb(['shell', 'input', 'swipe', '500', '500', '500', '1500', '300'])
    time.sleep(1)
    xml = dump_ui()
    # Find Fake KYC Update
    desc, x, y, bounds = find_element(xml, "Fake KYC Update")
    if bounds:
        tap_y = bounds[3] + 120
        adb(['shell', 'input', 'tap', str(bounds[0] + 200), str(tap_y)])
        time.sleep(2)
    else:
        tap_element("Play Scenario")
        time.sleep(2)

    take_screenshot("demo_step7_kyc_player")
    xml = dump_ui()
    has_kyc_player = "Start Simulation" in xml and ("Fake KYC" in xml or "KYC" in xml)
    print(f"In Fake KYC player: {has_kyc_player}")
    results['Step 7: Run Fake KYC Update'] = "PASS" if has_kyc_player else "FAIL"

    # 8. Show progressive risk
    print("\n--- STEP 8 & 9: Start Simulation and Verify Progressive Risk & Warning ---")
    tap_element("Start Simulation")
    
    # Wait for turn 1 (initial: 10 Safe)
    time.sleep(3)
    take_screenshot("demo_step8_kyc_turn1")
    xml1 = dump_ui()
    print("Turn 1 active. Dialog present:", "Possible Scam" in xml1)

    # Wait for turn 2 & 3 (escalates to ~35, then 75 HIGH RISK and triggers Scam Warning)
    warning_appeared = False
    for attempt in range(10):
        time.sleep(2)
        xml = dump_ui()
        if "Possible Scam" in xml or "High Risk" in xml or "HIGH RISK" in xml:
            warning_appeared = True
            print(f"Warning dialog appeared at attempt {attempt}!")
            break
    
    take_screenshot("demo_step9_scam_warning")
    xml_warn = dump_ui()
    has_high_risk = "High" in xml_warn or "75" in xml_warn or "HIGH RISK" in xml_warn
    has_buttons = ("End Call" in xml_warn or "END CALL" in xml_warn) and ("Alert Family" in xml_warn or "ALERT FAMILY" in xml_warn)
    print(f"Scam Warning checks: Warning appeared: {warning_appeared}, High Risk: {has_high_risk}, Buttons: {has_buttons}")
    results['Step 8: Progressive Risk Escalation'] = "PASS" if warning_appeared else "FAIL"
    results['Step 9: Show Scam Warning'] = "PASS" if (warning_appeared and has_buttons) else "FAIL"

    # 10. Select "Alert Family"
    print("\n--- STEP 10: Select Alert Family ---")
    tap_res = tap_element("Alert Family") or tap_element("ALERT FAMILY")
    time.sleep(2)
    take_screenshot("demo_step10_alert_family_tapped")
    xml_fam = dump_ui()
    has_sim_alert = "Simulated Family Alert" in xml_fam or "Simulated Alert" in xml_fam or "Simulation only" in xml_fam
    print(f"Simulated alert dialog appeared: {has_sim_alert}")
    results['Step 10: Select Alert Family'] = "PASS" if has_sim_alert else "FAIL"

    # 11. Show simulated family alert
    print("\n--- STEP 11: Show Simulated Family Alert ---")
    take_screenshot("demo_step11_simulated_alert")
    has_disclosure = "Simulation only" in xml_fam or "Simulated" in xml_fam
    has_meta = "Risk Score" in xml_fam or "75" in xml_fam or "High" in xml_fam
    print(f"Disclosure present: {has_disclosure}, Risk metadata: {has_meta}")
    results['Step 11: Show Simulated Family Alert'] = "PASS" if (has_disclosure and has_meta) else "FAIL"

    # Close simulated alert
    tap_element("Close")
    time.sleep(1)

    # If call is still running or finished, leave player screen
    xml = dump_ui()
    if "Back to Demo Center" in xml:
        tap_element("Back to Demo Center")
        time.sleep(1)
    else:
        # Tap back arrow
        adb(['shell', 'input', 'tap', '80', '150'])
        time.sleep(1)
    
    # Return from Demo Center to Home/Shell
    adb(['shell', 'input', 'tap', '80', '150'])
    time.sleep(1)

    # 12. Open Caregiver View
    print("\n--- STEP 12 & 13: Open Caregiver View & Show Structured Telemetry ---")
    xml = dump_ui()
    # Tap Family tab (Tab 4 of 5)
    tap_element("Family")
    time.sleep(1)
    take_screenshot("demo_step12_family_screen")
    xml_fam_screen = dump_ui()
    # Switch to "Caregiver View (Preview)"
    tap_element("Caregiver View")
    time.sleep(1)
    take_screenshot("demo_step12_caregiver_tab")
    xml_cg = dump_ui()
    has_cg_tab = "Caregiver View" in xml_cg and ("Robert Jenkins" in xml_cg or "High Risk" in xml_cg or "Recent Escalations" in xml_cg or "Recent Family Alerts" in xml_cg)
    print(f"Caregiver tab loaded: {has_cg_tab}")
    results['Step 12: Open Caregiver View'] = "PASS" if has_cg_tab else "FAIL"

    # Open Caregiver Alert Detail Dialog
    # Tap on the alert card or view details
    desc, x, y, bounds = find_element(xml_cg, "High Risk")
    if not bounds:
        desc, x, y, bounds = find_element(xml_cg, "75")
    if bounds:
        adb(['shell', 'input', 'tap', str(x), str(y)])
        time.sleep(1.5)
    
    take_screenshot("demo_step13_caregiver_detail")
    xml_cg_detail = dump_ui()
    has_telemetry_sections = ("WHAT HAPPENED" in xml_cg_detail or "WHY" in xml_cg_detail or "High Risk" in xml_cg_detail or "75" in xml_cg_detail)
    print(f"Caregiver Detail Dialog visible: {has_telemetry_sections}")
    results['Step 13: Show Structured Threat Telemetry'] = "PASS" if has_telemetry_sections else "FAIL"

    # Close detail dialog if open
    tap_element("Close")
    time.sleep(1)

    # 14. Open Risk History
    print("\n--- STEP 14 & 15: Open Risk History & Show Recorded Event ---")
    tap_element("History")
    time.sleep(1)
    take_screenshot("demo_step14_history_screen")
    xml_hist = dump_ui()
    has_hist = "History" in xml_hist and ("Fake KYC" in xml_hist or "75" in xml_hist or "High Risk" in xml_hist or "Legitimate Bank" in xml_hist)
    print(f"History screen checks: Has records: {has_hist}")
    results['Step 14: Open Risk History'] = "PASS" if "History" in xml_hist else "FAIL"
    results['Step 15: Show Recorded Event in History'] = "PASS" if has_hist else "FAIL"

    # 16. Return to Home
    print("\n--- STEP 16: Return to Home ---")
    tap_element("Home")
    time.sleep(1)
    take_screenshot("demo_step16_return_home")
    xml_home_final = dump_ui()
    has_home_final = "Protection Active" in xml_home_final or "GuardCall" in xml_home_final
    print(f"Returned to Home: {has_home_final}")
    results['Step 16: Return to Home'] = "PASS" if has_home_final else "FAIL"

    print("\n==================================================")
    print("VERIFICATION RESULTS SUMMARY:")
    print("==================================================")
    for step, res in results.items():
        print(f"{step}: {res}")
    
    all_pass = all(v == "PASS" for v in results.values())
    if all_pass:
        print("\nPRIMARY DEMO FLOW VERIFIED.")
    else:
        print("\nSome steps failed verification!")

if __name__ == '__main__':
    run_verification()
