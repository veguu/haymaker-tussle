--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local ResultPop = require("../src/shared/Core/ResultPop")

local CFG: ResultPop.Settings = {
	StartScale = 0.4,
	PeakScale = 1.16,
	DipScale = 0.97,
	PerfectPeakScale = 1.34,
	PerfectDipScale = 0.93,
	RiseSeconds = 0.08,
	DipSeconds = 0.07,
	SettleSeconds = 0.08,
	HoldSeconds = 0.55,
	PerfectHoldSeconds = 0.65,
	FadeSeconds = 0.25,
}

return {
	["it pops past full size, dips under it, then settles exactly at it"] = function()
		assert(ResultPop.scaleAt(CFG, 0, false) == 0.4, "starts small")
		assert(math.abs(ResultPop.scaleAt(CFG, 0.08, false) - 1.16) < 0.001, "peaks")
		assert(math.abs(ResultPop.scaleAt(CFG, 0.15, false) - 0.97) < 0.001, "dips")
		assert(ResultPop.scaleAt(CFG, 0.23, false) == 1, "settles")
		assert(ResultPop.scaleAt(CFG, 0.5, false) == 1, "stays")
	end,

	["it moves smoothly: no jump between the pop's stages"] = function()
		local last = ResultPop.scaleAt(CFG, 0, true)
		for step = 1, 40 do
			local now = ResultPop.scaleAt(CFG, step / 120, true)
			assert(math.abs(now - last) < 0.2, `jumped at step {step}: {last} to {now}`)
			last = now
		end
	end,

	["a perfect pops harder, and stays a moment longer"] = function()
		assert(
			ResultPop.scaleAt(CFG, 0.08, true) > ResultPop.scaleAt(CFG, 0.08, false),
			"bigger peak"
		)
		assert(ResultPop.duration(CFG, true) > ResultPop.duration(CFG, false), "longer")
	end,

	["it's solid through the hold, then fades out completely"] = function()
		assert(ResultPop.transparencyAt(CFG, 0, false) == 0, "solid at once")
		assert(ResultPop.transparencyAt(CFG, 0.55, false) == 0, "solid through the hold")
		local mid = ResultPop.transparencyAt(CFG, 0.675, false)
		assert(mid > 0.4 and mid < 0.6, `should be half gone, got {mid}`)
		assert(ResultPop.transparencyAt(CFG, 0.8, false) == 1, "gone")
		assert(ResultPop.transparencyAt(CFG, 5, false) == 1, "stays gone")
	end,

	["it's quick: readable, but never in the way of the next kick"] = function()
		assert(ResultPop.duration(CFG, true) < 1, "under a second, even for a perfect")
	end,
}
