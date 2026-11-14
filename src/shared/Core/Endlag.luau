--!strict
-- Endlag - recovery after every move, as plain maths with no Roblox instances (user, 2026-11-13: "give
-- endlag to all moves, so you can't just chain them"). The numbers are GameConfig.Endlag.
--
-- A fighter has one `busyUntil` time. While now is before it, no new move may START (a punch, the
-- launching kick, the Uppercut, the Cyclone, a dash, a blink, a jump). Running is untouched.
--
-- An ATTACK ("Punch", "Kick", "Uppercut", "Cyclone") locks from its press until its strike is over
-- (`lead`: its windup plus the active window) plus its Miss seconds. If it lands, that is cut to its
-- Hit seconds after the hit: landing is rewarded, whiffing punished.
-- Anything else ("Dash", "Blink", "AirKick") locks for its one number from the moment given.
--
-- The client (EndlagController) and the server (EndlagService) both keep a busyUntil on these rules;
-- the server's is the one that counts for attacks.

local Endlag = {}

export type Settings = {
	Enabled: boolean,
	Tolerance: number,
	[string]: any,
}

local ATTACKS = { Punch = true, Kick = true, Uppercut = true, Cyclone = true }

local function seconds(value: any): number
	if typeof(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return value
end

--- Is this move an attack (one with Hit and Miss numbers)?
function Endlag.isAttack(move: string): boolean
	return ATTACKS[move] == true
end

--- The recovery a move owes once it's over: an attack's Miss (or Hit, with `hit`) seconds, anything
--- else's one number. 0 for a move with no setting, or with endlag off.
function Endlag.recovery(cfg: Settings, move: string, hit: boolean?): number
	if not cfg.Enabled then
		return 0
	end
	if ATTACKS[move] then
		return seconds(cfg[move .. (if hit then "Hit" else "Miss")])
	end
	return seconds(cfg[move])
end

--- When a move started at `startAt` stops locking, assuming it hits nobody. `lead` is how long until
--- its strike is over (windup plus active window; 0 for a dash or blink). Never earlier than a lock
--- already running (`busyUntil`).
function Endlag.started(
	cfg: Settings,
	move: string,
	startAt: number,
	lead: number?,
	busyUntil: number?
): number
	local current = busyUntil or -math.huge
	if not cfg.Enabled then
		return current
	end
	return math.max(current, startAt + seconds(lead) + Endlag.recovery(cfg, move, false))
end

--- An attack landed at `hitAt`: its lock is cut to its Hit seconds from then. It only ever shortens
--- the lock, and never to before `hitAt` itself.
function Endlag.landed(cfg: Settings, move: string, busyUntil: number, hitAt: number): number
	if not cfg.Enabled or not ATTACKS[move] then
		return busyUntil
	end
	return math.min(busyUntil, hitAt + Endlag.recovery(cfg, move, true))
end

--- Is a fighter still in endlag at `now`? `tolerance` is the slack the server gives a client's clock.
function Endlag.busy(cfg: Settings, busyUntil: number?, now: number, tolerance: number?): boolean
	if not cfg.Enabled or busyUntil == nil then
		return false
	end
	return now < busyUntil - seconds(tolerance)
end

return Endlag
