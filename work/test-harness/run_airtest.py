import json, os, subprocess, sys, threading
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
gap = int(sys.argv[1]); mode = sys.argv[2]
src = open(os.path.join(SP, "airtest.luau"), encoding="utf-8").read()
if mode in ("green", "orange"): src = src.replace("local AUTO_GREEN = false", "local AUTO_GREEN = true")
if mode == "orange": src = src.replace("local PRESS_OFFSET = 0", "local PRESS_OFFSET = 0.085")
path = os.path.join(SP, "airtest_run.luau"); open(path, "w", encoding="utf-8").write(src)
out = {}
def run_test():
    out["log"] = subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--file", path], capture_output=True, text=True).stdout
t = threading.Thread(target=run_test); t.start()
poll = 'return tostring(workspace.TestBot1:GetAttribute("HT_Air"))'
for i in range(80):
    r = subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--code", poll], capture_output=True, text=True).stdout
    if "float" in r: break
key = sys.argv[3] if len(sys.argv) > 3 else "W"
late = key.startswith("late")
if late:
    key = key[4:]
acts = ([{"action": "keyDown", "key_code": key}] if key != "none" and not late else []) + [{"action": "keyPress", "key_code": "Space"}]
if late:
    acts += [{"action": "wait", "wait_time_ms": 750}, {"action": "keyDown", "key_code": key}]
if gap > 0: acts += [{"action": "wait", "wait_time_ms": gap}, {"action": "keyPress", "key_code": "Space"}]
acts += [{"action": "wait", "wait_time_ms": 1500}] + ([{"action": "keyUp", "key_code": key}] if key != "none" else [])
if key != "skip":
    subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": acts, "datamodel_type": "Client"})], capture_output=True, text=True)
t.join()
print(out.get("log", "")[:3400])
