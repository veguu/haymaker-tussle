--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Map plants in the wind (user, 2026-11-12): what moves, how far from the camera, and that it stays gentle.
local Foliage = require("../src/shared/Core/Foliage")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return {
	["flowers, plants, bushes, trees and lilies move; rocks and ruins never do"] = function()
		assert(Foliage.kindOf("Flowers_Daisy_Big_008") == "flower")
		assert(Foliage.kindOf("Plant_Spiky_010") == "plant")
		assert(Foliage.kindOf("Bush_Double_002") == "bush")
		assert(Foliage.kindOf("Tree_C_001") == "tree")
		assert(Foliage.kindOf("Lily_Lotus_163") == "lily")
		assert(Foliage.kindOf("Lily_Pad_Big_160") == "lily")
		assert(Foliage.kindOf("Rock_Round_149") == nil)
		assert(Foliage.kindOf("Ruin_Arch_134") == nil)
	end,

	["a tree's bark stays put, only its crown moves; a flower moves stem and petals together"] = function()
		assert(Foliage.partMoves("tree", "Tree_C_Leaf"))
		assert(not Foliage.partMoves("tree", "Tree_C_Bark"))
		assert(Foliage.partMoves("flower", "Flowers_Tulip_Stem"))
		assert(Foliage.partMoves("flower", "Flowers_Tulip_Petal"))
	end,

	["movement fades to nothing at the edge of the range, so leaving it can't be seen"] = function()
		assert(Foliage.fade(0, 100) == 1)
		assert(Foliage.fade(60, 100) == 1)
		assert(near(Foliage.fade(80, 100), 0.5))
		assert(Foliage.fade(100, 100) == 0)
		assert(Foliage.fade(500, 100) == 0)
	end,

	["phones and low graphics get shorter ranges for every kind"] = function()
		for kind, tune in Foliage.Tuning do
			assert(tune.rangeLow < tune.range, kind)
		end
	end,

	["it stays gentle: flowers lean most, trees least, nothing past 15 degrees from wind alone"] = function()
		local T = Foliage.Tuning
		assert(T.flower.gust > T.plant.gust and T.plant.gust > T.bush.gust and T.bush.gust > T.tree.gust)
		for kind, tune in T do
			local most = tune.lean + tune.gust + tune.flutter + tune.side
			assert(most <= math.rad(15), kind)
		end
	end,

	["the lean goes down-wind on average, and a gust leans it further"] = function()
		local tune = Foliage.Tuning.flower
		local wx, wz = 1, 0
		local calm, gusty = 0, 0
		for i = 0, 99 do
			local t = i * 0.37
			local cx = Foliage.lean(tune, 0, t, 1.2, 1.2, wx, wz)
			local gx = Foliage.lean(tune, 1, t, 1.2, 1.2, wx, wz)
			calm += cx
			gusty += gx
		end
		assert(calm > 0)
		assert(gusty > calm)
	end,

	["gusts stay between 0 and 1 and come and go"] = function()
		for i = 0, 200 do
			local g = Foliage.gust(i * 3.1, i * -1.7, i * 0.21, 1, 0, 40, 4.5)
			assert(g >= 0 and g <= 1)
		end
		-- at one spot it comes and goes: calm and gusty moments
		local lo, hi = 1, 0
		for i = 0, 90 do
			local g = Foliage.gust(10, 5, i * 0.1, 1, 0, 40, 4.5)
			lo, hi = math.min(lo, g), math.max(hi, g)
		end
		assert(lo < 0.1 and hi > 0.5)
	end,

	["a push is capped"] = function()
		local x, z = Foliage.cap(3, 4, 1)
		assert(near(math.sqrt(x * x + z * z), 1))
		local sx, sz = Foliage.cap(0.1, 0, 1)
		assert(sx == 0.1 and sz == 0)
	end,
}
