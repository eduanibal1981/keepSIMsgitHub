import subprocess
import time
import sys
import json
import urllib.request

DEV1 = "127.0.0.1:16384"
DEV2 = "127.0.0.1:16416"

def adb(dev, *args):
    cmd = ["adb", "-s", dev] + list(args)
    return subprocess.check_output(cmd).decode("utf-8", errors="ignore")

def adb_run(dev, *args):
    cmd = ["adb", "-s", dev] + list(args)
    subprocess.run(cmd)

def wait_for_callkit(dev, timeout=15):
    start = time.time()
    while time.time() - start < timeout:
        time.sleep(0.4)
        out = adb(dev, "shell", "dumpsys", "window")
        for line in out.splitlines():
            if "mCurrentFocus" in line and "CallkitIncomingActivity" in line:
                return True
    return False

def test_call_a():
    print("\n" + "="*60)
    print("TEST CALL A: Device 1 -> Device 2 (Accept & WebRTC Connect)")
    print("="*60)
    
    print("1. Clearing logcats...")
    adb_run(DEV1, "logcat", "-c")
    adb_run(DEV2, "logcat", "-c")
    
    print("2. Device 1 taps green phone button at (910, 410)...")
    adb_run(DEV1, "shell", "input", "tap", "910", "410")
    
    print("3. Waiting for CallkitIncomingActivity on Device 2...")
    if not wait_for_callkit(DEV2, timeout=12):
        print("FAILED: CallkitIncomingActivity did not appear on Device 2!")
        return False
        
    print("4. Callkit displayed! Waiting 600ms before accepting...")
    time.sleep(0.6)
    
    print("5. Device 2 taps Accept at (750, 1354)...")
    adb_run(DEV2, "shell", "input", "tap", "750", "1354")
    time.sleep(0.3)
    adb_run(DEV2, "shell", "input", "tap", "750", "1354")
    
    print("6. Waiting 10 seconds for WebRTC negotiation, Coturn ICE pairing, and active call timer...")
    time.sleep(10)
    
    print("7. Capturing in-call screenshots on both devices...")
    adb_run(DEV1, "shell", "screencap", "-p", "/sdcard/callA_active_dev1.png")
    adb_run(DEV1, "pull", "/sdcard/callA_active_dev1.png", "callA_active_dev1.png")
    adb_run(DEV2, "shell", "screencap", "-p", "/sdcard/callA_active_dev2.png")
    adb_run(DEV2, "pull", "/sdcard/callA_active_dev2.png", "callA_active_dev2.png")
    
    print("8. Device 1 hangs up at (750, 1405)...")
    adb_run(DEV1, "shell", "input", "tap", "750", "1405")
    time.sleep(3)
    
    print("Call A test sequence completed!")
    return True

if __name__ == "__main__":
    test_call_a()
