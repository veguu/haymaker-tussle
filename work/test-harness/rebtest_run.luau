-- One launch, jump and kick at the platform's edge, kicking outward. Reads the rebound: how far out it
-- started, how high it rose, its flat speed, and where it landed. run_rebtest.py pins the bot to the
-- edge from the server and sends Space. GRADE is replaced by the runner: green, orange or red.
local GRADE = "green"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Run = game:GetService("RunService")
local me = Players.LocalPlayer
local ch = me.Character
local root = ch.HumanoidRootPart
local humanoid = ch.Humanoid
local bot
for _, m in CS:GetTagged("HT_Combatant") do
	if m ~= ch then
		bot = m
	end
end
assert(bot, "no bot")
local botRoot = bot.HumanoidRootPart
local net = RS.HaymakerTussleNet
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
local nextPunch, giveUp = 0, os.clock() + 30
while os.clock() < giveUp do
	local air = bot:GetAttribute("HT_Air")
	if air == "float" and me:GetAttribute("HT_JumpReady") ~= false then
		break
	end
	if air == nil and os.clock() >= nextPunch then
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

local offset = if GRADE == "orange" then 0.085 else 0
local lockedAt, pressed, kickAt = nil, false, nil
local deadline = os.clock() + 8
local press = Run.Heartbeat:Connect(function()
	local skill = ch:GetAttribute("HT_Skill")
	if skill == "attach" then
		lockedAt = lockedAt or os.clock()
		if GRADE ~= "red" and not pressed and os.clock() - lockedAt >= (ch:GetAttribute("HT_KickAt") or 0.35) + offset then
			pressed = true
			net.KickCommit:FireServer()
		end
	elseif skill == "kick" then
		kickAt = kickAt or os.clock()
	end
end)
while not kickAt and os.clock() < deadline do
	task.wait()
end
press:Disconnect()
if not kickAt then
	return `no kick: closest try ended, me r {math.floor(flat(root.Position).Magnitude)}, y {math.floor(root.Position.Y)}`
end
local grade = ch:GetAttribute("HT_KickGrade")
local trace = {}
local tracing = Run.Heartbeat:Connect(function()
	if #trace < 14 then
		table.insert(trace, string.format("%.2f:y%.1f v%.0f f%.0f %s", os.clock() - kickAt, root.Position.Y - 100, root.AssemblyLinearVelocity.Y, flat(root.AssemblyLinearVelocity).Magnitude, tostring(ch:GetAttribute("HT_Skill"))))
	end
end)

-- The rebound starts when the body is thrown upward.
local kickPos
while root.AssemblyLinearVelocity.Y < 15 and os.clock() - kickAt < 1 do
	kickPos = root.Position
	task.wait()
end
kickPos = kickPos or root.Position
local started = os.clock()
local thrown = root.AssemblyLinearVelocity
local top = kickPos.Y
local speeds = {}
local nextSpeed = 0
local landedOn, landedAt
while os.clock() - started < 6 do
	task.wait()
	local p = root.Position
	top = math.max(top, p.Y)
	if os.clock() - started >= nextSpeed then
		nextSpeed += 0.3
		table.insert(speeds, string.format("%.0f", flat(root.AssemblyLinearVelocity).Magnitude))
	end
	if os.clock() - started > 0.15 and humanoid.FloorMaterial ~= Enum.Material.Air then
		landedOn, landedAt = true, p
		break
	end
	if p.Y < 92 then
		landedOn, landedAt = false, p
		break
	end
end
local air = os.clock() - started
tracing:Disconnect()
print("[rebtest] " .. table.concat(trace, " | "))
local after = ""
if landedOn then
	task.wait(0.1)
	after = string.format("; speed just after landing %.0f", flat(root.AssemblyLinearVelocity).Magnitude)
end
return string.format(
	"grade %s: started %.0f from centre (%.0f past the edge), %.0f above floor; thrown flat %.0f up %.0f; rose %.1f; flat speed %s; air %.2f s; %s at %.0f from centre%s",
	tostring(grade),
	flat(kickPos).Magnitude,
	flat(kickPos).Magnitude - 75,
	kickPos.Y - 100,
	flat(thrown).Magnitude,
	thrown.Y,
	top - kickPos.Y,
	table.concat(speeds, " "),
	air,
	if landedOn == nil then "still in the air" elseif landedOn then "LANDED" else "FELL OFF",
	landedAt and flat(landedAt).Magnitude or -1,
	after
)
