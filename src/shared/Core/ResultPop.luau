--!strict
-- ResultPop - the shape of the kick result text's pop, as plain maths with no Roblox instances.
--
-- Quick rise past full size, a small dip back under it, then a settle: sharp at the start so it
-- reads instantly, and only soft on the way out.

local ResultPop = {}

export type Settings = {
	StartScale: number,
	PeakScale: number,
	DipScale: number,
	PerfectPeakScale: number,
	PerfectDipScale: number,
	RiseSeconds: number,
	DipSeconds: number,
	SettleSeconds: number,
	HoldSeconds: number,
	PerfectHoldSeconds: number,
	FadeSeconds: number,
}

local function easeOut(a: number, b: number, t: number): number
	local left = 1 - t
	return a + (b - a) * (1 - left * left)
end

local function smooth(a: number, b: number, t: number): number
	return a + (b - a) * (t * t * (3 - 2 * t))
end

--- The text's size at `t` seconds after it appeared. `perfect` pops a little harder.
function ResultPop.scaleAt(cfg: Settings, t: number, perfect: boolean): number
	local peak = if perfect then cfg.PerfectPeakScale else cfg.PeakScale
	local dip = if perfect then cfg.PerfectDipScale else cfg.DipScale
	if t < cfg.RiseSeconds then
		return easeOut(cfg.StartScale, peak, math.max(t, 0) / cfg.RiseSeconds)
	end
	t -= cfg.RiseSeconds
	if t < cfg.DipSeconds then
		return smooth(peak, dip, t / cfg.DipSeconds)
	end
	t -= cfg.DipSeconds
	if t < cfg.SettleSeconds then
		return smooth(dip, 1, t / cfg.SettleSeconds)
	end
	return 1
end

--- How see-through the text is at `t` seconds: solid through the hold, then a smooth fade.
function ResultPop.transparencyAt(cfg: Settings, t: number, perfect: boolean): number
	local hold = if perfect then cfg.PerfectHoldSeconds else cfg.HoldSeconds
	if t <= hold then
		return 0
	end
	return smooth(0, 1, math.min((t - hold) / cfg.FadeSeconds, 1))
end

--- Seconds until it has completely gone.
function ResultPop.duration(cfg: Settings, perfect: boolean): number
	return (if perfect then cfg.PerfectHoldSeconds else cfg.HoldSeconds) + cfg.FadeSeconds
end

return ResultPop
