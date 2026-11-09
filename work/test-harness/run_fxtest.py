import json, os, subprocess, sys, threading, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
out = {}
def run_test():
    out["log"] = subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--file", os.path.join(SP, "fxtest.luau")], capture_output=True, text=True).stdout
t = threading.Thread(target=run_test); t.start()
poll = 'for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do if m:GetAttribute("HT_Air") == "float" and game.Players.LocalPlayer:GetAttribute("HT_JumpReady") ~= false then return "float" end end return "no"'
for i in range(200):
    r = subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--code", poll], capture_output=True, text=True).stdout
    if "float" in r: break
# Space with no keys, so the jump goes the way you face, then a real Q propel well after everything has landed.
acts = [{"action": "keyPress", "key_code": "Space"}, {"action": "wait", "wait_time_ms": 5500}, {"action": "keyDown", "key_code": "W"}, {"action": "keyPress", "key_code": "Q"}, {"action": "wait", "wait_time_ms": 1300}, {"action": "keyUp", "key_code": "W"}]
print(subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": acts, "datamodel_type": "Client"})], capture_output=True, text=True).stdout[:300])
t.join()
print(out.get("log", "")[:3400])
