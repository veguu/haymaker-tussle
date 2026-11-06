--!strict
-- LockOn - who the lock-on marker can show, and the shape of its animation, as plain maths with no Roblox
-- instances. It only ever decides what's drawn: nothing here moves anyone or changes what a hit does.
--
-- The timings and easing are the concept's own (haymaker-lock-on-reference.html). CSS eases each stretch
-- between keyframes separately, so these do too.

local LockOn = {}

export type Settings = {
	Range: number,
	ReleaseRange: number,
	LookDegrees: number,
	LookReleaseDegrees: number,
	LookStuds: number,
	LostSightSeconds: number,
	PopSeconds: number,
	PopStart: number,
	PopPeak: number,
	PopPeakAt: number,
	SqueezeSeconds: number,
	SqueezeStart: number,
	SqueezeLow: number,
	SqueezeLowAt: number,
	LockedScale: number,
	PulseSeconds: number,
	PulseRepeats: number,
	PulseStart: number,
	PulseEnd: number,
	PulseOpacity: number,
	FadeSeconds: number,
}

-- Someone who could be shown. `degrees` is how far they are from where the camera looks.
export type Option<T> = {
	who: T,
	distance: number,
	degrees: number,
	visible: boolean,
}

--- A CSS cubic-bezier: how far along the change is, `t` of the way through its time.
function LockOn.bezier(x1: number, y1: number, x2: number, y2: number, t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local function curve(a: number, b: number, u: number): number
		local rest = 1 - u
		return 3 * rest * rest * u * a + 3 * rest * u * u * b + u * u * u
	end
	-- x always rises along these curves, so halving finds the point for this time.
	local low, high = 0, 1
	for _ = 1, 24 do
		local middle = (low + high) / 2
		if curve(x1, x2, middle) < t then
			low = middle
		else
			high = middle
		end
	end
	return curve(y1, y2, (low + high) / 2)
end

local function easeOut(t: number): number
	return LockOn.bezier(0, 0, 0.58, 1, t)
end

--- CSS's plain `ease`, which the concept's transitions use.
function LockOn.ease(t: number): number
	return LockOn.bezier(0.25, 0.1, 0.25, 1, t)
end

local function popEase(t: number): number
	return LockOn.bezier(0.2, 0.7, 0.25, 1, t)
end

local function between(a: number, b: number, share: number): number
	return a + (b - a) * share
end

--- The marker appearing, `t` seconds in. Returns its scale and opacity.
function LockOn.popAt(cfg: Settings, t: number): (number, number)
	local share = math.clamp(t / cfg.PopSeconds, 0, 1)
	if share < cfg.PopPeakAt then
		local eased = popEase(share / cfg.PopPeakAt)
		return between(cfg.PopStart, cfg.PopPeak, eased), eased
	end
	return between(cfg.PopPeak, 1, popEase((share - cfg.PopPeakAt) / (1 - cfg.PopPeakAt))), 1
end

--- The reticle tightening on lock-on, `t` seconds in: a dip past its locked size, then a settle.
function LockOn.squeezeAt(cfg: Settings, t: number): number
	local share = math.clamp(t / cfg.SqueezeSeconds, 0, 1)
	if share < cfg.SqueezeLowAt then
		return between(cfg.SqueezeStart, cfg.SqueezeLow, easeOut(share / cfg.SqueezeLowAt))
	end
	return between(
		cfg.SqueezeLow,
		cfg.LockedScale,
		easeOut((share - cfg.SqueezeLowAt) / (1 - cfg.SqueezeLowAt))
	)
end

--- The confirmation pulse, `t` seconds in. Returns its scale and opacity, or nil once it has finished.
function LockOn.pulseAt(cfg: Settings, t: number): (number?, number?)
	if t < 0 or t >= cfg.PulseSeconds * cfg.PulseRepeats then
		return nil, nil
	end
	local eased = easeOut((t % cfg.PulseSeconds) / cfg.PulseSeconds)
	return between(cfg.PulseStart, cfg.PulseEnd, eased), between(cfg.PulseOpacity, 0, eased)
end

--- A clockwise turn in degrees, one revolution every `seconds`.
function LockOn.spin(seconds: number, t: number): number
	return (t / seconds * 360) % 360
end

-- Close up, a body fills more of the view, so looking at any of it should count.
local function allowedDegrees(cfg: Settings, baseDegrees: number, distance: number): number
	return math.max(baseDegrees, math.deg(math.atan2(cfg.LookStuds, math.max(distance, 0.001))))
end

--- Who the white marker should show. The one showing keeps it until they stop qualifying, with a little
--- more room than it took to earn it, so the marker can't flicker between two people. Being looked at
--- only ever shows the marker: selecting takes a press.
function LockOn.pick<T>(cfg: Settings, options: { Option<T> }, current: T?): T?
	local best: T? = nil
	local bestDegrees = math.huge
	for _, option in options do
		if option.visible then
			if
				option.who == current
				and option.distance <= cfg.ReleaseRange
				and option.degrees
					<= allowedDegrees(cfg, cfg.LookReleaseDegrees, option.distance)
			then
				return current
			end
			if
				option.distance <= cfg.Range
				and option.degrees <= allowedDegrees(cfg, cfg.LookDegrees, option.distance)
				and option.degrees < bestDegrees
			then
				best, bestDegrees = option.who, option.degrees
			end
		end
	end
	return best
end

--- Does a selected opponent stay selected? It never moves to someone else: it either holds or ends.
--- Looking away is fine. Going too far, or being out of sight for too long, ends it.
function LockOn.keepsSelection(cfg: Settings, distance: number, unseenSeconds: number): boolean
	return distance <= cfg.ReleaseRange and unseenSeconds < cfg.LostSightSeconds
end

return LockOn