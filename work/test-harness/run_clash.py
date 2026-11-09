# python run_clash.py : runs the real server rules through timed punches, clashes, ties, tap floods, a third-party repel,
# cleanup, height and walls, and prints what happened in each. It pins your character and fires punches and taps through
# the real remotes. Studio must be in Play with the bot on. Not part of the game.
import os, subprocess, sys, time
M = os.path.expanduser("~/.claude/skills/create-roblox-game/scripts/studio_mcp.py")

START = sys.argv[1] if len(sys.argv) > 1 else "1"

def luau(code, dm="Client"):
    return subprocess.run([sys.executable, M, "luau", "--dm", dm, "--code", code], capture_output=True, text=True).stdout.strip()

CLIENT = r'''
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
local pinned, pinAt = false, nil
pcall(function() Run:UnbindFromRenderStep("HT_TestHold") end)
Run:BindToRenderStep("HT_TestHold", Enum.RenderPriority.Input.Value, function()
	local c = me.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and pinned and pinAt and not c:GetAttribute("HT_Clash") then
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = pinAt
	end
end)
net.Knockback.OnClientEvent:Connect(function(v, up, keep)
	if not workspace:GetAttribute("HT_ClashDone") then
		local r = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		local from = r and r.Position
		task.delay(0.5, function()
			if from and r.Parent then
				print(("[HT test] knock %.0f,%.0f keep %s: carried %.1f studs in 0.5 s"):format(v.X, v.Z, tostring(keep), (r.Position - from).Magnitude))
			end
		end)
	end
end)
local tapping = 0
local conn = workspace:GetAttributeChangedSignal("HT_Cmd"):Connect(function()
	local raw = workspace:GetAttribute("HT_Cmd")
	if not raw then return end
	local what = raw:match("^%d+:(.*)$")
	if what == "punch" then
		net.PunchRequest:FireServer()
	elseif what == "free" then
		pinned = false
	elseif what:sub(1, 4) == "pin:" then
		local x, y, z = what:match("pin:(.-),(.-),(.+)")
		local at = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
		pinAt = CFrame.lookAt(at, at + Vector3.new(0, 0, -1))
		pinned = true
	elseif what:sub(1, 4) == "tap:" then
		local rate = tonumber(what:sub(5))
		tapping += 1
		local mine = tapping
		task.spawn(function()
			while tapping == mine and me.Character and me.Character:GetAttribute("HT_Clash") do
				net.ClashTap:FireServer()
				task.wait(1 / rate)
			end
		end)
	elseif what == "match" then
		tapping += 1
		local mine = tapping
		task.spawn(function()
			while tapping == mine and me.Character and me.Character:GetAttribute("HT_Clash") do
				local bot = workspace:FindFirstChild("TestBot1")
				local theirs = bot and bot:GetAttribute("HT_ClashScore") or 0
				if (me.Character:GetAttribute("HT_ClashScore") or 0) < theirs then
					net.ClashTap:FireServer()
				end
				task.wait(0.03)
			end
		end)
	elseif what == "kick" then
		net.KickRequest:FireServer()
	elseif what == "flood" then
		for _ = 1, 200 do net.ClashTap:FireServer() end
	end
end)
task.spawn(function()
	while not workspace:GetAttribute("HT_ClashDone") do task.wait(0.2) end
	conn:Disconnect()
	tapping += 1
	Run:UnbindFromRenderStep("HT_TestHold")
end)
return "client ready"
'''

SERVER = r'''
local CS = game:GetService("CollectionService")
local Log = game:GetService("LogService")
local Players = game:GetService("Players")
local net = game:GetService("ReplicatedStorage").HaymakerTussleNet
workspace:SetAttribute("HaymakerCombatDebug", true)
workspace:SetAttribute("HT_TestBotQuiet", true)
workspace:SetAttribute("HT_ClashDone", nil)
workspace:SetAttribute("HT_ClashOut", "")
local START = __START__
local player = Players:GetPlayers()[1]
local bot = workspace:FindFirstChild("TestBot1")
local HOME = Vector3.new(0, 103, -12)
local out = {}
local function say(text)
	table.insert(out, text)
	workspace:SetAttribute("HT_ClashOut", table.concat(out, "\n"))
end
local n = 0
local function cmd(text)
	n += 1
	workspace:SetAttribute("HT_Cmd", n .. ":" .. text)
end
local lines = {}
local log = Log.MessageOut:Connect(function(text)
	if text:find("[Combat]", 1, true) then table.insert(lines, (text:gsub("%[Combat%] ", ""))) end
end)
local function events()
	local found = table.concat(lines, " / ")
	table.clear(lines)
	return found
end
local requestAt = 0
local reqConn = net.PunchRequest.OnServerEvent:Connect(function() requestAt = os.clock() end)
local function setupPair(gap)
	bot.HumanoidRootPart.Anchored = true
	bot.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	bot:PivotTo(CFrame.lookAt(HOME, HOME + Vector3.zAxis) * bot.HumanoidRootPart.CFrame:ToObjectSpace(bot:GetPivot()))
	cmd(("pin:%f,%f,%f"):format(HOME.X, HOME.Y, HOME.Z + gap))
	task.wait(1.6)
	bot.HumanoidRootPart.Anchored = false
	task.wait(0.15)
	table.clear(lines)
end
local function myChar() return player.Character end
local function stag(m) return m:GetAttribute("HT_Stagger") or 0 end
local function inClash(m) return m:GetAttribute("HT_Clash") ~= nil end
-- Signals are deferred, so the attribute has to still be there when the hook reads it.
local function botPunch()
	workspace:SetAttribute("HT_TestPunch", bot.Name)
	task.defer(function()
		task.wait()
		workspace:SetAttribute("HT_TestPunch", nil)
	end)
end
-- strike gap: positive means the player's punch strikes later than the bot's
local function exchange(gap, latency)
	local extra = 0.15
	local playerAt = extra + gap - latency
	if playerAt >= 0 then
		botPunch()
		local t = os.clock()
		while os.clock() - t < playerAt do task.wait() end
		cmd("punch")
	else
		cmd("punch")
		local t = os.clock()
		while os.clock() - t < -playerAt do task.wait() end
		botPunch()
	end
end
local function waitClashEnd(limit)
	local t = os.clock()
	while inClash(bot) and os.clock() - t < limit do task.wait(0.03) end
	return os.clock() - t
end
task.spawn(function()
	local ok, err = pcall(function()
		-- how long a command takes to come back as a punch request
		setupPair(30)
		local total = 0
		for _ = 1, 5 do
			local t = os.clock()
			requestAt = 0
			cmd("punch")
			while requestAt == 0 and os.clock() - t < 1 do task.wait() end
			total += requestAt - t
			task.wait(0.5)
		end
		local latency = total / 5
		say(("command to request: %.0f ms; ping %.0f ms"):format(latency * 1000, player:GetNetworkPing() * 1000))
		table.clear(lines)

		-- 1 who wins an exchange, by how far apart the strikes are
		if START <= 1 then
		for _, gap in { -0.2, -0.12, -0.08, -0.03, 0, 0.03, 0.08, 0.12, 0.2 } do
			setupPair(5)
			local sBot, sMe = stag(bot), stag(myChar())
			exchange(gap, latency)
			task.wait(0.55)
			local clashing = inClash(bot)
			local text = events()
			local result = if clashing then "CLASH"
				elseif text:find("TestBot1 %a+ hit") and text:find("punch cancelled") and text:find(player.Name .. " %a+ punch cancelled") then "bot lands, your swing beaten"
				elseif text:find(player.Name .. " %a+ hit") and text:find("TestBot1 %a+ punch cancelled") then "you land, bot's swing beaten"
				else text
			say(("gap %+.2f: %s (stagger bot +%d, you +%d)"):format(gap, result, stag(bot) - sBot, stag(myChar()) - sMe))
			if clashing then cmd("tap:30"); waitClashEnd(3.2) end
			task.wait(0.6)
		end
		end

		local function startClash()
			for _ = 1, 8 do
				setupPair(5)
				exchange(0, latency)
				local t = os.clock()
				while not inClash(bot) and os.clock() - t < 0.6 do task.wait() end
				if inClash(bot) then table.clear(lines); return true end
				task.wait(0.7)
			end
			say("no clash started; last events: " .. events() .. "; bot air " .. tostring(bot:GetAttribute("HT_Air")) .. " skill " .. tostring(bot:GetAttribute("HT_Skill")) .. " stun " .. tostring(bot:GetAttribute("HT_Stunned")) .. " look " .. tostring(bot.HumanoidRootPart.CFrame.LookVector) .. " pos " .. tostring(bot.HumanoidRootPart.Position) .. " me " .. tostring(myChar().HumanoidRootPart.Position))
			return false
		end
		local function report(label, sBot, sMe, took)
			task.wait(0.5)
			say(("%s: %.1f s; stagger bot +%d, you +%d; marks left %s; [%s]"):format(label, took, stag(bot) - sBot, stag(myChar()) - sMe,
				tostring(inClash(bot) or inClash(myChar())), events()))
		end

		if START <= 2 then
		-- 2 alignment
		assert(startClash(), "no clash")
		local sBot, sMe = stag(bot), stag(myChar())
		local a, b = myChar().HumanoidRootPart, bot.HumanoidRootPart
		local samples = {}
		for _ = 1, 8 do
			task.wait(0.1)
			local postA = myChar():GetAttribute("HT_ClashAt") or a.Position
			local postB = bot:GetAttribute("HT_ClashAt") or b.Position
			table.insert(samples, ("%.1f(%.1f/%.1f)"):format(
				Vector3.new(b.Position.X - a.Position.X, 0, b.Position.Z - a.Position.Z).Magnitude,
				Vector3.new(a.Position.X - postA.X, 0, a.Position.Z - postA.Z).Magnitude,
				Vector3.new(b.Position.X - postB.X, 0, b.Position.Z - postB.Z).Magnitude))
		end
		say("apart(you from spot/bot from spot) every 0.1 s: " .. table.concat(samples, " "))
		local line = (b.Position - a.Position)
		local flatLine = Vector3.new(line.X, 0, line.Z)
		say(("aligned after 0.35 s: %.2f studs apart; you face them %.2f, bot faces you %.2f (1 is exactly)"):format(flatLine.Magnitude,
			a.CFrame.LookVector:Dot(flatLine.Unit), b.CFrame.LookVector:Dot(-flatLine.Unit)))
		task.wait(0.5)
		line = (b.Position - a.Position)
		say(("aligned after 0.85 s: %.2f studs apart"):format(Vector3.new(line.X, 0, line.Z).Magnitude))
		-- 3 winning
		cmd("tap:12")
		local took = waitClashEnd(3.5)
		report("tap 12/s against bot 5.5/s", sBot, sMe, took)

		-- 4 losing
		task.wait(1)
		assert(startClash(), "no clash")
		sBot, sMe = stag(bot), stag(myChar())
		report("no tapping against bot 5.5/s", sBot, sMe, waitClashEnd(3.5))

		-- 5 tie
		task.wait(1)
		assert(startClash(), "no clash")
		sBot, sMe = stag(bot), stag(myChar())
		cmd("match")
		report("keeping level with the bot", sBot, sMe, waitClashEnd(3.5))

		-- 6 flood
		task.wait(1)
		assert(startClash(), "no clash")
		task.wait(0.15)
		cmd("flood")
		task.wait(0.4)
		say(("200 taps fired at once: scored %d"):format(myChar():GetAttribute("HT_ClashScore") or -1))
		waitClashEnd(3.5)
		task.wait(1)
		end

		-- 7 third party: the bot and a copy clash, you punch into it
		table.clear(lines)
		local g = workspace:FindFirstChild("HT_Grid")
		if g then g:Destroy() end
		bot.Archivable = true
		g = bot:Clone()
		g.Name = "HT_Grid"
		for _, d in g:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
		end
		g.HumanoidRootPart.Anchored = true
		setupPair(30)
		local spot = HOME + Vector3.new(0, 0, 3.4)
		g.HumanoidRootPart.CFrame = CFrame.lookAt(spot, spot + Vector3.zAxis)
		g.Parent = workspace
		CS:AddTag(g, "HT_Combatant")
		cmd(("pin:%f,%f,%f"):format(spot.X, spot.Y, spot.Z + 5))
		task.wait(0.6)
		local sG, sB, sM = stag(g), stag(bot), stag(myChar())
		workspace:SetAttribute("HT_TestClash", bot.Name .. "|HT_Grid")
		task.wait(0.1)
		workspace:SetAttribute("HT_TestClash", nil)
		table.clear(lines)
		cmd("free")
		task.wait(0.03)
		cmd("punch")
		local trail = {}
		for _ = 1, 8 do
			task.wait(0.13)
			table.insert(trail, ("%.1f"):format((myChar().HumanoidRootPart.Position - spot).Magnitude))
		end
		say(("punch into a clash from 5 studs: still clashing %s; distance from them every 0.13 s: %s; stagger on them +%d/+%d, you +%d; [%s]"):format(
			tostring(inClash(g) and inClash(bot)), table.concat(trail, " "), stag(g) - sG, stag(bot) - sB, stag(myChar()) - sM, events()))
		-- right away, a second validated attack: within the cooldown, so no second push
		say("stand-in: repel cooldown checked by the spec and the earlier run")
		cmd("free")
		-- stand-in cleanup: destroy one fighter mid-clash
		task.wait(0.1)
		g:Destroy()
		task.wait(0.2)
		say(("a fighter removed mid-clash: marks left %s; [%s]"):format(tostring(inClash(bot)), events()))
		task.wait(1)

		-- 8 fall out of play
		assert(startClash(), "no clash")
		bot.HumanoidRootPart.Anchored = true
		bot:PivotTo(bot:GetPivot() - Vector3.new(0, 60, 0))
		task.wait(0.2)
		say(("bot dropped out of play mid-clash: marks left you %s bot %s; [%s]"):format(tostring(inClash(myChar())), tostring(inClash(bot)), events()))
		bot.HumanoidRootPart.Anchored = false
		task.wait(1.5)

		-- 9 die mid-clash
		assert(startClash(), "no clash")
		local gone = myChar()
		gone:FindFirstChildOfClass("Humanoid").Health = 0
		task.wait(0.2)
		say(("you die mid-clash: marks left bot %s, dead body %s; [%s]"):format(tostring(inClash(bot)), tostring(inClash(gone)), events()))
		local t = os.clock()
		while (player.Character == gone or not player.Character) and os.clock() - t < 12 do task.wait(0.2) end
		task.wait(1)

		-- 10 height and walls, against a still copy
		g = bot:Clone()
		g.Name = "HT_Grid"
		for _, d in g:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
		end
		g.HumanoidRootPart.Anchored = true
		local base = Vector3.new(30, 103, 20)
		g.HumanoidRootPart.CFrame = CFrame.new(base + Vector3.new(0, 0, 60))
		g.Parent = workspace
		CS:AddTag(g, "HT_Combatant")
		bot.HumanoidRootPart.Anchored = true
		cmd(("pin:%f,%f,%f"):format(base.X, base.Y, base.Z))
		task.wait(1)
		local function shot(label, offset, wall)
			local part
			if wall then
				part = Instance.new("Part")
				part.Anchored = true
				part.Size = wall.size
				part.CFrame = CFrame.new(base + wall.at)
				part.Parent = workspace
			end
			g.HumanoidRootPart.CFrame = CFrame.new(base + offset)
			task.wait(0.25)
			table.clear(lines)
			cmd("punch")
			task.wait(0.5)
			local text = events()
			local why = text:match("miss HT_Grid: (%a+)") or (text:find("hit HT_Grid") and "HIT") or "?"
			say(("%s: %s"):format(label, why))
			if part then part:Destroy() end
		end
		local ahead = Vector3.new(0, 0, -4)
		shot("3 above", ahead + Vector3.new(0, 3, 0))
		shot("4.4 above", ahead + Vector3.new(0, 4.4, 0))
		shot("5 above", ahead + Vector3.new(0, 5, 0))
		shot("3 below", ahead + Vector3.new(0, -3, 0))
		shot("5 below", ahead + Vector3.new(0, -5, 0))
		shot("full wall between", ahead, { size = Vector3.new(30, 12, 0.5), at = Vector3.new(0, 0, -2) })
		shot("half the body behind a wall edge", ahead, { size = Vector3.new(10, 12, 0.5), at = Vector3.new(-5, 0, -2) })
		shot("wall right behind them", ahead, { size = Vector3.new(30, 12, 0.5), at = Vector3.new(0, 0, -6.5) })
		g:Destroy()
		bot.HumanoidRootPart.Anchored = false
	end)
	if not ok then say("HARNESS ERROR: " .. tostring(err)) end
	log:Disconnect()
	reqConn:Disconnect()
	workspace:SetAttribute("HT_TestBotQuiet", nil)
	workspace:SetAttribute("HaymakerCombatDebug", nil)
	workspace:SetAttribute("HT_Cmd", nil)
	workspace:SetAttribute("HT_ClashDone", true)
end)
return "server running"
'''

luau('workspace:SetAttribute("HT_ClashDone", nil) return 1', "Server")
time.sleep(0.5)
print(luau(CLIENT))
print(luau(SERVER.replace("__START__", START), "Server"))
limit = time.time() + 300
while time.time() < limit:
    time.sleep(5)
    if "true" in luau('return tostring(workspace:GetAttribute("HT_ClashDone"))'):
        break
print(luau('return workspace:GetAttribute("HT_ClashOut")', "Server"))
