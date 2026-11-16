--!strict
local roblox = require("@lune/roblox")
local Ultimates = require("../src/shared/Core/Ultimates")
local Round = require("../src/shared/Core/Round")
local GameConfig = require("../src/shared/Config/GameConfig")

local Vector3 = roblox.Vector3
local CFG: any = GameConfig.Ultimate
local ARENA: any = GameConfig.Arena

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

return {
	["every kit has a timeline, Base's own until each kit gets one"] = function()
		for _, kitId in
			{ "Base", "Tempest", "Inferno", "Frost", "Beast", "Dragon", "Bruiser", "Trickster" }
		do
			local line = Ultimates.timeline(kitId)
			assert(line.cinematic > 0 and line.attackerFree >= line.cinematic, kitId)
			assert(#line.keys >= 2, kitId)
			local last = -1
			for _, key in line.keys do
				assert(key.t > last, `{kitId} keys in order`)
				last = key.t
			end
		end
		assert(Ultimates.timeline(nil).name == "Final Bell")
	end,

	["the anchor faces outward from the arena's middle"] = function()
		local centre = Vector3.new(0, 0, 0)
		local frame = Ultimates.anchor(Vector3.new(10, 5, 0), Vector3.new(5, 5, 0), centre)
		assert(
			near(frame.LookVector.X, 1, 0.001) and near(frame.LookVector.Y, 0, 0.001),
			"outward, flat"
		)
		local off = Ultimates.anchor(Vector3.new(10, 5, 0), Vector3.new(10, 5, 4), nil)
		assert(near(off.LookVector.Z, -1, 0.001), "off the arena: away from the attacker")
	end,

	["poses start where the attacker was and end on the last key"] = function()
		local line = Ultimates.timeline("Base")
		local start = Vector3.new(9, 0, 9)
		local a = Ultimates.pose(line, 0, start)
		assert(a == start, "the attacker starts where they were")
		local a2, t2 = Ultimates.pose(line, line.cinematic + 5, start)
		local lastKey = line.keys[#line.keys]
		assert(a2 == lastKey.attacker and t2 == lastKey.target, "after the end, the last key")
		assert(
			#Ultimates.cuesBetween(line, -1, line.cinematic) == #line.cues,
			"every cue fires once"
		)
		assert(#Ultimates.cuesBetween(line, 0.5, 0.5) == 0, "an empty span fires nothing")
	end,

	["camera shots cut where marked and ease otherwise"] = function()
		local line = Ultimates.timeline("Base")
		assert(#line.shots >= 6, "a real shot list, not one orbit")
		local cuts = 0
		for index, shot in line.shots do
			if shot.cut then
				cuts += 1
			end
			if index > 1 then
				assert(shot.t >= line.shots[index - 1].t, "shots in order")
			end
			assert(shot.fov > 20 and shot.fov < 120, "a sane field of view")
		end
		assert(cuts >= 5, "hard cuts, not just a slow move")
		-- On a cut shot's own moment, the camera is exactly that shot.
		for _, shot in line.shots do
			if shot.cut then
				local cam, look, fov = Ultimates.shot(line, shot.t)
				assert(cam == shot.cam and look == shot.look and fov == shot.fov, `cut at {shot.t}`)
			end
		end
		-- Half way into an eased move, the field of view is between the two shots'.
		local first, second = line.shots[1], line.shots[2]
		assert(not second.cut, "the blink's snap zoom eases")
		local _, _, mid = Ultimates.shot(line, (first.t + second.t) / 2)
		assert(mid < first.fov and mid > second.fov, "a snap zoom in progress")
		assert(line.flightFov > 0, "the chase widens to a set field of view")
	end,

	["final bell: close-up, then the dark beat, then the hit, all inside the cinematic"] = function()
		local line = Ultimates.timeline("Base")
		local at: { [string]: number } = {}
		for _, cue in line.cues do
			at[cue.name] = cue.t
		end
		assert(at.windup and at.dark and at.impact and at.launch, "every beat is cued")
		assert(
			at.windup < at.dark and at.dark < at.impact and at.impact < at.launch,
			"beats in order"
		)
		assert(at.launch == line.cinematic, "the flight starts on the launch")
		-- the close-up is a cut shot between the windup and the dark beat, and tighter than any barrage shot
		local closeUp = nil
		for _, shot in line.shots do
			if shot.cut and shot.t > at.windup and shot.t < at.dark then
				closeUp = shot
			end
		end
		assert(closeUp and closeUp.fov <= 36, "an extreme close-up before the dark beat")
		-- on the hit, a cut to the wide shot
		local _, _, fov = Ultimates.shot(line, at.impact)
		assert(fov >= 80, "a wide cut as the haymaker lands")
		assert(line.grade and #line.grade.tint == 3, "graded")
	end,

	["the flight always ends out of the round, from anywhere on the arena"] = function()
		local centre = Vector3.new(ARENA.CenterX, ARENA.CenterY, ARENA.CenterZ)
		for _, offset in
			{
				Vector3.new(0, 3, 0),
				Vector3.new(60, 3, 0),
				Vector3.new(-30, 10, 50),
				Vector3.new(0, 3, -90),
			}
		do
			local start = centre + offset
			local outward = if offset.Magnitude > 4
				then Vector3.new(offset.X, 0, offset.Z)
				else Vector3.new(1, 0, 0)
			local finish = Ultimates.flightEnd(CFG, ARENA, start, outward)
			assert(
				Round.isOut(ARENA, finish.X, finish.Y, finish.Z),
				`from {offset}: ends at {finish}`
			)
		end
		local lobby = Ultimates.flightEnd(CFG, nil, Vector3.new(0, 10, 0), Vector3.new(0, 0, -1))
		assert(
			near(lobby.Z, -CFG.LobbyFlightDistance, 0.001) and lobby.Y < 10,
			"off the arena: out and down"
		)
	end,

	["the flight arcs up then lands on its end"] = function()
		local start, finish = Vector3.new(0, 0, 0), Vector3.new(100, -50, 0)
		assert(Ultimates.flightPoint(start, finish, 0, 20) == start)
		local ending = Ultimates.flightPoint(start, finish, 1, 20)
		assert(near(ending.X, 100, 0.001) and near(ending.Y, -50, 0.001))
		assert(Ultimates.flightPoint(start, finish, 0.25, 20).Y > 0, "it rises first")
	end,
}
