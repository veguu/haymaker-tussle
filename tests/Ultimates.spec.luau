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

-- A small stand-in timeline for the playback maths (the kits' ultimates are being redesigned).
local TEST: Ultimates.Timeline = {
	name = "Test",
	cinematic = 1,
	attackerFree = 1.2,
	keys = {
		{ t = 0, target = Vector3.new(0, 0, 0) },
		{ t = 0.5, attacker = Vector3.new(0, 3, 3), target = Vector3.new(0, 3, 0), ease = "out" },
		{ t = 1, attacker = Vector3.new(0, 3, 1), target = Vector3.new(0, 3, -1) },
	},
	shots = {
		{ t = 0, cam = Vector3.new(7, 2, 1), look = Vector3.new(0, 3, 1), fov = 90, cut = true },
		{
			t = 0.4,
			cam = Vector3.new(6, 2, 1),
			look = Vector3.new(0, 3, 1),
			fov = 50,
			ease = "out",
		},
		{
			t = 0.6,
			cam = Vector3.new(-5, 3, -6),
			look = Vector3.new(0, 3, 1),
			fov = 80,
			cut = true,
		},
	},
	flightFov = 90,
	cues = { { t = 0, name = "start" }, { t = 0.6, name = "hit" }, { t = 1, name = "launch" } },
}

return {
	["no kit has an ultimate until its new one is built (Final Bell removed)"] = function()
		for _, kitId in
			{ "Base", "Tempest", "Inferno", "Frost", "Beast", "Dragon", "Bruiser", "Trickster" }
		do
			assert(Ultimates.timeline(kitId) == nil, kitId)
		end
		assert(Ultimates.timeline(nil) == nil)
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
		local start = Vector3.new(9, 0, 9)
		local a = Ultimates.pose(TEST, 0, start)
		assert(a == start, "the attacker starts where they were")
		local a2, t2 = Ultimates.pose(TEST, TEST.cinematic + 5, start)
		local lastKey = TEST.keys[#TEST.keys]
		assert(a2 == lastKey.attacker and t2 == lastKey.target, "after the end, the last key")
		assert(
			#Ultimates.cuesBetween(TEST, -1, TEST.cinematic) == #TEST.cues,
			"every cue fires once"
		)
		assert(#Ultimates.cuesBetween(TEST, 0.5, 0.5) == 0, "an empty span fires nothing")
	end,

	["camera shots cut where marked and ease otherwise"] = function()
		for _, shot in TEST.shots do
			if shot.cut then
				local cam, look, fov = Ultimates.shot(TEST, shot.t)
				assert(cam == shot.cam and look == shot.look and fov == shot.fov, `cut at {shot.t}`)
			end
		end
		local first, second = TEST.shots[1], TEST.shots[2]
		local _, _, mid = Ultimates.shot(TEST, (first.t + second.t) / 2)
		assert(mid < first.fov and mid > second.fov, "a snap zoom in progress")
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
