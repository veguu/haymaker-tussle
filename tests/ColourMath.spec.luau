--!strict
-- A fighter's palette from one colour, the countdown's shared random pick and the colour wheel (ui-24a).
local ColourMath = require("../src/shared/Core/ColourMath")

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

local function same(a: ColourMath.RGB, b: ColourMath.RGB): boolean
	return near(a.r, b.r, 2e-3) and near(a.g, b.g, 2e-3) and near(a.b, b.b, 2e-3)
end

local CLASSES = { "FFD23F", "2EC4B6", "FF7A2F", "64A3FF", "F0525A", "8C6CF0", "FFA41C", "C46BE0" }

return {
	["hex goes in and comes back out"] = function()
		for _, hex in CLASSES do
			assert(ColourMath.toHex(ColourMath.fromHex(hex)) == hex, hex)
		end
		assert(ColourMath.toHex(ColourMath.fromHex("#1e2233")) == "1E2233")
	end,

	["a typed colour is read only when it is six hex digits"] = function()
		assert(ColourMath.parseHex("#8c6cf0") ~= nil)
		assert(ColourMath.parseHex("  8C6CF0 ") ~= nil)
		assert(ColourMath.parseHex("8C6CF") == nil)
		assert(ColourMath.parseHex("8C6CFG") == nil)
		assert(ColourMath.parseHex("") == nil)
		assert(ColourMath.parseHex("#8C6CF0FF") == nil)
	end,

	["HSL and HSV come back to the same colour"] = function()
		for _, hex in CLASSES do
			local c = ColourMath.fromHex(hex)
			assert(same(ColourMath.fromHsl(ColourMath.toHsl(c)), c), "hsl " .. hex)
			assert(same(ColourMath.fromHsv(ColourMath.toHsv(c)), c), "hsv " .. hex)
		end
	end,

	["the mockup's palettes: tint, colour, deep"] = function()
		-- the values work/burst-options.html showed the owner
		local dragon = ColourMath.palette(ColourMath.fromHex("8C6CF0"))
		assert(ColourMath.toHex(dragon.light) == "CBB7E2", ColourMath.toHex(dragon.light))
		assert(ColourMath.toHex(dragon.deep) == "491FCC", ColourMath.toHex(dragon.deep))
		local base = ColourMath.palette(ColourMath.fromHex("FFD23F"))
		assert(ColourMath.toHex(base.light) == "FFE592", ColourMath.toHex(base.light))
		assert(ColourMath.toHex(base.deep) == "C4980A", ColourMath.toHex(base.deep))
	end,

	["the deep shade is darker than the colour and the tint lighter"] = function()
		for _, hex in CLASSES do
			local p = ColourMath.palette(ColourMath.fromHex(hex))
			local l = ColourMath.luminance(p.tone)
			assert(ColourMath.luminance(p.deep) < l, hex)
			assert(ColourMath.luminance(p.light) > l, hex)
		end
	end,

	["letters read on every card: ink or cream, whichever is clearer, at least 3 to 1"] = function()
		local ink, paper = ColourMath.INK, ColourMath.PAPER
		for _, hex in CLASSES do
			local p = ColourMath.palette(ColourMath.fromHex(hex))
			for _, face in { p.tone, p.light, p.deep, paper } do
				local letter = if ColourMath.inkReads(face) then ink else paper
				assert(ColourMath.contrast(face, letter) >= 3, hex .. " " .. ColourMath.toHex(face))
			end
		end
		assert(ColourMath.inkReads(paper))
		assert(not ColourMath.inkReads(ink))
	end,

	["the countdown's pick is the same for the same round, and spreads over rounds"] = function()
		local seen = {}
		for round = 1, 400 do
			local seed = 1795172540.5 + round * 47.3
			local a = ColourMath.pick(seed, 8)
			assert(a == ColourMath.pick(seed, 8))
			assert(a >= 1 and a <= 8)
			seen[a] = (seen[a] or 0) + 1
		end
		for index = 1, 8 do
			assert((seen[index] or 0) >= 20, "every colour comes up: " .. index)
		end
		assert(ColourMath.pick(123.4, 1) == 1)
	end,

	["the countdown's colours: the same list for the same round, no neighbours alike, all colours used"] = function()
		local counts = {}
		for round = 1, 300 do
			local seed = 1795172540.25 + round * 61.7
			local a = ColourMath.sequence(seed, 10, 8)
			local b = ColourMath.sequence(seed, 10, 8)
			assert(#a == 10)
			for index = 1, 10 do
				assert(a[index] == b[index], "same everywhere")
				assert(a[index] >= 1 and a[index] <= 8)
				if index > 1 then
					assert(a[index] ~= a[index - 1], "no two neighbours alike")
				end
				counts[a[index]] = (counts[a[index]] or 0) + 1
			end
		end
		for colour = 1, 8 do
			assert((counts[colour] or 0) > 200, "every colour comes up: " .. colour)
		end
		-- not one colour for the whole countdown (the owner: "not random SETS of colors")
		local one = ColourMath.sequence(1795172540.25, 10, 8)
		local seen = {}
		for _, pick in one do
			seen[pick] = true
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		assert(kinds >= 4)
	end,

	["the wheel: red at the top, then yellow, green, cyan, blue, magenta clockwise"] = function()
		local hue, strength = ColourMath.wheelAt(0, -1)
		assert(near(hue, 0) and near(strength, 1))
		hue = ColourMath.wheelAt(1, 0)
		assert(near(hue, 0.25), "a quarter round, right")
		hue = ColourMath.wheelAt(0, 1)
		assert(near(hue, 0.5), "half round, bottom: cyan")
		hue = ColourMath.wheelAt(-1, 0)
		assert(near(hue, 0.75))
		local _, middle = ColourMath.wheelAt(0, 0)
		assert(middle == 0)
		local _, out = ColourMath.wheelAt(3, 4)
		assert(out == 1, "past the rim counts as the rim")
		local x, y = ColourMath.wheelPoint(0.25, 0.5)
		assert(near(x, 0.5) and near(y, 0))
		local back, s = ColourMath.wheelAt(ColourMath.wheelPoint(0.6, 0.7))
		assert(near(back, 0.6) and near(s, 0.7))
	end,
}
