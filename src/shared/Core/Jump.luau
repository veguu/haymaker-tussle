--!strict
-- Jump - the running jump and the dive kick out of it, as plain maths with no Roblox instances.
--
-- THE JUMP (Space). Standing, it goes straight up. Moving, it's an arc: higher and longer the faster you
-- were going, because the lift grows with speed and the flat speed is carried (and boosted a little)
-- through the air.
-- THE DIVE (click in the air). A fast straight line down onto the spot the cursor is on, no further than
-- Range along the floor from where you are, and always downward.

local Jump = {}

export type JumpSettings = {
	Cooldown: number,
	UpBase: number,
	UpPerStud: number,
	UpMax: number,
	ForwardShare: number,
	ForwardMax: number,
	MoveMinSpeed: number,
	GravityScale: number,
}

export type DiveSettings = {
	Range: number,
	Speed: number,
	MinDrop: number,
	MaxSeconds: number,
}

local function finite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

--- A jump taken at this flat speed: the upward speed, and the flat speed to hold through the air (nil
--- when standing, which is a plain hop straight up).
function Jump.launch(cfg: JumpSettings, speed: number): (number, number?)
	local fast = if finite(speed) then math.max(speed, 0) else 0
	local up = math.min(cfg.UpBase + cfg.UpPerStud * fast, cfg.UpMax)
	if fast < cfg.MoveMinSpeed then
		return up, nil
	end
	-- Boosted a little, up to ForwardMax; a body already going faster than that (a dash) just keeps its speed.
	return up, math.max(fast, math.min(fast * cfg.ForwardShare, cfg.ForwardMax))
end

--- May a jump start now, having last started at `lastAt`?
function Jump.ready(cfg: JumpSettings, now: number, lastAt: number?): boolean
	return lastAt == nil or now - lastAt >= cfg.Cooldown
end

--- The way a dive goes, as a unit vector, from the offset to the aimed spot (spot minus body). The spot
--- is pulled in to Range along the floor, and the line is never flatter than MinDrop downward, so it's
--- always a kick down onto something. With no usable aim it goes straight down.
function Jump.diveWay(
	cfg: DiveSettings,
	dx: number,
	dy: number,
	dz: number
): (number, number, number)
	if not (finite(dx) and finite(dy) and finite(dz)) then
		return 0, -1, 0
	end
	local flat = math.sqrt(dx * dx + dz * dz)
	if flat > cfg.Range and flat > 0 then
		local share = cfg.Range / flat
		dx, dz = dx * share, dz * share
		flat = cfg.Range
	end
	local drop = math.min(dy, -flat * cfg.MinDrop)
	local size = math.sqrt(flat * flat + drop * drop)
	if size < 0.001 then
		return 0, -1, 0
	end
	return dx / size, drop / size, dz / size
end

return Jump
