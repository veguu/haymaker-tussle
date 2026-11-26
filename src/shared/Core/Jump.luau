--!strict
-- Jump - the running jump, as plain maths with no Roblox instances.
--
-- THE JUMP (Space). Standing, it goes straight up. Moving, it's an arc: higher and longer the faster you
-- were going, because the lift grows with speed and the flat speed is carried (and boosted a little)
-- through the air.

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

return Jump
