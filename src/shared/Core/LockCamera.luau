--!strict
-- LockCamera - where the camera looks while locked on, as plain maths with no Roblox instances. It only ever
-- decides the view: nothing here moves a character, and it has no say in any jump or hit.
--
-- The aim runs from a point just above your head through the opponent, and the camera sits behind that point
-- on the same line. So they stay centred, you stay just below them on screen, and neither blocks the other.
--
-- All smoothing is `1 - exp(-rate * dt)`, which gives the same result at any frame rate. It can't overshoot.
-- Angles here are radians, and settings are degrees.

local LockCamera = {}

export type Settings = {
	BaseDistance: number,
	DistancePerStud: number,
	MinDistance: number,
	MaxDistance: number,
	YawMaxDegrees: number,
	PitchUpMax: number,
	PitchDownMax: number,
	HoldFlat: number,
	FullFlat: number,
	OrbitYawMax: number,
	OrbitPitchMax: number,
	OrbitReturnDelay: number,
	OrbitReturnRate: number,
	PullOutRate: number,
	MinPull: number,
}

--- Moves `current` toward `target`. The same total move at any frame rate.
function LockCamera.smooth(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

--- The shortest way round from one angle to another, from -pi to pi.
function LockCamera.angleBetween(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

--- Moves an angle the short way toward `target`, no faster than `maxSpeed` radians per second. That limit is
--- what stops someone crossing behind you from whipping the camera round in a single frame.
function LockCamera.smoothAngle(
	current: number,
	target: number,
	rate: number,
	maxSpeed: number,
	dt: number
): number
	local away = LockCamera.angleBetween(current, target)
	local step = away * (1 - math.exp(-rate * dt))
	local limit = maxSpeed * dt
	return current + math.clamp(step, -limit, limit)
end

--- The yaw and pitch of the line between two points, and how far apart they are on the flat.
function LockCamera.angleTo(
	fromX: number,
	fromY: number,
	fromZ: number,
	toX: number,
	toY: number,
	toZ: number
): (number, number, number)
	local dx, dy, dz = toX - fromX, toY - fromY, toZ - fromZ
	local flat = math.sqrt(dx * dx + dz * dz)
	return math.atan2(-dx, -dz), math.atan2(dy, flat), flat
end

--- The direction a yaw and pitch look in, matching CFrame.fromOrientation(pitch, yaw, 0).
function LockCamera.look(yaw: number, pitch: number): (number, number, number)
	local level = math.cos(pitch)
	return -math.sin(yaw) * level, math.sin(pitch), -math.cos(yaw) * level
end

--- How far back the camera wants to be: further the further apart you are, between the limits.
function LockCamera.zoom(cfg: Settings, separation: number): number
	return math.clamp(
		cfg.BaseDistance + cfg.DistancePerStud * separation,
		cfg.MinDistance,
		cfg.MaxDistance
	)
end

--- How much the yaw should follow, 0 to 1. With them nearly straight above or below you, their flat direction
--- means nothing and swings wildly, so the yaw eases to a stop rather than spinning.
function LockCamera.yawShare(cfg: Settings, flat: number): number
	return math.clamp((flat - cfg.HoldFlat) / math.max(cfg.FullFlat - cfg.HoldFlat, 0.001), 0, 1)
end

--- Adds a mouse move to the player's own offset from the framing, within its limits. Pass degrees of
--- movement: right and down are positive, so moving right looks right and moving down looks down.
function LockCamera.orbit(
	cfg: Settings,
	orbitYaw: number,
	orbitPitch: number,
	rightDegrees: number,
	downDegrees: number
): (number, number)
	local yawLimit, pitchLimit = math.rad(cfg.OrbitYawMax), math.rad(cfg.OrbitPitchMax)
	return math.clamp(orbitYaw - math.rad(rightDegrees), -yawLimit, yawLimit),
		math.clamp(orbitPitch - math.rad(downDegrees), -pitchLimit, pitchLimit)
end

--- The player's offset easing back to nothing, only once they've left the mouse alone for a while, so the
--- framing never fights a hand that's moving.
function LockCamera.orbitSettle(
	cfg: Settings,
	offset: number,
	idleSeconds: number,
	dt: number
): number
	if idleSeconds < cfg.OrbitReturnDelay then
		return offset
	end
	return LockCamera.smooth(offset, 0, cfg.OrbitReturnRate, dt)
end

--- The pitch to use, with the player's offset added, kept to comfortable limits.
function LockCamera.finalPitch(cfg: Settings, pitch: number, orbitPitch: number): number
	return math.clamp(pitch + orbitPitch, -math.rad(cfg.PitchDownMax), math.rad(cfg.PitchUpMax))
end

--- How far back the camera actually sits, given what's in the way: in at once so it never passes through
--- anything, and back out slowly so it doesn't pump in and out along a wall.
function LockCamera.pull(cfg: Settings, current: number, clear: number, dt: number): number
	local allowed = math.max(clear, cfg.MinPull)
	if allowed <= current then
		return allowed
	end
	return LockCamera.smooth(current, allowed, cfg.PullOutRate, dt)
end

--- Entering and leaving lock-on: 0 is the normal camera, 1 is fully locked, with soft ends.
function LockCamera.blendShare(weight: number): number
	local t = math.clamp(weight, 0, 1)
	return t * t * (3 - 2 * t)
end

return LockCamera
