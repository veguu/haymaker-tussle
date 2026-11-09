# python run_shiftbug.py : measures camera lock frame by frame, standing and running, with and without shift lock.
# Against a client-only dummy, with the bot parked. Not part of the game.
import json, os, subprocess, sys, threading, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

def keys(*acts):
    subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": list(acts), "datamodel_type": "Client"})], capture_output=True, text=True)

def press(key):
    keys({"action": "keyPress", "key_code": key})
    time.sleep(0.4)

PARK = '''
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) and m:FindFirstChild("HumanoidRootPart") then
		m.HumanoidRootPart.Anchored = true
		m.HumanoidRootPart.CFrame = CFrame.new(70, 103, 70)
	end
end
return "bot parked"
'''

SETUP = '''
local me = game.Players.LocalPlayer
local ch = me.Character
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local old = workspace:FindFirstChild("HT_D")
if old then old:Destroy() end
ch.Archivable = true
local m = ch:Clone()
m.Name = "HT_D"
for _, d in m:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
end
m.HumanoidRootPart.Anchored = true
m.HumanoidRootPart.CFrame = CFrame.lookAt(Vector3.new(0, 103, 0), Vector3.new(0, 103, 30))
m.Parent = workspace
CS:AddTag(m, "HT_Combatant")
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
pcall(function() Run:UnbindFromRenderStep("HT_TestAim") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(Vector3.new(0, 103, 30), Vector3.new(0, 103, 0))
	end
end)
Run:BindToRenderStep("HT_TestAim", Enum.RenderPriority.Camera.Value + 2, function()
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 109, 44), Vector3.new(0, 103, 0))
end)
return "ready"
'''

FREE = '''
local Run = game:GetService("RunService")
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
pcall(function() Run:UnbindFromRenderStep("HT_TestAim") end)
return "free"
'''

SAMPLE = '''
local Run = game:GetService("RunService")
local U = game:GetService("UserInputService")
local me = game.Players.LocalPlayer
local root = me.Character.HumanoidRootPart
local cam = workspace.CurrentCamera
local torso = workspace.HT_D.Torso
local start = os.clock()
local frames, yawJerk, posJerk, flips, maxOff, off, faceSpin, mouseChanges = 0, 0, 0, 0, 0, 0, 0, 0
local maxDist, minDist = 0, math.huge
local lastYaw, lastPos, lastStep, lastFace
local con = U:GetPropertyChangedSignal("MouseBehavior"):Connect(function() mouseChanges += 1 end)
local behaviours = {}
while os.clock() - start < SECONDS do
	local dt = Run.RenderStepped:Wait()
	frames += 1
	local _, yaw = cam.CFrame:ToOrientation()
	if lastYaw then
		local step = (yaw - lastYaw + math.pi) % (2 * math.pi) - math.pi
		yawJerk = math.max(yawJerk, math.abs(math.deg(step)) / dt)
		if lastStep and step * lastStep < 0 and math.abs(math.deg(step)) / dt > 10 then flips += 1 end
		lastStep = step
		posJerk = math.max(posJerk, (cam.CFrame.Position - lastPos).Magnitude / dt)
	end
	lastYaw, lastPos = yaw, cam.CFrame.Position
	local _, faceYaw = root.CFrame:ToOrientation()
	if lastFace then
		faceSpin = math.max(faceSpin, math.abs(math.deg((faceYaw - lastFace + math.pi) % (2 * math.pi) - math.pi)) / dt)
	end
	lastFace = faceYaw
	local p, on = cam:WorldToViewportPoint(torso.Position)
	if not on then off += 1 end
	maxOff = math.max(maxOff, math.abs(p.X - cam.ViewportSize.X / 2) / (cam.ViewportSize.X / 2))
	local d = (cam.CFrame.Position - root.Position).Magnitude
	maxDist, minDist = math.max(maxDist, d), math.min(minDist, d)
	behaviours[U.MouseBehavior.Name] = true
end
con:Disconnect()
local names = {}
for k in behaviours do table.insert(names, k) end
local g = me.PlayerGui.HT_LockOnMarker
return string.format("%d frames | camera turn max %.0f deg/s, reversals %d, move max %.0f studs/s | them %d%% from centre, off screen %d | body spin max %.0f deg/s | camera distance %.1f to %.1f | mouse %s, changed %d times | shift %s gold %s | me at %s", frames, yawJerk, flips, posJerk, maxOff * 100, off, faceSpin, minDist, maxDist, table.concat(names, "+"), mouseChanges, tostring(me:GetAttribute("HT_ShiftLocked")), tostring(g.Layer2.ImageColor3.B < 0.5), tostring(root.Position))
'''

TRACE = '''
local me = game.Players.LocalPlayer
local U = game:GetService("UserInputService")
local log = {}
local function add(text)
	table.insert(log, string.format("%.2f %s", os.clock() % 1000, text))
	workspace:SetAttribute("HT_TraceLog", table.concat(log, "\n"):sub(-2500))
end
if _G.HT_Trace then for _, c in _G.HT_Trace do c:Disconnect() end end
_G.HT_Trace = {
	me:GetAttributeChangedSignal("HT_ShiftLocked"):Connect(function() add("SHIFT -> " .. tostring(me:GetAttribute("HT_ShiftLocked"))) end),
	U.InputBegan:Connect(function(i, gp) if i.UserInputType == Enum.UserInputType.Keyboard or i.UserInputType.Name:find("MouseButton") then add("begin " .. (i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name or i.UserInputType.Name)) end end),
	U.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Keyboard then add("end " .. i.KeyCode.Name) end end),
	U.WindowFocusReleased:Connect(function() add("WINDOW FOCUS LOST, mouse " .. U.MouseBehavior.Name) end),
	U.WindowFocused:Connect(function() add("WINDOW FOCUSED, mouse " .. U.MouseBehavior.Name) end),
}
add("trace on")
return "tracing"
'''

def sample(seconds):
    return luau(SAMPLE.replace("SECONDS", str(seconds)))

def run_case(label, use_shift):
    print("==", label)
    print(luau(SETUP))
    time.sleep(0.6)
    shifted = "true" in luau('return tostring(game.Players.LocalPlayer:GetAttribute("HT_ShiftLocked"))')
    if shifted != use_shift:
        press("LeftShift")
    press("LeftAlt")
    print("locked:", luau('local g = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker; return tostring(g.Adornee ~= nil and g.Layer2.ImageColor3.B < 0.5)'))
    print(luau(FREE))
    time.sleep(0.5)
    print("standing:", sample(1.5))
    result = {}
    t = threading.Thread(target=lambda: result.update(run=sample(2.5)))
    t.start()
    time.sleep(0.3)
    keys({"action": "keyDown", "key_code": "D"}, {"action": "wait", "wait_time_ms": 1500}, {"action": "keyUp", "key_code": "D"})
    t.join()
    print("strafing D:", result["run"])
    print(luau('local r = game.Players.LocalPlayer.Character.HumanoidRootPart; r.AssemblyLinearVelocity = Vector3.zero; return "reset"'))
    press("LeftAlt")
    time.sleep(0.5)
    if use_shift:
        press("LeftShift")

print(luau(PARK, "Server"))
time.sleep(1)
if len(sys.argv) > 1 and sys.argv[1] == "setup":
    # For real keys sent from outside: a dummy, you pinned, and the camera looking at it.
    print(luau(SETUP))
    print(luau(TRACE))
    sys.exit()
if len(sys.argv) > 1 and sys.argv[1] == "free":
    print(luau(FREE))
    sys.exit()
run_case("no shift lock", False)
run_case("shift lock on first", True)
print(luau('local d = workspace:FindFirstChild("HT_D"); if d then d:Destroy() end; return "dummy gone"'))
print(luau(PARK.replace("m.HumanoidRootPart.Anchored = true", "m.HumanoidRootPart.Anchored = false").replace("m.HumanoidRootPart.CFrame = CFrame.new(70, 103, 70)", ""), "Server"))
