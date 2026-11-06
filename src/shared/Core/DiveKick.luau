--!strict
-- DiveKick - the air kick's phases, as plain maths with no Roblox instances.
--
-- It starts with someone launched by an uppercut in the air. Whoever launched them can jump at any
-- range the jump can cover. Anyone else has to be close, and doing so takes the jump over. Either way
-- it's once per so many landed uppercuts, with a shortest time between jumps too.
-- squat: first Space. A few frames down into the legs, still on the floor.
-- chase: the spring. Its arc and strength are worked out once, at that moment, to meet them in the
--   air, and its direction is where the player aims. It never follows them after that: only the
--   movement keys steer it. Once it has missed, it's no longer a committed jump at all: the player
--   goes back to ordinary movement, in the air.
-- attach: close, so both are held in the air and you align beside them. A ring closes at a moment
--   that differs each time; press Space as it meets the key. Meanwhile the movement keys swing you
--   around them: they'll be kicked the way the keys point, and you'll rebound the other way.
-- flip: the press, or the ring running out. The kick always follows, and the timing only sets how
--   hard: red, orange or green. The server lands it when the flip ends.
-- The kick connecting ends this too, at any grade: the kicker gets a boost of ordinary running
-- momentum backward and a small hop, and carries on from there.

local DiveKick = {}

-- How a launched target comes down, for planning a jump at them, when that isn't simply one gravity
-- all the way. The caller supplies these from AirRecovery.
export type TargetFall = {
	-- Seconds until a body at vertical speed `vy` has dropped `height`.
	timeToDrop: (vy: number, height: number) -> number,
	-- How much higher it is after `seconds` at vertical speed `vy`. Negative is lower.
	rise: (vy: number, seconds: number) -> number,
}

export type Settings = {
	AirGravityScale: number,
	StealRange: number,
	JumpSquatSeconds: number,
	LeapMin: number,
	LeapMax: number,
	SteerSpeed: number,
	AirAcceleration: number,
	JumpCarryMax: number,
	JumpMeetShare: number,
	JumpMeetMin: number,
	JumpMeetMax: number,
	JumpShortShare: number,
	JumpShortMax: number,
	AimForgiveDegrees: number,
	JumpMissGrace: number,
	KickAimRate: number,
	LaunchSteerSpeed: number,
	LaunchSteerAcceleration: number,
	LaunchSteerStaggerLoss: number,
	TouchFlat: number,
	TouchTall: number,
	AttachAbove: number,
	AttachSide: number,
	FlipAbove: number,
	FlipSide: number,
	FollowRate: number,
	QteEarliest: number,
	QteLatest: number,
	GreenWindow: number,
	OrangeWindow: number,
	RedShare: number,
	OrangeShare: number,
	GreenShare: number,
	RedStop: number,
	OrangeStop: number,
	GreenStop: number,
	FlipSeconds: number,
	ReboundRiseRed: number,
	ReboundRiseOrange: number,
	ReboundRiseGreen: number,
	ReboundLandNear: number,
	ReboundLandFar: number,
	ReboundSpeedMax: number,
}

export type Phase = "squat" | "chase" | "attach" | "flip"
export type Grade = "red" | "orange" | "green"

-- Where a rebound starts from. `height` is the feet above the platform's top. `speed` is the flat
-- speed to use, and `gravity` what you'll fall under.
export type ReboundFrom = {
	x: number,
	z: number,
	height: number,
	backX: number,
	backZ: number,
	centerX: number,
	centerZ: number,
	radius: number,
	speed: number,
	gravity: number,
}

export type ReboundPlan = {
	dirX: number,
	dirZ: number,
	speed: number,
	up: number,
	air: number,
}

export type State = {
	phase: Phase,
	t: number,
	vx: number,
	vy: number,
	vz: number,
	steerX: number,
	steerZ: number,
	sideX: number,
	sideZ: number,
	qteAt: number,
	missAt: number,
}

export type JumpPlan = {
	meet: number,
	leap: number,
	carry: number,
	towardX: number,
	towardZ: number,
	reachable: boolean,
}

local FLIP_GRACE = 0.5 -- how long a flip waits for the server before giving up
local RING_RUN_OUT = 0.04 -- how long after the last usable moment an unpressed ring gives up

--- Can this jumper go for this target? Their own launch, at any range. Anyone else's, only when
--- close; only the flat distance counts, since the target may already be far overhead. Whether the
--- jump could actually get there is a separate question: see `canReach`.
function DiveKick.canJumpAt(
	cfg: Settings,
	isOwn: boolean,
	x: number,
	z: number,
	targetX: number,
	targetZ: number
): boolean
	if isOwn then
		return true
	end
	local dx, dz = targetX - x, targetZ - z
	return dx * dx + dz * dz <= cfg.StealRange * cfg.StealRange
end

--- Close enough to start the kick? Bodies are tall and narrow, so it's a short wide cylinder rather
--- than a ball. It doesn't need real contact, but nothing happens from any further away.
function DiveKick.isTouching(cfg: Settings, dx: number, dy: number, dz: number): boolean
	return dx * dx + dz * dz <= cfg.TouchFlat * cfg.TouchFlat and math.abs(dy) <= cfg.TouchTall
end

--- The spring of the jump, worked out once. It picks a moment partway through their remaining time
--- in the air, then an arc reaching their height at that moment and a strength covering the distance
--- to where they'll be, a little short so that it takes a small correction to finish. The strength
--- is automatic; `towardX`, `towardZ` is only used to forgive a nearly right aim. A long launch
--- therefore gets a long jump, without anything following the target afterward. `reachable` says
--- whether the jump's limits allow it at all.
--- `dx`, `dy`, `dz` is from you to them, `vx`, `vy`, `vz` how they're moving, `decay` how fast their
--- push fades, `gravity` the air gravity. `fall` says how they really fall, when that isn't simply
--- `gravity` all the way down: they rise on it and then fall on the lighter rules in AirRecovery.
function DiveKick.planJump(
	cfg: Settings,
	dx: number,
	dy: number,
	dz: number,
	vx: number,
	vy: number,
	vz: number,
	decay: number,
	gravity: number,
	fall: TargetFall?
): JumpPlan
	local height = math.max(dy, 0)
	local airLeft = if fall
		then fall.timeToDrop(vy, height)
		else (vy + math.sqrt(vy * vy + 2 * gravity * height)) / gravity
	local meet = math.clamp(airLeft * cfg.JumpMeetShare, cfg.JumpMeetMin, cfg.JumpMeetMax)
	-- You rise and fall on `gravity`. With nothing else given they do too, so the height between you
	-- closes at a steady rate. Otherwise it's how far they've really moved by then.
	local neededLeap = if fall
		then (height + fall.rise(vy, meet) + gravity * meet * meet / 2) / meet
		else vy + height / meet
	local leap = math.clamp(neededLeap, cfg.LeapMin, cfg.LeapMax)
	-- Where they'll be by then, with their push fading along the way.
	local speed = math.sqrt(vx * vx + vz * vz)
	local toX, toZ = dx, dz
	if speed > 0.01 then
		local moving = if decay > 0 then math.min(meet, speed / decay) else meet
		local travel = speed * moving - decay * moving * moving / 2
		toX += vx / speed * travel
		toZ += vz / speed * travel
	end
	local distance = math.sqrt(toX * toX + toZ * toZ)
	local short = math.min(distance * cfg.JumpShortShare, cfg.JumpShortMax)
	local neededCarry = (distance - short) / meet
	local reachable = airLeft >= meet
		and neededLeap <= cfg.LeapMax
		and neededCarry <= cfg.JumpCarryMax
	local carry = math.min(neededCarry, cfg.JumpCarryMax)
	if distance < 0.01 then
		return {
			meet = meet,
			leap = leap,
			carry = 0,
			towardX = 0,
			towardZ = 0,
			reachable = reachable,
		}
	end
	return {
		meet = meet,
		leap = leap,
		carry = carry,
		towardX = toX / distance,
		towardZ = toZ / distance,
		reachable = reachable,
	}
end

--- Would a jump pressed now be able to get there? It allows for the squat, since the jump leaves the
--- floor a moment later and they'll have moved on by then. This decides whether to offer the jump.
function DiveKick.canReach(
	cfg: Settings,
	dx: number,
	dy: number,
	dz: number,
	vx: number,
	vy: number,
	vz: number,
	decay: number,
	gravity: number,
	fall: TargetFall?
): boolean
	local wait = cfg.JumpSquatSeconds
	local plan = DiveKick.planJump(
		cfg,
		dx + vx * wait,
		dy + vy * wait - gravity * wait * wait / 2,
		dz + vz * wait,
		vx,
		vy - gravity * wait,
		vz,
		decay,
		gravity,
		fall
	)
	return plan.reachable
end

--- Where the jump actually goes: the player's aim, unless that's nearly right, when it's forgiven
--- into exactly right. An aim further off stays as it is, and so misses unless they correct it.
function DiveKick.aimJump(
	cfg: Settings,
	aimX: number,
	aimZ: number,
	towardX: number,
	towardZ: number
): (number, number)
	local size = math.sqrt(aimX * aimX + aimZ * aimZ)
	if size < 0.001 then
		return towardX, towardZ
	end
	aimX, aimZ = aimX / size, aimZ / size
	local cosine = aimX * towardX + aimZ * towardZ
	if cosine >= math.cos(math.rad(cfg.AimForgiveDegrees)) then
		return towardX, towardZ
	end
	return aimX, aimZ
end

--- Directional air control: pushes the velocity toward where the keys point, up to `limit`. With no
--- keys it keeps what it has. It's kept apart from any launch speed, so it never cancels that.
function DiveKick.airSteer(
	vx: number,
	vz: number,
	inputX: number,
	inputZ: number,
	limit: number,
	acceleration: number,
	dt: number
): (number, number)
	if inputX == 0 and inputZ == 0 then
		return vx, vz
	end
	local had = math.sqrt(vx * vx + vz * vz)
	local nextX, nextZ = vx + inputX * acceleration * dt, vz + inputZ * acceleration * dt
	local size = math.sqrt(nextX * nextX + nextZ * nextZ)
	local cap = math.max(limit, had)
	if size > cap then
		nextX, nextZ = nextX / size * cap, nextZ / size * cap
	end
	return nextX, nextZ
end

--- How much air control someone launched has. The more staggered, the less they can do about it.
function DiveKick.launchSteerShare(cfg: Settings, stagger: number, staggerMax: number): number
	return 1 - cfg.LaunchSteerStaggerLoss * math.clamp(stagger / staggerMax, 0, 1)
end

--- When the ring meets the key, in seconds after touching. `roll` is a random 0 to 1.
function DiveKick.pickQte(cfg: Settings, roll: number): number
	return cfg.QteEarliest + (cfg.QteLatest - cfg.QteEarliest) * math.clamp(roll, 0, 1)
end

--- How good a press was. `since` is seconds from touching to pressing. The server calls this with
--- its own clock, so a client can't claim a good press.
function DiveKick.grade(cfg: Settings, since: number, qteAt: number): Grade
	local off = math.abs(since - qteAt)
	if off <= cfg.GreenWindow then
		return "green"
	elseif off <= cfg.OrangeWindow then
		return "orange"
	end
	return "red"
end

--- How much of the kick's full force this grade gets, for the outward push, the slam and stagger.
function DiveKick.gradeShare(cfg: Settings, grade: Grade): number
	if grade == "green" then
		return cfg.GreenShare
	elseif grade == "orange" then
		return cfg.OrangeShare
	end
	return cfg.RedShare
end

--- How long both are frozen when this grade lands. A bigger kick stops the world for longer.
function DiveKick.gradeStop(cfg: Settings, grade: Grade): number
	if grade == "green" then
		return cfg.GreenStop
	elseif grade == "orange" then
		return cfg.OrangeStop
	end
	return cfg.RedStop
end

--- How long an unpressed ring lasts before the kick goes anyway, as a red.
function DiveKick.ringEnd(cfg: Settings, qteAt: number): number
	return qteAt + cfg.OrangeWindow + RING_RUN_OUT
end

--- Space: down into the squat, feet still on the floor.
function DiveKick.start(): State
	return {
		phase = "squat",
		t = 0,
		vx = 0,
		vy = 0,
		vz = 0,
		steerX = 0,
		steerZ = 0,
		sideX = 0,
		sideZ = 1,
		qteAt = 0,
		missAt = math.huge,
	}
end

--- Off the floor, with the speed the plan and the aim worked out. `missAt` is how long into the jump
--- it counts as having missed, if it hasn't reached them by then.
function DiveKick.spring(state: State, vx: number, vy: number, vz: number, missAt: number?): State
	local nextState = table.clone(state)
	nextState.phase = "chase"
	nextState.t = 0
	nextState.vx, nextState.vy, nextState.vz = vx, vy, vz
	nextState.missAt = missAt or math.huge
	return nextState
end

--- Has this jump missed? Then it's yours to recover from.
function DiveKick.hasMissed(state: State): boolean
	return state.phase == "chase" and state.t >= state.missAt
end

--- The jump has nothing left to reach: they landed, or someone else took it.
function DiveKick.giveUp(state: State): State
	if state.phase ~= "chase" then
		return state
	end
	local nextState = table.clone(state)
	nextState.missAt = math.min(state.missAt, state.t)
	return nextState
end

--- Close enough. `dx`, `dz` is the flat offset from the target to the jumper: you align on the side
--- you arrived on, so the way the kick will send them is the way you came.
function DiveKick.attach(state: State, dx: number, dz: number, qteAt: number): State
	if state.phase ~= "chase" then
		return state
	end
	local nextState = table.clone(state)
	nextState.phase = "attach"
	nextState.t = 0
	nextState.qteAt = qteAt
	local size = math.sqrt(dx * dx + dz * dz)
	if size > 0.01 then
		nextState.sideX, nextState.sideZ = dx / size, dz / size
	end
	return nextState
end

--- Aiming the kick. You stand on the far side of them from where the keys point, swinging around
--- them at `rate` degrees per second, since a kick sends them directly away from you. With no keys
--- you stay where you are. The arc means it never passes through them.
function DiveKick.aimSide(
	sideX: number,
	sideZ: number,
	inputX: number,
	inputZ: number,
	rate: number,
	dt: number
): (number, number)
	if inputX == 0 and inputZ == 0 then
		return sideX, sideZ
	end
	local now = math.atan2(sideZ, sideX)
	local want = math.atan2(-inputZ, -inputX)
	local gap = (want - now + math.pi) % (2 * math.pi) - math.pi
	local reach = math.rad(rate) * dt
	local nextAngle = now + math.clamp(gap, -reach, reach)
	return math.cos(nextAngle), math.sin(nextAngle)
end

--- The second Space. The server decides how good it was; the kick follows either way.
function DiveKick.press(state: State): State
	if state.phase ~= "attach" then
		return state
	end
	local nextState = table.clone(state)
	nextState.phase = "flip"
	nextState.t = 0
	return nextState
end

--- One step. `gravity` is the air gravity. In the jump, the keys steer on top of what it gave you.
--- Returns the new state, or nil when the move has ended.
function DiveKick.step(
	state: State,
	cfg: Settings,
	dt: number,
	gravity: number,
	inputX: number,
	inputZ: number
): State?
	local nextState = table.clone(state)
	nextState.t += dt
	if state.phase == "chase" then
		nextState.vy -= gravity * dt
		nextState.steerX, nextState.steerZ = DiveKick.airSteer(
			state.steerX,
			state.steerZ,
			inputX,
			inputZ,
			cfg.SteerSpeed,
			cfg.AirAcceleration,
			dt
		)
	elseif state.phase == "attach" then
		if nextState.t >= DiveKick.ringEnd(cfg, state.qteAt) then
			return DiveKick.press(state)
		end
		nextState.sideX, nextState.sideZ =
			DiveKick.aimSide(state.sideX, state.sideZ, inputX, inputZ, cfg.KickAimRate, dt)
	elseif state.phase == "flip" then
		if nextState.t >= cfg.FlipSeconds + FLIP_GRACE then
			return nil
		end
	end
	return nextState
end

--- The velocity this phase sets, or nil to leave the body to physics. In the air it's only its own
--- velocity: the target plays no part until close. After that you align beside them and stay with
--- them, and the flip takes you up over them.
function DiveKick.velocity(
	state: State,
	cfg: Settings,
	x: number,
	y: number,
	z: number,
	targetX: number,
	targetY: number,
	targetZ: number,
	targetVX: number,
	targetVY: number,
	targetVZ: number
): (number?, number?, number?)
	if state.phase == "chase" then
		return state.vx + state.steerX, state.vy, state.vz + state.steerZ
	elseif state.phase == "attach" or state.phase == "flip" then
		local side = if state.phase == "flip" then cfg.FlipSide else cfg.AttachSide
		local up = if state.phase == "flip" then cfg.FlipAbove else cfg.AttachAbove
		local wantX = targetX + state.sideX * side
		local wantY = targetY + up
		local wantZ = targetZ + state.sideZ * side
		return targetVX + (wantX - x) * cfg.FollowRate,
			targetVY + (wantY - y) * cfg.FollowRate,
			targetVZ + (wantZ - z) * cfg.FollowRate
	end
	return nil, nil, nil
end

--- Where a kick throws you, worked out once as it connects. Only the height depends on the grade. The
--- flat speed is a propel's and holds until you land, so a higher arc carries you further.
--- Nothing throws you past the far side of the platform. A green also can't fall short, however far out
--- you are: it speeds up to reach, and if backward doesn't lead to the platform at all it goes there
--- instead. Red and orange get what their arc gives them.
function DiveKick.planRebound(cfg: Settings, grade: Grade, at: ReboundFrom): ReboundPlan
	local rise = if grade == "green"
		then cfg.ReboundRiseGreen
		elseif grade == "orange" then cfg.ReboundRiseOrange
		else cfg.ReboundRiseRed
	local gravity = at.gravity
	local up = math.sqrt(2 * gravity * rise)
	local air = (up + math.sqrt(up * up + 2 * gravity * math.max(at.height, 0))) / gravity

	local px, pz = at.x - at.centerX, at.z - at.centerZ
	local fromCentre = math.sqrt(px * px + pz * pz)
	-- How far along a direction the platform starts and ends. Nil if that line never crosses it.
	local function crossing(dx: number, dz: number): (number?, number?)
		local along = px * dx + pz * dz
		local inside = along * along - (fromCentre * fromCentre - at.radius * at.radius)
		if inside < 0 then
			return nil, nil
		end
		local half = math.sqrt(inside)
		return -along - half, -along + half
	end

	local size = math.sqrt(at.backX * at.backX + at.backZ * at.backZ)
	local dirX, dirZ = 0, 0
	if size > 0.001 then
		dirX, dirZ = at.backX / size, at.backZ / size
	elseif fromCentre > 0.001 then
		dirX, dirZ = -px / fromCentre, -pz / fromCentre
	end
	local near, far = crossing(dirX, dirZ)
	local leadsThere = near ~= nil and far ~= nil and far > 0
	if grade == "green" and not leadsThere and fromCentre > 0.001 then
		dirX, dirZ = -px / fromCentre, -pz / fromCentre
		near, far = crossing(dirX, dirZ)
		leadsThere = near ~= nil and far ~= nil and far > 0
	end

	local speed = at.speed
	if leadsThere then
		local enter = math.max(near :: number, 0)
		local leave = far :: number
		local middle = (enter + leave) / 2
		local closest = if near :: number > 0
			then math.min(enter + cfg.ReboundLandNear, middle)
			else 0
		local furthest = math.max(leave - cfg.ReboundLandFar, middle)
		if grade == "green" and closest / air > speed then
			speed = math.min(closest / air, cfg.ReboundSpeedMax)
		end
		speed = math.min(speed, furthest / air)
	end
	return { dirX = dirX, dirZ = dirZ, speed = speed, up = up, air = air }
end

return DiveKick