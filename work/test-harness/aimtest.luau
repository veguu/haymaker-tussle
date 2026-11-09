-- Punches until the bot floats, then waits for the runner's Space. On locking on, turns the real camera
-- a quarter-turn and checks the attacker swings to the far side of the bot from where it now looks.
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local bot = workspace.TestBot1
local botRoot = bot.HumanoidRootPart
local punch = RS.HaymakerTussleNet.PunchRequest
local cam = workspace.CurrentCamera
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
local log = {}
local stop = os.clock() + 4
while ch:GetAttribute("HT_Skill") ~= "attach" and os.clock() < stop do
	task.wait()
end
if ch:GetAttribute("HT_Skill") ~= "attach" then
	return "no lock-on; jump ready " .. tostring(me:GetAttribute("HT_JumpReady"))
end
local arrived = flat(root.Position - botRoot.Position).Unit
cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(-90), 0)
task.wait(0.34)
local look = flat(cam.CFrame.LookVector).Unit
local side = flat(root.Position - botRoot.Position).Unit
table.insert(log, string.format("shift locked %s; skill %s", tostring(me:GetAttribute("HT_ShiftLocked")), tostring(ch:GetAttribute("HT_Skill"))))
table.insert(log, string.format("arrived from (%.2f, %.2f); camera now looks (%.2f, %.2f); now on side (%.2f, %.2f); dot with -look %.2f", arrived.X, arrived.Z, look.X, look.Z, side.X, side.Z, side:Dot(-look)))
local stopKick = os.clock() + 2
while ch:GetAttribute("HT_Skill") ~= "kick" and os.clock() < stopKick do
	task.wait()
end
local kickY = root.Position.Y
local kickFlat = flat(root.Position)
task.wait(0.2)
local v = root.AssemblyLinearVelocity
table.insert(log, string.format("0.2 s after the kick: velocity (%.0f, %.0f, %.0f); facing (%.2f, %.2f)", v.X, v.Y, v.Z, root.CFrame.LookVector.X, root.CFrame.LookVector.Z))
local top = kickY
local started = os.clock()
while os.clock() - started < 2.6 do
	top = math.max(top, root.Position.Y)
	task.wait()
end
do
	local fv = root.AssemblyLinearVelocity
	table.insert(log, string.format("2.8 s after the kick: flat speed %.0f, height above floor %.1f, tracks showing %s", flat(fv).Magnitude, root.Position.Y - 103, tostring(ch:GetAttribute("HT_Skill"))))
end
table.insert(log, string.format("rose %.1f studs above the kick, moved %.1f along the floor in 2.8 s", top - kickY, (flat(root.Position) - kickFlat).Magnitude))
return table.concat(log, "\n")
