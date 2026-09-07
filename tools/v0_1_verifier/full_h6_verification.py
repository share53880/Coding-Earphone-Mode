#!/usr/bin/env python3
import os
import sys
import time
import subprocess

REC_DIR = "/Users/hanzhen/Library/Application Support/Typeless/Recordings"
POSTER_BIN = "./tools/v0_1_verifier/poster"
ENGINE_BIN = "./bin/coding_earphone"
MONITOR_BIN = "./tools/v0_1_verifier/monitor"

def activate_app(bundle_id):
    subprocess.run(["osascript", "-e", f'tell application id "{bundle_id}" to activate'], check=True)
    time.sleep(1.0)

def test_typeless_10_rounds(app_label, bundle_id):
    print(f"\n=======================================================")
    print(f"🧪 [H6] Testing Middle Button -> Typeless 10 Rounds in {app_label}")
    print(f"=======================================================")
    activate_app(bundle_id)
    
    rounds_passed = 0
    for i in range(1, 11):
        before_files = set(os.listdir(REC_DIR))
        t0 = time.time()
        
        # 1st press: Middle button -> Start recording
        subprocess.run([POSTER_BIN, "play"], check=True)
        time.sleep(1.3)
        
        # 2nd press: Middle button -> Stop recording
        subprocess.run([POSTER_BIN, "play"], check=True)
        time.sleep(1.3)
        
        after_files = set(os.listdir(REC_DIR))
        new_oggs = [f for f in (after_files - before_files) if f.endswith(".ogg")]
        
        if len(new_oggs) >= 1:
            rounds_passed += 1
            f = new_oggs[0]
            sz = os.path.getsize(os.path.join(REC_DIR, f))
            print(f"Round {i:2d}/10: [PASS] Audio recorded -> {f} ({sz} bytes, elapsed={time.time()-t0:.2f}s)")
        else:
            print(f"Round {i:2d}/10: [FAIL] No new recording file found!")
            
    print(f"--> {app_label} Typeless Toggle: {rounds_passed}/10 PASSED")
    return rounds_passed == 10

def test_keys(app_label, bundle_id):
    print(f"\n=======================================================")
    print(f"🧪 [H6] Testing Vol+ (Enter), Vol- (Backspace), Vol- Hold in {app_label}")
    print(f"=======================================================")
    activate_app(bundle_id)
    
    # Start temporary downstream monitor to count keys
    mon_proc = subprocess.Popen([MONITOR_BIN], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(0.5)
    
    # 1. Single Vol + -> 1 Return
    print("Testing Vol + -> Expect 1 Return...")
    subprocess.run([POSTER_BIN, "vol_up"], check=True)
    time.sleep(0.3)
    
    # 2. Single Vol - -> 1 Backspace
    print("Testing Vol - -> Expect 1 Backspace...")
    subprocess.run([POSTER_BIN, "vol_down"], check=True)
    time.sleep(0.3)
    
    # 3. Vol - Hold 1.0s (~12 repeats)
    print("Testing Vol - Hold 1.0s -> Expect continuous Backspaces...")
    subprocess.run([POSTER_BIN, "vol_down_hold", "1.0"], check=True)
    time.sleep(0.5)
    
    mon_proc.terminate()
    stdout, _ = mon_proc.communicate()
    
    return_count = stdout.count("KeyDown: Return (36)")
    backspace_count = stdout.count("KeyDown: Backspace (51)")
    media_leak_count = stdout.count("[DOWNSTREAM:MEDIA]")
    
    print(f"Observed Downstream Events in {app_label}:")
    print(f"  • Return KeyDown count: {return_count} (Expected: 1)")
    print(f"  • Backspace KeyDown count: {backspace_count} (Expected: ~13: 1 single + 12 repeats)")
    print(f"  • Leaked Media Keys count: {media_leak_count} (Expected: 0)")
    
    passed = (return_count == 1 and backspace_count >= 10 and media_leak_count == 0)
    print(f"--> {app_label} Key Mapping Verdict: {'PASS' if passed else 'FAIL'}")
    return passed

def test_passthrough(app_label, bundle_id):
    print(f"\n=======================================================")
    print(f"🧪 [H6] Testing Passthrough in Non-Coding App: {app_label}")
    print(f"=======================================================")
    activate_app(bundle_id)
    
    mon_proc = subprocess.Popen([MONITOR_BIN], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    time.sleep(0.5)
    
    # Send all three keys
    subprocess.run([POSTER_BIN, "play"], check=True)
    time.sleep(0.2)
    subprocess.run([POSTER_BIN, "vol_up"], check=True)
    time.sleep(0.2)
    subprocess.run([POSTER_BIN, "vol_down"], check=True)
    time.sleep(0.5)
    
    mon_proc.terminate()
    stdout, _ = mon_proc.communicate()
    
    synthetic_count = stdout.count("Synthetic=true")
    media_passed_count = stdout.count("[DOWNSTREAM:MEDIA]")
    
    print(f"Observed in {app_label}:")
    print(f"  • Synthetic Key count: {synthetic_count} (Expected: 0)")
    print(f"  • Media Keys passed through: {media_passed_count} (Expected: >= 3)")
    
    passed = (synthetic_count == 0 and media_passed_count >= 3)
    print(f"--> {app_label} Passthrough Verdict: {'PASS' if passed else 'FAIL'}")
    return passed

def test_switching_sequence():
    print(f"\n=======================================================")
    print(f"🧪 [H6] Testing Seamless App Switching Sequence")
    print(f"Sequence: Codex -> Music -> Antigravity -> Finder -> Codex")
    print(f"=======================================================")
    
    sequence = [
        ("Codex", "com.openai.codex", True),
        ("Music", "com.apple.Music", False),
        ("Antigravity", "com.google.antigravity", True),
        ("Finder", "com.apple.finder", False),
        ("Codex", "com.openai.codex", True)
    ]
    
    all_switch_pass = True
    for name, bid, expect_coding in sequence:
        print(f"\nSwitching to: {name} ({bid}) -> Expecting: {'CODING 🟢' if expect_coding else 'PASSTHROUGH ⚪'}")
        activate_app(bid)
        
        mon_proc = subprocess.Popen([MONITOR_BIN], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        time.sleep(0.3)
        subprocess.run([POSTER_BIN, "vol_up"], check=True)
        time.sleep(0.3)
        mon_proc.terminate()
        stdout, _ = mon_proc.communicate()
        
        had_return = "KeyDown: Return (36)" in stdout
        had_media = "[DOWNSTREAM:MEDIA] Key=0" in stdout
        
        if expect_coding:
            step_pass = (had_return and not had_media)
        else:
            step_pass = (not had_return and had_media)
            
        print(f"  -> Result: had_return={had_return}, had_media={had_media} -> {'PASS' if step_pass else 'FAIL'}")
        if not step_pass:
            all_switch_pass = False
            
    print(f"\n--> App Switching Sequence Verdict: {'PASS' if all_switch_pass else 'FAIL'}")
    return all_switch_pass

def main():
    print("==================================================================")
    print("🚀 Running Full H6 Verification Suite for Coding Earphone V0.1")
    print("==================================================================")
    
    # Start engine
    engine_proc = subprocess.Popen([ENGINE_BIN], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(1.0)
    
    results = {}
    try:
        # 1. Codex
        results["codex_typeless_10"] = test_typeless_10_rounds("Codex", "com.openai.codex")
        results["codex_keys"] = test_keys("Codex", "com.openai.codex")
        
        # 2. Antigravity
        results["antigravity_typeless_10"] = test_typeless_10_rounds("Antigravity", "com.google.antigravity")
        results["antigravity_keys"] = test_keys("Antigravity", "com.google.antigravity")
        
        # 3. Non-Coding Apps
        results["safari_passthrough"] = test_passthrough("Safari", "com.apple.Safari")
        results["finder_passthrough"] = test_passthrough("Finder", "com.apple.finder")
        results["music_passthrough"] = test_passthrough("Music", "com.apple.Music")
        
        # 4. Switching sequence
        results["switching_sequence"] = test_switching_sequence()
        
    finally:
        print("\nStopping engine...")
        engine_proc.terminate()
        try:
            engine_proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            engine_proc.kill()
            
    # Switch back to Antigravity at end
    activate_app("com.google.antigravity")
    
    print("\n==================================================================")
    print("📊 FULL VERIFICATION SUMMARY")
    print("==================================================================")
    all_pass = True
    for test_name, res in results.items():
        print(f"  • {test_name:30}: {'PASS ✅' if res else 'FAIL ❌'}")
        if not res:
            all_pass = False
            
    final_verdict = "V0_1_PASS" if all_pass else "V0_1_REVISE"
    print(f"\nFinal Verdict: {final_verdict}")
    sys.exit(0 if all_pass else 1)

if __name__ == "__main__":
    main()
