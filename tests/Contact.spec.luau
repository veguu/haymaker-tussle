--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Contact between fighters on the game's real settings: point-blank punches, crossings, the grace before
-- the active frames, bumps, and a punch taking priority over a bump on the same impact. The server runs
-- these exact functions (CombatService.sample, KnockbackService:_checkBumps), so a regression here is
-- a regression in play.
local Combat = require("../src/shared/Core/Combat")
local GameConfig = require("../src/shared/Config/GameConfig")

local PUNCH: any = GameConfig.Punch
local KNOCK: any = GameConfig.Knockback
local STAGGER: any = GameConfig.Stagger
local MOVE: any = GameConfig.Movement

local FRAME = 1 / 60

type Path = (t: number) -> (number, number)

-- A swing pressed at 0, run frame by frame the way the server runs it: the windup, then the active
-- window, each frame looking back over the moments since the last look. The attacker faces -Z.
-- Returns the moment of contact, or nil and the reason it missed.
local function swing(
	cfg: any,
	attacker: Path,
	target: Path,
	side: string?,
	firstFrame: number?
): (number?, string?)
	local acceptedAt = 0
	local activeFrom = cfg.Windup
	local activeUntil = cfg.Windup + cfg.ActiveSeconds
	local checked: number? = nil
	local why: string? = nil
	local now = firstFrame or activeFrom
	while true do
		local from, to =
			Combat.contactWindow(cfg, acceptedAt, activeFrom, activeUntil, checked, now)
		if from and to then
			checked = to
			local times = Combat.sweepTimes(from, to, cfg.SweepStep)
			local samples = {}
			for _, moment in times do
				local ax, az = attacker(moment)
				local tx, tz = target(moment)
				table.insert(samples, { ax = ax, ay = 0, az = az, tx = tx, ty = 0, tz = tz })
			end
			local index, reason = Combat.sweepReach(cfg, samples, 0, -1, side)
			if index then
				return times[index], nil
			end
			why = reason
		end
		if checked and checked >= activeUntil then
			return nil, why
		end
		now += FRAME
	end
end

local function still(x: number, z: number): Path
	return function()
		return x, z
	end
end

-- Moving along Z at `speed`, at the attacker's position (x = 0, z = 0) at time `crossAt`.
local function crossing(speed: number, crossAt: number, x: number?): Path
	return function(t: number)
		return x or 0, speed * (t - crossAt)
	end
end

local function withGrace(seconds: number): any
	local cfg = table.clone(PUNCH)
	cfg.GraceSeconds = seconds
	return cfg
end

-- Bump checks every 0.05 s along two paths; returns the times bumps started.
local function bumps(a: Path, b: Path, va: { number }, vb: { number }, seconds: number): { number }
	local pair = Combat.newBumpPair()
	local out = {}
	local t = 0
	while t <= seconds do
		local ax, az = a(t)
		local bx, bz = b(t)
		local closing
		pair, closing =
			Combat.stepBumpPair(KNOCK, pair, bx - ax, bz - az, va[1] - vb[1], va[2] - vb[2], t)
		if closing then
			table.insert(out, t)
		end
		t += 0.05
	end
	return out
end

return {
	-- 1. Point blank ---------------------------------------------------------------------------------
	["exact overlap connects with every swing, centres coinciding"] = function()
		for _, side in { "Left", "Right", "Uppercut" } do
			local at = swing(PUNCH, still(0, 0), still(0, 0), side)
			assert(at ~= nil, `{side} missed at exact overlap`)
		end
	end,

	["exact overlap throws the target the way the punch was thrown, every time"] = function()
		local fx, fz = 0, -1
		for _, offset in { { 0, 0 }, { 0.01, 0 }, { -0.3, 0.2 }, { 0.5, 0.5 } } do
			local x, z = Combat.punchAway(PUNCH, offset[1], offset[2], fx, fz)
			assert(x == fx and z == fz, `({offset[1]}, {offset[2]}) threw ({x}, {z})`)
		end
		-- Further apart, it's away from the attacker as before.
		local x, z = Combat.punchAway(PUNCH, 3, 0, fx, fz)
		assert(math.abs(x - 1) < 1e-9 and math.abs(z) < 1e-9, "away from the attacker")
	end,

	["outside the overlap, each swing keeps its own direction"] = function()
		-- 4.5 studs away, 50 degrees to the left: the left hook's side.
		local r = math.rad(-50)
		local x, z = math.sin(r) * 4.5, -math.cos(r) * 4.5
		assert(swing(PUNCH, still(0, 0), still(x, z), "Left") ~= nil, "left hook reaches its side")
		local at, why = swing(PUNCH, still(0, 0), still(x, z), "Right")
		assert(at == nil and why == "facing", `right hook shouldn't reach the left: {why}`)
		local up, upWhy = swing(PUNCH, still(0, 0), still(x, z), "Uppercut")
		assert(up == nil and upWhy == "facing", "nor should the uppercut")
	end,

	-- 2. Crossings and the grace window --------------------------------------------------------------
	["a target crossing you just before the swing goes live is hit"] = function()
		-- Crosses your centre 60 ms before the swing goes live and is behind you, out of reach, by then.
		local target = crossing(72, PUNCH.Windup - 0.06)
		local tx, tz = target(PUNCH.Windup)
		assert(
			not Combat.inHitbox(PUNCH, 0, 0, 0, 0, -1, tx, 0, tz, "Left"),
			"setup: gone at activeFrom"
		)
		local at = swing(PUNCH, still(0, 0), target, "Left")
		assert(at ~= nil and at < PUNCH.Windup, "forgiven in the grace window")
	end,

	["it works when you're the one moving, and when both are"] = function()
		local me = function(t: number)
			return 0, -84 * (t - (PUNCH.Windup - 0.06))
		end
		assert(swing(PUNCH, me, still(0, 0), "Left") ~= nil, "you ran through them")
		local meHalf = function(t: number)
			return 0, -50 * (t - (PUNCH.Windup - 0.05))
		end
		assert(
			swing(PUNCH, meHalf, crossing(50, PUNCH.Windup - 0.05), "Left") ~= nil,
			"both running"
		)
	end,

	["the grace ends where it says: inside it hits, just outside misses"] = function()
		-- The target is last inside the hitbox when its centre is OverlapRadius behind yours.
		local speed = 72
		local inside = PUNCH.OverlapRadius / speed
		local edge = PUNCH.Windup - PUNCH.GraceSeconds
		local justIn = crossing(speed, edge + 0.004 - inside)
		local justOut = crossing(speed, edge - 0.004 - inside)
		assert(swing(PUNCH, still(0, 0), justIn, "Left") ~= nil, "4 ms inside the grace should hit")
		local at, why = swing(PUNCH, still(0, 0), justOut, "Left")
		assert(at == nil, `4 ms outside the grace should miss, hit at {at}`)
		assert(why == "facing" or why == "range", `and miss because they're past you: {why}`)
	end,

	["no grace at all is the old behaviour: that same crossing misses"] = function()
		local at = swing(withGrace(0), still(0, 0), crossing(72, PUNCH.Windup - 0.06), "Left")
		assert(at == nil, "only the grace forgives it")
	end,

	["contact before the press never counts, however long the grace"] = function()
		-- Ran past and separated, then pressed: the grace may not reach back before the press.
		local cfg = withGrace(0.5)
		local from = Combat.contactWindow(
			cfg,
			0,
			cfg.Windup,
			cfg.Windup + cfg.ActiveSeconds,
			nil,
			cfg.Windup
		)
		assert(from == 0, `looked back to {from}, before the press`)
		local at = swing(cfg, still(0, 0), crossing(72, -0.15), "Left")
		assert(at == nil, "crossed 0.15 s before the press: a miss")
	end,

	["contact entirely between two server frames is caught"] = function()
		-- Sideways across your back at 240 studs/s, 1 stud behind: inside only for about 19 ms, with a
		-- 50 ms server hitch over it, so no frame lands on it.
		local target = function(t: number)
			return 240 * (t - (PUNCH.Windup + 0.025)), 1
		end
		local first = PUNCH.Windup
		local tx, tz = target(first)
		assert(
			not Combat.inHitbox(PUNCH, 0, 0, 0, 0, -1, tx, 0, tz, "Left"),
			"setup: outside at frame 1"
		)
		local cfg = table.clone(PUNCH)
		-- Two looks only: at the start of the window and once the hitch is over.
		local from, to = Combat.contactWindow(
			cfg,
			0,
			cfg.Windup,
			cfg.Windup + cfg.ActiveSeconds,
			first,
			first + 0.05
		)
		assert(from and to, "a window to look at")
		local hx, hz = target(to :: number)
		assert(
			not Combat.inHitbox(PUNCH, 0, 0, 0, 0, -1, hx, 0, hz, "Left"),
			"setup: outside after the hitch"
		)
		local samples = {}
		for _, moment in Combat.sweepTimes(from :: number, to :: number, cfg.SweepStep) do
			local x, z = target(moment)
			table.insert(samples, { ax = 0, ay = 0, az = 0, tx = x, ty = 0, tz = z })
		end
		assert(Combat.sweepReach(cfg, samples, 0, -1, "Left") ~= nil, "the swept look finds it")
	end,

	["each swing reaches a target once: the window never looks at the same moment twice"] = function()
		local a = PUNCH.Windup
		local from1, to1 = Combat.contactWindow(PUNCH, 0, a, a + PUNCH.ActiveSeconds, nil, a + 0.02)
		local from2 = Combat.contactWindow(PUNCH, 0, a, a + PUNCH.ActiveSeconds, to1, a + 0.04)
		assert(
			from1 and to1 and from2 and from2 >= to1,
			"the second look starts where the first ended"
		)
		local late = Combat.contactWindow(
			PUNCH,
			0,
			a,
			a + PUNCH.ActiveSeconds,
			a + PUNCH.ActiveSeconds,
			a + 0.3
		)
		assert(late == nil, "nothing left once the window has been looked at")
	end,

	["walls and height are judged at the contact"] = function()
		local samples = { { ax = 0, ay = 0, az = 0, tx = 0, ty = 0, tz = -3 } }
		local index, why = Combat.sweepReach(PUNCH, samples, 0, -1, "Left", function()
			return false
		end)
		assert(index == nil and why == "blocked", `a wall: {why}`)
		local high = { { ax = 0, ay = 0, az = 0, tx = 0, ty = PUNCH.VerticalLimit + 1, tz = 0 } }
		local hIndex, hWhy = Combat.sweepReach(PUNCH, high, 0, -1, "Left")
		assert(hIndex == nil and hWhy == "height", `well above: {hWhy}`)
		-- Blocked at first, in the open a moment later: that later moment counts.
		local two = {
			{ ax = 0, ay = 0, az = 0, tx = 0, ty = 0, tz = -3 },
			{ ax = 0, ay = 0, az = 0, tx = 0, ty = 0, tz = -2.5 },
		}
		local later = Combat.sweepReach(PUNCH, two, 0, -1, "Left", function(i: number)
			return i == 2
		end)
		assert(later == 2, "found in the open")
	end,

	["a clear miss is still a miss"] = function()
		local at, why = swing(PUNCH, still(0, 0), still(0, -12), "Left")
		assert(at == nil and why == "range", `{why}`)
	end,

	-- 3. Bumps ---------------------------------------------------------------------------------------
	["running into someone standing still bumps once, and so does being run into"] = function()
		local run = MOVE.MaxSpeed
		local intoThem = bumps(function(t)
			return 0, 20 - run * t
		end, still(0, 0), { 0, -run }, { 0, 0 }, 1.5)
		assert(#intoThem == 1, `you ran in: {#intoThem} bumps`)
		local intoYou = bumps(still(0, 0), function(t)
			return 0, -20 + run * t
		end, { 0, 0 }, { 0, run }, 1.5)
		assert(#intoYou == 1, `they ran in: {#intoYou} bumps`)
	end,

	["seen with centres coinciding, after approaching, it's still a bump"] = function()
		local pair = Combat.newBumpPair()
		local closing
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, -6, 0, -40, 0)
		assert(closing == nil, "apart")
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, 0, 0, -40, 0.05)
		assert(closing ~= nil and closing > 30, `closing {closing}`)
	end,

	["seen just after crossing, already separating, it's still a bump"] = function()
		local pair = Combat.newBumpPair()
		local closing
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, -4, 0, -84, 0)
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, 0.2, 0, -84, 0.05)
		assert(closing ~= nil and closing > 60, `closing {closing}`)
	end,

	["a crossing entirely between two checks is a bump"] = function()
		local pair = Combat.newBumpPair()
		local closing
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, -5, 0, -200, 0)
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, 5, 0, -200, 0.05)
		assert(closing ~= nil, "passed straight through")
		assert(not pair.inContact, "and they're apart again")
	end,

	["idling inside each other, or running side by side, never bumps"] = function()
		local idle = bumps(still(0, 0), still(0.5, 0), { 0, 0 }, { 0, 0 }, 2)
		assert(#idle == 0, `idle: {#idle}`)
		local side = bumps(function(t)
			return 0, -30 * t
		end, function(t)
			return 1.5, -30 * t
		end, { 0, -30 }, { 0, -30 }, 2)
		assert(#side == 0, `alongside: {#side}`)
	end,

	["one continuous contact is one bump; separating and coming back after the cooldown is another"] = function()
		local pair = Combat.newBumpPair()
		local count = 0
		local function check(dz: number, rvz: number, t: number)
			local closing
			pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, dz, 0, rvz, t)
			if closing then
				count += 1
			end
		end
		check(-8, -30, 0)
		check(-2, -30, 0.05) -- bump
		for k = 2, 20 do
			check(-1, 0, k * 0.05) -- leaning on them for a second
		end
		assert(count == 1, `continuous contact gave {count}`)
		check(-8, 30, 1.1) -- back off
		check(-2, -30, 1.15) -- and back in, past the cooldown
		assert(count == 2, `coming back gave {count - 1}`)
		check(-8, 30, 1.2)
		check(-2, -30, 1.25) -- again, inside the cooldown
		assert(count == 2, "the pair cooldown holds")
	end,

	["a teleport between checks isn't a crossing"] = function()
		local pair = Combat.newBumpPair()
		local closing
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, -30, 0, 0, 0)
		pair, closing = Combat.stepBumpPair(KNOCK, pair, 0, 30, 0, 0, 0.05)
		assert(closing == nil, "a 60-stud jump in one check is a respawn, not a run through")
	end,

	-- 4. Punch over bump -------------------------------------------------------------------------------
	["a landing punch takes the impact, whichever runs first"] = function()
		-- Bump check just before the punch is decided: it waits, then the hit drops it.
		assert(Combat.bumpPriority(true, false) == "wait")
		assert(Combat.bumpPriority(false, true) == "drop")
		-- Bump check just after: the hit is already there.
		assert(Combat.bumpPriority(false, true) == "drop")
		-- A punch still pending on someone else entirely doesn't matter once it's decided as a miss.
		assert(Combat.bumpPriority(false, false) == "bump")
	end,

	["a fresh bump holds a moment, so a punch pressed just before contact claims the impact"] = function()
		assert(
			Combat.bumpPriority(false, false, true) == "wait",
			"held: the press may still be arriving"
		)
		assert(
			Combat.bumpPriority(true, false, false) == "wait",
			"the press arrived: wait for the swing"
		)
		assert(
			Combat.bumpPriority(false, true, false) == "drop",
			"it landed: only the punch counts"
		)
		assert(
			Combat.bumpPriority(false, false, false) == "bump",
			"no press came: the bump happens"
		)
	end,

	["a punch that misses leaves the bump to happen"] = function()
		assert(Combat.bumpPriority(true, false) == "wait", "while the swing is undecided")
		assert(Combat.bumpPriority(false, false) == "bump", "then it happens")
	end,

	-- 5. Stagger ---------------------------------------------------------------------------------------
	["about 14 ordinary punches take a fresh fighter to full stagger"] = function()
		local stagger, hits = 0, 0
		while stagger < STAGGER.Max do
			stagger = Combat.addStagger(STAGGER, stagger)
			hits += 1
		end
		assert(hits == 14, `{hits} punches`)
	end,

	["a running bump adds a little stagger, well under a punch, the most to whoever was run into"] = function()
		local out = Combat.bumpOutcome(
			KNOCK,
			STAGGER,
			MOVE.PropelSpeed,
			MOVE.MaxSpeed,
			MOVE.MaxSpeed,
			0,
			0,
			0
		)
		local share = out.staggerB / STAGGER.PerHit
		assert(share > 0.05 and share < 0.33, `{out.staggerB} is {share} of a punch`)
		assert(out.staggerA < out.staggerB, "the runner takes less")
	end,
}
