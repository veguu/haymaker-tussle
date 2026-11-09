# python run_turntest.py : holds W, then D, then A, then lets go, while turntest.luau samples.
import json, os, subprocess, sys, threading, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
out = {}
t = threading.Thread(target=lambda: out.update(log=subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--file", os.path.join(SP, "turntest.luau")], capture_output=True, text=True).stdout))
t.start()
time.sleep(1.5)
acts = [{"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": 1000}, {"action": "keyUp", "key_code": "W"},
        {"action": "keyDown", "key_code": "D"}, {"action": "wait", "wait_time_ms": 700}, {"action": "keyUp", "key_code": "D"},
        {"action": "keyDown", "key_code": "A"}, {"action": "wait", "wait_time_ms": 700}, {"action": "keyUp", "key_code": "A"}]
subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": acts, "datamodel_type": "Client"})], capture_output=True, text=True)
t.join()
print(out.get("log", "")[:1200])
