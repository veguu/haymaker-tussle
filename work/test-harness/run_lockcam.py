# python run_lockcam.py <stage> [args] : tests the lock-on camera in Play with real keys, against dummies that only
# exist on this client. The bot is anchored out of the way by `prep` and put back by `done`. Not part of the game.
import json, os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

def keys(*acts):
    subprocess.run([sys.executable, M, "call", "user_keyboard_input", json.dumps({"actions": list(acts), "datamodel_type": "Client"})], capture_output=True, text=True)

def alt():
    keys({"action": "keyPress", "key_code": "LeftAlt"})
    time.sleep(0.5)

STATE = r'''
local me = game.Players.LocalPlayer
local g = me.PlayerGui.HT_LockOnMarker
local c = g.Layer2.ImageColor3
local cam = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local x, y, z = cam.CFrame:ToOrientation()
local a = g.Adornee
return string.format("marker %s on %s %s guiPx=%.0f ringPx=%.0f | cam pitch %.0f yaw %.0f roll %.2f dist %.1f | mouse %s icon %s | viewport %.0fx%.0f", g.Enabled and "SHOWN" or "hidden", a and a.Parent.Name or "nobody", c.B < 0.5 and "GOLD" or "white", g.AbsoluteSize.X, g.Layer2.AbsoluteSize.X * 112/144, math.deg(x), math.deg(y), math.deg(z), (cam.CFrame.Position - me.Character.HumanoidRootPart.Position).Magnitude, UIS.MouseBehavior.Name, tostring(UIS.MouseIconEnabled), cam.ViewportSize.X, cam.ViewportSize.Y)
'''

DUMMY = r'''
local me = game.Players.LocalPlayer
local ch = me.Character
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
pcall(function() Run:UnbindFromRenderStep("HT_TestAim") end)
local old = workspace:FindFirstChild("HT_D")
if old then old:Destroy() end
ch.Archivable = true
local m = ch:Clone()
m.Name = "HT_D"
for _, d in m:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
end
m.HumanoidRootPart.Anchored = true
local at = Vector3.new(0, 103, 40 - DISTANCE)
m.HumanoidRootPart.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
m.Parent = workspace
CS:AddTag(m, "HT_Combatant")
-- A one-off teleport doesn't always stick, so you're pinned here every frame until `done`.
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local body = me.Character
	local r = body and body:FindFirstChild("HumanoidRootPart")
	local h = body and body:FindFirstChildOfClass("Humanoid")
	if r and h and h.Health > 0 then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(Vector3.new(0, 103, 40), Vector3.new(0, 103, 0))
	end
end)
-- Looks at them, until the lock takes over.
Run:BindToRenderStep("HT_TestAim", Enum.RenderPriority.Camera.Value + 2, function()
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 110, 54), m.HumanoidRootPart.Position)
end)
return "dummy at " .. DISTANCE
'''

UNAIM = 'game:GetService("RunService"):UnbindFromRenderStep("HT_TestAim")'

# Moves the dummy by a path for some seconds, sampling the camera every frame. SPIN slows the frame rate.
TRACK = r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local d = workspace.HT_D.HumanoidRootPart
local torso = workspace.HT_D.Torso
local myRoot = me.Character.HumanoidRootPart
local cam = workspace.CurrentCamera
local start = os.clock()
local home = d.Position
local function path(t) PATH end
local spin = SPIN
local spinner = spin > 0 and Run.RenderStepped:Connect(function()
	local u = os.clock()
	while os.clock() - u < spin do end
end) or nil
local frames, maxYaw, maxPitch, maxRoll, maxOff, offScreen, meOff, flips = 0, 0, 0, 0, 0, 0, 0, 0
local lastYaw, lastPitch, lastStep = nil, nil, nil
local maxJump = 0
local lastPos = cam.CFrame.Position
while os.clock() - start < SECONDS do
	local dt = Run.RenderStepped:Wait()
	local t = os.clock() - start
	d.CFrame = CFrame.new(home + path(t))
	local pitch, yaw, roll = cam.CFrame:ToOrientation()
	frames += 1
	maxRoll = math.max(maxRoll, math.abs(math.deg(roll)))
	if lastYaw then
		local step = (yaw - lastYaw + math.pi) % (2 * math.pi) - math.pi
		maxYaw = math.max(maxYaw, math.abs(math.deg(step)) / dt)
		maxPitch = math.max(maxPitch, math.abs(math.deg(pitch - lastPitch)) / dt)
		if lastStep and step * lastStep < 0 and math.abs(math.deg(step)) / dt > 15 and math.abs(math.deg(lastStep)) / dt > 15 then flips += 1 end
		lastStep = step
	end
	lastYaw, lastPitch = yaw, pitch
	maxJump = math.max(maxJump, (cam.CFrame.Position - lastPos).Magnitude / dt)
	lastPos = cam.CFrame.Position
	local p, on = cam:WorldToViewportPoint(torso.Position)
	local size = cam.ViewportSize
	if not on then offScreen += 1 end
	maxOff = math.max(maxOff, math.abs(p.X - size.X/2) / (size.X/2), math.abs(p.Y - size.Y/2) / (size.Y/2))
	local q, onMe = cam:WorldToViewportPoint(myRoot.Position)
	if not onMe then meOff += 1 end
end
if spinner then spinner:Disconnect() end
local t = os.clock() - start
d.CFrame = CFrame.new(home)
return string.format("%.0f fps: fastest yaw %.0f deg/s, pitch %.0f deg/s; roll max %.2f; them furthest %.0f%% from centre, off screen %d frames; you off screen %d frames; direction reversals %d; camera speed max %.0f studs/s", frames/t, maxYaw, maxPitch, maxRoll, maxOff*100, offScreen, meOff, flips, maxJump)
'''

def track(path, seconds, spin=0):
    code = TRACK.replace("PATH", path).replace("SECONDS", str(seconds)).replace("SPIN", str(spin))
    print(luau(code))
    state = luau(STATE)
    print("   still locked:", "GOLD" in state, "|", state.split("|")[1].strip())

stage = sys.argv[1]
if stage == "prep":
    print(luau(r'''
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) then
		m.HumanoidRootPart.Anchored = true
		m.HumanoidRootPart.CFrame = CFrame.new(70, 103, 70)
	end
end
return "bot parked"
''', "Server"))
    print(luau('game.Players.LocalPlayer.CameraMaxZoomDistance = 400; game.Players.LocalPlayer.CameraMinZoomDistance = 0.5; return "zoom ok"'))
elif stage == "size":
    # Selects a dummy at this distance and leaves it selected, for a screenshot.
    if "GOLD" in luau(STATE):
        alt()
        time.sleep(0.6)
    print(luau(DUMMY.replace("DISTANCE", sys.argv[2])))
    time.sleep(0.6)
    print("white:", luau(STATE))
    alt()
    luau(UNAIM)
    time.sleep(1.2)
    print("gold: ", luau(STATE))
elif stage == "unlock":
    alt()
    print("0.5 s after Alt:", luau(STATE))
    time.sleep(0.6)
    print("1.1 s after Alt:", luau(STATE))
elif stage == "dark":
    print(luau(r'''
local p = workspace:FindFirstChild("HT_TestDark") or Instance.new("Part")
p.Name = "HT_TestDark"
p.Anchored = true
p.CanCollide = false
p.Size = Vector3.new(60, 40, 1)
p.Color = Color3.new(0.02, 0.02, 0.03)
p.Material = Enum.Material.SmoothPlastic
p.Position = workspace.HT_D.HumanoidRootPart.Position + Vector3.new(0, 8, -6)
p.Parent = workspace
return "black wall behind them"
'''))
elif stage == "undark":
    print(luau('local p = workspace:FindFirstChild("HT_TestDark"); if p then p:Destroy() end; return "gone"'))
elif stage == "track":
    spin = float(sys.argv[2]) if len(sys.argv) > 2 else 0
    print("-- side to side, 30 studs each way, about 60 studs/s peak")
    track("return Vector3.new(math.sin(t * 2) * 30, 0, 0)", 4, spin)
    print("-- launched: up 57 studs and back down")
    track("local u = (t % 3) / 3; return Vector3.new(0, 57 * 4 * u * (1 - u), 0)", 4, spin)
elif stage == "cross":
    print("-- runs past you and round behind you, close by")
    track("local a = t * 1.2; return Vector3.new(math.sin(a) * 12, 0, 40 - 12 * math.cos(a) - home.Z)", 5.2)
    print("-- straight overhead")
    track("local a = math.min(t / 1.2, 1); return Vector3.new(0, 40 * a, (40 + 0.5 * math.sin(t * 3) - home.Z) * a)", 3.5)
elif stage == "sight":
    wall = r'''
local d = workspace.HT_D.HumanoidRootPart
local p = Instance.new("Part")
p.Name = "HT_TestWall"
p.Anchored = true
p.Size = Vector3.new(40, 40, 1)
p.Position = d.Position + Vector3.new(0, 0, 5)
p.Parent = workspace
return "wall up"
'''
    print(luau(wall))
    time.sleep(0.08)
    print("wall, 0.1 s:", luau(STATE))
    # They move while hidden: the camera mustn't follow.
    before = luau('local _, y = workspace.CurrentCamera.CFrame:ToOrientation(); workspace.HT_D.HumanoidRootPart.CFrame += Vector3.new(14, 0, 0); return string.format("%.2f", math.deg(y))')
    time.sleep(0.25)
    after = luau('local _, y = workspace.CurrentCamera.CFrame:ToOrientation(); return string.format("%.2f", math.deg(y))')
    print(f"they moved 14 studs while hidden: camera yaw {before} then {after}")
    luau('workspace.HT_D.HumanoidRootPart.CFrame -= Vector3.new(14, 0, 0); workspace.HT_TestWall.Parent = nil')
    time.sleep(0.25)
    print("back in sight within the grace:", luau(STATE))
    time.sleep(0.4)
    luau('local p = Instance.new("Part"); p.Name = "HT_TestWall2"; p.Anchored = true; p.Size = Vector3.new(40, 40, 1); p.Position = workspace.HT_D.HumanoidRootPart.Position + Vector3.new(0, 0, 5); p.Parent = workspace')
    time.sleep(1.2)
    print("hidden past the grace, let go:", luau(STATE))
    luau('workspace.HT_TestWall2:Destroy()')
    time.sleep(0.5)
    print("wall gone:", luau(STATE))
elif stage == "collide":
    print(luau(r'''
local me = game.Players.LocalPlayer
local root = me.Character.HumanoidRootPart
local p = Instance.new("Part")
p.Name = "HT_TestBack"
p.Anchored = true
p.Size = Vector3.new(60, 60, 1)
p.Position = root.Position + Vector3.new(0, 0, 6)
p.Parent = workspace
task.wait(0.6)
local cam = workspace.CurrentCamera.CFrame.Position
local behind = cam.Z > p.Position.Z
p:Destroy()
task.wait(1.5)
local away = (workspace.CurrentCamera.CFrame.Position - root.Position).Magnitude
return string.format("wall 6 studs behind you: camera z %.1f, wall z %.1f, through it: %s; %.1f from you once it's gone", cam.Z, p.Position.Z, tostring(behind), away)
'''))
elif stage == "hold":
    keys({"action": "keyDown", "key_code": "LeftAlt"}, {"action": "wait", "wait_time_ms": 1500})
    print("holding Alt:", luau(STATE))
    keys({"action": "keyUp", "key_code": "LeftAlt"})
    time.sleep(0.5)
    print("let go once:", luau(STATE))
    alt()
    print("Alt again:", luau(STATE))
elif stage == "die":
    print("before:", luau(STATE))
    luau('game.Players.LocalPlayer.Character.Humanoid.Health = 0')
    time.sleep(0.7)
    print("just died:", luau(STATE))
    time.sleep(7)
    print("respawned:", luau(STATE))
elif stage == "shift":
    # The two locks together. Shift is the stock toggle, so real keys through the tool reach it.
    Q = '''
local me = game.Players.LocalPlayer
local U = game:GetService("UserInputService")
local g = me.PlayerGui.HT_LockOnMarker
local dot = me.PlayerGui.HT_ShiftLockDot.Dot
return string.format("camera lock %s | shift lock %s | mouse %s | cursor %s | dot %s", tostring(g.Layer2.ImageColor3.B < 0.5 and g.Adornee ~= nil), tostring(me:GetAttribute("HT_ShiftLocked")), U.MouseBehavior.Name, tostring(U.MouseIconEnabled), tostring(dot.Visible))
'''
    def shift():
        keys({"action": "keyPress", "key_code": "LeftShift"})
        time.sleep(0.4)
    def lock():
        alt()
        time.sleep(0.5)
    print("start:                   ", luau(Q))
    print(luau(DUMMY.replace("DISTANCE", "25")))
    time.sleep(0.6)
    if "shift lock true" in luau(Q):
        shift()
    print("-- 1. off, lock, unlock")
    print("off:                     ", luau(Q))
    lock(); luau(UNAIM)
    print("camera locked:           ", luau(Q))
    lock()
    print("unlocked:                ", luau(Q))
    print("-- 2. Shift during camera lock does nothing")
    luau(DUMMY.replace("DISTANCE", "25")); time.sleep(0.6)
    lock(); luau(UNAIM)
    shift()
    print("locked, pressed Shift:   ", luau(Q))
    lock()
    print("unlocked:                ", luau(Q))
    print("-- 3. shift lock on first, it comes back")
    shift()
    print("shift lock on:           ", luau(Q))
    luau(DUMMY.replace("DISTANCE", "25")); time.sleep(0.6)
    lock(); luau(UNAIM)
    print("camera locked too:       ", luau(Q))
    lock()
    print("unlocked, still shift:   ", luau(Q))
    shift()
    print("shift lock off (the bug):", luau(Q))
    print("-- 4. right-click during camera lock can't save a stuck mouse")
    luau(DUMMY.replace("DISTANCE", "25")); time.sleep(0.6)
    lock(); luau(UNAIM)
    keys({"action": "keyPress", "key_code": "MouseRightButton"})
    time.sleep(0.2)
    lock()
    print("unlocked:                ", luau(Q))
    shift(); shift()
    print("shift on then off:       ", luau(Q))
elif stage == "done":
    print(luau('''
local Run = game:GetService("RunService")
pcall(function() Run:UnbindFromRenderStep("HT_TestAim") end)
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
for _, n in {"HT_D", "HT_TestDark", "HT_TestWall", "HT_TestWall2", "HT_TestBack"} do
	local d = workspace:FindFirstChild(n)
	if d then d:Destroy() end
end
return "client test parts gone"
'''))
    print(luau(r'''
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) then
		m.HumanoidRootPart.Anchored = false
	end
end
return "bot free"
''', "Server"))
