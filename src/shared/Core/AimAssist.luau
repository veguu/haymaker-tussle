--!strict
-- AimAssist - the help a lock-on gives, as plain maths with no Roblox instances.
--
-- Locking on never takes control. It leans three things toward the one you picked, each a little:
-- - the camera turns toward them at a gentle rate, much gentler while you're turning it yourself, and
--   not at all once they're well off to the side (cameraYaw);
-- - the movement keys bend partway toward them when they already point roughly their way (bendInput);
-- - a punch thrown when they're close and roughly in front turns you to face them (punchFacing).
-- Directions are on the ground plane (x, z), as Roblox world axes.

local AimAssist = {}

export type Settings = {
	AssistRange: number,
	AssistYawRate: number,
	AssistMouseShare: number,
	AssistCameraDegrees: number,
	AssistInputDegrees: number,
	AssistInputShare: number,
	AssistPunchDegrees: number,
	AssistPunchReach: number,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

--- The signed turn about the vertical, in radians, that takes direction (ax, az) to (bx, bz): positive is
--- the way CFrame.Angles(0, angle, 0) turns. Zero if either has no length.
function AimAssist.turnBetween(ax: number, az: number, bx: number, bz: number): number
	if (ax == 0 and az == 0) or (bx == 0 and bz == 0) then
		return 0
	end
	return math.atan2(az * bx - ax * bz, ax * bx + az * bz)
end

--- How far to turn the camera this frame toward someone `angle` radians off where it looks. It closes a
--- share of the gap each second (AssistYawRate), at AssistMouseShare of that while you're turning it
--- yourself, and does nothing past AssistCameraDegrees, so it never drags you round to someone behind you.
function AimAssist.cameraYaw(cfg: Settings, angle: number, dt: number, steering: boolean): number
	if not isFinite(angle) or not isFinite(dt) or dt <= 0 then
		return 0
	end
	if math.abs(angle) > math.rad(cfg.AssistCameraDegrees) then
		return 0
	end
	local rate = cfg.AssistYawRate * (if steering then cfg.AssistMouseShare else 1)
	return angle * (1 - math.exp(-rate * dt))
end

--- The movement keys, bent partway toward someone at (toX, toZ) from you. Only when the keys already point
--- within AssistInputDegrees of them, and only AssistInputShare of the way: it guides, it doesn't steer for
--- you. The length (how far a thumbstick is pushed) is kept.
function AimAssist.bendInput(
	cfg: Settings,
	inputX: number,
	inputZ: number,
	toX: number,
	toZ: number
): (number, number)
	local length = math.sqrt(inputX * inputX + inputZ * inputZ)
	if length < 0.001 or not isFinite(toX) or not isFinite(toZ) then
		return inputX, inputZ
	end
	local angle = AimAssist.turnBetween(inputX, inputZ, toX, toZ)
	if angle == 0 or math.abs(angle) > math.rad(cfg.AssistInputDegrees) then
		return inputX, inputZ
	end
	local turn = angle * cfg.AssistInputShare
	local c, s = math.cos(turn), math.sin(turn)
	-- The same turn CFrame.Angles(0, turn, 0) makes.
	return inputX * c + inputZ * s, -inputX * s + inputZ * c
end

--- Which way to face for a punch: toward them if they're within AssistPunchReach and no more than
--- AssistPunchDegrees off where you face now. Otherwise nil, and you punch where you were facing.
function AimAssist.punchFacing(
	cfg: Settings,
	faceX: number,
	faceZ: number,
	toX: number,
	toZ: number
): (number?, number?)
	local distance = math.sqrt(toX * toX + toZ * toZ)
	if distance < 0.001 or distance > cfg.AssistPunchReach or not isFinite(distance) then
		return nil, nil
	end
	local angle = AimAssist.turnBetween(faceX, faceZ, toX, toZ)
	if math.abs(angle) > math.rad(cfg.AssistPunchDegrees) then
		return nil, nil
	end
	return toX / distance, toZ / distance
end

return AimAssist
