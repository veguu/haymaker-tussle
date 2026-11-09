-- Measures a jump's ground break and the rebound's speed against a real Q propel. Teleports the player
-- to the bot to land the uppercut. run_fxtest.py sends the keys: Space, then later W and Q.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local me = Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local bot
for _, m in CS:GetTagged("HT_Combatant") do
	if m ~= ch then
		bot = m
	end
end
assert(bot, "no bot")
local botRoot = bot.HumanoidRootPart
local net = RS.HaymakerTussleNet
local log = {}
local function note(s)
	table.insert(log, s)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local holding = true
local stick = Run.Heartbeat:Connect(function()
	if holding and bot:GetAttribute("HT_Air") == nil then
		local dir = flat(root.CFrame.LookVector).Unit
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(botRoot.Position - dir * 4) * root.CFrame.Rotation
	end
end)
task.wait(0.4)
-- A jump needs 2 landed uppercuts, so a launch that doesn't earn one just has to land first.
local nextPunch, giveUp = 0, os.clock() + 30
while os.clock() < giveUp do
	local floating = bot:GetAttribute("HT_Air") == "float"
	if floating and me:GetAttribute("HT_JumpReady") ~= false then
		break
	end
	if not floating and bot:GetAttribute("HT_Air") == nil and os.clock() >= nextPunch then
		nextPunch = os.clock() + 0.6
		net.PunchRequest:FireServer()
	end
	task.wait()
end
holding = false
stick:Disconnect()
if bot:GetAttribute("HT_Air") ~= "float" then
	return "never launched"
end
root.AssemblyLinearVelocity = Vector3.zero
note(`launched; jump ready {tostring(me:GetAttribute("HT_JumpReady"))}`)

local function rocks()
	local list = {}
	for _, part in workspace.HT_Fx:GetChildren() do
		if part:IsA("BasePart") and not part:FindFirstChildOfClass("SpecialMesh") and part.Position.Y > -500 then
			table.insert(list, part)
		end
	end
	return list
end

-- Waits for the spring: the first frame any rock exists.
local started = os.clock()
local before = root.Position
local prompt = me.PlayerGui.HT_KickPrompt:FindFirstChildWhichIsA("Frame")
local promptOn, stateSeen = nil, nil
while #rocks() == 0 and os.clock() - started < 6 do
	before = root.Position
	if prompt.Visible ~= promptOn then
		promptOn = prompt.Visible
		note(`{string.format("%.2f", os.clock() - started)} prompt {tostring(promptOn)}; bot air {tostring(bot:GetAttribute("HT_Air"))}`)
	end
	local st = ch.Humanoid:GetState().Name .. " floor " .. ch.Humanoid.FloorMaterial.Name
	if st ~= stateSeen then
		stateSeen = st
		note(`{string.format("%.2f", os.clock() - started)} me {st} at {root.Position}`)
	end
	task.wait()
end
local list = rocks()
if #list == 0 then
	note(`no rocks appeared; skill {tostring(ch:GetAttribute("HT_Skill"))}`)
	return table.concat(log, "\n")
end
local jumpAt = os.clock()
local toBot = flat(botRoot.Position - root.Position)
note(`facing {flat(root.CFrame.LookVector).Unit}; bot is toward {toBot.Unit}, {toBot.Magnitude} flat, {botRoot.Position.Y - root.Position.Y} up, moving {botRoot.AssemblyLinearVelocity}`)
local params = RaycastParams.new()
params.FilterDescendantsInstances = { ch, bot }
local ray = workspace:Raycast(before, Vector3.new(0, -8, 0), params)
local floorY = if ray then ray.Position.Y else before.Y - 3
note(`rocks {#list} at the spring; my height over the floor {before.Y - floorY}; floor {ray and ray.Instance:GetFullName()} {ray and ray.Material.Name} {ray and tostring(ray.Instance.Color)}`)
note(`piece look: {list[#list].Material.Name} {tostring(list[#list].Color)}`)

-- Copies of what's showing, kept still so the look can be inspected. Removed by the runner afterwards.
local function freeze(name)
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, part in rocks() do
		if part.Transparency < 1 then
			part:Clone().Parent = folder
		end
	end
	folder.Parent = RS
end
local frozeA, frozeB = false, false
_G.HT_fx_floor = before

local kickAt, boostSeries, qSeries
local boosts, sampleEnd = {}, nil
local nextReport = 0
local reports = { 0.1, 0.3, 0.6, 1, 1.5, 2, 2.3, 2.7 }
local index = 1
local closest = math.huge
local conn = Run.Heartbeat:Connect(function()
	closest = math.min(closest, (botRoot.Position - root.Position).Magnitude)
	local t = os.clock() - jumpAt
	if t >= 0.25 and not frozeA then
		frozeA = true
		freeze("HT_FreezeA")
	end
	if t >= 1.8 and not frozeB then
		frozeB = true
		freeze("HT_FreezeB")
	end
	local at = reports[index]
	if at and t >= at then
		index += 1
		local shown, high, far, solid = 0, 0, 0, 0
		for _, part in rocks() do
			shown += 1
			if part.Transparency < 1 then
				solid += 1
				high = math.max(high, part.Position.Y - floorY)
				far = math.max(far, flat(part.Position - before).Magnitude)
			end
		end
		note(`t {at}: rocks {shown}, visible {solid}, highest {math.floor(high * 10) / 10}, furthest {math.floor(far * 10) / 10}; me {math.floor((root.Position.Y - floorY) * 10) / 10} up`)
	end
	local skill = ch:GetAttribute("HT_Skill")
	if skill == "kick" and not kickAt then
		kickAt = os.clock()
		note(`kick connected {kickAt - jumpAt} after the spring; grade {tostring(ch:GetAttribute("HT_KickGrade"))}`)
	end
	local speed = flat(root.AssemblyLinearVelocity).Magnitude
	if kickAt and speed > 60 and not sampleEnd then
		table.insert(boosts, { name = if #boosts == 0 then "rebound" else "propel", at = os.clock(), series = {}, nextAt = 0 })
		sampleEnd = os.clock() + 1.2
	end
	local current = boosts[#boosts]
	if current and sampleEnd then
		local since = os.clock() - current.at
		if since >= current.nextAt then
			current.nextAt += 0.1
			table.insert(current.series, string.format("%.0f", speed))
		end
		if os.clock() >= sampleEnd then
			sampleEnd = if #boosts == 1 then nil else math.huge
			if #boosts == 1 and speed > 60 then
				sampleEnd = os.clock() + 0.5 -- still fast: don't count this as the next one
			end
		end
	end
	-- Auto-press in the ring so the kick is a green.
	if skill == "attach" and not _G.HT_fx_pressed then
		_G.HT_fx_at = _G.HT_fx_at or os.clock()
		if os.clock() - _G.HT_fx_at >= (ch:GetAttribute("HT_KickAt") or 0.35) then
			_G.HT_fx_pressed = true
			net.KickCommit:FireServer()
		end
	end
end)
task.wait(9)
conn:Disconnect()
note(`closest to the bot {closest}; kick {kickAt and "connected" or "never"}`)
_G.HT_fx_at, _G.HT_fx_pressed = nil, nil
for _, boost in boosts do
	note(`{boost.name} speed every 0.1 s: {table.concat(boost.series, " ")}`)
end
local parked = 0
for _, part in workspace.HT_Fx:GetChildren() do
	if part:IsA("BasePart") and not part:FindFirstChildOfClass("SpecialMesh") and part.Position.Y < -500 then
		parked += 1
	end
end
note(`afterwards: rocks still showing {#rocks()}, parked for reuse {parked}; spring at {before}; me {root.Position}`)
return table.concat(log, "\n")
