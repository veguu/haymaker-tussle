# Real flights for air recovery, on the real client code. Studio must be in Play. It moves your character,
# sends real keys and real clicks, and leaves the bot quiet until `done`.
#   python run_recovery.py fly <gap> <height> <outward> <up> <float 0|1> [reaction ms] [click gap ms] [clicks] [W 0|1]
#       Holds you <gap> studs past the edge and <height> above the floor, launches you with a real knockback
#       message, then holds W toward the centre and clicks. Prints what happened.
#   python run_recovery.py ledge <studs below the floor> : drifts you at the rim from just below its top
#   python run_recovery.py ground : real clicks standing still and running, for the speed they add
#   python run_recovery.py done : cleans up
# Keys are camera-relative, so the camera is held looking at the platform's centre for the whole flight.
import json, os, subprocess, sys, threading, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
RADIUS = 75
FLOOR = 100


def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()


def call(tool, args):
    return subprocess.run([sys.executable, M, "call", tool, json.dumps(args)], capture_output=True, text=True).stdout.strip()


ARM = r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local c = me.Character
local root = c.HumanoidRootPart
local hum = c.Humanoid
local gap, height = __GAP__, __HEIGHT__
local at = Vector3.new(__RADIUS__ + gap, __FLOOR__ + 3 + height, 0)
local armedAt = workspace:GetAttribute("HT_RecGo")
workspace:SetAttribute("HT_RecOut", nil)
pcall(function() Run:UnbindFromRenderStep("HT_RecPin") end)
pcall(function() Run:UnbindFromRenderStep("HT_RecCam") end)
if _G.HTRec then _G.HTRec:Disconnect() end
local cam = workspace.CurrentCamera
Run:BindToRenderStep("HT_RecCam", Enum.RenderPriority.Input.Value - 2, function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if r then
		cam.CameraType = Enum.CameraType.Scriptable
		local flat = Vector3.new(r.Position.X, 0, r.Position.Z)
		local toward = if flat.Magnitude > 1 then -flat.Unit else Vector3.new(-1, 0, 0)
		toward = CFrame.Angles(0, math.rad(__YAW__), 0):VectorToWorldSpace(toward)
		cam.CFrame = CFrame.lookAt(r.Position - toward * 14 + Vector3.yAxis * __PITCH__, r.Position + toward * 10)
	end
end)
Run:BindToRenderStep("HT_RecPin", Enum.RenderPriority.Input.Value - 1, function()
	root.CFrame = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end)
local samples, go = {}, nil
local UIS = game:GetService("UserInputService")
local wAt = nil
local top, topIn, furthest, low = 0, 0, -math.huge, math.huge
local apex, lastY, ended = at.Y, at.Y, nil
_G.HTRec = Run.RenderStepped:Connect(function(dt)
	if workspace:GetAttribute("HT_RecGo") == armedAt then return end
	if not go then
		go = os.clock()
		Run:UnbindFromRenderStep("HT_RecPin")
	end
	local t = os.clock() - go
	if not wAt and UIS:IsKeyDown(Enum.KeyCode.W) then wAt = t end
	local p, v = root.Position, root.AssemblyLinearVelocity
	local flat = Vector3.new(p.X, 0, p.Z)
	local out = flat.Magnitude - __RADIUS__
	local inward = -(v.X * flat.Unit.X + v.Z * flat.Unit.Z)
	top = math.max(top, Vector3.new(v.X, 0, v.Z).Magnitude)
	topIn = math.max(topIn, inward)
	furthest = math.max(furthest, out)
	apex = math.max(apex, p.Y)
	if #samples < 400 and (#samples == 0 or t - samples[#samples][1] >= 0.1) then
		table.insert(samples, { math.floor(t * 100) / 100, math.floor(out * 10) / 10, math.floor((p.Y - __FLOOR__ - 3) * 10) / 10, math.floor(inward), math.floor(v.Y) })
	end
	if not ended then
		-- Sent home by the elimination floor, or standing on the platform.
		if math.abs(p.Y - lastY) > 15 or t > 15 then
			ended = "lost"
		elseif t > __MINT__ and hum.FloorMaterial ~= Enum.Material.Air and out < 2 then
			ended = "back"
		elseif p.Y < __FLOOR__ - 12 then
			ended = "lost"
		end
		if ended then
			workspace:SetAttribute("HT_RecOut", game:GetService("HttpService"):JSONEncode({
				ended = ended, seconds = math.floor(t * 100) / 100, furthest = math.floor(furthest * 10) / 10,
				apex = math.floor((apex - __FLOOR__ - 3) * 10) / 10, topSpeed = math.floor(top), topInward = math.floor(topIn),
				endHeight = math.floor((p.Y - __FLOOR__ - 3) * 10) / 10, wAt = wAt, samples = samples,
			}))
		end
	end
	lastY = p.Y
end)
return "armed"
'''

LAUNCH = r'''
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
local player = game.Players:GetPlayers()[1]
local c = player.Character
workspace:SetAttribute("HT_TestBotQuiet", true)
c:SetAttribute("HT_Stagger", 0)
if _G.HTPunches then _G.HTPunches:Disconnect() end
workspace:SetAttribute("HT_RecPunches", "")
local started = os.clock()
_G.HTPunches = net.PunchRequest.OnServerEvent:Connect(function()
	workspace:SetAttribute("HT_RecPunches", workspace:GetAttribute("HT_RecPunches") .. string.format("%.2f ", os.clock() - started))
end)
local float = __FLOAT__
if float then c:SetAttribute("HT_Air", "float") else c:SetAttribute("HT_Air", nil) end
workspace:SetAttribute("HT_RecGo", os.clock())
task.wait(0.03)
__ATTRS__
net.Knockback:FireClient(player, Vector3.new(__OUT__, __UP__, 0), __AIRUP__)
return "launched"
'''

CLEAR = r'''
local c = game.Players:GetPlayers()[1].Character
if c then c:SetAttribute("HT_Air", nil); c:SetAttribute("HT_AirBy", nil) end
return "cleared"
'''

END = r'''
local Run = game:GetService("RunService")
pcall(function() Run:UnbindFromRenderStep("HT_RecPin") end)
pcall(function() Run:UnbindFromRenderStep("HT_RecCam") end)
if _G.HTRec then _G.HTRec:Disconnect(); _G.HTRec = nil end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "client clean"
'''


def fill(code, **values):
    for key, value in values.items():
        code = code.replace(f"__{key}__", str(value))
    return code


def fly(gap, height, outward, up, floating, reaction=350, click_gap=150, clicks=12, hold_w=1, pitch=8, yaw=0, key="W", air_up=None, attrs="", min_t=0.3):
    print(luau(fill(ARM, GAP=gap, HEIGHT=height, RADIUS=RADIUS, FLOOR=FLOOR, PITCH=pitch, YAW=yaw, MINT=min_t)))
    time.sleep(0.4)

    def inputs():
        time.sleep(reaction / 1000)
        if hold_w:
            call("user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": "keyDown", "key_code": key}]})
        if clicks > 0:
            steps = [{"action": "moveTo", "x": 500, "y": 300}]
            for _ in range(clicks):
                steps.append({"action": "mouseButtonClick", "mouse_button": "left"})
                steps.append({"action": "wait", "wait_time_ms": click_gap})
            call("user_mouse_input", {"datamodel_type": "Client", "actions": steps})

    thread = threading.Thread(target=inputs)
    print(luau(fill(LAUNCH, FLOAT="true" if floating else "false", OUT=outward, UP=up, AIRUP=up if air_up is None else air_up, ATTRS=attrs), "Server"))
    thread.start()
    result = ""
    for _ in range(60):
        result = luau('return workspace:GetAttribute("HT_RecOut") or ""')
        if result and result != '""':
            break
        time.sleep(0.25)
    thread.join()
    call("user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": "keyUp", "key_code": key}]})
    print("punches:", luau('return workspace:GetAttribute("HT_RecPunches")', "Server"))
    luau(CLEAR, "Server")
    print(result)
    return result


def show(result, keep=4):
    data = json.loads(result)
    keys = ("ended", "seconds", "furthest", "apex", "topSpeed", "topInward", "endHeight", "wAt")
    print({k: data.get(k) for k in keys})
    print("  t,out,height,inward,vy:", data["samples"][::keep])


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "suite":
        def run(title, *args, keep=4, **kw):
            print("=== " + title)
            show(fly(*args, **kw), keep)
            print(luau(END))
            time.sleep(2)
        run("hover check: 150 up, no keys, clicking as fast as allowed", 40, 150, 0, 0, False, 0, 100, 34, 0, keep=5)
        run("same with no clicks, for comparison", 40, 150, 0, 0, False, 0, 100, 0, 0, keep=5)
        run("no keys: push goes where the body faces (inward)", 30, 60, 0, 0, False, 200, 130, 6, 0)
        run("steep camera: same launch, W, camera nearly overhead", 20, 40, 0, 0, False, 200, 130, 6, 1, pitch=60)
        run("level camera: same launch, W", 20, 40, 0, 0, False, 200, 130, 6, 1, pitch=1)
        run("camera turned 90 degrees away, D steers home", 20, 40, 0, 0, False, 200, 130, 6, 1, yaw=90, key="D")
        run("slam, red: 40 up, -55", 30, 40, 0, 0, False, 200, 130, 4, 0, air_up=-55)
        run("slam, green: 40 up, -143", 30, 40, 0, 0, False, 200, 130, 4, 0, air_up=-143)
        run("held by a kick: clicks must do nothing", 30, 40, 0, 0, False, 200, 130, 4, 0, attrs='c:SetAttribute("HT_Air", "hold")')
        run("stunned: clicks must do nothing", 30, 40, 0, 0, False, 200, 130, 4, 0, attrs='c:SetAttribute("HT_Stunned", true) task.delay(1.2, function() c:SetAttribute("HT_Stunned", nil) end)')
    elif mode == "more":
        def run(title, *args, keep=4, **kw):
            print("=== " + title)
            show(fly(*args, **kw), keep)
            print(luau(END))
            time.sleep(2)
        run("grounded, standing: clicks", -40, 0, 0, 0, False, 200, 130, 8, 0, min_t=3)
        run("grounded, running with W, no clicks", -60, 0, 0, 0, False, 100, 130, 0, 1, min_t=2.5, keep=6)
        run("grounded, running with W, clicks", -60, 0, 0, 0, False, 100, 130, 8, 1, min_t=2.5, keep=6)
        follow = """
local bot = workspace:FindFirstChild("TestBot1")
_G.HTFollow = game:GetService("RunService").Heartbeat:Connect(function()
	local r = c:FindFirstChild("HumanoidRootPart")
	if r and bot then
		local at = r.Position + Vector3.new(-2.5, 0, 0)
		bot.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		bot.HumanoidRootPart.CFrame = CFrame.new(at)
	end
end)
task.delay(2.2, function() _G.HTFollow:Disconnect() end)
"""
        print("bot stagger before:", luau('return workspace.TestBot1:GetAttribute("HT_Stagger")', "Server"))
        run("connected in the air: the bot held at the shoulder, W and clicks", 30, 60, 0, 0, False, 200, 130, 5, 1, attrs=follow)
        print("bot stagger after:", luau('return workspace.TestBot1:GetAttribute("HT_Stagger")', "Server"))
        run("uppercut state: real clicks while launched are accepted", 5, 0, 55, 125, True, 150, 130, 6, 1)
    elif mode == "fly":
        values = [float(x) for x in sys.argv[2:7]]
        rest = [int(x) for x in sys.argv[7:]]
        fly(values[0], values[1], values[2], values[3], values[4] != 0, *rest)
    elif mode == "ledge":
        below = float(sys.argv[2])
        fly(3, -below, -14, 0, False, 0, 150, 0, 0)
    elif mode == "done":
        print(luau(END))
        print(luau(r'''
workspace:SetAttribute("HT_TestBotQuiet", nil)
if _G.HTPunches then _G.HTPunches:Disconnect(); _G.HTPunches = nil end
local c = game.Players:GetPlayers()[1].Character
if c then c:SetAttribute("HT_Air", nil); c:SetAttribute("HT_AirBy", nil) end
return "server clean"''', "Server"))
