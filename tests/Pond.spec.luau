--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Gnomon's central pond (user, 2026-11-11) on the game's real settings: its basin, its water and the wading slowdown.
local GameConfig = require("../src/shared/Config/GameConfig")
local Envs = require("../src/shared/Config/MapEnvironments")
local Round = require("../src/shared/Core/Round")
local Pond = require("../src/shared/Core/Pond")

local CFG: any = GameConfig.Pond
local POND: any = (Envs :: any).Maps.gnomon.pond

return {
	["the pond sits in the middle of Gnomon and nowhere else"] = function()
		assert(POND and POND.x == 0 and POND.z == 0)
		local live: any = Round.arenaFor(GameConfig.Arena :: any, (Envs :: any).Maps.gnomon, nil)
		assert(live.Pond == POND)
		for id, entry in (Envs :: any).Maps do
			if id ~= "gnomon" then
				assert(entry.pond == nil, id)
			end
		end
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
