# Every training station, in real play, with real keys and clicks. Studio must be in Play. It moves your
# character the whole time. python training_suite.py [station letters, default ABCDEFGX]
# X is the rest: dummy replaced, respawn in training, leaving, and whether anything ever attacked.
import sys, time
from run_training import luau, call, click, key, press

HUB_X = 370


def wait(seconds):
    time.sleep(seconds)


def stand(name, studs=8.0, side=0.0):
    """Stands this far on the hub side of a dummy, really facing it: a heading only changes by walking."""
    print(luau(r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer.Character
local root = me.HumanoidRootPart
local target = workspace:FindFirstChild("%s")
if not target then return "no target" end
local t = target.HumanoidRootPart.Position
local toward = -Vector3.new(t.X - %d, 0, t.Z).Unit
local right = Vector3.new(-toward.Z, 0, toward.X)
local at = t + toward * %s + right * %s
at = Vector3.new(at.X, 103, at.Z)
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.lookAt(at, Vector3.new(t.X, 103, t.Z))
local cam = workspace.CurrentCamera
pcall(function() Run:UnbindFromRenderStep("HT_View") end)
Run:BindToRenderStep("HT_View", Enum.RenderPriority.Camera.Value + 1, function()
	local r = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if r then
		cam.CameraType = Enum.CameraType.Scriptable
		local look = Vector3.new(t.X, 103, t.Z) - at
		cam.CFrame = CFrame.lookAt(r.Position - look.Unit * 14 + Vector3.yAxis * 7, r.Position + look.Unit * 10)
	end
end)
return "standing"
''' % (name, HUB_X, studs, side)))
    wait(0.3)
    call("user_keyboard_input", {"datamodel_type": "Client", "actions": [
        {"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": 90}, {"action": "keyUp", "key_code": "W"}]})
    wait(0.6)
    # Back to the exact spot, still facing the way the tap turned it.
    luau(r'''
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
local t = workspace:FindFirstChild("%s").HumanoidRootPart.Position
local toward = -Vector3.new(t.X - %d, 0, t.Z).Unit
local right = Vector3.new(-toward.Z, 0, toward.X)
local at = t + toward * %s + right * %s
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.new(at.X, 103, at.Z) * root.CFrame.Rotation
return "ok"
''' % (name, HUB_X, min(studs, 5), side))
    wait(0.2)


def combo(name):
    """Left, right, uppercut on one dummy. Each hit knocks it away, so this catches up between swings, as a
    player would with a run or a propel."""
    for _ in range(3):
        luau(r'''
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
local t = workspace:FindFirstChild("%s").HumanoidRootPart.Position
local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
local at = t - look * 4
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.new(at.X, 103, at.Z) * root.CFrame.Rotation
return "ok"
''' % name)
        click(1, 60)
        wait(0.45)


def snap(name):
    return luau(r'''
local m = workspace:FindFirstChild("%s")
if not m then return "gone" end
local r = m.HumanoidRootPart
return string.format("(%%.0f, %%.1f, %%.0f) speed %%.0f stagger %%s air %%s stun %%s", r.Position.X, r.Position.Y, r.Position.Z, r.AssemblyLinearVelocity.Magnitude, tostring(m:GetAttribute("HT_Stagger")), tostring(m:GetAttribute("HT_Air")), tostring(m:GetAttribute("HT_Stunned")))
''' % name, "Server")


def watch(name, seconds):
    """How far and how high a dummy goes, sampled on the server. Sits apart from the clicks."""
    return luau(r'''
local m = workspace:FindFirstChild("%s")
local r = m.HumanoidRootPart
local s = r.Position
local far, high, t0, jumped = 0, 0, os.clock(), false
local last = s
while os.clock() - t0 < %s do
	if (r.Position - last).Magnitude > 30 then jumped = true end
	last = r.Position
	if not jumped then
		far = math.max(far, (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(s.X, 0, s.Z)).Magnitude)
		high = math.max(high, r.Position.Y - s.Y)
	end
	game:GetService("RunService").Heartbeat:Wait()
end
return string.format("far %%.1f high %%.1f sent home %%s", far, high, tostring(jumped))
''' % (name, seconds), "Server")


def panel():
    return luau(r'''
local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("HT_TrainingPanel")
if not g then return "no panel" end
local out = {}
for _, d in g:GetDescendants() do
	if d:IsA("TextLabel") and d.Text ~= "" then
		table.insert(out, (d.Text:gsub("<[^>]+>", "")))
	end
end
return table.concat(out, " | ") .. " | enabled " .. tostring(g.Enabled)
''')


def enter():
    print("in training:", luau('return tostring(game.Players.LocalPlayer:GetAttribute("HT_InTraining"))'))
    if "true" not in luau('return tostring(game.Players.LocalPlayer:GetAttribute("HT_InTraining"))'):
        print(press("TRAINING"))
        wait(1)


def station_a():
    print("=== A: M1 practice")
    print("start  ", snap("M1 Dummy 2"))
    stand("M1 Dummy 2")
    click(1, 100)
    wait(0.5)
    print("one M1 ", snap("M1 Dummy 2"))
    print(panel())
    stand("M1 Dummy 3")
    combo("M1 Dummy 3")
    print("combo  ", snap("M1 Dummy 3"))
    print(panel())
    wait(8)
    print("8 s on, should be home at stagger 0:", snap("M1 Dummy 3"))


def station_c():
    print("=== C: stagger comparison: one hook, from the same distance, standing")
    for name in ("Low stagger", "Medium stagger", "Max stagger"):
        print("start  ", name, snap(name))
        stand(name)
        import threading
        out = {}
        t = threading.Thread(target=lambda: out.update(r=watch(name, 3)))
        t.start()
        click(1, 100)
        t.join()
        print("  hit  ", out["r"], "|", panel())
        wait(5)
        print("  after", snap(name))


def station_d():
    print("=== D: hitbox target, stationary. Four marks, one swing each from the marks' real positions")
    print("start  ", snap("Hitbox Target"))
    for label, studs, side in (("front", 5.5, 0), ("off-centre", 5.0, 1.5), ("overlap", 1.5, 0), ("beside", 3.0, 2.0)):
        stand("Hitbox Target", 8, side)
        luau(r'''
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
local t = workspace:FindFirstChild("Hitbox Target").HumanoidRootPart.Position
local toward = -Vector3.new(t.X - 370, 0, t.Z).Unit
local right = Vector3.new(-toward.Z, 0, toward.X)
local at = t + toward * %s + right * %s
root.AssemblyLinearVelocity = Vector3.zero
root.CFrame = CFrame.new(at.X, 103, at.Z) * root.CFrame.Rotation
return "ok"
''' % (studs, side))
        wait(0.2)
        click(1, 450)
        wait(0.6)
        print(f"  {label:10}", snap("Hitbox Target"))
    print("  past reach, 8 studs:")
    stand("Hitbox Target", 8)
    luau(r'''
local root = game.Players.LocalPlayer.Character.HumanoidRootPart
local t = workspace:FindFirstChild("Hitbox Target").HumanoidRootPart.Position
local toward = -Vector3.new(t.X - 370, 0, t.Z).Unit
local at = t + toward * 8
root.CFrame = CFrame.new(at.X, 103, at.Z) * root.CFrame.Rotation
root.AssemblyLinearVelocity = Vector3.zero
return "ok"
''')
    click(1, 450)
    wait(0.5)
    print("  ", snap("Hitbox Target"))
    print(press("Hitboxes"))
    wait(0.5)
    print("  hitboxes:", luau('local h=workspace:FindFirstChild("HT_HitboxDebug") return h and tostring(#h:GetChildren()) or "none"'), panel())
    press("Hitboxes")
    print(press("Target: stationary"))
    wait(1.5)
    print("  switched to physics:", snap("Hitbox Target"))
    stand("Hitbox Target")
    click(1, 100)
    wait(0.4)
    print("  physics hit:", snap("Hitbox Target"))
    wait(6)
    print(press("Target: stationary"))
    wait(1)
    print("  back to stationary:", snap("Hitbox Target"))


def station_e():
    print("=== E: moving target at each speed, then a hit")
    for _ in range(3):
        wait(0.2)
        print("  speed reading:", luau(r'''
local m = workspace:FindFirstChild("Moving Dummy")
local r = m.HumanoidRootPart
local top = 0
local t0 = os.clock()
local xs = {}
while os.clock() - t0 < 2.5 do
	top = math.max(top, Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude)
	game:GetService("RunService").Heartbeat:Wait()
end
return string.format("top %.0f", top)
''', "Server"))
        print("  ", press_speed())
        wait(0.5)
    print("  before", snap("Moving Dummy"))
    stand("Moving Dummy", 7)
    click(2, 100)
    wait(0.4)
    print("  hit   ", snap("Moving Dummy"))
    wait(4)
    print("  later ", snap("Moving Dummy"))


def press_speed():
    press("Speed: Medium")
    wait(0.3)
    label = luau(r'''
for _, d in workspace.HT_Training:GetDescendants() do
	if d:IsA("TextLabel") and string.sub(d.Text, 1, 6) == "Speed:" then return d.Text end
end
return "?"
''')
    return f"walked on -> {label}"


def face_home():
    # Keys are camera-relative, so the camera looks at the platform whatever else it was doing.
    luau(r'''
local Run = game:GetService("RunService")
local cam = workspace.CurrentCamera
local c = Vector3.new(525.9, 103, -90)
pcall(function() Run:UnbindFromRenderStep("HT_View") end)
Run:BindToRenderStep("HT_View", Enum.RenderPriority.Camera.Value + 1, function()
	local r = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if r then
		cam.CameraType = Enum.CameraType.Scriptable
		local flat = Vector3.new(c.X - r.Position.X, 0, c.Z - r.Position.Z)
		local toward = if flat.Magnitude > 1 then flat.Unit else Vector3.xAxis
		cam.CFrame = CFrame.lookAt(r.Position - toward * 14 + Vector3.yAxis * 8, r.Position + toward * 10)
	end
end)
return "camera"
''')


def station_f():
    print("=== F: launch pads")
    face_home()
    for name, react in (("Close uppercut", True), ("Far uppercut", True), ("Very far uppercut", True), ("Close drift", True), ("Far drift", True), ("Close uppercut", False)):
        print(press(name))
        if react:
            wait(0.1)
            call("user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": "keyDown", "key_code": "W"}]})
            click(10, 130)
            call("user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": "keyUp", "key_code": "W"}]})
        wait(4.5)
        print(f"  {name} (input {react}):", panel().split(" | Recovery")[-1][:60], "|", luau('local r=game.Players.LocalPlayer.Character.HumanoidRootPart return string.format("at (%.0f, %.1f, %.0f) stagger %s", r.Position.X, r.Position.Y, r.Position.Z, tostring(r.Parent:GetAttribute("HT_Stagger")))'))


KICK = r'''
-- Times the ring, on the server's own rule, for a chosen grade. Sends no jump: that's the real Space.
local GRADE = "%s"
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer.Character
local target = workspace:FindFirstChild("Kick Dummy")
local log = {}
local lockedAt, pressed = nil, false
local t0 = os.clock()
local home = target.HumanoidRootPart.Position
local top = 0
local conn
conn = Run.Heartbeat:Connect(function()
	local skill = me:GetAttribute("HT_Skill")
	top = math.max(top, target.HumanoidRootPart.Position.Y - 103)
	if skill == "attach" then
		lockedAt = lockedAt or os.clock()
		local at = me:GetAttribute("HT_KickAt")
		if at and not pressed and GRADE ~= "red" then
			local off = if GRADE == "orange" then 0.085 else 0
			if os.clock() - lockedAt >= at + off then
				pressed = true
				net.KickCommit:FireServer()
			end
		end
	end
end)
local grade, stun, bounced = nil, false, 0
local floored = false
while os.clock() - t0 < 12 do
	grade = me:GetAttribute("HT_KickGrade") or grade
	local y = target.HumanoidRootPart.Position.Y - 103
	if target:GetAttribute("HT_Stunned") then
		stun = true
		if y < 1.5 then floored = true end
		if floored then bounced = math.max(bounced, y) end
	end
	task.wait()
end
conn:Disconnect()
local r = me.HumanoidRootPart.Position
return string.format("locked %%s grade %%s stunned %%s dummy top %%.0f floor bounce %%.1f me at (%%.0f, %%.1f, %%.0f) dummy %%s", tostring(lockedAt ~= nil), tostring(grade), tostring(stun), top, bounced, r.X, r.Y, r.Z, tostring(target:GetAttribute("HT_Stagger")))
'''


def station_b():
    import threading
    print("=== B: uppercut, real jump, kick at each grade. The 15 s jump cooldown is real, so this is slow")
    for grade in ("green", "orange", "red"):
        print("  start", snap("Kick Dummy"))
        out = {}
        t = threading.Thread(target=lambda: out.update(r=luau(KICK % grade)))
        stand("Kick Dummy")
        t.start()
        combo("Kick Dummy")
        # Space as soon as it's up there: a real press, with the real requirements.
        for _ in range(40):
            if "float" in snap("Kick Dummy"):
                break
            wait(0.05)
        wait(0.15)
        key("Space")
        t.join()
        print(f"  {grade}:", out.get("r"))
        print("  ", panel().split(" | Kick")[-1][:30], "|", snap("Kick Dummy"))
        wait(5)
    print("  reset pressed mid-air: it must wait for the landing")
    stand("Kick Dummy")
    combo("Kick Dummy")
    print("  launched:", snap("Kick Dummy"))
    print(press("Reset B"))
    wait(0.4)
    print("  just after pressing:", snap("Kick Dummy"))
    wait(4)
    print("  after landing:", snap("Kick Dummy"))


def station_x():
    print("=== X: the rest")
    print("  replacing a destroyed dummy:", luau(r'''
local m = workspace:FindFirstChild("M1 Dummy 1")
m:FindFirstChildOfClass("Humanoid").Health = 0
task.wait(3)
local n = workspace:FindFirstChild("M1 Dummy 1")
return tostring(n ~= nil) .. " " .. tostring(n and n ~= m) .. " health " .. tostring(n and n:FindFirstChildOfClass("Humanoid").Health)
''', "Server"))
    print("  still resets through its station:", press("Reset A"))
    wait(1)
    print("  respawn in training:", luau('game.Players.LocalPlayer.Character.Humanoid.Health = 0 return "killed"'))
    wait(7)
    print("  ", luau('local r=game.Players.LocalPlayer.Character.HumanoidRootPart return string.format("at (%.0f, %.1f, %.0f) in training %s", r.Position.X, r.Position.Y, r.Position.Z, tostring(game.Players.LocalPlayer:GetAttribute("HT_InTraining")))'))
    print("  leaving:", press("To 1v1 arena"))
    wait(1)
    print("  ", luau('local r=game.Players.LocalPlayer.Character.HumanoidRootPart return string.format("at (%.0f, %.1f, %.0f) in training %s panel %s", r.Position.X, r.Position.Y, r.Position.Z, tostring(game.Players.LocalPlayer:GetAttribute("HT_InTraining")), tostring(game.Players.LocalPlayer.PlayerGui.HT_TrainingPanel.Enabled))'))
    print("  anything that ever swung, other than me:", luau('return tostring(_G.HTOtherSwings)'))
    print("  dummies still on the 1v1 arena:", luau(r'''
local n = 0
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if m:GetAttribute("HT_Dummy") and m.HumanoidRootPart.Position.Magnitude < 150 then n += 1 end
end
return tostring(n)''', "Server"))
    luau('local Run=game:GetService("RunService") pcall(function() Run:UnbindFromRenderStep("HT_View") end) workspace.CurrentCamera.CameraType=Enum.CameraType.Custom return "camera back"')


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "ABCDEFX"
    luau(r'''
_G.HTOtherSwings = 0
if _G.HTOther then _G.HTOther:Disconnect() end
_G.HTOther = game:GetService("ReplicatedStorage").HaymakerTussleNet.PunchStarted.OnClientEvent:Connect(function(attacker)
	if attacker ~= game.Players.LocalPlayer.Character then _G.HTOtherSwings += 1 end
end)
return "listening"
''') if "A" in which or "X" not in which else None
    enter()
    for letter in which:
        {"A": station_a, "B": station_b, "C": station_c, "D": station_d, "E": station_e, "F": station_f, "X": station_x}[letter]()
