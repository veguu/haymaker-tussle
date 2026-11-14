--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Endlag (user, 2026-11-13): every move owes a recovery in which no other move can start, longer on
-- a whiff than on a hit. Run on the game's real numbers.
local GameConfig = require("../src/shared/Config/GameConfig")
local Endlag = require("../src/shared/Core/Endlag")

local CFG: any = GameConfig.Endlag
local OFF: any = table.clone(CFG)
OFF.Enabled = false

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return {
	["every attack has a Hit and a Miss, and a whiff costs more than a hit"] = function()
		for _, move in { "Punch", "Kick", "Uppercut", "Cyclone" } do
			assert(Endlag.isAttack(move))
			local hit, miss = Endlag.recovery(CFG, move, true), Endlag.recovery(CFG, move, false)
			assert(hit > 0 and miss > hit, `{move}: hit {hit}, miss {miss}`)
		end
	end,

	["the other moves have one number each"] = function()
		for _, move in { "Dash", "Blink", "AirKick" } do
			assert(not Endlag.isAttack(move))
			assert(Endlag.recovery(CFG, move) == CFG[move])
			assert(Endlag.recovery(CFG, move, true) == CFG[move], "hit or not makes no difference")
		end
	end,

	["a move nobody set, or nonsense numbers, owes nothing"] = function()
		assert(Endlag.recovery(CFG, "Teabag") == 0)
		local broken: any =
			{ Enabled = true, Tolerance = 0, Dash = -3, Blink = 0 / 0, PunchMiss = "x" }
		assert(Endlag.recovery(broken, "Dash") == 0)
		assert(Endlag.recovery(broken, "Blink") == 0)
		assert(Endlag.recovery(broken, "Punch", false) == 0)
	end,

	["an attack locks through its strike and then its Miss"] = function()
		local lead = GameConfig.Uppercut.Windup + GameConfig.Punch.ActiveSeconds
		local busyUntil = Endlag.started(CFG, "Uppercut", 100, lead)
		assert(near(busyUntil, 100 + lead + CFG.UppercutMiss))
		assert(Endlag.busy(CFG, busyUntil, 100 + lead))
		assert(Endlag.busy(CFG, busyUntil, busyUntil - 0.01))
		assert(not Endlag.busy(CFG, busyUntil, busyUntil))
	end,

	["landing it cuts the lock to its Hit, and only ever shortens it"] = function()
		local lead = GameConfig.Uppercut.Windup + GameConfig.Punch.ActiveSeconds
		local busyUntil = Endlag.started(CFG, "Uppercut", 100, lead)
		local hitAt = 100 + lead
		local after = Endlag.landed(CFG, "Uppercut", busyUntil, hitAt)
		assert(near(after, hitAt + CFG.UppercutHit))
		assert(after < busyUntil)
		-- a hit confirmed very late can't make the lock longer than the whiff's
		assert(Endlag.landed(CFG, "Uppercut", busyUntil, busyUntil + 5) == busyUntil)
		-- a dash can't be "landed"
		assert(Endlag.landed(CFG, "Dash", 50, 10) == 50)
	end,

	["a dash or blink locks from its start, with no strike to wait for"] = function()
		assert(near(Endlag.started(CFG, "Dash", 20), 20 + CFG.Dash))
		assert(near(Endlag.started(CFG, "Blink", 20, 0), 20 + CFG.Blink))
	end,

	["a new lock never ends before one already running"] = function()
		local long = Endlag.started(CFG, "Cyclone", 10, 0.3)
		assert(Endlag.started(CFG, "Dash", 10.1, 0, long) == long)
		assert(Endlag.started(CFG, "Cyclone", 30, 0.3, long) > long)
	end,

	["punch after punch is no slower than its cooldown already made it"] = function()
		local punch = GameConfig.Punch
		local lead = punch.Windup + punch.ActiveSeconds
		local hit = Endlag.landed(CFG, "Punch", Endlag.started(CFG, "Punch", 0, lead), lead)
		assert(hit <= punch.Cooldown, "a landed punch's endlag is inside the punch cooldown")
		local miss = Endlag.started(CFG, "Punch", 0, lead)
		assert(
			miss <= punch.Cooldown + punch.MissRecovery,
			"and a whiff's inside its miss recovery"
		)
	end,

	["the server's slack lets a press right on time through"] = function()
		local busyUntil = 10
		assert(Endlag.busy(CFG, busyUntil, 9.97))
		assert(not Endlag.busy(CFG, busyUntil, 9.97, CFG.Tolerance))
		assert(Endlag.busy(CFG, busyUntil, 9.5, CFG.Tolerance))
		assert(not Endlag.busy(CFG, nil, 0))
	end,

	["switched off, nothing locks"] = function()
		assert(Endlag.recovery(OFF, "Uppercut", false) == 0)
		assert(Endlag.started(OFF, "Uppercut", 100, 0.35) == -math.huge)
		assert(Endlag.started(OFF, "Uppercut", 100, 0.35, 42) == 42)
		assert(not Endlag.busy(OFF, 1e9, 0))
		assert(Endlag.landed(OFF, "Uppercut", 7, 1) == 7)
	end,
}
