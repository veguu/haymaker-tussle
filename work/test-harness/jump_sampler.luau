-- Read-only. Watches a real jump while camera locked: the camera, the gap to the bot, and every change of state.
-- Runs on in a thread after this call returns, writing to a workspace attribute that run_lockjump.py reads back.
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local cam = workspace.CurrentCamera
local g = me.PlayerGui.HT_LockOnMarker
local bot
for _, m in game:GetService("CollectionService"):GetTagged("HT_Combatant") do
	if not game.Players:GetPlayerFromCharacter(m) then
		bot = m
	end
end
workspace:SetAttribute("HT_JumpLog", "")
task.spawn(function()
	local start = os.clock()
	local maxRoll, frames, offBot, offMe, unlocked, closest, jumped = 0, 0, 0, 0, 0, math.huge, false
	local trail, events = {}, {}
	local nextTrail = 0
	local wasLocked, wasFloat, wasPrompt, wasSkill = g.Adornee ~= nil, false, false, nil
	local holder = me.PlayerGui:FindFirstChild("HT_KickPrompt")
	local prompt = holder and holder:FindFirstChildWhichIsA("Frame")
	local function event(text)
		table.insert(events, string.format("%.1f %s", os.clock() - start, text))
	end
	while os.clock() - start < 30 do
		Run.RenderStepped:Wait()
		frames += 1
		local _, _, roll = cam.CFrame:ToOrientation()
		maxRoll = math.max(maxRoll, math.abs(math.deg(roll)))
		local skill = ch:GetAttribute("HT_Skill")
		local alive = bot.Parent ~= nil
		local gap = if alive then (bot.HumanoidRootPart.Position - root.Position).Magnitude else -1
		if alive and (skill ~= nil or bot:GetAttribute("HT_Air") ~= nil) then
			local _, onBot = cam:WorldToViewportPoint(bot.HumanoidRootPart.Position)
			local _, onMe = cam:WorldToViewportPoint(root.Position)
			if not onBot then
				offBot += 1
			end
			if not onMe then
				offMe += 1
			end
		end
		if skill == "chase" and alive then
			jumped = true
			closest = math.min(closest, gap)
			if os.clock() >= nextTrail then
				nextTrail = os.clock() + 0.2
				local v = root.AssemblyLinearVelocity
				local to = bot.HumanoidRootPart.Position - root.Position
				local flatV, flatTo = Vector3.new(v.X, 0, v.Z), Vector3.new(to.X, 0, to.Z)
				local angle = -1
				if flatV.Magnitude > 1 and flatTo.Magnitude > 1 then
					angle = math.deg(math.acos(math.clamp(flatV.Unit:Dot(flatTo.Unit), -1, 1)))
				end
				table.insert(trail, string.format("%.0f@%.0f", flatV.Magnitude, angle))
			end
		end
		if g.Adornee == nil then
			unlocked += 1
		end
		local nowLocked = g.Adornee ~= nil
		if nowLocked ~= wasLocked then
			wasLocked = nowLocked
			event(string.format("marker %s gap %.0f", tostring(nowLocked), gap))
		end
		local floating = alive and bot:GetAttribute("HT_Air") == "float"
		if floating ~= wasFloat then
			wasFloat = floating
			event(string.format("bot float %s gap %.0f stagger %s", tostring(floating), gap, tostring(bot:GetAttribute("HT_Stagger"))))
		end
		if prompt and prompt.Visible ~= wasPrompt then
			wasPrompt = prompt.Visible
			event("prompt " .. tostring(wasPrompt))
		end
		if skill ~= wasSkill then
			wasSkill = skill
			local U = game:GetService("UserInputService")
			event("skill " .. tostring(skill) .. " S down " .. tostring(U:IsKeyDown(Enum.KeyCode.S)))
		end
		workspace:SetAttribute(
			"HT_JumpLog",
			string.format(
				"roll max %.2f; off screen in the air: bot %d, you %d frames; frames with no marker %d of %d; jumped %s; closest to the bot during the jump %.1f studs; flat speed@degrees off the bot: %s ;; events: %s",
				maxRoll,
				offBot,
				offMe,
				unlocked,
				frames,
				tostring(jumped),
				closest,
				table.concat(trail, " "),
				table.concat(events, " | ")
			)
		)
	end
end)
return "sampling"
