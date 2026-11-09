# python run_kickwindow.py [space delay after the uppercut, s] : you combo the real bot (left, right, uppercut),
# stepping back into reach before each punch, and Space is pressed a set time after the uppercut, scheduled in
# advance so tool latency can't eat the shorter air time. Prints the bot's flight and whether your jump left
# the ground and connected. Studio must be in Play. Not part of the game.
import json, os, subprocess, sys, threading, time

M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
SP = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SP)
import run_feel as F  # noqa: E402

delay = float(sys.argv[1]) if len(sys.argv) > 1 else 0.5
UPPERCUT_AT = 3.2  # seconds after the schedule starts
print(F.luau(F.CLIENT))
F.luau('workspace:SetAttribute("HT_TestBotQuiet", true) return 1', "Server")
time.sleep(0.5)

server = '''_G.HT_KW = {}
local b = workspace.TestBot1
local me = game.Players:GetPlayers()[1].Character
local t0 = os.clock()
if _G.HT_KWC then _G.HT_KWC:Disconnect() end
_G.HT_KWC = game:GetService("RunService").Heartbeat:Connect(function()
	local p, m = b.HumanoidRootPart.Position, me.HumanoidRootPart.Position
	local flat = Vector3.new(p.X - m.X, 0, p.Z - m.Z).Magnitude
	table.insert(_G.HT_KW, string.format("%.2f,%.1f,%.1f,%s,%s,%.1f", os.clock() - t0, p.Y, m.Y,
		tostring(b:GetAttribute("HT_Air")), tostring(me:GetAttribute("HT_Skill")), flat))
end)
local function step()
	local p = b.HumanoidRootPart.Position
	workspace:SetAttribute("HT_FPin", string.format("[%f,103,%f,0,-1]", p.X, p.Z + 3.5))
end
step()
for _, at in { UP - 1.2, UP - 0.6, UP } do
	task.delay(at - 0.15, step)
	task.delay(at, function() workspace:SetAttribute("HT_FPunch", os.clock()) end)
end
task.delay(UP + 0.05, function() workspace:SetAttribute("HT_FPin", nil) end)
task.delay(UP + 4, function() _G.HT_KWC:Disconnect() end)
return 1'''.replace("UP", str(UPPERCUT_AT))

# Space lands `delay` after the uppercut's impact (its windup is 0.08 s).
space_ms = int((UPPERCUT_AT + 0.08 + delay) * 1000)
keys = {"actions": [{"action": "wait", "wait_time_ms": min(space_ms, 10000)}, {"action": "keyPress", "key_code": "Space"},
                    {"action": "wait", "wait_time_ms": 1500}], "datamodel_type": "Client"}
t = threading.Thread(target=lambda: subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps(keys)],
                                                   capture_output=True, text=True))
t.start()
time.sleep(0.35)  # roughly the tool's own start-up, so both clocks line up
F.luau(server, "Server")
t.join()
time.sleep(UPPERCUT_AT + 4.5 - 1.5)
raw = F.luau('return table.concat(_G.HT_KW, "|")', "Server")
rows = [r.split(",") for r in raw.split("|") if r.count(",") == 5]
F.luau("if _G.HT_F_STOP then _G.HT_F_STOP() end return 1")
F.luau('workspace:SetAttribute("HT_TestBotQuiet", nil) workspace:SetAttribute("HT_FPin", nil) return 1', "Server")
if not rows:
    print("no track")
    sys.exit()
launch = next((float(r[0]) for r in rows if r[3] == "float"), None)
bot_apex = max(rows, key=lambda r: float(r[1]))
my_apex = max(rows, key=lambda r: float(r[2]))
states = []
for r in rows:
    if not states or states[-1][1:] != (r[3], r[4]):
        states.append((float(r[0]), r[3], r[4]))
print(f"Space set for {delay:.2f} s after the uppercut lands")
print(f"bot launched at {launch}, apex +{float(bot_apex[1]) - 103:.1f} at {bot_apex[0]}; your highest +{float(my_apex[2]) - 103:.1f} at {my_apex[0]}")
print("bot air / your skill over time: " + "; ".join(f"{s[0]:.2f} {s[1]}/{s[2]}" for s in states[:14]))

jump = next((float(r[0]) for r in rows if r[4] == "chase"), None)
if jump:
    for r in rows:
        if jump <= float(r[0]) <= jump + 1.4 and int(float(r[0]) * 100) % 10 == 0:
            print(f"  t {float(r[0]) - jump:.2f}: bot +{float(r[1]) - 103:.1f}, you +{float(r[2]) - 103:.1f}, flat gap {r[5]}, {r[3]}/{r[4]}")
