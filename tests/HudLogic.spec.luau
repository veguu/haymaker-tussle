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

	["the speed gauge fills to running speed, then shows the extra separately"] = function()
		local base, over = HudLogic.speedGauge(18, 36, 120)
		assert(base == 0.5 and over == 0)
		base, over = HudLogic.speedGauge(84, 36, 120)
		assert(base == 1 and math.abs(over - 48 / 84) < 1e-9)
		base, over = HudLogic.speedGauge(400, 36, 120)
		assert(base == 1 and over == 1)
	end,

	["speed digits hold steady through small wobble, and reach zero"] = function()
		assert(HudLogic.steadyDigits(36, 35.6, 0.8) == 36)
		assert(HudLogic.steadyDigits(36, 34.9, 0.8) == 35)
		assert(HudLogic.steadyDigits(3, 0.2, 0.8) == 0)
		assert(HudLogic.steadyDigits(36, 84, 0.8) == 84, "a propel shows its real speed")
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
		s = HudLogic.strip({ phase = "Starting", countdownEnd = 3 }, 5)
		assert(s.count == "0", "never negative")
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
}
