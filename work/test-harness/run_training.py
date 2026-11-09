# The training arena, in real play, on the real rules. Studio must be in Play. It moves your character and
# sends real keys and clicks.
#   python run_training.py state            : what exists: dummies, attributes, parts, prompts
#   python run_training.py enter            : uses the real gate prompt logic through a real key press
#   python run_training.py go <dummy name> [studs]  : puts you this far on the hub side of a dummy, facing it
#   python run_training.py click [n] [gap ms] : real clicks
#   python run_training.py read <dummy name> [seconds] : samples a dummy's position, height, stagger and state
#   python run_training.py press <pillar name> : stands at a pillar and presses F for real
# Run done at the end of a session: nothing here leaves anything behind but where you're standing.
import json, os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")


def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()


def call(tool, args):
    return subprocess.run([sys.executable, M, "call", tool, json.dumps(args)], capture_output=True, text=True).stdout.strip()


def click(n=1, gap=200):
    steps = [{"action": "moveTo", "x": 500, "y": 300}]
    for _ in range(n):
        steps.append({"action": "mouseButtonClick", "mouse_button": "left"})
        steps.append({"action": "wait", "wait_time_ms": gap})
    return call("user_mouse_input", {"datamodel_type": "Client", "actions": steps})


def key(name):
    return call("user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": "keyPress", "key_code": name}]})


def go(name, studs=4.5, side=0.0):
    # Client side, because the client owns the body. A body reset isn't available here, so this waits to settle.
    code = r'''
local me = game.Players.LocalPlayer.Character
local root = me.HumanoidRootPart
local target = workspace:FindFirstChild("__NAME__")
if not target then return "no " .. "__NAME__" end
local t = target.HumanoidRootPart.Position
local flat = Vector3.new(t.X - 370, 0, t.Z)
local toward = -flat.Unit
local right = Vector3.new(-toward.Z, 0, toward.X)
local at = t + toward * __STUDS__ + right * __SIDE__
at = Vector3.new(at.X, 103, at.Z)
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.lookAt(at, Vector3.new(t.X, 103, t.Z))
local align = root:FindFirstChild("HT_Facing")
return "at " .. tostring(at)
'''
    return luau(code.replace("__NAME__", name).replace("__STUDS__", str(studs)).replace("__SIDE__", str(side)))


def read(name, seconds=2.0):
    code = r'''
local m = workspace:FindFirstChild("__NAME__")
if not m then return "gone" end
local r = m.HumanoidRootPart
local out = {}
local start = r.Position
local far, high = 0, 0
local t0 = os.clock()
while os.clock() - t0 < __SECONDS__ do
	far = math.max(far, (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude)
	high = math.max(high, r.Position.Y - 103)
	game:GetService("RunService").Heartbeat:Wait()
end
return string.format("far %.1f high %.1f now (%.0f, %.1f, %.0f) stagger %s air %s stun %s", far, high, r.Position.X, r.Position.Y, r.Position.Z, tostring(m:GetAttribute("HT_Stagger")), tostring(m:GetAttribute("HT_Air")), tostring(m:GetAttribute("HT_Stunned")))
'''
    return luau(code.replace("__NAME__", name).replace("__SECONDS__", str(seconds)), "Server")


def press(pillar):
    # Walks on, really: off to one side first, because a pad only works once until you've stepped off.
    code = r'''
local p = workspace.HT_Training:FindFirstChild("Pad __NAME__")
if not p then return "no pad" end
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.new(p.Position.X, 103, p.Position.Z + __OFF__) * root.CFrame.Rotation
return "by pad"
'''
    out = luau(code.replace("__NAME__", pillar).replace("__OFF__", "7"))
    time.sleep(0.25)
    luau(code.replace("__NAME__", pillar).replace("__OFF__", "0"))
    return out


STATE = r'''
local names = {}
local plain = {}
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	local r = m:FindFirstChild("HumanoidRootPart")
	table.insert(names, string.format("%s (%.0f, %.1f, %.0f) stagger %s dummy %s anchored %s", m.Name, r.Position.X, r.Position.Y, r.Position.Z, tostring(m:GetAttribute("HT_Stagger")), tostring(m:GetAttribute("HT_Dummy")), tostring(r.Anchored)))
end
local f = workspace:FindFirstChild("HT_Training")
local prompts = 0
local parts = 0
if f then
	for _, d in f:GetDescendants() do
		if d:IsA("ProximityPrompt") then prompts += 1 end
		if d:IsA("BasePart") then parts += 1 end
	end
end
local p = game.Players:GetPlayers()[1]
return table.concat(names, "\n") .. string.format("\nparts %d, prompts %d, in training %s, TestBot1 %s, streaming %s", parts, prompts, tostring(p and p:GetAttribute("HT_InTraining")), tostring(workspace:FindFirstChild("TestBot1") ~= nil), tostring(workspace.StreamingEnabled))
'''

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "state":
        print(luau(STATE, "Server"))
    elif mode == "go":
        print(go(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 4.5, float(sys.argv[4]) if len(sys.argv) > 4 else 0))
    elif mode == "click":
        click(int(sys.argv[2]) if len(sys.argv) > 2 else 1, int(sys.argv[3]) if len(sys.argv) > 3 else 200)
    elif mode == "read":
        print(read(sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 2))
    elif mode == "press":
        print(press(sys.argv[2]))
    elif mode == "key":
        print(key(sys.argv[2]))
    elif mode == "view":
        a = sys.argv[2:8]
        print(luau('local Run=game:GetService("RunService") pcall(function() Run:UnbindFromRenderStep("HT_View") end) local cam=workspace.CurrentCamera Run:BindToRenderStep("HT_View",Enum.RenderPriority.Camera.Value+1,function() cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=CFrame.lookAt(Vector3.new(%s,%s,%s),Vector3.new(%s,%s,%s)) end) return "view"' % tuple(a)))
    elif mode == "unview":
        print(luau('local Run=game:GetService("RunService") pcall(function() Run:UnbindFromRenderStep("HT_View") end) workspace.CurrentCamera.CameraType=Enum.CameraType.Custom return "unview"'))
