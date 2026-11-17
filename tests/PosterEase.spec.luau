--!strict
-- The fight-poster mockup's motion curves: the spring is its CSS linear() list point for point, the pop is its
-- cubic-bezier, and keyframes ease each stretch on its own.
local PosterEase = require("../src/shared/Core/PosterEase")

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-3)
end

return {
	["the spring starts at 0, ends at 1 and passes through the mockup's stops"] = function()
		assert(PosterEase.spring(0) == 0)
		assert(PosterEase.spring(1) == 1)
		assert(PosterEase.spring(-1) == 0 and PosterEase.spring(2) == 1)
		assert(near(PosterEase.spring(0.129), 0.723))
		assert(near(PosterEase.spring(0.243), 1.149))
		assert(near(PosterEase.spring(0.271), 1.163), "the peak")
		assert(near(PosterEase.spring(0.538), 0.974), "the dip")
		assert(near(PosterEase.spring(0.838), 1.004))
	end,

	["stops without a position sit evenly between their neighbours"] = function()
		-- 1.017, 1.077, 1.121 lie between 16.7 % and 24.3 %
		assert(near(PosterEase.spring(0.186), 1.017))
		assert(near(PosterEase.spring(0.205), 1.077))
		assert(near(PosterEase.spring(0.224), 1.121))
		-- 0.991 lies halfway between 43.1 % and 51 %
		assert(near(PosterEase.spring(0.4705), 0.991))
	end,

	["the spring never strays far: it overshoots once and dips once"] = function()
		local high, low = 0, 1
		for step = 300, 1000 do
			local v = PosterEase.spring(step / 1000)
			high, low = math.max(high, v), math.min(low, v)
		end
		assert(high < 1.16 and low > 0.97, `{high} {low}`)
	end,

	["the pop overshoots once and lands on 1"] = function()
		assert(PosterEase.pop(0) == 0 and PosterEase.pop(1) == 1)
		local peak = 0
		for step = 0, 100 do
			peak = math.max(peak, PosterEase.pop(step / 100))
		end
		assert(peak > 1.1 and peak < 1.2, tostring(peak))
	end,

	["the CSS ease keywords match their known midpoints"] = function()
		assert(near(PosterEase.ease(0.5), 0.8024, 2e-3))
		assert(near(PosterEase.easeIn(0.5), 0.3154, 2e-3))
		assert(near(PosterEase.easeOut(0.5), 0.6846, 2e-3))
		assert(PosterEase.linear(0.25) == 0.25)
	end,

	["keyframes ease each stretch on its own and hold the ends"] = function()
		local frames = { { 0, -10 }, { 0.35, 8 }, { 0.7, -4 }, { 1, 0 } }
		assert(PosterEase.keyframes(frames, 0, PosterEase.linear) == -10)
		assert(near(PosterEase.keyframes(frames, 0.35, PosterEase.linear), 8))
		assert(near(PosterEase.keyframes(frames, 0.175, PosterEase.linear), -1))
		assert(near(PosterEase.keyframes(frames, 0.85, PosterEase.linear), -2))
		assert(PosterEase.keyframes(frames, 1, PosterEase.ease) == 0)
		assert(PosterEase.keyframes(frames, 5, PosterEase.ease) == 0)
	end,
}
