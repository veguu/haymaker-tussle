# python run_hitgrid.py [label] : fires real punches at a still target placed all around you, and prints what the
# server decided, one grid per swing, since each swing covers a different arc. You face -Z, at angle 0, and positive
# angles are to your right. X is a hit; otherwise the first letter of the server's reason: r range, f facing, h height,
# b blocked, c cancelled, ? no result. Every cell gets three swings, so it takes a few minutes. Uses a brainless server
# copy of the bot and parks the real one. Studio must be in Play. Not part of the game.
import os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")
label = sys.argv[1] if len(sys.argv) > 1 else "grid"

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

SERVER = r'''
workspace:SetAttribute("HaymakerCombatDebug", true)
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local Log = game:GetService("LogService")
local HOME = Vector3.new(0, 103, 40)
local DISTANCES = { 0.5, 1.5, 2.5, 3, 3.5, 4, 5, 6, 6.5, 7, 8 }
local ANGLES = { -180, -135, -90, -60, -35, -15, 0, 15, 35, 60, 90, 135 }
local SIDES = { "Left", "Right", "Uppercut" }
local bot
for _, m in CS:GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) and m.Name ~= "HT_Grid" then bot = m end
end
bot.HumanoidRootPart.Anchored = true
bot.HumanoidRootPart.CFrame = CFrame.new(70, 103, 70)
local old = workspace:FindFirstChild("HT_Grid")
if old then old:Destroy() end
bot.Archivable = true
local g = bot:Clone()
g.Name = "HT_Grid"
for _, d in g:GetDescendants() do
	if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
end
g.HumanoidRootPart.Anchored = true
g.HumanoidRootPart.CFrame = CFrame.new(HOME + Vector3.new(0, 0, -30))
g.Parent = workspace
CS:AddTag(g, "HT_Combatant")
local at = g.HumanoidRootPart.Position
local pin = Run.Heartbeat:Connect(function()
	if g.Parent then
		g.HumanoidRootPart.CFrame = CFrame.new(at)
		g:SetAttribute("HT_Air", nil)
	end
end)
local cellResult, cellSide = "?", nil
local log = Log.MessageOut:Connect(function(text)
	local why = text:match("miss HT_Grid: (%a+)")
	if why then cellResult = why:sub(1, 1) end
	if text:find("hit HT_Grid", 1, true) then cellResult = "X" end
	if text:find("punch cancelled", 1, true) then cellResult = "c" end
	local side = text:match("(%a+) punch resolved")
	if side then cellSide = side end
end)
workspace:SetAttribute("HT_GridDone", nil)
workspace:SetAttribute("HT_GridOut", "")
task.spawn(function()
	local cell = 0
	local grid = {}
	for _, side in SIDES do grid[side] = {} end
	for _, d in DISTANCES do
		for _, angle in ANGLES do
			local r = math.rad(angle)
			at = HOME + Vector3.new(math.sin(r) * d, 0, -math.cos(r) * d)
			task.wait(0.2)
			for _ = 1, 3 do
				cellResult, cellSide = "?", nil
				cell += 1
				workspace:SetAttribute("HT_GridCell", cell)
				task.wait(0.46)
				if cellSide and grid[cellSide] then grid[cellSide][d .. "/" .. angle] = cellResult end
			end
		end
	end
	local lines = {}
	for _, side in SIDES do
		local head = {}
		for _, a in ANGLES do table.insert(head, string.format("%4d", a)) end
		table.insert(lines, side)
		table.insert(lines, "angle " .. table.concat(head))
		for _, d in DISTANCES do
			local row = {}
			for _, angle in ANGLES do
				table.insert(row, "   " .. (grid[side][d .. "/" .. angle] or "?"))
			end
			table.insert(lines, string.format("%5.1f %s", d, table.concat(row)))
		end
	end
	workspace:SetAttribute("HT_GridOut", table.concat(lines, "\n"))
	pin:Disconnect()
	log:Disconnect()
	g:Destroy()
	workspace:SetAttribute("HT_GridCell", nil)
	workspace:SetAttribute("HaymakerCombatDebug", nil)
	bot.HumanoidRootPart.Anchored = false
	workspace:SetAttribute("HT_GridDone", true)
end)
return "server grid running"
'''

CLIENT = r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
local HOME = Vector3.new(0, 103, 40)
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if r then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(HOME, HOME + Vector3.new(0, 0, -1))
	end
end)
local fired = workspace:GetAttributeChangedSignal("HT_GridCell"):Connect(function()
	if workspace:GetAttribute("HT_GridCell") then
		net.PunchRequest:FireServer()
	end
end)
task.spawn(function()
	while not workspace:GetAttribute("HT_GridDone") do task.wait(0.2) end
	fired:Disconnect()
	Run:UnbindFromRenderStep("HT_TestHold")
end)
return "client firing"
'''

print(luau(CLIENT))
print(luau(SERVER, "Server"))
print(f"== {label}: floor level, you face angle 0")
limit = time.time() + 132 * 1.7 + 40
while time.time() < limit:
    time.sleep(5)
    if "true" in luau('return tostring(workspace:GetAttribute("HT_GridDone"))'):
        break
print(luau('return workspace:GetAttribute("HT_GridOut")', "Server"))
