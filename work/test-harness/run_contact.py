# python run_contact.py [scenario names...] : scripted crossings, overlaps and bumps between you and a
# brainless server copy of the bot ("HT_C"), with the server's own verdicts. You face -Z. Paths run on server
# time, so both bodies follow the same clock: yours is moved by your client, the copy by the server, and the
# server only knows either from what it observes. Prints, per scenario: the [Combat] lines (hit, miss reason,
# bump) and the knockback messages your client received. Studio must be in Play. Not part of the game.
#   python run_contact.py            -> every scenario
#   python run_contact.py done       -> removes the copy and frees you
import json, os, subprocess, sys, time

M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")


def luau(code, dm="Client"):
    out = subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True)
    return (out.stdout + out.stderr).strip()


SETUP_SERVER = r'''
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local Log = game:GetService("LogService")
local Http = game:GetService("HttpService")
if _G.HT_C_STOP then _G.HT_C_STOP() end
workspace:SetAttribute("HaymakerCombatDebug", true)
local bot
for _, m in CS:GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) and m:GetAttribute("HT_Bot") and m.Name ~= "HT_C" then bot = m end
end
if not bot then return "no bot" end
bot.HumanoidRootPart.Anchored = true
bot.HumanoidRootPart.CFrame = CFrame.new(70, 103, 70)
bot:SetAttribute("HT_TestBotQuiet", true)
workspace:SetAttribute("HT_TestBotQuiet", true)
bot.Archivable = true
local c = bot:Clone()
c.Name = "HT_C"
for _, d in c:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
end
c.HumanoidRootPart.Anchored = true
c.HumanoidRootPart.CFrame = CFrame.new(60, 103, 60)
c.Parent = workspace
CS:AddTag(c, "HT_Combatant")
local trial, buffer, wall = nil, {}, nil
local log = Log.MessageOut:Connect(function(text)
	if trial and text:find("[Combat]", 1, true) then
		table.insert(buffer, string.format("%.3f %s", workspace:GetServerTimeNow() - trial.t0, text))
	end
end)
local function at(path, t)
	return Vector3.new(path[1] + path[4] * t, path[2], path[3] + path[5] * t) -- x, y, z, vx, vz
end
local hb = Run.Heartbeat:Connect(function()
	if not trial or not c.Parent then return end
	local t = workspace:GetServerTimeNow() - trial.t0
	local p = trial.b
	if trial.bstop and t > trial.bstop then t = trial.bstop end
	if trial.bback and t > trial.bback[1] then
		-- out and back: reverse velocity after bback[1], until bback[2]
		local t1 = trial.bback[1]
		local pos1 = at(p, t1)
		local t2 = math.min(t, trial.bback[2])
		local pos = pos1 - Vector3.new(p[4], 0, p[5]) * (t2 - t1)
		if t > trial.bback[2] then
			pos = pos + Vector3.new(p[4], 0, p[5]) * (t - trial.bback[2])
		end
		c.HumanoidRootPart.CFrame = CFrame.new(pos)
	else
		c.HumanoidRootPart.CFrame = CFrame.new(at(p, t))
	end
	c:SetAttribute("HT_Air", nil)
	if trial.hitch and not trial.hitched and t >= trial.hitch then
		trial.hitched = true
		local s = os.clock()
		while os.clock() - s < (trial.hitchLen or 0.045) do end
	end
end)
workspace:SetAttribute("HT_COut", nil)
local changed = workspace:GetAttributeChangedSignal("HT_CTrial"):Connect(function()
	local raw = workspace:GetAttribute("HT_CTrial")
	if not raw then return end
	local spec = Http:JSONDecode(raw)
	if wall then wall:Destroy() wall = nil end
	if spec.wall then
		wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(12, 12, 1)
		wall.CFrame = CFrame.new(spec.wall[1], spec.wall[2], spec.wall[3])
		wall.Name = "HT_CWall"
		wall.Parent = workspace
	end
	-- park the copy at its start before the clock runs, so no old history counts
	c.HumanoidRootPart.CFrame = CFrame.new(at(spec.b, 0) + Vector3.new(0, 0, 0))
	spec.t0 = workspace:GetServerTimeNow() + 0.6
	buffer = {}
	trial = spec
	workspace:SetAttribute("HT_CGo", Http:JSONEncode(spec))
	task.delay(0.6 + spec.dur + 0.4, function()
		workspace:SetAttribute("HT_COut", table.concat(buffer, "\n"))
		trial = nil
		if wall then wall:Destroy() wall = nil end
		c.HumanoidRootPart.CFrame = CFrame.new(60, 103, 60)
		workspace:SetAttribute("HT_CGo", nil)
	end)
end)
_G.HT_C_STOP = function()
	log:Disconnect() hb:Disconnect() changed:Disconnect()
	if c.Parent then c:Destroy() end
	if wall then wall:Destroy() end
	bot.HumanoidRootPart.Anchored = false
	bot:SetAttribute("HT_TestBotQuiet", nil)
	workspace:SetAttribute("HT_TestBotQuiet", nil)
	workspace:SetAttribute("HaymakerCombatDebug", nil)
	_G.HT_C_STOP = nil
end
return "server ready"
'''

SETUP_CLIENT = r'''
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local me = game.Players.LocalPlayer
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
if _G.HT_C_STOP then _G.HT_C_STOP() end
local spec, fired, knocks = nil, false, {}
local function at(path, t)
	return Vector3.new(path[1] + path[4] * t, path[2], path[3] + path[5] * t)
end
pcall(function() Run:UnbindFromRenderStep("HT_CHold") end)
Run:BindToRenderStep("HT_CHold", Enum.RenderPriority.Input.Value, function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local pos
	if spec then
		local t = workspace:GetServerTimeNow() - spec.t0
		local p = spec.a
		local tt = t
		if spec.astop and tt > spec.astop then tt = spec.astop end
		pos = at(p, tt)
		if spec.press and not fired and t >= spec.press then
			fired = true
			net.PunchRequest:FireServer()
		end
	else
		pos = Vector3.new(0, 103, 40)
	end
	r.AssemblyLinearVelocity = Vector3.zero
	r.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end)
local kc = net.Knockback.OnClientEvent:Connect(function(v, airUp, keep, selfRecoil)
	if spec then
		table.insert(knocks, string.format("%.3f knock (%d,%d,%d)%s", workspace:GetServerTimeNow() - spec.t0, v.X, v.Y, v.Z, if selfRecoil then " self" else ""))
	end
end)
local go = workspace:GetAttributeChangedSignal("HT_CGo"):Connect(function()
	local raw = workspace:GetAttribute("HT_CGo")
	if raw then
		spec = Http:JSONDecode(raw)
		fired, knocks = false, {}
		workspace:SetAttribute("HT_CKnocks", nil)
	else
		workspace:SetAttribute("HT_CKnocks", table.concat(knocks, "\n"))
		spec = nil
	end
end)
_G.HT_C_STOP = function()
	go:Disconnect() kc:Disconnect()
	Run:UnbindFromRenderStep("HT_CHold")
	_G.HT_C_STOP = nil
end
return "client ready"
'''

Y = 103
HX, HZ = 0, 40


def path(x, z, vx=0, vz=0):
    return [HX + x, Y, HZ + z, vx, vz]


# Times are seconds from the start; press at 0.5 everywhere. Windup 0.08, active 0.08 to 0.13 after the press.
P = 0.5
SCENARIOS = {
    # --- punches ---
    "overlap_still": dict(a=path(0, 0), b=path(0, 0), press=P, dur=1.0),
    "overlap_near": dict(a=path(0, 0), b=path(0.4, 0.3), press=P, dur=1.0),
    "behind_3": dict(a=path(0, 0), b=path(0, 3), press=P, dur=1.0),
    # target runs through you from the front (+Z) and crosses at press + c
    "cross_target_02": dict(a=path(0, 0), b=path(0, -72 * (P + 0.02), 0, 72), press=P, dur=1.2),
    "cross_target_05": dict(a=path(0, 0), b=path(0, -72 * (P + 0.05), 0, 72), press=P, dur=1.2),
    "cross_target_07": dict(a=path(0, 0), b=path(0, -72 * (P + 0.07), 0, 72), press=P, dur=1.2),
    # you run through a still target
    "cross_me_02": dict(a=path(0, 84 * (P + 0.02), 0, -84), b=path(0, 0), press=P, dur=1.2),
    "cross_me_05": dict(a=path(0, 84 * (P + 0.05), 0, -84), b=path(0, 0), press=P, dur=1.2),
    "cross_me_07": dict(a=path(0, 84 * (P + 0.07), 0, -84), b=path(0, 0), press=P, dur=1.2),
    # both moving, closing at 100
    "cross_both_04": dict(a=path(0, 50 * (P + 0.04), 0, -50), b=path(0, -50 * (P + 0.04), 0, 50), press=P, dur=1.2),
    # ran past before pressing: crossed 0.15 s before the press
    "past_then_press": dict(a=path(0, 0), b=path(0, -72 * (P - 0.15), 0, 72), press=P, dur=1.2),
    # sideways through the back of you during the active window, with a server hitch over it
    "side_hitch": dict(a=path(0, 0), b=path(-120 * (P + 0.10), 1.2, 120, 0), press=P, dur=1.2, hitch=P + 0.085, hitchLen=0.05),
    "miss_far": dict(a=path(0, 0), b=path(0, -9), press=P, dur=1.0),
    "wall": dict(a=path(0, 0), b=path(0, -4), press=P, dur=1.0, wall=[HX, Y, HZ - 2]),
    "above": dict(a=path(0, 0), b=[HX, Y + 6, HZ - 1, 0, 0], press=P, dur=1.0),
    # --- bumps, no punch ---
    "bump_target_runs": dict(a=path(0, 0), b=path(0, -30 * 0.6, 0, 30), dur=1.4),
    "bump_me_runs": dict(a=path(0, 30 * 0.6, 0, -30), b=path(0, 0), dur=1.4),
    "bump_fast_cross": dict(a=path(0, 0), b=path(0, -84 * 0.6, 0, 84), dur=1.4),
    "idle_inside": dict(a=path(0, 0), b=path(0.5, 0), dur=1.5),
    "alongside": dict(a=path(0, 0, 0, -30), b=path(1.5, 0, 0, -30), dur=1.5),
    "contact_stays": dict(a=path(0, 0), b=path(0, -30 * 0.6, 0, 30), bstop=0.6, dur=1.6),
    "out_and_back": dict(a=path(0, 0), b=path(0, -30 * 0.6, 0, 30), bback=[0.62, 1.0], dur=2.0),
    # --- punch and bump at the same impact: target runs in, contact as the swing lands ---
    "punch_vs_bump": dict(a=path(0, 0), b=path(0, -30 * (P + 0.08), 0, 30), bstop=P + 0.08, press=P, dur=1.2),
    "punch_vs_bump_early": dict(a=path(0, 0), b=path(0, -30 * (P + 0.03), 0, 30), bstop=P + 0.03, press=P, dur=1.2),
    "punch_vs_bump_late": dict(a=path(0, 0), b=path(0, -30 * (P + 0.12), 0, 30), bstop=P + 0.12, press=P, dur=1.2),
    # runs into your back and stops 3.2 behind: inside bump distance, outside the overlap disc, so the punch
    # (thrown forward) misses and the bump should still happen once the swing is decided
    "punch_miss_bump": dict(a=path(0, 0), b=path(0, 3.2 + 30 * 0.56, 0, -30), bstop=0.56, press=P, dur=1.2),
}


def run(name):
    spec = SCENARIOS[name]
    luau('workspace:SetAttribute("HT_COut", nil)', "Server")
    luau(f"workspace:SetAttribute('HT_CTrial', nil) workspace:SetAttribute('HT_CTrial', [=[{json.dumps(spec)}]=]) return 'ok'", "Server")
    time.sleep(spec["dur"] + 1.6)
    out = luau('return workspace:GetAttribute("HT_COut") or "(none)"', "Server")
    knocks = luau('return workspace:GetAttribute("HT_CKnocks") or ""', "Client")
    print(f"== {name}")
    for line in out.splitlines():
        if line.strip():
            print("  S " + line.replace("[Combat] ", ""))
    for line in knocks.splitlines():
        if line.strip():
            print("  C " + line)
    time.sleep(0.8)  # past the bump pair cooldown and the punch cooldown


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["done"]:
        print(luau("if _G.HT_C_STOP then _G.HT_C_STOP() end return 'freed'", "Client"))
        print(luau("if _G.HT_C_STOP then _G.HT_C_STOP() end return 'removed'", "Server"))
        sys.exit()
    print(luau(SETUP_CLIENT))
    print(luau(SETUP_SERVER, "Server"))
    time.sleep(1)
    for name in args or list(SCENARIOS):
        run(name)
