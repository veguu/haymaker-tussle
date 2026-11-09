--!strict
-- Momentum - the steering rules, as plain maths with no Roblox instances.
--
-- A character has a SPEED and a HEADING, and travels along its heading. Steering
-- bends the heading at a limited rate, and that rate falls as speed rises: that
-- limit is what turns a swerve into an arc. There is no swerve button.
--
-- A propel (Q) is a short burst of speed the way you're already going. It eases up to its speed, holds
-- it, and eases back down to running speed, all on a fixed profile, so there's never a sudden jump in
-- velocity. While it runs the keys still steer, but only at PropelTurnScale of the normal turn rate, so
-- changing direction is possible but hard. Input more than a right angle off the travel is ignored, so
-- it can't be turned round. When it ends, normal steering comes back gradually rather than all at once.
--
-- Headings are unit vectors on the ground plane (x, z), as Roblox world axes.

local Momentum = {}

export type Settings = {
	Acceleration: number,
	MaxSpeed: number,
	CoastHoldSeconds: number,
	CoastFallSeconds: number,
	CoastFallCurve: number,
	CoastDeceleration: number,
	SideStopDeceleration: number,
	CoastMaxAngle: number,
	BrakeDeceleration: number,
	KnockbackDecay: number,
	KnockbackAirDecay: number,
	KnockbackResist: number,
	KnockbackMaxSpeed: number,
	HitSpeedKeep: number,
	PropelSpeed: number,
	PropelSeconds: number,
	PropelRampSeconds: number,
	PropelEaseOutSeconds: number,
	PropelCooldown: number,
	PropelTurnScale: number,
	PropelControlReturnSeconds: number,
	ReverseDeceleration: number,
	TurnRateLowSpeed: number,
	TurnRateHighSpeed: number,
	TurnBlendLowSpeed: number,
	AirControl: number,
	InputDeadzone: number,
	RestSnapSpeed: number,
}

export type State = {
	speed: number,
	headingX: number,
	headingZ: number,
	-- How hard the heading bent this step: -1 full left, +1 full right.
	-- Presentation only (body lean); never used for gameplay.
	turn: number,
	-- Seconds since input was released; 0 while there is input.
	coastElapsed: number,
	-- True after running forward (W), until the coast ends. Only forward
	-- running earns the coast; steering with A or D keeps it for when you let go.
	forwardCoast: boolean,
	-- True while S is holding the character in a brake, until it stops or S is released.
	braking: boolean?,
	-- Propel: seconds of it left and seconds until the next is allowed. Empty until the first propel.
	propelLeft: number?,
	propelCooldownLeft: number?,
	-- The running burst's shape, fixed when it starts: how long it lasts, its top speed and the speed it
	-- started from.
	dashSeconds: number?,
	dashPeak: number?,
	dashFrom: number?,
	-- Seconds until steering is fully back after a dash.
	controlReturnLeft: number?,
	-- Knockback velocity, on top of normal travel. Normal movement never replaces it.
	knockX: number?,
	knockZ: number?,
}

-- What the input is doing relative to the camera: W is "forward", S is "back",
-- A or D alone is "side".
export type Drive = "forward" | "back" | "side"

local BRAKE_MAX_ALIGNMENT = 0.5 -- S brakes unless travel is already within about 60 degrees of the S direction
local REVERSE_ANGLE = math.pi / 2 -- steering further than this from travel brakes instead of accelerating

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Momentum.new(headingX: number?, headingZ: number?): State
	return {
		speed = 0,
		headingX = headingX or 0,
		headingZ = headingZ or -1,
		turn = 0,
		coastElapsed = 0,
		forwardCoast = false,
	}
end

--- Largest turn rate, in radians per second, at this speed on the ground.
function Momentum.turnRate(cfg: Settings, speed: number): number
	local span = math.max(cfg.MaxSpeed - cfg.TurnBlendLowSpeed, 0.001)
	local t = math.clamp((speed - cfg.TurnBlendLowSpeed) / span, 0, 1)
	return math.rad(cfg.TurnRateLowSpeed + (cfg.TurnRateHighSpeed - cfg.TurnRateLowSpeed) * t)
end

-- Bends a heading toward the wanted direction at the limited rate.
-- Returns the new heading, the angle still left to turn, and the lean amount.
local function steer(
	cfg: Settings,
	speed: number,
	hx: number,
	hz: number,
	wantX: number,
	wantZ: number,
	grounded: boolean,
	control: number,
	dt: number
): (number, number, number, number)
	-- Signed angle from heading to input. Positive is a right turn.
	local remaining = math.atan2(hx * wantZ - hz * wantX, hx * wantX + hz * wantZ)
	if speed <= cfg.RestSnapSpeed and grounded then
		-- Effectively standing still: face the input at once.
		return wantX, wantZ, 0, 0
	end
	local maxStep = Momentum.turnRate(cfg, speed) * control * dt
	local applied = math.clamp(remaining, -maxStep, maxStep)
	local c, s = math.cos(applied), math.sin(applied)
	local turn = if maxStep > 0 then applied / maxStep else 0
	return hx * c - hz * s, hx * s + hz * c, remaining - applied, turn
end

-- After W is released, speed holds for a moment, then falls gently at first and
-- faster the longer W stays off, reaching zero at the end of the fall:
-- speed = held speed * (1 - (time / fall time) ^ curve).
-- Stepping by the ratio between two times gives the same curve at any frame rate.
local function coastSpeed(
	cfg: Settings,
	speed: number,
	elapsed: number,
	control: number,
	dt: number
): (number, number)
	local coasted = elapsed + dt
	local fallSeconds = cfg.CoastFallSeconds / math.max(control, 0.001)
	local function left(at: number): number
		local t = math.clamp((at - cfg.CoastHoldSeconds) / fallSeconds, 0, 1)
		return 1 - t ^ cfg.CoastFallCurve
	end
	local before = left(elapsed)
	return if before > 0 then speed * left(coasted) / before else 0, coasted
end

--- Normal movement for one step. Input is a world-space direction on the ground, length 0 to 1
--- (a partly pushed thumbstick is shorter). `drive` says what that input is
--- relative to the camera; left out, it counts as forward. `side` is how much of
--- the input points to the camera's right (-1 left to +1 right), used to steer while braking.
--- `turnScale` is the share of the normal turn rate, for steering coming back after a dash.
--- Returns a new state; never mutates.
local function moveStep(
	state: State,
	cfg: Settings,
	inputX: number,
	inputZ: number,
	grounded: boolean,
	dt: number,
	drive: Drive?,
	side: number?,
	turnScale: number?
): State
	if not (isFinite(inputX) and isFinite(inputZ)) then
		inputX, inputZ = 0, 0
	end
	if not isFinite(dt) or dt <= 0 then
		return state
	end

	local speed, hx, hz = state.speed, state.headingX, state.headingZ
	local control = if grounded then 1 else cfg.AirControl
	-- Turning only: braking and speed changes are untouched.
	local turnControl = control * math.clamp(turnScale or 1, 0, 1)
	local length = math.sqrt(inputX * inputX + inputZ * inputZ)
	local amount = math.min(length, 1)
	local hasInput = amount >= cfg.InputDeadzone
	local kind: Drive = drive or "forward"

	if not hasInput and not state.forwardCoast then
		-- Letting go of A/D or S: no coast, just a quick stop along the same heading.
		return {
			speed = math.max(speed - cfg.SideStopDeceleration * control * dt, 0),
			headingX = hx,
			headingZ = hz,
			turn = 0,
			coastElapsed = 0,
			forwardCoast = false,
		}
	end

	if state.forwardCoast and not hasInput then
		-- W is off with nothing else held: the coast.
		local nextSpeed, coasted = coastSpeed(cfg, speed, state.coastElapsed, control, dt)
		return {
			speed = nextSpeed,
			headingX = hx,
			headingZ = hz,
			turn = 0,
			coastElapsed = coasted,
			forwardCoast = nextSpeed > 0,
		}
	end

	if hasInput and kind == "back" and speed > cfg.RestSnapSpeed then
		local alignment = (hx * inputX + hz * inputZ) / length
		if state.braking or alignment < BRAKE_MAX_ALIGNMENT then
			-- S while moving is a brake: slow down without turning around. A or D still
			-- steer at the normal rate. A coast already running keeps its place, so
			-- letting go of S carries on with it.
			local turn = 0
			local sideAmount = side or 0
			if math.abs(sideAmount) >= cfg.InputDeadzone then
				turn = if sideAmount > 0 then 1 else -1
				local angle = turn * Momentum.turnRate(cfg, speed) * turnControl * dt
				local c, s = math.cos(angle), math.sin(angle)
				hx, hz = hx * c - hz * s, hx * s + hz * c
			end
			local nextSpeed, coasted = speed, 0
			if state.forwardCoast then
				nextSpeed, coasted = coastSpeed(cfg, speed, state.coastElapsed, control, dt)
			end
			nextSpeed = math.max(nextSpeed - cfg.BrakeDeceleration * control * dt, 0)
			return {
				speed = nextSpeed,
				headingX = hx,
				headingZ = hz,
				turn = turn,
				coastElapsed = coasted,
				forwardCoast = state.forwardCoast and nextSpeed > 0,
				braking = true,
			}
		end
	end

	local newX, newZ, remaining, turn =
		steer(cfg, speed, hx, hz, inputX / length, inputZ / length, grounded, turnControl, dt)

	if math.abs(remaining) > REVERSE_ANGLE and kind ~= "side" then
		-- Steering against travel with W: brake through the turn, so reversing at speed
		-- is a readable arc rather than an instant flip. A and D never brake: going from
		-- one straight to the other keeps all your speed.
		speed = math.max(speed - cfg.ReverseDeceleration * control * dt, 0)
	else
		local target = cfg.MaxSpeed * amount
		if speed < target then
			speed = math.min(speed + cfg.Acceleration * control * dt, target)
		else
			speed = math.max(speed - cfg.CoastDeceleration * control * dt, target)
		end
	end

	return {
		speed = speed,
		headingX = newX,
		headingZ = newZ,
		turn = turn,
		coastElapsed = 0,
		-- Steering with A or D alone keeps running, and keeps a coast W already earned.
		forwardCoast = kind == "forward" or (kind == "side" and state.forwardCoast),
	}
end

-- Knockback fades on its own, and only partly responds to input: pushing against it
-- fades it a little faster, by how much KnockbackResist allows.
local function fadeKnock(
	state: State,
	cfg: Settings,
	inputX: number,
	inputZ: number,
	grounded: boolean,
	dt: number
): (number?, number?)
	local x, z = state.knockX or 0, state.knockZ or 0
	local size = math.sqrt(x * x + z * z)
	if size <= 0 then
		return nil, nil
	end
	local fade = if grounded then cfg.KnockbackDecay else cfg.KnockbackAirDecay
	if isFinite(inputX) and isFinite(inputZ) then
		local against = -(inputX * x + inputZ * z) / size
		if against > 0 then
			fade += cfg.KnockbackResist * cfg.Acceleration * math.min(against, 1)
		end
	end
	local nextSize = size - fade * dt
	if nextSize <= 0 then
		return nil, nil
	end
	return x / size * nextSize, z / size * nextSize
end

--- Adds a knockback hit. Running speed drops, but steering is left alone. `speedKeep` is
--- the share of running speed to keep, HitSpeedKeep if left out. Bumps set their own: the loser
--- of a collision keeps none, the winner a little.
function Momentum.applyKnock(
	state: State,
	cfg: Settings,
	x: number,
	z: number,
	speedKeep: number?
): State
	if not (isFinite(x) and isFinite(z)) then
		return state
	end
	local nextState = table.clone(state)
	local newX, newZ = (state.knockX or 0) + x, (state.knockZ or 0) + z
	local size = math.sqrt(newX * newX + newZ * newZ)
	if size > cfg.KnockbackMaxSpeed then
		newX, newZ = newX / size * cfg.KnockbackMaxSpeed, newZ / size * cfg.KnockbackMaxSpeed
	end
	nextState.knockX, nextState.knockZ = newX, newZ
	nextState.speed = state.speed * (speedKeep or cfg.HitSpeedKeep)
	-- Getting hit ends a propel, so a bump's speed loss really stands.
	nextState.propelLeft = nil
	nextState.controlReturnLeft = nil
	return nextState
end

--- Adds a push to the knockback without counting as being hit: running speed, steering and any propel
--- carry on. For a push the body gave itself in the air, or kept when it landed.
function Momentum.addPush(state: State, cfg: Settings, x: number, z: number): State
	if not (isFinite(x) and isFinite(z)) then
		return state
	end
	local nextState = table.clone(state)
	local newX, newZ = (state.knockX or 0) + x, (state.knockZ or 0) + z
	local size = math.sqrt(newX * newX + newZ * newZ)
	if size > cfg.KnockbackMaxSpeed then
		newX, newZ = newX / size * cfg.KnockbackMaxSpeed, newZ / size * cfg.KnockbackMaxSpeed
	end
	nextState.knockX, nextState.knockZ = newX, newZ
	return nextState
end

--- Hands a body something else was moving back to ordinary movement, already travelling this way at
--- this speed. From here it's exactly the normal rules: acceleration, turning, braking and coasting.
--- Above top speed it eases back down to it, which is how a boost wears off.
function Momentum.moving(state: State, dirX: number, dirZ: number, speed: number): State
	local nextState = Momentum.stopped(state)
	local size = math.sqrt(dirX * dirX + dirZ * dirZ)
	if size > 0.001 then
		nextState.headingX, nextState.headingZ = dirX / size, dirZ / size
		nextState.speed = speed
		nextState.forwardCoast = true
		nextState.coastElapsed = 0
		nextState.turn = 0
	end
	return nextState
end

--- For the moment A or D is let go: only travel that's still forward keeps the long coast. Travel the
--- turn swung off to the side, past `CoastMaxAngle` from where the camera looks, stops quickly instead.
function Momentum.endSidewaysCoast(
	state: State,
	cfg: Settings,
	forwardX: number,
	forwardZ: number
): State
	if not state.forwardCoast then
		return state
	end
	local along = state.headingX * forwardX + state.headingZ * forwardZ
	if along >= math.cos(math.rad(cfg.CoastMaxAngle)) then
		return state
	end
	local nextState = table.clone(state)
	nextState.forwardCoast = false
	nextState.coastElapsed = 0
	return nextState
end

--- Holds flat speed through the air, for a rebound: coasting can't fade it, and steering sideways keeps
--- it. Pushing against the travel really slows you, and what's lost stays lost. A hit ends the hold.
--- Returns the state and the speed still being held, or nil once it's over.
function Momentum.airKeep(
	state: State,
	keep: number,
	inputX: number,
	inputZ: number
): (State, number?)
	if math.abs(state.knockX or 0) > 0.01 or math.abs(state.knockZ or 0) > 0.01 then
		return state, nil
	end
	if state.headingX * inputX + state.headingZ * inputZ < -0.1 then
		return state, math.min(keep, state.speed)
	end
	if state.speed >= keep then
		return state, keep
	end
	local nextState = table.clone(state)
	nextState.speed = keep
	return nextState, keep
end

--- Landing from a rebound: down to running speed, still moving the same way. The landing was worked out
--- to be on the platform, and this is what stops the speed sliding you off the far side of it.
function Momentum.landed(state: State, cfg: Settings): State
	local nextState = table.clone(state)
	nextState.speed = math.min(state.speed, cfg.MaxSpeed)
	return nextState
end

--- No travel and no knockback: for a body something else is moving.
function Momentum.stopped(state: State): State
	local nextState = table.clone(state)
	nextState.speed = 0
	nextState.forwardCoast = false
	nextState.knockX, nextState.knockZ = nil, nil
	nextState.propelLeft = nil
	nextState.controlReturnLeft = nil
	return nextState
end

--- The total flat velocity this state wants: travel plus knockback.
--- `speedShare` scales running, for stagger. Knockback and a propel aren't scaled: a hit's push has to
--- stay what the hit said, and a propel is the way out. Speed, acceleration and turning underneath
--- stay exactly as they are, so a staggered runner is slower but no less responsive.
function Momentum.velocity(state: State, speedShare: number?): (number, number)
	local share = if (state.propelLeft or 0) > 0 then 1 else speedShare or 1
	return state.headingX * state.speed * share + (state.knockX or 0),
		state.headingZ * state.speed * share + (state.knockZ or 0)
end

--- Where the body should point: along the heading.
function Momentum.facing(state: State): (number, number)
	return state.headingX, state.headingZ
end

--- True while a propel is still building up, when the character can't match it yet.
function Momentum.isPropelBuilding(state: State, cfg: Settings): boolean
	local left = state.propelLeft or 0
	return left > 0 and (state.dashSeconds or cfg.PropelSeconds) - left < cfg.PropelRampSeconds
end

local function signedAngle(ax: number, az: number, bx: number, bz: number): number
	return math.atan2(ax * bz - az * bx, ax * bx + az * bz)
end

local function rotated(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c - z * s, x * s + z * c
end

-- The burst's speed after `elapsed` seconds: eased up to the peak, held, then eased down to `exit`.
local function dashSpeed(
	cfg: Settings,
	elapsed: number,
	total: number,
	from: number,
	peak: number,
	exit: number
): number
	local ramp = math.min(cfg.PropelRampSeconds, total)
	local easeOut = math.min(cfg.PropelEaseOutSeconds, math.max(total - ramp, 0))
	if elapsed < ramp then
		return from + (peak - from) * smooth(elapsed / ramp)
	end
	local fadeAt = total - easeOut
	if elapsed < fadeAt or easeOut <= 0 then
		return peak
	end
	return peak + (exit - peak) * smooth((elapsed - fadeAt) / easeOut)
end

-- One step of a burst. Its speed follows the fixed profile. The keys steer it, but only at
-- PropelTurnScale of the turn rate for its speed, and input pointing back against travel is ignored, so
-- it bends but never turns round.
local function dashStep(
	state: State,
	cfg: Settings,
	inputX: number,
	inputZ: number,
	grounded: boolean,
	dt: number
): State
	local total = state.dashSeconds or cfg.PropelSeconds
	local left = (state.propelLeft or 0) - dt
	local elapsed = total - math.max(left, 0)
	local peak = state.dashPeak or cfg.PropelSpeed
	local from = state.dashFrom or state.speed
	local exit = math.min(cfg.MaxSpeed, peak)
	local hx, hz = state.headingX, state.headingZ

	if left <= 0 then
		-- Over: ordinary running from here, already at the speed it eased down to, and steering comes
		-- back over the next moment instead of all at once.
		return {
			speed = exit,
			headingX = hx,
			headingZ = hz,
			turn = 0,
			coastElapsed = 0,
			forwardCoast = true,
			controlReturnLeft = cfg.PropelControlReturnSeconds,
		}
	end

	local speed = dashSpeed(cfg, elapsed, total, from, peak, exit)
	local turn = 0
	if isFinite(inputX) and isFinite(inputZ) then
		local length = math.sqrt(inputX * inputX + inputZ * inputZ)
		if length >= cfg.InputDeadzone then
			local remaining = signedAngle(hx, hz, inputX / length, inputZ / length)
			if math.abs(remaining) <= REVERSE_ANGLE then
				local control = if grounded then 1 else cfg.AirControl
				local maxStep = Momentum.turnRate(cfg, speed)
					* math.clamp(cfg.PropelTurnScale, 0, 1)
					* control
					* dt
				local applied = math.clamp(remaining, -maxStep, maxStep)
				hx, hz = rotated(hx, hz, applied)
				turn = if maxStep > 0 then applied / maxStep else 0
			end
		end
	end
	local size = math.sqrt(hx * hx + hz * hz)
	if size > 0.0001 then
		hx, hz = hx / size, hz / size
	end

	return {
		speed = speed,
		headingX = hx,
		headingZ = hz,
		turn = turn,
		coastElapsed = 0,
		forwardCoast = true,
		propelLeft = left,
		dashSeconds = total,
		dashPeak = peak,
		dashFrom = from,
	}
end

--- One step of movement, including any burst in progress. Returns a new state; never mutates.
function Momentum.step(
	state: State,
	cfg: Settings,
	inputX: number,
	inputZ: number,
	grounded: boolean,
	dt: number,
	drive: Drive?,
	side: number?
): State
	if not isFinite(dt) or dt <= 0 then
		return state
	end
	local cooldown = math.max((state.propelCooldownLeft or 0) - dt, 0)
	local knockX, knockZ = fadeKnock(state, cfg, inputX, inputZ, grounded, dt)
	local nextState: State
	if (state.propelLeft or 0) > 0 then
		nextState = dashStep(state, cfg, inputX, inputZ, grounded, dt)
	else
		-- Just out of a burst, steering eases back from the burst's own share up to the full rate.
		local returning = math.max((state.controlReturnLeft or 0) - dt, 0)
		local turnScale: number? = nil
		if returning > 0 then
			local share = smooth(1 - returning / math.max(cfg.PropelControlReturnSeconds, 0.001))
			local low = math.clamp(cfg.PropelTurnScale, 0, 1)
			turnScale = low + (1 - low) * share
		end
		nextState = moveStep(state, cfg, inputX, inputZ, grounded, dt, drive, side, turnScale)
		nextState.controlReturnLeft = if returning > 0 then returning else nil
	end
	nextState.propelCooldownLeft = cooldown
	nextState.knockX, nextState.knockZ = knockX, knockZ
	return nextState
end

--- Starts a burst along the current travel, or toward the input from a standstill. It never goes
--- backward: S is refused without spending the cooldown. Returns the new state, or nil if refused. Its
--- speed is a fixed profile rather than something added, so pressing again can never stack speed: one
--- runs at a time, and the cooldown starts the moment it does.
function Momentum.tryPropel(
	state: State,
	cfg: Settings,
	inputX: number,
	inputZ: number,
	drive: Drive?
): State?
	if (state.propelCooldownLeft or 0) > 0 or (state.propelLeft or 0) > 0 then
		return nil
	end
	local hx, hz = state.headingX, state.headingZ
	if isFinite(inputX) and isFinite(inputZ) then
		local length = math.sqrt(inputX * inputX + inputZ * inputZ)
		if length >= cfg.InputDeadzone then
			if drive == "back" then
				return nil
			end
			if state.speed <= cfg.RestSnapSpeed then
				hx, hz = inputX / length, inputZ / length
			end
		end
	end
	local total = math.max(cfg.PropelSeconds, 0.05)
	return {
		speed = state.speed,
		headingX = hx,
		headingZ = hz,
		turn = 0,
		coastElapsed = 0,
		forwardCoast = true,
		propelLeft = total,
		propelCooldownLeft = cfg.PropelCooldown,
		knockX = state.knockX,
		knockZ = state.knockZ,
		dashSeconds = total,
		dashPeak = math.max(cfg.PropelSpeed, state.speed),
		dashFrom = state.speed,
	}
end

return Momentum
