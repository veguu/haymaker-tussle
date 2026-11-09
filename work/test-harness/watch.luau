local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local ch = me.Character
local joint = ch.HumanoidRootPart:FindFirstChild("RootJoint")
local base = joint.C1
local log, last = {}, nil
local start = os.clock()
local maxTurn, turnClips = 0, ""
local conn = Run.Heartbeat:Connect(function()
	local names = {}
	for _, t in ch.Humanoid.Animator:GetPlayingAnimationTracks() do
		local n = t.Animation.Name
		if t.WeightCurrent > 0.2 and n ~= "" and n ~= "WalkAnim" and n ~= "Guard" and not n:find("^Animation") then
			table.insert(names, n .. string.format("(%.1f)", t.WeightCurrent))
		end
	end
	table.sort(names)
	local s = table.concat(names, ",")
	local key = s:gsub("%(%d%.%d%)", "")
	local v = ch.HumanoidRootPart.AssemblyLinearVelocity
	if key ~= last then
		last = key
		table.insert(log, string.format("%.2f speed %d: %s", os.clock() - start, Vector3.new(v.X, 0, v.Z).Magnitude, s))
	end
	local _, y = (joint.C1 * base:Inverse()):ToOrientation()
	if math.abs(math.deg(y)) > math.abs(maxTurn) then
		maxTurn, turnClips = math.deg(y), s
	end
end)
task.wait(5)
conn:Disconnect()
table.insert(log, `biggest body turn {math.floor(maxTurn)} with {turnClips}; root joint back to base {joint.C1 == base}`)
return table.concat(log, "\n")
