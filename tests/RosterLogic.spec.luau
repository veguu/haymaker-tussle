--!strict
-- The fighters' row: tile size, places, the crown, and the stand-in for a picture.
local RosterLogic = require("../src/shared/Core/RosterLogic")

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

return {
	["a few fighters get the biggest tile, a full round a smaller one, never under the least"] = function()
		local side, step = RosterLogic.fit(5, 1000, 40, 22, 4)
		assert(side == 40 and step == 44)
		side, step = RosterLogic.fit(25, 1000, 40, 22, 4)
		assert(side == 36 and step == 40, "25 tiles of 36 and 24 gaps of 4 are 996")
		side, step = RosterLogic.fit(25, 300, 40, 22, 4)
		assert(side == 22 and step == 26, "too narrow: the least size, and the row runs wide")
		side = RosterLogic.fit(0, 1000, 40, 22, 4)
		assert(side == 40)
	end,

	["the row is centred: its places mirror each other about the middle"] = function()
		assert(near(RosterLogic.slot(1, 1, 44), 0))
		assert(near(RosterLogic.slot(1, 2, 44), -22) and near(RosterLogic.slot(2, 2, 44), 22))
		assert(near(RosterLogic.slot(3, 5, 44), 0))
		for index = 1, 7 do
			assert(near(RosterLogic.slot(index, 7, 30), -RosterLogic.slot(8 - index, 7, 30)))
		end
	end,

	["nobody is crowned before the first ring-out"] = function()
		assert(RosterLogic.leader({ "a", "b" }, {}, {}) == nil)
		assert(RosterLogic.leader({ "a", "b" }, { a = 0 }, { a = 1 }) == nil)
	end,

	["the crown goes to the most ring-outs, and on a tie to whoever got there first"] = function()
		assert(
			RosterLogic.leader({ "a", "b", "c" }, { a = 1, b = 3, c = 2 }, { a = 1, b = 5, c = 4 })
				== "b"
		)
		assert(RosterLogic.leader({ "a", "b" }, { a = 2, b = 2 }, { a = 9, b = 4 }) == "b")
		assert(
			RosterLogic.leader({ "b", "a" }, { a = 2, b = 2 }, { a = 9, b = 4 }) == "b",
			"order does not decide"
		)
	end,

	["someone out of the row cannot wear the crown"] = function()
		assert(RosterLogic.leader({ "a" }, { a = 1, gone = 5 }, { a = 2, gone = 1 }) == "a")
	end,

	["an eased move covers the same ground whatever the frame rate, and lands"] = function()
		local one = RosterLogic.approach(0, 100, 1 / 30, 10, 0.05)
		local two = RosterLogic.approach(
			RosterLogic.approach(0, 100, 1 / 60, 10, 0.05),
			100,
			1 / 60,
			10,
			0.05
		)
		assert(near(one, two, 1e-9))
		assert(one > 0 and one < 100)
		assert(RosterLogic.approach(99.97, 100, 1 / 60, 10, 0.05) == 100, "close enough is there")
		assert(RosterLogic.approach(5, 5, 1, 10, 0.05) == 5)
	end,

	["the spring sets off gently, never overshoots, and lands"] = function()
		local x, v = 0, 0
		local first = 0
		local peak = 0
		for frame = 1, 120 do
			local was = x
			x, v = RosterLogic.spring(x, v, 100, 1 / 60, 14, 0.05)
			if frame == 1 then
				first = x - was
			end
			peak = math.max(peak, x - was)
			assert(x <= 100 + 1e-9, "no overshoot")
			assert(x >= was - 1e-9, "never backwards")
		end
		assert(x == 100 and v == 0, "it lands")
		assert(first < peak / 2, "the first frame is slower than its fastest: it eases in")
	end,

	["the spring is the same at 30 and at 60 frames a second"] = function()
		local a, av = RosterLogic.spring(0, 0, 100, 1 / 30, 14, 0.05)
		local b, bv = RosterLogic.spring(0, 0, 100, 1 / 60, 14, 0.05)
		b, bv = RosterLogic.spring(b, bv, 100, 1 / 60, 14, 0.05)
		assert(near(a, b, 1e-9) and near(av, bv, 1e-9))
	end,

	["a target that moves mid-way bends the move: the speed carries over"] = function()
		local x, v = 0, 0
		for _ = 1, 6 do
			x, v = RosterLogic.spring(x, v, 100, 1 / 60, 14, 0.05)
		end
		local before = v
		local x2, v2 = RosterLogic.spring(x, v, 60, 1 / 600, 14, 0.05)
		assert(math.abs(v2 - before) < before * 0.2, "no jolt in the speed")
		assert(x2 > x, "still going the way it was")
	end,
}
