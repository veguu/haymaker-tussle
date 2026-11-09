# python run_feel.py <uppercut|ledge|slide|slide_run|ringout_weak|ringout_strong|airpunch|all> : measures how
# falls and hits feel in real play, on the running build. Your character is held in place by your client
# until the moment that matters, then released and tracked; the bot (TestBot1, kept quiet) throws the
# punches through the game's own Studio hook HT_TestPunch, or you throw one through the real remote.
# Prints apex, descent time, slide and recoil distances, and how far out a hit carries you.
# Studio must be in Play. Not part of the game.
import json, os, subprocess, sys, time

M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")


def luau(code, dm="Client"):
    out = subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True)
    return (out.stdout + out.stderr).strip()


CLIENT = r'''
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local me = game.Players.LocalPlayer
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
if _G.HT_F_STOP then _G.HT_F_STOP() end
local rec, t0 = nil, 0
pcall(function() Run:UnbindFromRenderStep("HT_FHold") end)
Run:BindToRenderStep("HT_FHold", Enum.RenderPriority.Input.Value, function()
	local pin = workspace:GetAttribute("HT_FPin")
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if pin and r then
		local p = Http:JSONDecode(pin) -- x, y, z, lookX, lookZ, vz
		local t = workspace:GetServerTimeNow() - (p[7] or workspace:GetServerTimeNow())
		local pos = Vector3.new(p[1], p[2], p[3] + (p[6] or 0) * t)
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(pos, pos + Vector3.new(p[4], 0, p[5]))
	end
end)
local hb = Run.Heartbeat:Connect(function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if rec and r then
		local p = r.Position
		table.insert(rec, string.format("%.3f,%.2f,%.2f,%.2f", os.clock() - t0, p.X, p.Y, p.Z))
	end
end)
local c1 = workspace:GetAttributeChangedSignal("HT_FRec"):Connect(function()
	if workspace:GetAttribute("HT_FRec") then
		rec, t0 = {}, os.clock()
	elseif rec then
		workspace:SetAttribute("HT_FTrack", table.concat(rec, ";"))
		rec = nil
	end
end)
local c2 = workspace:GetAttributeChangedSignal("HT_FPunch"):Connect(function()
	if workspace:GetAttribute("HT_FPunch") then net.PunchRequest:FireServer() end -- a new value each time
end)
_G.HT_F_STOP = function()
	hb:Disconnect() c1:Disconnect() c2:Disconnect()
	Run:UnbindFromRenderStep("HT_FHold")
	_G.HT_F_STOP = nil
end
return "client ready"
'''

SERVER_SETUP = r'''
workspace:SetAttribute("HT_TestBotQuiet", true)
local CS = game:GetService("CollectionService")
local Http = game:GetService("HttpService")
local real
for _, m in CS:GetTagged("HT_Combatant") do
	if m:GetAttribute("HT_Bot") and m.Name == "TestBot1" then real = m end
end
if not real then return "no bot" end
local old = workspace:FindFirstChild("HT_F")
if old then old:Destroy() end
real.Archivable = true
local bot = real:Clone()
bot.Name = "HT_F"
for _, d in bot:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
end
bot.HumanoidRootPart.Anchored = true
bot.Parent = workspace
CS:AddTag(bot, "HT_Combatant")
_G.HT_FBOT = bot
if _G.HT_FBOTPIN then _G.HT_FBOTPIN:Disconnect() end
_G.HT_FBOTPIN = game:GetService("RunService").Heartbeat:Connect(function()
	local raw = workspace:GetAttribute("HT_FBotPin")
	if raw and bot.Parent then
		local p = Http:JSONDecode(raw) -- x, y, z, lookX, lookZ, vz, start
		local t = if p[7] then workspace:GetServerTimeNow() - p[7] else 0
		local pos = Vector3.new(p[1], p[2], p[3] + (p[6] or 0) * t)
		bot.HumanoidRootPart.CFrame = CFrame.lookAt(pos, pos + Vector3.new(p[4], 0, p[5]))
		bot:SetAttribute("HT_Air", nil)
	end
end)
return "server ready (brainless copy HT_F)"
'''


def server(code):
    return luau("local bot = _G.HT_FBOT\n" + code, "Server")


def pin(x, y, z, lx, lz, vz=0.0, start=None):
    spec = [x, y, z, lx, lz, vz] + ([start] if start is not None else [])
    luau(f"workspace:SetAttribute('HT_FPin', [=[{json.dumps(spec)}]=]) return 1", "Server")


def unpin():
    luau("workspace:SetAttribute('HT_FPin', nil) return 1", "Server")


def place_bot(x, y, z, lx, lz, vz=0.0, start=None):
    spec = [x, y, z, lx, lz, vz] + ([start] if start is not None else [])
    luau(f"workspace:SetAttribute('HT_FBotPin', [=[{json.dumps(spec)}]=]) return 1", "Server")


def bot_punch():
    server('workspace:SetAttribute("HT_TestPunch", nil) workspace:SetAttribute("HT_TestPunch", bot.Name) return 1')


def seq(actions, total):
    """Runs timed steps inside Studio on the server's clock: (seconds, kind, arg). Kinds: pin, unpin,
    bot (place the copy), botpunch, punch (you), rec, stop."""
    lines = []
    for at, kind, arg in actions:
        if kind == "pin":
            body = f"workspace:SetAttribute('HT_FPin', [=[{json.dumps(arg)}]=])"
        elif kind == "unpin":
            body = "workspace:SetAttribute('HT_FPin', nil)"
        elif kind == "bot":
            body = f"workspace:SetAttribute('HT_FBotPin', [=[{json.dumps(arg)}]=])"
        elif kind == "botpunch":
            body = "workspace:SetAttribute('HT_TestPunch', nil) workspace:SetAttribute('HT_TestPunch', 'HT_F')"
        elif kind == "punch":
            body = "workspace:SetAttribute('HT_FPunch', os.clock())"
        elif kind == "rec":
            body = "workspace:SetAttribute('HT_FRec', true)"
        elif kind == "stop":
            body = "workspace:SetAttribute('HT_FRec', nil)"
        lines.append(f"task.delay({at}, function() {body} end)")
    luau(" ".join(lines) + " return 1", "Server")
    time.sleep(total + 0.6)


def record(on):
    luau("workspace:SetAttribute('HT_FRec', " + ("true" if on else "nil") + ") return 1", "Server")


def track():
    raw = luau('return workspace:GetAttribute("HT_FTrack") or ""')
    out = []
    for item in raw.split(";"):
        parts = item.split(",")
        if len(parts) == 4:
            try:
                out.append(tuple(float(v) for v in parts))
            except ValueError:
                pass
    return out


def stagger_of(target):
    return luau('return tostring(game.Players.LocalPlayer.Character:GetAttribute("HT_Stagger"))')


def flight_summary(points, y0):
    if not points:
        return "no track"
    apex = max(points, key=lambda p: p[2])
    land = None
    for p in points:
        if p[0] > apex[0] and p[2] <= y0 + 0.3:
            land = p
            break
    s = f"apex +{apex[2] - y0:.1f} at {apex[0]:.2f} s"
    if land:
        s += f", back to launch height {land[0] - apex[0]:.2f} s after the apex (total {land[0]:.2f} s)"
    else:
        s += ", never came back down to launch height in the window"
    return s


def wait_quiet(seconds):
    time.sleep(seconds)


Y = 103


def test_uppercut():
    # The copy, 4 studs in front, throws left, right, uppercut; you're held for the first two.
    acts = [(0, "bot", [0, Y, 36, 0, 1]), (0, "pin", [0, Y, 40, 0, -1]),
            (2.5, "botpunch", None), (3.0, "botpunch", None), (3.5, "rec", None), (3.5, "botpunch", None),
            (3.62, "unpin", None), (8.0, "stop", None)]
    seq(acts, 8.0)
    pts = track()
    print("uppercut, no input: " + flight_summary(pts, Y))
    return pts


def test_airpunch():
    acts = [(0, "bot", [0, Y, 36, 0, 1]), (0, "pin", [0, Y, 40, 0, -1]),
            (2.5, "botpunch", None), (3.0, "botpunch", None), (3.5, "rec", None), (3.5, "botpunch", None),
            (3.62, "unpin", None)]
    acts += [(3.62 + 0.4 * (k + 1), "punch", None) for k in range(8)]
    acts += [(8.0, "stop", None)]
    seq(acts, 8.0)
    pts = track()
    print("uppercut, air punch every 0.4 s: " + flight_summary(pts, Y))


def test_ledge():
    # Held 2 studs past the arena's edge, then let go from standing.
    seq([(0, "pin", [0, Y, 77.5, 0, 1]), (0.8, "rec", None), (0.85, "unpin", None), (3.5, "stop", None)], 3.5)
    pts = track()
    res = []
    leave = next((p for p in pts if p[2] <= Y - 0.05), None)
    for drop in (5, 10, 20):
        hit = next((p for p in pts if p[2] <= Y - drop), None)
        res.append(f"{drop} studs in {hit[0] - leave[0]:.2f} s" if hit and leave else f"{drop}: not reached")
    print("off the ledge from standing: " + ", ".join(res))


def test_slide(running):
    # The copy punches you from 3.5 studs (standing, or arriving at full running speed); you're let go
    # just before it lands and slide on the real knockback rules, with no input.
    time.sleep(3.5)
    st = stagger_of("me")
    acts = [(0, "pin", [0, Y, 39.5, 0, -1])]
    if running:
        now = float(luau("return workspace:GetServerTimeNow()", "Server"))
        arrive = now + 2.0 + 0.23  # the copy's windup is 0.23 s
        acts += [(0, "bot", [0, Y, 36 - 36 * 2.23, 0, 1, 36, now])]
        acts += [(2.0, "rec", None), (2.0, "botpunch", None), (2.15, "unpin", None),
                 (2.24, "bot", [0, Y, 36, 0, 1]), (5.0, "stop", None)]
    else:
        acts += [(0, "bot", [0, Y, 36, 0, 1]), (2.0, "rec", None), (2.0, "botpunch", None),
                 (2.15, "unpin", None), (5.0, "stop", None)]
    seq(acts, 5.0)
    pts = track()
    start_pt = next((p for p in pts if p[0] >= 0.15), None)
    if not start_pt:
        print("slide: no track"); return None
    end_pt = pts[-1]
    slide = ((end_pt[1] - start_pt[1]) ** 2 + (end_pt[3] - start_pt[3]) ** 2) ** 0.5
    label = "running punch (36)" if running else "standing punch"
    print(f"{label} at your stagger {st}: you slid {slide:.1f} studs")
    return slide


def test_recoil():
    # You punch the copy from 3.5 studs and are let go as it lands.
    seq([(0, "bot", [0, Y, 36, 0, 1]), (0, "pin", [0, Y, 39.5, 0, -1]), (1.5, "rec", None),
         (1.5, "punch", None), (1.4, "unpin", None), (4.0, "stop", None)], 4.0)
    pts = track()
    start_pt = next((p for p in pts if p[0] >= 0.06), None)
    if not start_pt:
        print("recoil: no track"); return None
    end_pt = pts[-1]
    recoil = ((end_pt[1] - start_pt[1]) ** 2 + (end_pt[3] - start_pt[3]) ** 2) ** 0.5
    print(f"your recoil after landing a punch: {recoil:.1f} studs")
    return recoil


def build_stagger(target_value):
    # The copy punches you while you're held, until your stagger reaches the value.
    count = 0
    while True:
        s = stagger_of("me")
        try:
            v = float(s)
        except ValueError:
            v = 0.0
        if v >= target_value or count > 30:
            return count, v
        seq([(0, "botpunch", None)], 0.0)
        count += 1


def test_ringout(strong):
    # You stand 15 studs from the edge (radius 60), the copy just inside you, punching outward.
    seq([(0, "bot", [0, Y, 56, 0, 1]), (0, "pin", [0, Y, 60, 0, -1])], 2.5)
    taken, value = (0, 0.0)
    if strong:
        taken, value = build_stagger(95)
        time.sleep(2.2)  # combo reset, so the finisher is a hook like the weak hit
    seq([(0, "rec", None), (0, "botpunch", None), (0.15, "unpin", None), (4.5, "stop", None)], 4.5)
    pts = track()
    if not pts:
        print("ringout: no track")
        return
    far = max(pts, key=lambda p: (p[1] ** 2 + p[3] ** 2) ** 0.5)
    rad = (far[1] ** 2 + far[3] ** 2) ** 0.5
    out = any(p[2] < 90 for p in pts)
    label = f"finisher at stagger {value:.0f} (after {taken} punches)" if strong else "weak hit at stagger 0"
    print(f"{label} from radius 60: carried to radius {rad:.1f} (edge 75), {'RING-OUT' if out else 'stayed on'}")
    time.sleep(1)


if __name__ == "__main__":
    what = sys.argv[1:] or ["all"]
    print(luau(CLIENT))
    print(luau(SERVER_SETUP, "Server"))
    tests = {
        "uppercut": test_uppercut,
        "airpunch": test_airpunch,
        "ledge": test_ledge,
        "slide": lambda: test_slide(False),
        "slide_run": lambda: test_slide(True),
        "recoil": test_recoil,
        "ringout_weak": lambda: test_ringout(False),
        "ringout_strong": lambda: test_ringout(True),
    }
    order = list(tests) if what == ["all"] else what
    for name in order:
        tests[name]()
        time.sleep(1.5)
    unpin()
    print(luau("if _G.HT_F_STOP then _G.HT_F_STOP() end return 'client freed'"))
    luau('workspace:SetAttribute("HT_FBotPin", nil) if _G.HT_FBOTPIN then _G.HT_FBOTPIN:Disconnect() end workspace:SetAttribute("HT_TestBotQuiet", nil) if _G.HT_FBOT then _G.HT_FBOT:Destroy() end return 1', "Server")
