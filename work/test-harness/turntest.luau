-- Read-only. Samples real speed and travel direction while run_turntest.py holds W, then D, then A, then
-- lets go. Reports the slowest speed through each stretch, how fast travel turned, and the stop.
local Run = game:GetService("RunService")
local me = game.Players.LocalPlayer
local root = me.Character.HumanoidRootPart
local out = {}
local stages = { { "W", 1.0 }, { "D", 0.7 }, { "A", 0.7 }, { "release", 2.2 } }
local function flat()
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z)
end
-- Waits until the run starts: the runner presses W after this script begins.
local waited = os.clock()
while flat().Magnitude < 3 and os.clock() - waited < 8 do
	task.wait()
end
local startAt = os.clock()
for _, stage in stages do
	local name, seconds = stage[1], stage[2]
	local stageStart = os.clock()
	local slowest, fastest, turned, peakTurn = math.huge, 0, 0, 0
	local last = flat()
	while os.clock() - stageStart < seconds do
		local dt = Run.Heartbeat:Wait()
		local now = flat()
		local speed = now.Magnitude
		slowest, fastest = math.min(slowest, speed), math.max(fastest, speed)
		if speed > 2 and last.Magnitude > 2 then
			local angle = math.deg(math.atan2(last.Unit:Cross(now.Unit).Y, last.Unit:Dot(now.Unit)))
			turned += math.abs(angle)
			peakTurn = math.max(peakTurn, math.abs(angle) / dt)
		end
		last = now
	end
	table.insert(out, string.format("%s: speed %.1f to %.1f; end %.1f; turned %.0f deg, peak %.0f deg/s", name, slowest, fastest, flat().Magnitude, turned, peakTurn))
end
table.insert(out, string.format("total %.1f s; position %s", os.clock() - startAt, tostring(root.Position)))
return table.concat(out, "\n")
