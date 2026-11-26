--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The pond rules (user, 2026-11-11): basin, water and the wading slowdown. Only the old Gnomon map had a pond, and it was
-- deleted 2026-11-26, so these run on Gnomon's pond as it was, kept here as a test pond; the code stays for a future map.
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
	["no map has a pond now (the old Gnomon was the only one), and a map's pond reaches the live arena"] = function()
		for id, entry in (Envs :: any).Maps do
			assert(entry.pond == nil, id)
		end
		local live: any = Round.arenaFor(GameConfig.Arena :: any, { pond = POND }, nil)
		assert(live.Pond == POND)
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
