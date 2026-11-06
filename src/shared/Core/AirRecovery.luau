--!strict
-- AirRecovery - how a body falls, and what a punch thrown in the air does for it, as plain maths with
-- no Roblox instances.
--
-- FALLING. Physics always applies full gravity. `fallVelocity` takes the vertical speed physics left
-- and hands back some of it, which is the only gravity adjustment any ordinary airborne body gets, so
-- nothing stacks. Going up, a body keeps the gravity its launch was designed around. From the top of
-- the arc it eases into the lighter falling gravity over `FallEaseSpeed`, and it can't fall faster than
-- `MaxFallSpeed`. It never stops falling, and no vertical speed is ever set to zero.
--
-- PUNCHING. Each accepted punch in the air gives one push, toward the movement keys, or where the body
-- faces with no keys. There's no count, meter or fade per punch: what limits it is the punch cadence, how
-- quickly a push fades, the speed cap and the fall. A push never replaces velocity. It's added on top,
-- so a launch still has to be countered, and it only adds up to the cap along its own direction, so
-- pushing against a huge launch always gets all of it while pushing with one gets nothing.

local AirRecovery = {}

export type Settings = {
	BoostSpeed: number,
	BoostFade: number,
	MaxSpeed: number,
	UpAssist: number,
	UpAssistCeiling: number,
	FallGravityScale: number,
	FallEaseSpeed: number,
	MaxFallSpeed: number,
	FallDrag: number,
	MinAirSeconds: number,
	LiftEnabled: boolean,
	LiftSpeed: number,
	LiftSeconds: number,
	LiftGravityScale: number,
	LiftForwardSpeed: number,
	LiftCooldown: number,
	LiftsPerFall: number,
	LiftFallingSpeed: number,
	LiftFloorCheck: number,
}

-- How finely `predictRise` and `timeToDrop` walk the fall. Coarse is fine: they plan a jump.
local PREDICT_STEP = 1 / 30
local PREDICT_LIMIT_SECONDS = 8

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

--- The share of gravity a body feels at this vertical speed. `risingScale` is what its launch uses on
--- the way up: 1 normally, less for an uppercut.
function AirRecovery.gravityScale(cfg: Settings, risingScale: number, vy: number): number
	if vy >= 0 then
		return risingScale
	end
	local falling = math.min(risingScale, cfg.FallGravityScale)
	local eased = smooth(math.clamp(-vy / math.max(cfg.FallEaseSpeed, 0.001), 0, 1))
	return risingScale + (falling - risingScale) * eased
end

--- One step of the fall. `vy` is the vertical speed physics has just left, after a whole `dt` of full
--- `gravity`. Returns what it should be instead. Past the top speed it's drawn back gently, so the
--- speed of a launch downward doesn't vanish in a frame.
function AirRecovery.fallVelocity(
	cfg: Settings,
	gravity: number,
	risingScale: number,
	vy: number,
	dt: number
): number
	local scale = AirRecovery.gravityScale(cfg, risingScale, vy)
	local nextVy = vy + gravity * (1 - scale) * dt
	if nextVy < -cfg.MaxFallSpeed then
		local before = vy + gravity * dt
		if before < -cfg.MaxFallSpeed then
			-- Already past it before this step: all of this step's gravity goes, and the excess bleeds off.
			return math.min(before + cfg.FallDrag * dt, -cfg.MaxFallSpeed)
		end
		return -cfg.MaxFallSpeed
	end
	return nextVy
end

--- How much higher a body will be after `seconds`, starting at vertical speed `vy`. Negative is lower.
function AirRecovery.predictRise(
	cfg: Settings,
	gravity: number,
	risingScale: number,
	vy: number,
	seconds: number
): number
	local rise, t = 0, 0
	while t < seconds do
		local step = math.min(PREDICT_STEP, seconds - t)
		local before = vy
		vy = AirRecovery.fallVelocity(cfg, gravity, risingScale, vy - gravity * step, step)
		rise += (before + vy) / 2 * step
		t += step
	end
	return rise
end

--- How long until a body starting at vertical speed `vy` has dropped `height` below where it is.
function AirRecovery.timeToDrop(
	cfg: Settings,
	gravity: number,
	risingScale: number,
	vy: number,
	height: number
): number
	local rise, t = 0, 0
	while rise > -height and t < PREDICT_LIMIT_SECONDS do
		local before = vy
		vy = AirRecovery.fallVelocity(
			cfg,
			gravity,
			risingScale,
			vy - gravity * PREDICT_STEP,
			PREDICT_STEP
		)
		rise += (before + vy) / 2 * PREDICT_STEP
		t += PREDICT_STEP
	end
	return t
end

--- Which way a punch's push goes: the keys, or where the body faces with none. Both are already flat,
--- so the camera's pitch can't enter into it. Returns a unit direction.
function AirRecovery.direction(
	inputX: number,
	inputZ: number,
	faceX: number,
	faceZ: number,
	deadzone: number
): (number, number)
	local size = math.sqrt(inputX * inputX + inputZ * inputZ)
	if size >= deadzone and size > 0.0001 then
		return inputX / size, inputZ / size
	end
	local faceSize = math.sqrt(faceX * faceX + faceZ * faceZ)
	if faceSize > 0.0001 then
		return faceX / faceSize, faceZ / faceSize
	end
	return 0, 0
end

--- The flat push one punch gives, given how fast the body is already going. It adds up to the cap along
--- its own direction and no further. Speed the other way doesn't count against it.
--- `boost` is the most it adds, BoostSpeed if left out (the recovery lift uses LiftForwardSpeed).
function AirRecovery.push(
	cfg: Settings,
	vx: number,
	vz: number,
	dirX: number,
	dirZ: number,
	boost: number?
): (number, number)
	local along = vx * dirX + vz * dirZ
	local add = math.clamp(cfg.MaxSpeed - along, 0, boost or cfg.BoostSpeed)
	return dirX * add, dirZ * add
end

--- The lift one punch gives. It only tops up to a low ceiling, so it does nothing to a body already
--- rising, and repeated punches can't add up to a climb.
function AirRecovery.lift(cfg: Settings, vy: number): number
	return math.clamp(cfg.UpAssistCeiling - vy, 0, cfg.UpAssist)
end

--- The recovery lift. Does a punch thrown in the air right now earn one? Only falling (`vy` at most
--- -LiftFallingSpeed), with no floor close below (`floorBelow` false, which is the caller's raycast), not
--- slammed, at least LiftCooldown since the last (`sinceLast`), and fewer than LiftsPerFall already this
--- fall (`used`). Rising bodies and ordinary punches never get it.
function AirRecovery.earnsLift(
	cfg: Settings,
	vy: number,
	floorBelow: boolean,
	slammed: boolean,
	sinceLast: number,
	used: number
): boolean
	return cfg.LiftEnabled
		and not slammed
		and not floorBelow
		and vy <= -cfg.LiftFallingSpeed
		and sinceLast >= cfg.LiftCooldown
		and used < cfg.LiftsPerFall
end

--- One step of the fall while a recovery lift is running. It replaces whatever fall rule the body was on
--- for those LiftSeconds, so the two never stack: `vy` is what physics left after a whole `dt` of full
--- `gravity`, and this hands back all but LiftGravityScale of it.
function AirRecovery.liftFall(cfg: Settings, gravity: number, vy: number, dt: number): number
	return vy + gravity * (1 - cfg.LiftGravityScale) * dt
end

--- A push fades on its own in the air, at a steady rate.
function AirRecovery.fade(cfg: Settings, x: number, z: number, dt: number): (number, number)
	local size = math.sqrt(x * x + z * z)
	if size <= 0 then
		return 0, 0
	end
	local left = size - cfg.BoostFade * dt
	if left <= 0 then
		return 0, 0
	end
	return x / size * left, z / size * left
end

--- Stops pushes from carrying a body past the cap once whatever they were fighting has faded. A push is
--- trimmed only when it's what puts the body over: a launch can still be faster than the cap, and a push
--- against that launch stays whole. `baseX`, `baseZ` is the velocity without the push.
function AirRecovery.limit(
	cfg: Settings,
	x: number,
	z: number,
	baseX: number,
	baseZ: number
): (number, number)
	local base = math.sqrt(baseX * baseX + baseZ * baseZ)
	local most = math.max(cfg.MaxSpeed, base)
	local totalX, totalZ = baseX + x, baseZ + z
	if totalX * totalX + totalZ * totalZ <= most * most then
		return x, z
	end
	-- The share of the push that lands exactly on the limit: |base + share * push| = most.
	local a = x * x + z * z
	local b = 2 * (baseX * x + baseZ * z)
	local c = baseX * baseX + baseZ * baseZ - most * most
	local root = b * b - 4 * a * c
	if a <= 0 or root < 0 then
		return 0, 0
	end
	local share = math.clamp((-b + math.sqrt(root)) / (2 * a), 0, 1)
	return x * share, z * share
end

return AirRecovery