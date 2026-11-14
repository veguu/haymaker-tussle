--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Blink (Tempest's Q, 2026-11-13): reappear ahead the way you're going, short of walls, on a cooldown.
local Abilities = require("../src/shared/Config/Abilities")
local Blink = require("../src/shared/Core/Blink")

local CFG: any = Abilities.Blink

local function near(a: number?, b: number): boolean
	return a ~= nil and math.abs(a - b) < 1e-6
end

return {
	["Tempest's skills are built, and Blink and Cyclone have their numbers"] = function()
		local kit = Abilities.Kits.Tempest
		assert(kit.mobility.id == "Blink" and kit.mobility.built)
		assert(kit.attack.id == "Cyclone" and kit.attack.built)
		assert(CFG.Distance > 0 and CFG.Cooldown > 0 and CFG.WallGap >= 0)
		local cyclone: any = Abilities.Cyclone
		assert(cyclone.Degrees == 180, "the cyclone reaches all the way round")
		assert(cyclone.Windup > 0 and cyclone.Cooldown > 0 and cyclone.Range > 0)
	end,

	["a moving body blinks the way it's going, whatever it faces"] = function()
		local x, z = Blink.direction(CFG, 0, -30, 1, 0)
		assert(near(x, 0) and near(z, -1))
		x, z = Blink.direction(CFG, 3, 4, 0, -1) -- speed 5
		assert(near(x, 0.6) and near(z, 0.8))
	end,

	["a slow or still body blinks the way it faces"] = function()
		local x, z = Blink.direction(CFG, 0, 0, 0, -2)
		assert(near(x, 0) and near(z, -1))
		x, z = Blink.direction(CFG, CFG.MoveMinSpeed * 0.5, 0, 0, 1)
		assert(near(x, 0) and near(z, 1))
	end,

	["no direction at all, or nonsense, gives none"] = function()
		local x, z = Blink.direction(CFG, 0, 0, 0, 0)
		assert(x == nil and z == nil)
		x, z = Blink.direction(CFG, 0 / 0, 0, 0, 0)
		assert(x == nil and z == nil)
	end,

	["a clear path travels the whole distance"] = function()
		assert(Blink.travel(CFG, nil) == CFG.Distance)
		assert(Blink.travel(CFG, CFG.Distance + CFG.WallGap + 5) == CFG.Distance)
		assert(Blink.travel(CFG, 0 / 0) == CFG.Distance)
	end,

	["a wall stops it short, and never sends it backward"] = function()
		assert(near(Blink.travel(CFG, 10), 10 - CFG.WallGap))
		assert(Blink.travel(CFG, CFG.WallGap * 0.5) == 0)
		assert(Blink.travel(CFG, 0) == 0)
	end,

	["the cooldown, with the server's slack"] = function()
		assert(Blink.ready(CFG, 100, nil))
		assert(not Blink.ready(CFG, 100, 100 - CFG.Cooldown + 0.5))
		assert(Blink.ready(CFG, 100, 100 - CFG.Cooldown))
		assert(Blink.ready(CFG, 100, 100 - CFG.Cooldown + 0.05, 0.06))
		assert(not Blink.ready(CFG, 100, 100 - CFG.Cooldown + 0.05, 0))
	end,
}
