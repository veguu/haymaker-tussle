--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The pond rules (user, 2026-11-11): basin, water and the wading slowdown. The old Gnomon map's pond (Gnomon was deleted
-- 2026-11-26) is kept here exactly; Map 1 got the same pond the same day (owner: "u could actually add the pond in the
-- new map 1"), and its numbers must stay these, which design/maps/suite/meadow.py POND builds the basin from.
local GameConfig = require("../src/shared/Config/GameConfig")
local Envs = require("../src/shared/Config/MapEnvironments")
local Round = require("../src/shared/Core/Round")
local Pond = require("../src/shared/Core/Pond")

local CFG: any = GameConfig.Pond
local POND: any = { -- the old Gnomon's pond, exactly
	x = 0,
	z = 0,
	semiX = 24,
	semiZ = 18,
	wobble = { { 3, 0.08, 0.6 }, { 5, 0.05, 2.1 } },
	depth = 1.6,
	inner = 0.68,
	water = 0.55,
}

return {
	["Map 1 has the old Gnomon pond exactly (the Blender basin is built from these numbers), no other map has one"] = function()
		for id, entry in (Envs :: any).Maps do
			if id ~= "meadow" then
				assert(entry.pond == nil, id)
			end
		end
		local p: any = (Envs :: any).Maps.meadow.pond
		assert(p, "Map 1's pond")
		for _, k in { "x", "z", "semiX", "semiZ", "depth", "inner", "water" } do
			assert(p[k] == POND[k], k)
		end
		assert(#p.wobble == #POND.wobble)
		for i, w in POND.wobble do
			for j = 1, 3 do
				assert(p.wobble[i][j] == w[j], "wobble " .. i)
			end
		end
	end,

	["a map's pond reaches the live arena"] = function()
		local entry: any = (Envs :: any).Maps.meadow
		local live: any = Round.arenaFor(GameConfig.Arena :: any, entry, nil)
		assert(live.Pond == entry.pond)
	end,

	["Map 1's pond stays clear of the spawn ring and inside the arena"] = function()
		local entry: any = (Envs :: any).Maps.meadow
		local p: any = entry.pond
		local spawnR = entry.arena.semiX * entry.arena.spawnShare
		for i = 0, 71 do
			local a = i / 72 * 2 * math.pi
			-- no spawn point anywhere on the ring is in or near the basin
			assert(Pond.bedDepth(p, math.cos(a) * spawnR, math.sin(a) * spawnR) == 0)
		end
		assert(
			math.max(p.semiX, p.semiZ) * 1.2 < entry.arena.semiX * 0.25,
			"a feature, not the battlefield"
		)
	end,

	["the basin is deepest in the middle and meets the floor at its rim"] = function()
		assert(math.abs(Pond.bedDepth(POND, 0, 0) - POND.depth) < 1e-9)
		assert(Pond.bedDepth(POND, POND.semiX * 1.3, 0) == 0)
		assert(Pond.bedDepth(POND, 0, POND.semiZ * 1.3) == 0)
	end,

	["the water covers the middle, not the shore, and leaves room to fight round it"] = function()
		assert(Pond.inWater(POND, 0, 0))
		assert(not Pond.inWater(POND, POND.semiX * 1.05, 0))
		-- no more than a small share of the arena: the pond is a feature, not the battlefield
		assert(POND.semiX * POND.semiZ < 213 * 176 * 0.03)
	end,

	["wading slows by the setting, and nothing else does"] = function()
		assert(CFG.SpeedMultiplier > 0.3 and CFG.SpeedMultiplier < 0.9, "moderate")
		assert(
			Pond.speedShare(POND, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 0, 0, 1.5)
				== CFG.SpeedMultiplier
		)
		assert(
			Pond.speedShare(POND, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 80, 0, 3) == 1,
			"dry ground"
		)
		assert(
			Pond.speedShare(POND, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 0, 0, 12) == 1,
			"in the air over it"
		)
		assert(
			Pond.speedShare(nil, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 0, 0, 1) == 1,
			"a map with no pond"
		)
	end,

	["it never stacks: the same spot always gives the same share"] = function()
		local a = Pond.speedShare(POND, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 3, -2, 1.4)
		local b = Pond.speedShare(POND, CFG.SpeedMultiplier, CFG.MaxRootAboveFloor, 3, -2, 1.4)
		assert(a == b and a == CFG.SpeedMultiplier)
	end,
}
