-- Read only, watching me after the runner sends a deliberately bad jump. Notes the arc and the prompt.
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local bot = workspace.TestBot1
local botRoot = bot.HumanoidRootPart
local punch = RS.HaymakerTussleNet.PunchRequest
local prompt = me.PlayerGui.HT_KickPrompt:FindFirstChildWhichIsA("Frame")
local log = {}
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local stick = Run.Heartbeat:Connect(function()
	local dir = flat(root.CFrame.LookVector).Unit
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(botRoot.Position - dir * 4) * root.CFrame.Rotation
end)
task.wait(0.3)
local nextPunch, giveUp = 0, os.clock() + 14
while bot:GetAttribute("HT_Air") ~= "float" and os.clock() < giveUp do
	if os.clock() >= nextPunch then
		nextPunch = os.clock() + 0.6
		punch:FireServer()
	end
	task.wait()
end
stick:Disconnect()
if bot:GetAttribute("HT_Air") ~= "float" then
	return "never launched"
end
root.AssemblyLinearVelocity = Vector3.zero
table.insert(log, `launched: jump ready {tostring(me:GetAttribute("HT_JumpReady"))}`)
local shown = false
local started = os.clock()
local jumpAt, landAt, top, lastSample = nil, nil, 0, 0
local peakSteer = 0
while os.clock() - started < 6 do
	task.wait()
	shown = shown or prompt.Visible
	local skill = ch:GetAttribute("HT_Skill")
	if skill == "chase" and not jumpAt then
		jumpAt = os.clock()
	end
	if jumpAt and not landAt then
		local t = os.clock() - jumpAt
		top = math.max(top, root.Position.Y - 103)
		if t - lastSample >= 0.4 then
			lastSample = t
			local v = root.AssemblyLinearVelocity
			table.insert(log, string.format("%.1f s: height %.0f, flat speed %.0f, up %.0f", t, root.Position.Y - 103, flat(v).Magnitude, v.Y))
		end
		if t > 0.5 and root.Position.Y < 104 and math.abs(root.AssemblyLinearVelocity.Y) < 5 then
			landAt = os.clock()
			table.insert(log, string.format("landed %.2f s after the jump, top %.0f studs up", landAt - jumpAt, top))
		end
		if root.Position.Y < 70 then
			table.insert(log, string.format("fell off %.2f s after the jump", os.clock() - jumpAt))
			break
		end
	end
end
table.insert(log, `prompt ever shown {shown}; jump ready now {tostring(me:GetAttribute("HT_JumpReady"))}`)
return table.concat(log, "\n")
