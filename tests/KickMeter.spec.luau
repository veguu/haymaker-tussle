--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The air kick's timing meter on the game's real settings. Written 2026-11-12 from the module as it stood
-- in the place (BUILD meter-1), not by the meter's author: it pins down what the code does today.
local GameConfig = require("../src/shared/Config/GameConfig")
local KickMeter = require("../src/shared/Core/KickMeter")

local CFG: any = GameConfig.KickMeter

return {
	["the marker starts well out on a random side and heads inward"] = function()
		local left = KickMeter.plan(CFG, 0, 0)
		local right = KickMeter.plan(CFG, 0.9, 1)
		assert(left.start == -CFG.StartSpanMin and left.dir == 1, "left side, going right")
		assert(right.start == 1 and right.dir == -1, "right end, going left")
		for roll = 0, 10 do
			local plan = KickMeter.plan(CFG, roll / 10, roll / 10)
			assert(math.abs(plan.start) >= CFG.StartSpanMin and math.abs(plan.start) <= 1)
			assert(plan.dir == -math.sign(plan.start), "always toward the middle first")
		end
	end,

	["the marker waits through the bar's entrance, then stays on the bar"] = function()
		local plan = KickMeter.plan(CFG, 0, 0.5)
		assert(KickMeter.position(CFG, plan, 0) == plan.start)
		assert(
			KickMeter.position(CFG, plan, CFG.EntranceSeconds) == plan.start,
			"still at its start"
		)
		assert(
			KickMeter.position(CFG, plan, CFG.EntranceSeconds + 0.05) ~= plan.start,
			"then it moves"
		)
		for step = 0, 400 do
			local at = KickMeter.position(CFG, plan, step / 100)
			assert(at >= -1 and at <= 1, `off the bar at {step / 100} s: {at}`)
		end
	end,

	["the server scores a press a little earlier than it arrived"] = function()
		local plan = KickMeter.plan(CFG, 0, 0)
		local since = CFG.EntranceSeconds + 0.3
		assert(
			KickMeter.pressedAt(CFG, plan, since)
				== KickMeter.position(CFG, plan, since - CFG.PressLagSeconds)
		)
		assert(CFG.PressLagSeconds >= 0 and CFG.PressLagSeconds < 0.1, "a frame or two, no more")
	end,

	["an unpressed meter gives up after its passes"] = function()
		assert(KickMeter.endsAt(CFG) == CFG.EntranceSeconds + CFG.Passes * CFG.SweepSeconds)
		assert(KickMeter.endsAt(CFG) < 3, "nobody hangs in the air for long")
	end,

	["only the distance from the middle counts, the same on both sides"] = function()
		assert(KickMeter.accuracy(0) == 1, "dead centre")
		assert(KickMeter.accuracy(1) == 0 and KickMeter.accuracy(-1) == 0, "either end")
		assert(KickMeter.accuracy(0.3) == KickMeter.accuracy(-0.3))
		assert(KickMeter.accuracy(5) == 0, "off the bar counts as the end")
	end,

	["the named results run poor, okay, good, perfect toward the middle"] = function()
		assert(CFG.OkayAccuracy < CFG.GoodAccuracy and CFG.GoodAccuracy < CFG.PerfectAccuracy)
		assert(KickMeter.tier(CFG, 1) == "perfect")
		assert(KickMeter.tier(CFG, CFG.PerfectAccuracy) == "perfect", "on the line counts")
		assert(KickMeter.tier(CFG, CFG.GoodAccuracy) == "good")
		assert(KickMeter.tier(CFG, CFG.OkayAccuracy) == "okay")
		assert(KickMeter.tier(CFG, 0) == "poor")
		for _, tier: any in { "poor", "okay", "good", "perfect" } do
			assert(KickMeter.tierAt(KickMeter.tierIndex(tier)) == tier, tier)
		end
		assert(KickMeter.tierAt(-3) == "poor" and KickMeter.tierAt(99) == "perfect", "clamped")
	end,

	["better timing hits harder, stops the world longer and throws you higher"] = function()
		local last = -1
		for step = 0, 10 do
			local quality = KickMeter.quality(CFG, step / 10)
			assert(quality >= last, "quality never falls as accuracy rises")
			last = quality
		end
		assert(KickMeter.quality(CFG, 0) == 0 and KickMeter.quality(CFG, 1) == 1)
		assert(
			KickMeter.strength(CFG, 0) == CFG.StrengthMin
				and KickMeter.strength(CFG, 1) == CFG.StrengthMax
		)
		assert(KickMeter.stop(CFG, 0) == CFG.StopMin and KickMeter.stop(CFG, 1) == CFG.StopMax)
		assert(KickMeter.rise(CFG, 0) == CFG.RiseMin and KickMeter.rise(CFG, 1) == CFG.RiseMax)
		assert(
			CFG.StrengthMin > 0 and CFG.StrengthMin < CFG.StrengthMax,
			"the worst kick still lands"
		)
		assert(CFG.StopMin < CFG.StopMax and CFG.RiseMin < CFG.RiseMax)
		assert(KickMeter.strength(CFG, 7) == CFG.StrengthMax, "quality is clamped")
	end,

	["a marker plan from outside is made safe"] = function()
		assert(KickMeter.readPlan("x", 1) == nil and KickMeter.readPlan(0, nil) == nil)
		assert(KickMeter.readPlan(0 / 0, 1) == nil, "NaN is refused")
		local plan: any = KickMeter.readPlan(4, -0.2)
		assert(
			plan.start == 1 and plan.dir == -1,
			"clamped to the bar, and a direction is only a side"
		)
	end,
}
