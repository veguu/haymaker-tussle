--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local LockOn = require("../src/shared/Core/LockOn")

local CFG: LockOn.Settings = {
	Range = 70,
	ReleaseRange = 85,
	LookDegrees = 12,
	LookReleaseDegrees = 18,
	LookStuds = 2.5,
	LostSightSeconds = 1.5,
	PopSeconds = 0.26,
	PopStart = 0.88,
	PopPeak = 1.06,
	PopPeakAt = 0.65,
	SqueezeSeconds = 0.24,
	SqueezeStart = 1.04,
	SqueezeLow = 0.82,
	SqueezeLowAt = 0.55,
	LockedScale = 0.88,
	PulseSeconds = 0.65,
	PulseRepeats = 2,
	PulseStart = 0.94,
	PulseEnd = 1.14,
	PulseOpacity = 0.65,
	FadeSeconds = 0.15,
}

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 0.001)
end

local function option(
	who: string,
	distance: number,
	degrees: number,
	visible: boolean?
): LockOn.Option<string>
	return { who = who, distance = distance, degrees = degrees, visible = visible ~= false }
end

return {
	["the easing matches CSS's own curves"] = function()
		assert(
			LockOn.bezier(0, 0, 0.58, 1, 0) == 0 and LockOn.bezier(0, 0, 0.58, 1, 1) == 1,
			"ends"
		)
		-- Published values for ease-out and ease at the halfway point.
		assert(near(LockOn.bezier(0, 0, 0.58, 1, 0.5), 0.683, 0.005), "ease-out")
		assert(near(LockOn.ease(0.5), 0.802, 0.005), "ease")
		local last = 0
		for step = 1, 50 do
			local value = LockOn.ease(step / 50)
			assert(value >= last, "it never runs backward")
			last = value
		end
	end,

	["the pop starts small and clear, overshoots, and ends at full size"] = function()
		local scale, opacity = LockOn.popAt(CFG, 0)
		assert(near(scale, 0.88) and opacity == 0, "start")
		scale, opacity = LockOn.popAt(CFG, 0.26 * 0.65)
		assert(near(scale, 1.06) and opacity == 1, "peak at 65%")
		scale, opacity = LockOn.popAt(CFG, 0.26)
		assert(scale == 1 and opacity == 1, "end")
		assert(LockOn.popAt(CFG, 5) == 1, "stays there")
	end,

	["locking dips past its locked size, then settles at 88%"] = function()
		assert(near(LockOn.squeezeAt(CFG, 0), 1.04), "start")
		assert(near(LockOn.squeezeAt(CFG, 0.24 * 0.55), 0.82), "the dip")
		assert(near(LockOn.squeezeAt(CFG, 0.24), 0.88), "settled")
		assert(near(LockOn.squeezeAt(CFG, 9), 0.88), "stays")
	end,

	["the pulse expands and fades twice, then it's over"] = function()
		local scale, opacity = LockOn.pulseAt(CFG, 0)
		assert(near(scale :: number, 0.94) and near(opacity :: number, 0.65), "start")
		scale, opacity = LockOn.pulseAt(CFG, 0.649)
		assert((scale :: number) > 1.13 and (opacity :: number) < 0.01, "nearly out")
		scale = LockOn.pulseAt(CFG, 0.65)
		assert(near(scale :: number, 0.94), "the second one starts over")
		assert(LockOn.pulseAt(CFG, 1.3) == nil, "finished after two")
	end,

	["spinning takes the given time per turn and never jumps"] = function()
		assert(near(LockOn.spin(5, 1.25), 90), "a quarter of 5 s")
		assert(near(LockOn.spin(7, 7), 0), "a full turn")
		assert(near(LockOn.spin(5, 6.25), 90), "keeps going")
	end,

	["looking at someone in range shows them"] = function()
		assert(LockOn.pick(CFG, { option("a", 30, 5) }) == "a", "in view")
		assert(LockOn.pick(CFG, { option("a", 30, 40) }) == nil, "looking away")
		assert(LockOn.pick(CFG, { option("a", 90, 2) }) == nil, "too far")
		assert(LockOn.pick(CFG, { option("a", 30, 2, false) }) == nil, "behind a wall")
		assert(LockOn.pick(CFG, {}) == nil, "nobody there")
	end,

	["close up, looking anywhere at the body counts"] = function()
		assert(LockOn.pick(CFG, { option("a", 5, 20) }) == "a", "atan(2.5 / 5) is about 26 degrees")
		assert(LockOn.pick(CFG, { option("a", 40, 20) }) == nil, "not from further away")
	end,

	["only one is ever shown: the nearest to where you look"] = function()
		local who = LockOn.pick(CFG, { option("a", 20, 9), option("b", 60, 3), option("c", 30, 7) })
		assert(who == "b", `got {who}`)
	end,

	["the one showing keeps it with a little room, so it can't flicker"] = function()
		assert(LockOn.pick(CFG, { option("a", 30, 15) }, "a") == "a", "held past 12 degrees")
		assert(LockOn.pick(CFG, { option("a", 30, 15) }) == nil, "but 15 wouldn't earn it")
		assert(
			LockOn.pick(CFG, { option("a", 30, 15), option("b", 30, 1) }, "a") == "a",
			"no switching"
		)
		assert(
			LockOn.pick(CFG, { option("a", 30, 25), option("b", 30, 1) }, "a") == "b",
			"once it's gone"
		)
		assert(LockOn.pick(CFG, { option("a", 80, 5) }, "a") == "a", "held past 70 studs")
		assert(LockOn.pick(CFG, { option("a", 90, 5) }, "a") == nil, "not past 85")
	end,

	["losing sight of the one showing drops them straight away"] = function()
		assert(LockOn.pick(CFG, { option("a", 30, 5, false) }, "a") == nil, "gone")
	end,

	["a selection survives looking away, and ends only by distance or long loss of sight"] = function()
		assert(LockOn.keepsSelection(CFG, 30, 0), "normal")
		assert(LockOn.keepsSelection(CFG, 80, 1), "a moment behind cover")
		assert(not LockOn.keepsSelection(CFG, 90, 0), "too far")
		assert(not LockOn.keepsSelection(CFG, 30, 1.5), "out of sight too long")
	end,
}
