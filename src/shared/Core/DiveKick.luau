--!strict
-- DiveKick - the air kick's phases, as plain maths with no Roblox instances.
--
-- It starts with someone launched by an uppercut in the air: the follow-up. Anyone launched within
-- FollowUpRange can be followed up, with nothing solid in between; `pickFollowUp` says which, and the
-- server's pick is the one that counts. Once per Cooldown.
-- squat: first Space. A few frames down into the legs, still on the floor, waiting for the server to
--   accept it. Nothing moves until it has, and if it never does, the squat simply ends.
-- chase: the snap. A straight, fast move to beside them, re-aimed every frame at where they are, so it
--   arrives in `approach` seconds whatever small drift they make. The server holds them still from the
--   moment it accepts. If something solid stops it short, it has missed: the player goes back to
--   ordinary movement, in the air.
-- attach: close, so both are held in the air and you align beside them. A ring closes at a moment
--   that differs each time; press Space as it meets the key. Meanwhile the movement keys swing you
--   around them: they'll be kicked the way the keys point, and you'll rebound the other way.
-- flip: the press, or the ring running out. The kick always follows, and the timing only sets how
--   hard: red, orange or green. The server lands it when the flip ends.
-- The kick connecting ends this too, at any grade: the kicker gets a boost of ordinary running
-- momentum backward and a small hop, and carries on from there.

local DiveKick = {}

export type Settings = {
	AirGravityScale: number,
	JumpSquatSeconds: number,
	ApproachSpeed: number,
	ApproachMinSeconds: number,
	ApproachMaxSeconds: number,
	ApproachMaxSpeed: number,
	FollowUpRange: number,
	FollowUpOwnRange: number,
	FollowUpAimWeight: number,
	FollowUpOwnShare: number,
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

-- Someone who could be followed up: where they are, and whether it's your own launch.
export type Candidate = {
	x: number,
	y: number,
	z: number,
	own: boolean,
}

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
	-- Seconds from leaving at vertical speed `up` to dropping `height`, when the fall isn't plain
	-- `gravity` (the game's lighter falling gravity). Nil works it out from `gravity` alone.
	fallTime: ((up: number, height: number) -> number)?,
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
	-- The snap's length in seconds, while it runs.
	approach: number?,
}

local FLIP_GRACE = 0.5 -- how long a flip waits for the server before giving up
local RING_RUN_OUT = 0.04 -- how long after the last usable moment an unpressed ring gives up
local SNAP_MIN_REMAINING = 1 / 30 -- the snap never aims to close the gap faster than this

--- How a follow-up candidate scores: lower is better, nil if out of range (FollowUpOwnRange for your own
--- launch, FollowUpRange for anyone else's). The distance counts, and so
--- does how far off where you face it is: straight ahead counts as it is, directly behind as
--- (1 + FollowUpAimWeight) times further. Your own launch counts FollowUpOwnShare as far. `slack` is extra
--- range for the server, which sees both bodies slightly late.
function DiveKick.followUpScore(
	cfg: Settings,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number,
	candidate: Candidate,
	slack: number?
): number?
	local dx, dy, dz = candidate.x - x, candidate.y - y, candidate.z - z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	local range = if candidate.own then cfg.FollowUpOwnRange else cfg.FollowUpRange
	if distance > range + (slack or 0) then
		return nil
	end
	local flat = math.sqrt(dx * dx + dz * dz)
	local faceSize = math.sqrt(faceX * faceX + faceZ * faceZ)
	local cosine = 1
	if flat > 0.01 and faceSize > 0.01 then
		cosine = (dx * faceX + dz * faceZ) / (flat * faceSize)
	end
	local score = distance * (1 + cfg.FollowUpAimWeight * (1 - cosine) / 2)
	if candidate.own then
		score *= cfg.FollowUpOwnShare
	end
	return score
end

--- The follow-up target: the candidate with the lowest score, or nil if none is in range. Candidates
--- are already known to be valid (launched, fightable, nothing solid in between); this only picks. Client
--- and server both use it, so they agree unless two are nearly level, and then the server's pick stands.
function DiveKick.pickFollowUp(
	cfg: Settings,
	x: number,
	y: number,
	z: number,
	faceX: number,
	faceZ: number,
	candidates: { Candidate },
	slack: number?
): number?
	local best: number? = nil
	local bestScore = math.huge
	for index, candidate in candidates do
		local score = DiveKick.followUpScore(cfg, x, y, z, faceX, faceZ, candidate, slack)
		if score and score < bestScore then
			best, bestScore = index, score
		end
	end
	return best
end

--- How long the snap to a target this far away takes.
function DiveKick.approachSeconds(cfg: Settings, distance: number): number
	return math.clamp(
		distance / math.max(cfg.ApproachSpeed, 1),
		cfg.ApproachMinSeconds,
		cfg.ApproachMaxSeconds
	)
end

--- Close enough to start the kick? Bodies are tall and narrow, so it's a short wide cylinder rather
--- than a ball. It doesn't need real contact, but nothing happens from any further away.
function DiveKick.isTouching(cfg: Settings, dx: number, dy: number, dz: number): boolean
	return dx * dx + dz * dz <= cfg.TouchFlat * cfg.TouchFlat and math.abs(dy) <= cfg.TouchTall
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

--- Off the floor in the snap: `approach` seconds to reach them. `dx`, `dz` is the flat offset from the
--- target to the jumper, which is the side you'll arrive on. Past `missAt` without touching, it has missed.
function DiveKick.snap(
	state: State,
	dx: number,
	dz: number,
	approach: number,
	missAt: number
): State
	local nextState = table.clone(state)
	nextState.phase = "chase"
	nextState.t = 0
	nextState.vx, nextState.vy, nextState.vz = 0, 0, 0
	nextState.steerX, nextState.steerZ = 0, 0
	nextState.approach = approach
	nextState.missAt = missAt
	local size = math.sqrt(dx * dx + dz * dz)
	if size > 0.01 then
		nextState.sideX, nextState.sideZ = dx / size, dz / size
	end
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

--- One step. `gravity` is the air gravity. The snap is committed: the keys play no part in it.
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
		if state.approach == nil then
			nextState.vy -= gravity * dt
		end
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

--- The velocity this phase sets, or nil to leave the body to physics. In the snap it heads straight for
--- the spot beside them it will attach at, timed to get there as the snap ends: it's re-aimed every
--- frame, so a target that drifts a little is still reached, but never faster than ApproachMaxSpeed.
--- It's a velocity, not a teleport, so walls really stop it. After that you align beside them and stay
--- with them, and the flip takes you up over them.
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
		local approach = state.approach
		if approach == nil then
			return state.vx, state.vy, state.vz
		end
		local remaining = math.max(approach - state.t, SNAP_MIN_REMAINING)
		local wantX = targetX + state.sideX * cfg.AttachSide
		local wantY = targetY + cfg.AttachAbove
		local wantZ = targetZ + state.sideZ * cfg.AttachSide
		local vx = targetVX + (wantX - x) / remaining
		local vy = targetVY + (wantY - y) / remaining
		local vz = targetVZ + (wantZ - z) / remaining
		local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
		if speed > cfg.ApproachMaxSpeed then
			local share = cfg.ApproachMaxSpeed / speed
			vx, vy, vz = vx * share, vy * share, vz * share
		end
		return vx, vy, vz
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
	local air = if at.fallTime
		then at.fallTime(up, math.max(at.height, 0))
		else (up + math.sqrt(up * up + 2 * gravity * math.max(at.height, 0))) / gravity

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
