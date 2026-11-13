--!strict
-- KickMeter - the air kick's timing meter, as plain maths with no Roblox instances.
--
-- A marker runs along a horizontal bar: red at both ends, through orange and yellow, to green at the exact
-- middle. Pressing records where the marker IS; the closer to the middle, the stronger and faster the kick.
-- Positions run from -1 (left end) through 0 (the middle) to 1 (right end), and only the distance from the
-- middle counts, so the two sides are worth exactly the same.
--
-- The marker's position is a pure function of the seconds since the jumper touched the target, and of a
-- `plan` the SERVER rolled for this kick (where it starts and which way it first goes, so it has to be
-- watched rather than learned). The server works the position out from its own clock; the client draws the
-- same function, and shows the server's recorded position as the result. Settings: GameConfig.KickMeter.

local KickMeter = {}

export type Settings = {
	MarkerStyle: string, -- "M1" constant-speed bounce, "M2" one-way sweep with reset, "M3" accelerating bounce
	EntranceSeconds: number, -- the bar's entrance; the marker only starts once it has settled
	SweepSeconds: number, -- end to end, at the starting speed
	Passes: number, -- how many end-to-end runs before an unpressed meter gives up
	StartSpanMin: number, -- the marker starts this far from the middle at least (0 to 1), up to an end
	AccelPerSecond: number, -- M3: how much faster it gets each second (0.3 = 30%)
	-- The server takes this much off the time it measured for a press: a press reaches it about a frame and a
	-- network tick after the picture the player pressed on (measured 38-54 ms in Studio), so without it a press
	-- that looked dead centre scores a little late.
	PressLagSeconds: number,
	PerfectAccuracy: number,
	GoodAccuracy: number,
	OkayAccuracy: number,
	AccuracyCurve: number, -- 1 = strength follows accuracy in a straight line; higher = the middle matters more
	StrengthMin: number, -- share of the kick's full force at the very ends
	StrengthMax: number, -- and dead centre
	StopMin: number, -- hit stop, seconds
	StopMax: number,
	RiseMin: number, -- how high the kick throws the kicker back, studs
	RiseMax: number,
}

export type Plan = { start: number, dir: number }
export type Tier = "perfect" | "good" | "okay" | "poor"

--- This kick's marker: where it starts (well out from the middle, on a random side) and which way it goes
--- first (inward). `sideRoll` and `spanRoll` are random numbers from 0 to 1.
function KickMeter.plan(cfg: Settings, sideRoll: number, spanRoll: number): Plan
	local side = if sideRoll < 0.5 then -1 else 1
	local span = cfg.StartSpanMin + (1 - cfg.StartSpanMin) * math.clamp(spanRoll, 0, 1)
	return { start = side * span, dir = -side }
end

--- A plan as a client sent or read it, made safe (nil when it isn't one).
function KickMeter.readPlan(start: any, dir: any): Plan?
	if type(start) ~= "number" or type(dir) ~= "number" or start ~= start then
		return nil
	end
	return { start = math.clamp(start, -1, 1), dir = if dir < 0 then -1 else 1 }
end

--- How far the marker has travelled (in bar half-widths) `live` seconds after it started.
local function travelled(cfg: Settings, live: number): number
	local speed = 2 / math.max(cfg.SweepSeconds, 0.05)
	if cfg.MarkerStyle == "M3" then
		return speed * (live + cfg.AccelPerSecond * live * live / 2)
	end
	return speed * live
end

--- Where the marker is `since` seconds after touching: still at its start through the entrance, then moving.
function KickMeter.position(cfg: Settings, plan: Plan, since: number): number
	local live = math.max(since - cfg.EntranceSeconds, 0)
	local x = plan.start + plan.dir * travelled(cfg, live)
	if cfg.MarkerStyle == "M2" then
		-- one way, jumping back to the far end each time it runs off
		local y = (x * plan.dir + 1) % 2 - 1
		return y * plan.dir
	end
	-- bouncing: fold the straight run back and forth between the ends
	local y = (x + 1) % 4
	if y > 2 then
		y = 4 - y
	end
	return y - 1
end

--- Where the SERVER scores a press it measured `since` seconds after touching (see PressLagSeconds).
function KickMeter.pressedAt(cfg: Settings, plan: Plan, since: number): number
	return KickMeter.position(cfg, plan, since - cfg.PressLagSeconds)
end

--- Seconds after touching at which an unpressed meter gives up (the kick still comes, at its weakest).
function KickMeter.endsAt(cfg: Settings): number
	return cfg.EntranceSeconds + cfg.Passes * cfg.SweepSeconds
end

--- 1 dead centre, 0 at either end. The same on both sides.
function KickMeter.accuracy(position: number): number
	return 1 - math.clamp(math.abs(position), 0, 1)
end

--- The kick's quality from 0 to 1: accuracy, bent by AccuracyCurve. Everything that scales, scales by this.
function KickMeter.quality(cfg: Settings, accuracy: number): number
	return math.clamp(accuracy, 0, 1) ^ math.max(cfg.AccuracyCurve, 0.01)
end

--- The named result, for the label and for the few things that are all-or-nothing.
function KickMeter.tier(cfg: Settings, accuracy: number): Tier
	if accuracy >= cfg.PerfectAccuracy then
		return "perfect"
	elseif accuracy >= cfg.GoodAccuracy then
		return "good"
	elseif accuracy >= cfg.OkayAccuracy then
		return "okay"
	end
	return "poor"
end

local TIERS: { Tier } = { "poor", "okay", "good", "perfect" }

--- A tier as a number (1 poor to 4 perfect) and back, for sending.
function KickMeter.tierIndex(tier: Tier): number
	return table.find(TIERS, tier) or 1
end

function KickMeter.tierAt(index: number): Tier
	return TIERS[math.clamp(math.floor(index + 0.5), 1, #TIERS)]
end

local function between(a: number, b: number, quality: number): number
	return a + (b - a) * math.clamp(quality, 0, 1)
end

--- Share of the kick's full force (the outward push, the slam and the stagger it adds).
function KickMeter.strength(cfg: Settings, quality: number): number
	return between(cfg.StrengthMin, cfg.StrengthMax, quality)
end

--- How long both fighters freeze as it lands.
function KickMeter.stop(cfg: Settings, quality: number): number
	return between(cfg.StopMin, cfg.StopMax, quality)
end

--- How high the kick throws the kicker back.
function KickMeter.rise(cfg: Settings, quality: number): number
	return between(cfg.RiseMin, cfg.RiseMax, quality)
end

return KickMeter
