# python run_coasttest.py : W then let go (coast), D then A then let go (turn), W with Q and D (propel drift).
import json, os, subprocess, sys, threading, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
out = {}
t = threading.Thread(target=lambda: out.update(log=subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--file", os.path.join(SP, "coasttest.luau")], capture_output=True, text=True).stdout))
t.start()
time.sleep(1.5)
def hold(key, ms):
    return [{"action": "keyDown", "key_code": key}, {"action": "wait", "wait_time_ms": ms}, {"action": "keyUp", "key_code": key}]
acts = hold("W", 1000) + [{"action": "wait", "wait_time_ms": 3000}] + hold("D", 750) + hold("A", 750) + [{"action": "wait", "wait_time_ms": 1500},
    {"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": 700}, {"action": "keyPress", "key_code": "Q"}, {"action": "keyUp", "key_code": "W"}] + hold("D", 600)
subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": acts, "datamodel_type": "Client"})], capture_output=True, text=True)
t.join()
print(out.get("log", "")[:900])
