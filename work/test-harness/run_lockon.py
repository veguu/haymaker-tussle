# python run_lockon.py <setup|read|lock|rest> : drives the lock-on marker in Play with real Alt presses,
# against test dummies that only exist on this client. Nothing here is part of the game.
import json, os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")

def luau(code):
    return subprocess.run([sys.executable, M, "luau", "--dm", "Client", "--code", code], capture_output=True, text=True).stdout.strip()

def keys(*acts):
    subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": list(acts), "datamodel_type": "Client"})], capture_output=True, text=True)

def tap(key="LeftAlt"):
    keys({"action": "keyPress", "key_code": key})
    time.sleep(0.5)

STATE = r'''
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("HT_LockOnMarker")
local function txt(c) return string.format("%02X%02X%02X", c.R*255+0.5, c.G*255+0.5, c.B*255+0.5) end
if not gui then return "NO GUI" end
local outer, inner, dia, fill, pulse = gui.Layer2, gui.Layer3, gui.Layer4, gui.Layer5, gui.Layer1
local a = gui.Adornee
return string.format("on=%s on-%s colour=%s outerShare=%.3f innerOp=%.2f diaShare=%.3f diaOp=%.2f fillOp=%.2f pulseOp=%.2f guiPx=%.0f", tostring(gui.Enabled), a and a.Parent.Name or "nobody", txt(outer.ImageColor3), outer.Size.X.Scale, 1-inner.ImageTransparency, dia.Size.X.Scale, 1-dia.ImageTransparency, 1-fill.ImageTransparency, 1-pulse.ImageTransparency, gui.AbsoluteSize.X)
'''

SETUP = r'''
local me = game.Players.LocalPlayer
local ch = me.Character
ch.Archivable = true
local CS = game:GetService("CollectionService")
local function dummy(name, at)
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
	local m = ch:Clone()
	m.Name = name
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
	end
	m.HumanoidRootPart.Anchored = true
	m.HumanoidRootPart.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
	m.Parent = workspace
	CS:AddTag(m, "HT_Combatant")
	return m
end
dummy("HT_TestA", Vector3.new(0, 103, -30))
-- First person, so your own body isn't in the shot, straight on as the concept shows it. The Follow camera
-- swings back to where you face, and Studio's tool resets a Scriptable one, so it's held here every frame.
me.CameraMaxZoomDistance = 0.5
me.CameraMinZoomDistance = 0.5
workspace:SetAttribute("HT_TestLook", Vector3.new(0, 103, -30))
local Run = game:GetService("RunService")
pcall(function() Run:UnbindFromRenderStep("HT_TestCam") end)
Run:BindToRenderStep("HT_TestCam", Enum.RenderPriority.Camera.Value + 1, function()
	local body = me.Character
	local r = body and body:FindFirstChild("HumanoidRootPart")
	local h = body and body:FindFirstChildOfClass("Humanoid")
	if r and h and h.Health > 0 then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(Vector3.new(0, 103, -21), Vector3.new(0, 103, -30))
	end
	workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 104.5, -21), workspace:GetAttribute("HT_TestLook"))
end)
return "ready"
'''

stage = sys.argv[1]
if stage == "setup":
    print(luau(SETUP))
    time.sleep(0.8)
    print("candidate:", luau(STATE))
elif stage == "front":
    # The capture tool leaves out AlwaysOnTop gui, so on this client only: in front of the body and
    # shrunk by the same perspective, which keeps its apparent size true.
    print(luau(r'''
local gui = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker
if not gui.Adornee then return "nobody" end
local d = (workspace.CurrentCamera.CFrame.Position - gui.Adornee.Position).Magnitude
local keep = (d - 3) / d
gui.AlwaysOnTop = false
gui.StudsOffsetWorldSpace = Vector3.new(0, 0, 3)
gui.Size = UDim2.fromScale(gui.Size.X.Scale * keep, gui.Size.Y.Scale * keep)
return "distance " .. d .. " keep " .. keep
'''))
elif stage == "unfront":
    print(luau(r'''
local gui = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker
gui.AlwaysOnTop = true
gui.StudsOffsetWorldSpace = Vector3.zero
return "restored"
'''))
elif stage == "lock":
    print("before:", luau(STATE))
    tap()
    print("after Alt:", luau(STATE))
elif stage == "spin":
    print(luau(r'''
local gui = game.Players.LocalPlayer.PlayerGui.HT_LockOnMarker
local Run = game:GetService("RunService")
local o, i = gui.Layer2, gui.Layer3
local function diff(a, b) return (b - a + 540) % 360 - 180 end
local turnedO, turnedI, lastO, lastI = 0, 0, o.Rotation, i.Rotation
local start = os.clock()
while os.clock() - start < 3 do
	Run.Heartbeat:Wait()
	turnedO += diff(lastO, o.Rotation); lastO = o.Rotation
	turnedI += diff(lastI, i.Rotation); lastI = i.Rotation
end
local t = os.clock() - start
return string.format("outer %.2f s per turn (sign %d), inner %.2f s per turn (sign %d)", 360/math.abs(turnedO/t), math.sign(turnedO), 360/math.abs(turnedI/t), math.sign(turnedI))
'''))
elif stage == "rest":
    print("selected at start:", luau(STATE))
    # Holding Alt only counts once.
    keys({"action": "keyDown", "key_code": "LeftAlt"}, {"action": "wait", "wait_time_ms": 1500})
    print("holding Alt 1.5 s:", luau(STATE))
    keys({"action": "keyUp", "key_code": "LeftAlt"})
    time.sleep(0.5)
    print("released once (unlock):", luau(STATE))
    # Alt+Tab doesn't count.
    keys({"action": "keyDown", "key_code": "LeftAlt"}, {"action": "keyPress", "key_code": "Tab"}, {"action": "keyUp", "key_code": "LeftAlt"})
    time.sleep(0.5)
    print("after Alt+Tab keys:", luau(STATE))
    tap()
    print("selected again:", luau(STATE))
    # Looking away keeps a selection.
    luau('workspace:SetAttribute("HT_TestLook", Vector3.new(60, 103, -21))')
    time.sleep(0.6)
    print("looked away, still selected:", luau(STATE))
    # A second target doesn't take the selection.
    luau(r'''
local ch = game.Players.LocalPlayer.Character
ch.Archivable = true
local m = workspace.HT_TestA:Clone()
m.Name = "HT_TestB"
m:PivotTo(CFrame.new(40, 103, -21))
m.Parent = workspace
game:GetService("CollectionService"):AddTag(m, "HT_Combatant")
''')
    time.sleep(0.6)
    print("looking straight at B while A is selected:", luau(STATE))
    tap()
    print("Alt on selected A, looking at B (unlock, then moves to B):", luau(STATE))
    time.sleep(0.5)
    print("0.5 s later:", luau(STATE))
    tap()
    print("selects B:", luau(STATE))
    tap()
    # Nobody in view: Alt does nothing.
    luau('workspace:SetAttribute("HT_TestLook", Vector3.new(-60, 103, -60))')
    time.sleep(0.8)
    print("nobody in view:", luau(STATE))
    tap()
    print("Alt with nobody:", luau(STATE))
    # A wall hides a candidate at once, and a selection after LostSightSeconds.
    luau('workspace:SetAttribute("HT_TestLook", Vector3.new(0, 103, -30))')
    time.sleep(0.6)
    tap()
    print("selected A:", luau(STATE))
    luau(r'''
local p = Instance.new("Part")
p.Name = "HT_TestWallPart"
p.Anchored = true
p.Size = Vector3.new(12, 12, 1)
p.Position = Vector3.new(0, 103, -25)
p.Parent = workspace
''')
    time.sleep(0.5)
    print("behind a wall 0.5 s, still selected:", luau(STATE))
    time.sleep(1.6)
    print("behind a wall 2.1 s, let go:", luau(STATE))
    luau('workspace.HT_TestWallPart:Destroy()')
    time.sleep(0.6)
    print("wall gone, candidate again:", luau(STATE))
    tap()
    # Dying, and disappearing.
    luau('workspace.HT_TestA.Humanoid.Health = 0')
    time.sleep(0.5)
    print("selected target died:", luau(STATE))
    luau('workspace.HT_TestA:Destroy()')
    luau('workspace:SetAttribute("HT_TestLook", Vector3.new(40, 103, -21))')
    time.sleep(0.6)
    print("looking at B:", luau(STATE))
    tap()
    luau('workspace.HT_TestB:Destroy()')
    time.sleep(0.5)
    print("selected target vanished:", luau(STATE))
elif stage == "respawn":
    # Your own death ends everything, and it works again after.
    luau(r'''
local ch = game.Players.LocalPlayer.Character
ch.Archivable = true
local m = workspace:FindFirstChild("HT_TestC") or ch:Clone()
m.Name = "HT_TestC"
for _, d in m:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
m.HumanoidRootPart.Anchored = true
m:PivotTo(CFrame.new(0, 103, -30))
m.Parent = workspace
game:GetService("CollectionService"):AddTag(m, "HT_Combatant")
workspace:SetAttribute("HT_TestLook", Vector3.new(0, 103, -30))
''')
    time.sleep(0.6)
    tap()
    print("selected before dying:", luau(STATE))
    luau('game.Players.LocalPlayer.Character.Humanoid.Health = 0')
    time.sleep(0.6)
    print("just died:", luau(STATE))
    time.sleep(7)
    luau('workspace:SetAttribute("HT_TestLook", Vector3.new(0, 103, -30))')
    time.sleep(0.8)
    print("respawned, looking at target:", luau(STATE))
    tap()
    print("Alt after respawn:", luau(STATE))
    tap()
    luau('workspace.HT_TestC:Destroy(); local me = game.Players.LocalPlayer; me.CameraMaxZoomDistance = 40; me.CameraMinZoomDistance = 0.5; game:GetService("RunService"):UnbindFromRenderStep("HT_TestCam")')
    print("cleaned up")
