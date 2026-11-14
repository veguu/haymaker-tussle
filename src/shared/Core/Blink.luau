--!strict
-- Blink - the rules of the Blink skill (Tempest's Q) as plain maths, with no Roblox instances. The
-- numbers are Config/Abilities.Blink. The blink itself runs on the player's own client, like the dash;
-- the server only checks the kit and the cooldown before showing it to everyone else.

local Blink = {}

export type Settings = {
	Distance: number,
	Cooldown: number,
	WallGap: number,
	MoveMinSpeed: number,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

--- The flat unit direction a blink goes: the way the body is moving when it's going at least
--- MoveMinSpeed, otherwise the way it faces. Returns nil when neither is a real direction.
function Blink.direction(
	cfg: Settings,
	velocityX: number,
	velocityZ: number,
	faceX: number,
	faceZ: number
): (number?, number?)
	local speed = math.sqrt(velocityX * velocityX + velocityZ * velocityZ)
	if isFinite(speed) and speed >= cfg.MoveMinSpeed then
		return velocityX / speed, velocityZ / speed
	end
	local facing = math.sqrt(faceX * faceX + faceZ * faceZ)
	if isFinite(facing) and facing > 0.001 then
		return faceX / facing, faceZ / facing
	end
	return nil, nil
end

--- How far a blink travels: the whole Distance, or WallGap short of something solid `wallDistance`
--- studs ahead (nil: nothing in the way). Never backward.
function Blink.travel(cfg: Settings, wallDistance: number?): number
	if wallDistance == nil or not isFinite(wallDistance) then
		return cfg.Distance
	end
	return math.clamp(wallDistance - cfg.WallGap, 0, cfg.Distance)
end

--- Has the cooldown run since the last blink? `tolerance` is the slack the server gives a client's clock.
function Blink.ready(cfg: Settings, now: number, last: number?, tolerance: number?): boolean
	return last == nil or now - last >= cfg.Cooldown - (tolerance or 0)
end

return Blink
