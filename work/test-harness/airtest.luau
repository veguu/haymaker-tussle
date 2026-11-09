-- Client-side measurement of one launch and chase. Keys are sent separately by the runner; the
-- camera is pointed at the bot so that holding W really steers at it.
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
local punch = RS.HaymakerTussleNet.PunchRequest
local commit = RS.HaymakerTussleNet.KickCommit
local AUTO_GREEN = false
local PRESS_OFFSET = 0
local label = me.PlayerGui.HT_KickPrompt.Result
local labelUp, shownAt, shownText, peakScale, shows, solidUntil = false, nil, nil, 0, 0, nil
local fired = false
local lowY, peakY = math.huge, -math.huge
local trail, nextTrail = {}, 0
local log = {}
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function note(s)
	table.insert(log, string.format("%.2f %s", os.clock() % 1000, s))
end

note(`start: my y {root.Position.Y}, my state {ch.Humanoid:GetState().Name}, floor {ch.Humanoid.FloorMaterial.Name}`)
local tries = 0
local stick = Run.Heartbeat:Connect(function()
	local look = root.CFrame.LookVector
	local dir = flat(look).Unit
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(botRoot.Position - dir * 4) * root.CFrame.Rotation
end)
task.wait(0.4)
local nextPunch = 0
local giveUp = os.clock() + 14
while bot:GetAttribute("HT_Air") ~= "float" and os.clock() < giveUp do
	if os.clock() >= nextPunch then
		tries += 1
		nextPunch = os.clock() + 0.6
		punch:FireServer()
	end
	task.wait()
end
stick:Disconnect()
if bot:GetAttribute("HT_Air") ~= "float" then
	return "never launched: " .. table.concat(log, "\n")
end
local launchAt = os.clock()
local startY = 103
local startPos = botRoot.Position
note(`launched after {tries} punches; stagger {bot:GetAttribute("HT_Stagger")}; mine {bot:GetAttribute("HT_AirBy") == me.UserId}`)

local cam = workspace.CurrentCamera
local apex, apexAt, topFlat = 0, 0, 0
local phase, lockedAt, kickedAt, kickPos
local wordSeen = nil
local prompt = me.PlayerGui.HT_KickPrompt:FindFirstChildWhichIsA("Frame")
local landTime, landTravel
local sampledLock, sampledKick = false, false
local endedAt
local conn = Run.Heartbeat:Connect(function()
	local p = root.Position
	local dir = flat(botRoot.Position - p)
	if false then
		cam.CFrame = CFrame.lookAt(p - dir.Unit * 12 + Vector3.yAxis * 4, p + dir.Unit * 12 + Vector3.yAxis * 4)
	end
	local h = botRoot.Position.Y - startY
	if h > apex then
		apex, apexAt = h, os.clock() - launchAt
	end
	topFlat = math.max(topFlat, flat(botRoot.AssemblyLinearVelocity).Magnitude)
	if prompt.Visible ~= (_G.HT_pv or false) then
		_G.HT_pv = prompt.Visible
		note(`prompt {prompt.Visible and "SHOWN" or "hidden"} {os.clock() - launchAt} s after launch; flat gap {dir.Magnitude}; bot h {h}`)
	end
	if phase == "kick" and not _G.HT_rb and os.clock() - kickedAt > 0.2 then
		_G.HT_rb = true
		note(`attacker 0.2 s after the kick: velocity {root.AssemblyLinearVelocity}; facing {flat(root.CFrame.LookVector)}; tracks {ch.HumanoidRootPart.Parent:GetAttribute("HT_Skill")}`)
	end
	if prompt.Visible and wordSeen ~= prompt.Word.Text then
		wordSeen = prompt.Word.Text
		note(`prompt {wordSeen} at {os.clock() - launchAt} s after launch, flat gap {dir.Magnitude}`)
	end
	local skill = ch:GetAttribute("HT_Skill")
	if skill ~= phase then
		note(`skill {tostring(phase)} -> {tostring(skill)} at {os.clock() - launchAt}; flat gap {dir.Magnitude}; bot h {h}; ring at {ch:GetAttribute("HT_KickAt")}; my y {p.Y}`)
		phase = skill
		if skill == "attach" then
			lockedAt = os.clock()
			-- Turn the camera a quarter-turn right on locking on: the kick should now aim that way.
			cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-90), 0)
			note(`camera look frozen at {flat(cam.CFrame.LookVector).Unit}; shift locked {tostring(me:GetAttribute("HT_ShiftLocked"))}`)
			note(`camera right frozen at {cam.CFrame.RightVector}; I arrived from {flat(p - botRoot.Position).Unit}`)
		elseif skill == "kick" then
			kickedAt = os.clock()
			kickPos = botRoot.Position
			note(`bot at kick {kickPos}; me {p}`)
		elseif skill == nil then
			endedAt = os.clock()
		end
	end
	if lockedAt and phase == "attach" and not sampledLock and os.clock() - lockedAt > 0.35 then
		sampledLock = true
		note(`locked: my offset from bot {p - botRoot.Position}; bot faces {flat(botRoot.CFrame.LookVector)}; to me {dir.Unit * -1}`)
	end
	if kickedAt and not sampledKick and os.clock() - kickedAt > 0.2 then
		sampledKick = true
		note(`after kick bot velocity {botRoot.AssemblyLinearVelocity}; my velocity {root.AssemblyLinearVelocity}; camera right {cam.CFrame.RightVector}`)
	end
	if kickedAt and os.clock() - kickedAt < 1.6 then
		local d = flat(botRoot.Position - kickPos).Magnitude
		if d > (_G.HT_far or 0) then
			_G.HT_far = d
		end
	end
	if AUTO_GREEN and lockedAt and phase == "attach" and not fired and os.clock() - lockedAt >= (ch:GetAttribute("HT_KickAt") or 0.35) + PRESS_OFFSET then
		fired = true
		commit:FireServer()
	end
	if label.Visible and not labelUp then
		labelUp, shownAt, shownText, shows = true, os.clock(), label.Text, shows + 1
		peakScale = 0
		note(`TEXT {label.Text} appeared, {kickedAt and "after kick" or "before kick"}, colour {label.TextColor3}, size {label.AbsoluteSize}, centre y share {(label.AbsolutePosition.Y + label.AbsoluteSize.Y / 2) / workspace.CurrentCamera.ViewportSize.Y}`)
	elseif label.Visible then
		peakScale = math.max(peakScale, label.UIScale.Scale)
		if label.TextTransparency == 0 then
			solidUntil = os.clock()
		end
	elseif labelUp then
		labelUp = false
		note(`TEXT gone after {os.clock() - shownAt} s; peak scale {peakScale}; solid for {solidUntil and solidUntil - shownAt or 0} s; final transparency {label.TextTransparency}`)
	end
	if kickedAt and os.clock() - kickedAt < 1.6 and os.clock() >= nextTrail then
		nextTrail = os.clock() + 0.1
		local b = botRoot.Position
		table.insert(trail, string.format("%.1f:y%.0f r%.0f", os.clock() - kickedAt, b.Y, flat(b).Magnitude))
	end
	if kickedAt and os.clock() - kickedAt < 1.6 then
		local y = botRoot.Position.Y
		if y < lowY then
			lowY = y
			peakY = y
		elseif y > peakY then
			peakY = y
		end
	end
	local stunNow = bot:GetAttribute("HT_Stunned") ~= nil
	if stunNow ~= (_G.HT_stun or false) then
		_G.HT_stun = stunNow
		note(`bot stunned {stunNow} at {kickedAt and os.clock() - kickedAt or -1} s after the kick; y {botRoot.Position.Y}`)
	end
	if phase == "chase" and not _G.HT_jumpV and os.clock() - launchAt > 0 then
		_G.HT_jumpV = root.AssemblyLinearVelocity
		note(`jump start velocity {_G.HT_jumpV}; to bot flat {flat(botRoot.Position - p)}; bot velocity {botRoot.AssemblyLinearVelocity}`)
	end
	if not landTime and bot:GetAttribute("HT_Air") == nil then
		landTime = os.clock() - launchAt
		landTravel = flat(botRoot.Position - startPos).Magnitude
	end
end)
local stop = os.clock() + 7
local fellNoted = false
while os.clock() < stop do
	task.wait(0.1)
	if endedAt and not fellNoted and os.clock() - endedAt > 1.5 then
		fellNoted = true
		note(`1.5 s after my jump ended: my y {root.Position.Y}, velocity y {root.AssemblyLinearVelocity.Y}, state {ch.Humanoid:GetState().Name}, floor {ch.Humanoid.FloorMaterial.Name}`)
	end
	if landTime and fellNoted and os.clock() - launchAt > landTime + 2.5 then
		break
	end
end
conn:Disconnect()
cam.CameraType = Enum.CameraType.Custom
note(`apex {apex} at {apexAt}; top flat speed {topFlat}; air cleared {landTime} s after launch, {landTravel} studs along the floor; final bot {botRoot.Position}, travel since kick {kickPos and flat(botRoot.Position - kickPos).Magnitude or "no kick"}; my y {root.Position.Y}`)
note("trail " .. table.concat(trail, " "))
note(`furthest from kick spot {_G.HT_far}`)
_G.HT_jumpV = nil
_G.HT_rb = nil
_G.HT_pv = nil
_G.HT_stun = nil
local names = {}
for _, t in ch.Humanoid.Animator:GetPlayingAnimationTracks() do
	if t.WeightCurrent > 0.3 then
		table.insert(names, t.Animation.Name)
	end
end
note("my tracks now " .. table.concat(names, ","))
_G.HT_far = nil
note(`shows this kick {shows}`)
return table.concat(log, "\n")
