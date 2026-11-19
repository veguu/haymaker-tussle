--!strict
local HudLogic = require("../src/shared/Core/HudLogic")

return {
	["a tile recovering beats unavailable, and is ready only when usable"] = function()
		assert(HudLogic.actionState(1, 2, false) == "recovering")
		assert(HudLogic.actionState(1, 2, true) == "recovering")
		assert(HudLogic.actionState(3, 2, true) == "ready")
		assert(HudLogic.actionState(3, 2, false) == "unavailable")
	end,

	["cooldown share runs from 1 to 0 and never past"] = function()
		assert(HudLogic.cooldownLeft(0, 3, 3) == 1)
		assert(math.abs(HudLogic.cooldownLeft(1.5, 3, 3) - 0.5) < 1e-9)
		assert(HudLogic.cooldownLeft(5, 3, 3) == 0)
		assert(HudLogic.cooldownLeft(0, 3, 0) == 0)
	end,

	["stagger accent only for a real gain"] = function()
		assert(HudLogic.staggerAccent(10, 22, 8))
		assert(not HudLogic.staggerAccent(10, 14, 8))
		assert(not HudLogic.staggerAccent(30, 10, 8), "recovering never flashes")
	end,

	["the strip shows survivors in a fight, countdowns before, nothing without a round"] = function()
		assert(not HudLogic.strip({}, 0).visible)
		local s = HudLogic.strip({ phase = "Fighting", alive = 3, total = 4 }, 0)
		assert(s.visible and s.count == "3" and s.total == "4" and not s.finalTwo)
		s = HudLogic.strip({ phase = "Fighting", alive = 2, total = 2 }, 0)
		assert(s.finalTwo and s.title == "FINAL TWO", "a two-player match is final two at once")
		s = HudLogic.strip({ phase = "Intermission", countdownEnd = 10.2 }, 5)
		assert(s.count == "6")
		s = HudLogic.strip({ phase = "Intermission", countdownEnd = 3 }, 5)
		assert(s.count == "0", "never negative")
	end,

	["no GET READY strip: the start of a round is the countdown's"] = function()
		assert(not HudLogic.strip({ phase = "Starting", countdownEnd = 9 }, 5).visible)
		assert(not HudLogic.strip({ phase = "Starting" }, 5).visible)
	end,

	["the round-start countdown: nothing, then 3, 2, 1, then the word, then nothing"] = function()
		assert(HudLogic.countBeat(0, nil, 1) == nil, "no countdown, no beat")
		assert(
			HudLogic.countBeat(6.5, 10, 1) == nil,
			"the first second of a 4 s start shows nothing"
		)
		assert(HudLogic.countBeat(7, 10, 1) == 3, "3 lands exactly three seconds before")
		assert(HudLogic.countBeat(7.99, 10, 1) == 3)
		assert(HudLogic.countBeat(8, 10, 1) == 2)
		assert(HudLogic.countBeat(9.2, 10, 1) == 1)
		assert(HudLogic.countBeat(10, 10, 1) == 0, "the word lands as the fight starts")
		assert(HudLogic.countBeat(10.9, 10, 1) == 0)
		assert(HudLogic.countBeat(11, 10, 1) == nil)
		assert(math.abs(HudLogic.countLate(8.25, 10, 2) - 0.25) < 1e-9)
		assert(HudLogic.countLate(7, 10, 3) == 0)
	end,

	["an intermission with no countdown (too few players ready) hides the strip"] = function()
		local s = HudLogic.strip({ phase = "Intermission" }, 5)
		assert(not s.visible, "no NEXT ROUND 0 while nothing is counting")
		s = HudLogic.strip({ phase = "Intermission", countdownEnd = 4 }, 5)
		assert(s.visible and s.count == "0", "a countdown that has just run out still shows")
	end,

	["feed lines for a knock, a fall with nobody credited, and a disconnect"] = function()
		assert(HudLogic.feedLine("ace", "vegu", "knocked") == "vegu knocked out ace")
		assert(HudLogic.feedLine("ace", nil, "knocked") == "ace fell")
		assert(HudLogic.feedLine("ace", nil, "fell") == "ace fell")
		assert(HudLogic.feedLine("ace", "vegu", "left") == "ace left")
	end,

	["no emphasis while a timed prompt is up, or with reduced motion"] = function()
		assert(HudLogic.emphasize(false, false))
		assert(not HudLogic.emphasize(true, false))
		assert(not HudLogic.emphasize(false, true))
	end,

	["stagger catch-up retargets from where the bar is and lands exactly"] = function()
		assert(HudLogic.catchUp(0, 30, 0, 0.15) == 0)
		assert(HudLogic.catchUp(0, 30, 0.15, 0.15) == 30)
		local mid = HudLogic.catchUp(0, 30, 0.075, 0.15)
		assert(mid > 15 and mid < 30, "eases out")
		-- Three quick hits: each retarget starts from the current bar value, so it ends on the newest.
		local bar = HudLogic.catchUp(0, 12, 0.05, 0.15)
		bar = HudLogic.catchUp(bar, 24, 0.05, 0.15)
		bar = HudLogic.catchUp(bar, 36, 0.15, 0.15)
		assert(bar == 36)
	end,
	["stagger bands: calm under 40, rising 40-69, critical from 70"] = function()
		assert(HudLogic.staggerBand(0, 100) == "calm")
		assert(HudLogic.staggerBand(39, 100) == "calm")
		assert(HudLogic.staggerBand(40, 100) == "rising")
		assert(HudLogic.staggerBand(69, 100) == "rising")
		assert(HudLogic.staggerBand(70, 100) == "critical")
		assert(HudLogic.staggerBand(100, 100) == "critical")
	end,

	["the knockback caption has one decimal"] = function()
		assert(HudLogic.multiplierText(1) == "1.0")
		assert(HudLogic.multiplierText(3.35) == "3.4")
		assert(HudLogic.multiplierText(6) == "6.0")
	end,

	["a drop is recovery only after the delay; sooner it's hit relief"] = function()
		assert(HudLogic.recovering(40, 43, 10, 6, 3))
		assert(not HudLogic.recovering(40, 43, 10, 8, 3))
		assert(not HudLogic.recovering(43, 40, 10, 0, 3))
	end,

	["your stagger number goes white, yellow, pink at the same shares as the bar"] = function()
		local third, twoThirds = 1 / 3, 2 / 3
		assert(HudLogic.staggerTier(0, 100, third, twoThirds) == "white")
		assert(HudLogic.staggerTier(33, 100, third, twoThirds) == "white")
		assert(HudLogic.staggerTier(34, 100, third, twoThirds) == "yellow")
		assert(HudLogic.staggerTier(66, 100, third, twoThirds) == "yellow")
		assert(HudLogic.staggerTier(67, 100, third, twoThirds) == "pink")
		assert(HudLogic.staggerTier(100, 100, third, twoThirds) == "pink")
		-- at the mockup's range (0 to 150) the steps land on 50 and 100
		assert(HudLogic.staggerTier(49, 150, third, twoThirds) == "white")
		assert(HudLogic.staggerTier(50, 150, third, twoThirds) == "yellow")
		assert(HudLogic.staggerTier(100, 150, third, twoThirds) == "pink")
	end,

	["the segmented bar lights from the first hit and fills only at the top"] = function()
		assert(HudLogic.segmentsLit(0, 100, 12) == 0)
		assert(HudLogic.segmentsLit(1, 100, 12) == 1, "any stagger lights one")
		assert(HudLogic.segmentsLit(7.2, 100, 12) == 1)
		assert(HudLogic.segmentsLit(50, 100, 12) == 6)
		assert(HudLogic.segmentsLit(100, 100, 12) == 12)
		assert(HudLogic.segmentsLit(400, 100, 12) == 12, "never past the last")
	end,

	["the speed dial lights no tick at rest, one for any movement, all past its top"] = function()
		assert(HudLogic.speedTicks(0, 140, 30) == 0)
		assert(HudLogic.speedTicks(0.4, 140, 30) == 0, "standing still")
		assert(HudLogic.speedTicks(1, 140, 30) == 1, "any movement lights one")
		assert(HudLogic.speedTicks(70, 140, 30) == 15)
		assert(HudLogic.speedTicks(140, 140, 30) == 30)
		assert(HudLogic.speedTicks(250, 140, 30) == 30, "never past the last")
	end,

	["speed is white up to a run, yellow above it, pink from the redline"] = function()
		assert(HudLogic.speedTier(0, 50, 100) == "white")
		assert(HudLogic.speedTier(49.9, 50, 100) == "white")
		assert(HudLogic.speedTier(50, 50, 100) == "yellow")
		assert(HudLogic.speedTier(99, 50, 100) == "yellow")
		assert(HudLogic.speedTier(100, 50, 100) == "pink")
		assert(HudLogic.speedTier(250, 50, 100) == "pink")
	end,

	["segments are white, yellow and pink in thirds"] = function()
		local third, twoThirds = 1 / 3, 2 / 3
		for index = 1, 12 do
			local want = if index <= 4 then "white" elseif index <= 8 then "yellow" else "pink"
			assert(HudLogic.segmentTier(index, 12, third, twoThirds) == want, `segment {index}`)
		end
	end,

	["the stagger word: rising after a gain, recovering while it drains, else steady"] = function()
		assert(HudLogic.staggerWord(10.5, 10, 0.8, false) == "RISING")
		assert(HudLogic.staggerWord(10.5, 10, 0.8, true) == "RISING", "a fresh gain wins")
		assert(HudLogic.staggerWord(11, 10, 0.8, false) == "STEADY")
		assert(HudLogic.staggerWord(14, 10, 0.8, true) == "RECOVERING")
		assert(HudLogic.staggerWord(0, -math.huge, 0.8, false) == "STEADY")
	end,
}
