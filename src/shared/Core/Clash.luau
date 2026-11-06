--!strict
-- Clash - when two punches landing together become a contest of tapping, as plain maths with no
-- Roblox instances. Everything here is decided on the server; clients only draw it.

local Clash = {}

export type Settings = {
	Window: number,
	LatencyMax: number,
	HoldMax: number,
	Seconds: number,
	WinLead: number,
	TieMargin: number,
	MaxTapsPerSecond: number,
	TapBurst: number,
	Standoff: number,
	AlignSpeed: number,
	AlignGain: number,
	AlignDeadband: number,
	FinishShare: number,
	FinishMaxSpeed: number,
	RepelCooldown: number,
}

export type TapBucket = { tokens: number, at: number }

--- The largest gap between two strike times that still counts as the same moment. Press times are
--- estimates from each player's ping, so the window widens a little with ping, and never by much.
--- Both ping values are round trips.
function Clash.window(cfg: Settings, pingA: number, pingB: number): number
	return cfg.Window + math.min(cfg.LatencyMax, (pingA + pingB) / 4)
end

--- Did these two punches strike at effectively the same moment? The same rule for everyone, however
--- fast they've been clicking: it only looks at when these two swings land.
function Clash.simultaneous(
	cfg: Settings,
	impactA: number,
	impactB: number,
	pingA: number,
	pingB: number
): boolean
	return math.abs(impactA - impactB) <= Clash.window(cfg, pingA, pingB)
end

--- How long a landed punch waits before it counts, in case the target's simultaneous press is still
--- on its way to the server. A target with more ping than the attacker can have pressed at the same
--- moment and not have arrived yet. The windup already covers most of that, so this is usually nothing.
function Clash.holdSeconds(
	cfg: Settings,
	windup: number,
	attackerPing: number,
	targetPing: number
): number
	local behind = (targetPing - attackerPing) / 2
	return math.clamp(cfg.Window + behind - windup, 0, cfg.HoldMax)
end

--- Does this tap count? Holds a small burst, so taps bunched by the network aren't lost, and refills
--- at the fastest believable rate, so nothing can score faster than that for long.
function Clash.takeTap(cfg: Settings, bucket: TapBucket, now: number): boolean
	local elapsed = math.max(now - bucket.at, 0)
	bucket.tokens = math.min(bucket.tokens + elapsed * cfg.MaxTapsPerSecond, cfg.TapBurst)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--- How far along the contest is, for the bar: 0.5 is even, 1 is A has won outright, 0 is B has.
function Clash.share(cfg: Settings, scoreA: number, scoreB: number): number
	return math.clamp(0.5 + (scoreA - scoreB) / cfg.WinLead * 0.5, 0, 1)
end

--- Is it over? Returns "a", "b", "tie" or nil. A big enough lead ends it early; otherwise it runs to
--- the time limit, where a small enough gap is nobody's win.
function Clash.outcome(cfg: Settings, scoreA: number, scoreB: number, elapsed: number): string?
	local lead = scoreA - scoreB
	if math.abs(lead) >= cfg.WinLead then
		return if lead > 0 then "a" else "b"
	end
	if elapsed < cfg.Seconds then
		return nil
	end
	if math.abs(lead) <= cfg.TieMargin then
		return "tie"
	end
	return if lead > 0 then "a" else "b"
end

--- The finishing punch's knockback, from what a standing punch at the loser's stagger would do. The
--- cap keeps a long fight's stagger from turning one clash into an instant ring-out.
function Clash.finishStrength(cfg: Settings, standingStrength: number): number
	return math.min(standingStrength * cfg.FinishShare, cfg.FinishMaxSpeed)
end

--- Where the two stand and which way the line between them runs. They meet around their midpoint, each
--- facing the other. When they're exactly on top of each other their positions say nothing, so A's
--- facing decides the line. Returns A's spot, B's spot, and the unit direction from A to B.
function Clash.stands(
	cfg: Settings,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	fx: number,
	fz: number
): (number, number, number, number, number, number)
	local dx, dz = bx - ax, bz - az
	local size = math.sqrt(dx * dx + dz * dz)
	if size < 0.05 then
		dx, dz, size = fx, fz, math.sqrt(fx * fx + fz * fz)
		if size < 0.001 then
			dx, dz, size = 0, -1, 1
		end
	end
	local dirX, dirZ = dx / size, dz / size
	local midX, midZ = (ax + bx) / 2, (az + bz) / 2
	local half = cfg.Standoff / 2
	return midX - dirX * half,
		midZ - dirZ * half,
		midX + dirX * half,
		midZ + dirZ * half,
		dirX,
		dirZ
end

--- How fast to walk toward your spot, from how far off it you are. Eases in and stops just short, because
--- a Humanoid takes a moment to change speed, and chasing the exact spot harder than that makes it wobble.
function Clash.alignSpeed(cfg: Settings, distance: number): number
	if distance <= cfg.AlignDeadband then
		return 0
	end
	return math.min(distance * cfg.AlignGain, cfg.AlignSpeed)
end

--- May an outside attacker be repelled again? One overlapping attack never pushes twice.
function Clash.repelReady(cfg: Settings, now: number, lastRepel: number?): boolean
	return lastRepel == nil or now - lastRepel >= cfg.RepelCooldown
end

return Clash