--!strict
-- Combat - the punch, knockback and stagger rules, as plain maths with no Roblox
-- instances. Everything here runs on the server; clients are never asked for a result.

local Combat = {}

local MAX_STAGGER_SLOWDOWN = 0.2

export type PunchSettings = {
	Cooldown: number,
	CooldownTolerance: number,
	Range: number,
	TargetRadius: number,
	OverlapRadius: number,
	HitCancelsPunch: boolean,
	ComboResetSeconds: number,
	MissSpeedKeep: number,
	HitRecoilSpeed: number,
	HitSpeedKeep: number,
	HookOuterDegrees: number,
	HookInnerDegrees: number,
	UppercutDegrees: number,
	CloseRange: number,
	CloseDegrees: number,
	VerticalLimit: number,
	ActiveSeconds: number?,
	MissRecovery: number?,
	BufferSeconds: number?,
	GraceSeconds: number?,
	SweepStep: number?,
	PointBlankRadius: number?,
}

export type KnockbackSettings = {
	BaseSpeed: number,
	SpeedBonusPerStud: number,
	SpeedBonusMax: number?,
	UpwardFraction: number,
	UpwardMax: number,
	AirborneUpwardFraction: number,
	UppercutLift: number,
}

export type StaggerSettings = {
	Max: number,
	PerHit: number,
	HitRelief: number,
	MaxKnockbackMultiplier: number,
	RecoveryEnabled: boolean,
	RecoveryDelay: number,
	RecoveryPerSecond: number,
	SpeedPenaltyMax: number,
	SpeedPenaltyCurve: number,
}

--- Knockback multiplier: 1 at no stagger, rising in a straight line to the cap at full.
function Combat.staggerMultiplier(cfg: StaggerSettings, stagger: number): number
	local share = math.clamp(stagger / cfg.Max, 0, 1)
	return 1 + (cfg.MaxKnockbackMultiplier - 1) * share
end

--- The one thing stagger does to running: a share of normal speed. It isn't stacked per hit, only
--- read from the stagger value, so it comes back smoothly as stagger recovers. A slight curve keeps
--- it light at first. However it's set, it never takes away more than a fifth.
function Combat.staggerSpeedShare(cfg: StaggerSettings, stagger: number): number
	local share = math.clamp(stagger / cfg.Max, 0, 1)
	return 1 - math.min(cfg.SpeedPenaltyMax, MAX_STAGGER_SLOWDOWN) * share ^ cfg.SpeedPenaltyCurve
end

--- How hard a punch launches, in studs/s. THE RULE: `staggerBefore` is the target's
--- stagger from before this hit. The hit's own stagger only affects the next punch.
function Combat.punchStrength(
	knock: KnockbackSettings,
	stagger: StaggerSettings,
	attackerSpeed: number,
	staggerBefore: number
): number
	-- The faster the attacker is going, the harder it throws, up to SpeedBonusMax extra.
	local bonus = math.min(
		knock.SpeedBonusPerStud * math.max(attackerSpeed, 0),
		knock.SpeedBonusMax or math.huge
	)
	local base = knock.BaseSpeed + bonus
	return base * Combat.staggerMultiplier(stagger, staggerBefore)
end

function Combat.addStagger(cfg: StaggerSettings, stagger: number): number
	return math.min(stagger + cfg.PerHit, cfg.Max)
end

--- Stagger left after landing a hit. Winning an exchange is a way back from behind.
function Combat.relieveStagger(cfg: StaggerSettings, stagger: number): number
	return math.max(stagger - cfg.HitRelief, 0)
end

--- Stagger after `dt` seconds, given how long it has been since the last hit.
function Combat.recoverStagger(
	cfg: StaggerSettings,
	stagger: number,
	sinceHit: number,
	dt: number
): number
	if not cfg.RecoveryEnabled or sinceHit < cfg.RecoveryDelay then
		return stagger
	end
	return math.max(stagger - cfg.RecoveryPerSecond * dt, 0)
end

--- Upward launch speed. Only a grounded target gets a real lift, and it's capped, so
--- repeated punches can't carry anyone up into the sky.
function Combat.upwardSpeeds(cfg: KnockbackSettings, strength: number): (number, number)
	local grounded = math.min(strength * cfg.UpwardFraction, cfg.UpwardMax)
	local airborne = math.min(strength * cfg.AirborneUpwardFraction, cfg.UpwardMax)
	return grounded, airborne
end

--- The lift for a particular swing. An uppercut really throws them upward, on the ground or
--- already in the air.
function Combat.swingLift(cfg: KnockbackSettings, side: string, strength: number): (number, number)
	if side == "Uppercut" then
		return cfg.UppercutLift, cfg.UppercutLift
	end
	return Combat.upwardSpeeds(cfg, strength)
end

--- The arc a swing's reach covers, in degrees from straight ahead, positive to the attacker's right. A
--- hook sweeps in from its own side and only a little past the middle. An uppercut goes straight up the
--- middle, and it's what's used when the swing isn't known yet.
function Combat.swingArc(cfg: PunchSettings, side: string?): (number, number)
	if side == "Left" then
		return -cfg.HookOuterDegrees, cfg.HookInnerDegrees
	elseif side == "Right" then
		return -cfg.HookInnerDegrees, cfg.HookOuterDegrees
	end
	return -cfg.UppercutDegrees, cfg.UppercutDegrees
end

-- The smallest turn between two angles, in radians.
local function angleBetween(a: number, b: number): number
	local gap = (a - b) % (math.pi * 2)
	return if gap > math.pi then math.pi * 2 - gap else gap
end

-- How far a point at this distance and angle is from a sector of this radius and angular span, both
-- from the attacker. Zero means the point is inside it.
local function gapToSector(
	distance: number,
	angle: number,
	low: number,
	high: number,
	radius: number
): number
	if angle >= low and angle <= high then
		return math.max(distance - radius, 0)
	end
	local turn = math.min(angleBetween(angle, low), angleBetween(angle, high))
	-- The nearest point on the sector's straight edge.
	local along = distance * math.cos(turn)
	if along <= 0 then
		return distance
	end
	along = math.min(along, radius)
	return math.sqrt(distance * distance + along * along - 2 * distance * along * math.cos(turn))
end

--- Does this swing reach the target? Facing is a flat unit vector. Returns the answer and, when it's no,
--- why. Line of sight is checked separately by the service.
---
--- The target is its hurtbox: an upright capsule of TargetRadius, with no regard for accessories or effects.
--- The attack is three shapes together, and it connects when the hurtbox touches any of them:
--- - the swing's reach, a sector of Range over the arc from swingArc,
--- - a close sector of CloseRange over CloseDegrees either way, for someone at your side,
--- - a contact disc of OverlapRadius, centre to centre, for someone you're inside.
--- These overlap, so the reach falls away smoothly toward the back rather than at a cliff.
function Combat.inHitbox(
	cfg: PunchSettings,
	ax: number,
	ay: number,
	az: number,
	fx: number,
	fz: number,
	tx: number,
	ty: number,
	tz: number,
	side: string?
): (boolean, string?)
	if math.abs(ty - ay) > cfg.VerticalLimit then
		return false, "height"
	end
	local dx, dz = tx - ax, tz - az
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance > cfg.Range + cfg.TargetRadius then
		return false, "range"
	end
	if distance <= cfg.OverlapRadius then
		return true, nil
	end
	local forward = dx * fx + dz * fz
	local right = dx * -fz + dz * fx
	local angle = math.atan2(right, forward)
	local low, high = Combat.swingArc(cfg, side)
	if
		gapToSector(distance, angle, math.rad(low), math.rad(high), cfg.Range) <= cfg.TargetRadius
	then
		return true, nil
	end
	local close = math.rad(cfg.CloseDegrees)
	if gapToSector(distance, angle, -close, close, cfg.CloseRange) <= cfg.TargetRadius then
		return true, nil
	end
	return false, "facing"
end

--- The way a landed punch throws its target, as a flat unit vector. Away from the attacker, except when
--- the two are so far inside each other (`PointBlankRadius`) that the offset between them is only noise:
--- then it's the way the punch was thrown, the attacker's facing `fx, fz`, so the shove is steady.
function Combat.punchAway(
	cfg: PunchSettings,
	dx: number,
	dz: number,
	fx: number,
	fz: number
): (number, number)
	local size = math.sqrt(dx * dx + dz * dz)
	if size <= math.max(cfg.PointBlankRadius or 0, 0.001) then
		return fx, fz
	end
	return dx / size, dz / size
end

--- The stretch of time a swing looks at for contact, on the server's clock, as (from, to). It starts
--- `GraceSeconds` before the active frames, so bodies that crossed just before the swing went live still
--- count, but never before the press was accepted: running past someone and then pressing is a miss.
--- `checkedTo` is how far an earlier look got, so each moment is looked at once and contact that happens
--- entirely between two server frames is still found. Nil when there's nothing new to look at.
function Combat.contactWindow(
	cfg: PunchSettings,
	acceptedAt: number,
	activeFrom: number,
	activeUntil: number,
	checkedTo: number?,
	now: number
): (number?, number?)
	if now < activeFrom then
		return nil, nil
	end
	local from = math.max(acceptedAt, activeFrom - (cfg.GraceSeconds or 0))
	if checkedTo then
		from = math.max(from, checkedTo)
	end
	local to = math.min(now, activeUntil)
	-- Nothing new: each moment is looked at once.
	if to < from or (checkedTo ~= nil and to <= from) then
		return nil, nil
	end
	return from, to
end

--- Moments from `from` to `to`, at most `step` apart, always ending exactly on `to`.
function Combat.sweepTimes(from: number, to: number, step: number): { number }
	local times = {}
	local span = to - from
	local count = math.max(math.ceil(span / math.max(step, 0.001) - 1e-6), 0)
	for index = 0, count do
		times[index + 1] = if count == 0 then to else from + span * index / count
	end
	return times
end

export type SweepSample = {
	ax: number,
	ay: number,
	az: number,
	tx: number,
	ty: number,
	tz: number,
}

--- The first moment in a swept look where the swing reaches the target, as an index into `samples`
--- (earliest first), or nil and the reason it missed at the latest moment. Each sample pairs where the
--- attacker was with where the target was then, so height and walls are judged at that contact. `sight`,
--- when given, is asked only about moments inside the hitbox, and a blocked one keeps looking.
function Combat.sweepReach(
	cfg: PunchSettings,
	samples: { SweepSample },
	fx: number,
	fz: number,
	side: string?,
	sight: ((index: number) -> boolean)?
): (number?, string?)
	local why: string? = nil
	local blocked = false
	for index, s in samples do
		local inside, reason =
			Combat.inHitbox(cfg, s.ax, s.ay, s.az, fx, fz, s.tx, s.ty, s.tz, side)
		if inside then
			if not sight or sight(index) then
				return index, nil
			end
			blocked = true
		else
			why = reason
		end
	end
	return nil, if blocked then "blocked" else why
end

--- The swing after this one: left hook, right hook, uppercut, then round again.
function Combat.nextSwing(side: string): string
	if side == "Left" then
		return "Right"
	elseif side == "Right" then
		return "Uppercut"
	end
	return "Left"
end

--- The swing to throw now: the next in the order, or back to the first after a pause.
function Combat.comboSwing(
	cfg: PunchSettings,
	nextSide: string,
	now: number,
	lastPunch: number?
): string
	if lastPunch == nil or now - lastPunch >= cfg.ComboResetSeconds then
		return "Left"
	end
	return nextSide
end

--- Was this punch beaten to it? True if its thrower got hit after pressing it.
function Combat.punchCancelled(cfg: PunchSettings, pressedAt: number?, lastHitAt: number?): boolean
	return cfg.HitCancelsPunch and pressedAt ~= nil and lastHitAt ~= nil and lastHitAt >= pressedAt
end

--- A swing's edge, for drawing it: a ring of points around someone at the origin facing
--- -Z. Each is the furthest a target's centre can be in that direction, found by asking
--- inHitbox itself, so a drawing can't disagree with what really hits.
function Combat.hitboxOutline(
	cfg: PunchSettings,
	segments: number,
	side: string?
): { { x: number, z: number } }
	local reach = cfg.Range + cfg.TargetRadius
	local outline = {}
	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		local dirX, dirZ = math.sin(angle), -math.cos(angle)
		local low, high = 0, reach
		for _ = 1, 14 do
			local middle = (low + high) / 2
			if Combat.inHitbox(cfg, 0, 0, 0, 0, -1, dirX * middle, 0, dirZ * middle, side) then
				low = middle
			else
				high = middle
			end
		end
		outline[index] = { x = dirX * low, z = dirZ * low }
	end
	return outline
end

--- The hitbox check for a punch pressed now, using where both will be when it lands, a
--- windup later, at their current speeds. For telling a player when to press. The server
--- still decides the real hit at that moment.
function Combat.inHitboxAtImpact(
	cfg: PunchSettings,
	windup: number,
	ax: number,
	ay: number,
	az: number,
	fx: number,
	fz: number,
	avx: number,
	avz: number,
	tx: number,
	ty: number,
	tz: number,
	tvx: number,
	tvz: number,
	side: string?
): (boolean, string?)
	return Combat.inHitbox(
		cfg,
		ax + avx * windup,
		ay,
		az + avz * windup,
		fx,
		fz,
		tx + tvx * windup,
		ty,
		tz + tvz * windup,
		side
	)
end

--- What a punch does to the one who threw it: a push, as flat x and z, and the share of
--- running speed to keep. A miss slows them. A hit stops them and pushes them back, away
--- from `awayX, awayZ`, the summed directions to everyone hit. `fx, fz` is their facing,
--- used when those directions cancel out.
function Combat.punchAftermath(
	cfg: PunchSettings,
	hits: number,
	awayX: number,
	awayZ: number,
	fx: number,
	fz: number
): (number, number, number)
	if hits <= 0 then
		return 0, 0, cfg.MissSpeedKeep
	end
	local size = math.sqrt(awayX * awayX + awayZ * awayZ)
	local dirX, dirZ = fx, fz
	if size > 0.001 then
		dirX, dirZ = awayX / size, awayZ / size
	end
	return -dirX * cfg.HitRecoilSpeed, -dirZ * cfg.HitRecoilSpeed, cfg.HitSpeedKeep
end

--- May a punch start now? The small tolerance forgives honest inputs arriving
--- bunched up by a network hiccup; it can't make punches faster over time. `extra` is any recovery
--- on top of the cooldown, which is what a whiffed swing owes.
function Combat.cooldownReady(
	cfg: PunchSettings,
	now: number,
	lastPunch: number?,
	extra: number?
): boolean
	if lastPunch == nil then
		return true
	end
	return now - lastPunch >= cfg.Cooldown + (extra or 0) - cfg.CooldownTolerance
end

--- Is a press this early worth remembering? Only one that's just ahead of the swing being ready.
function Combat.pressBuffers(cfg: PunchSettings, now: number, readyAt: number): boolean
	return readyAt - now <= (cfg.BufferSeconds or 0)
end

--- Is a remembered press still fresh enough to throw? It dies quickly, so a swing never comes out
--- after the player stopped asking for one.
function Combat.bufferLive(cfg: PunchSettings, now: number, pressedAt: number?): boolean
	return pressedAt ~= nil and now - pressedAt <= (cfg.BufferSeconds or 0)
end

export type Bucket = { tokens: number, at: number }

--- A token bucket for rate limiting. Holds at most one second's worth of requests.
function Combat.takeToken(bucket: Bucket, now: number, perSecond: number): boolean
	local elapsed = math.max(now - bucket.at, 0)
	bucket.tokens = math.min(bucket.tokens + elapsed * perSecond, perSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--- How fast two characters are approaching each other along the line between them.
--- Positive means getting closer; zero or below means they're apart or separating.
function Combat.closingSpeed(
	ax: number,
	az: number,
	avx: number,
	avz: number,
	bx: number,
	bz: number,
	bvx: number,
	bvz: number
): number
	local dx, dz = bx - ax, bz - az
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 0.001 then
		return 0
	end
	return ((avx - bvx) * dx + (avz - bvz) * dz) / distance
end

export type BumpSettings = {
	BumpPropelShare: number,
	BumpFullClosing: number,
	BumpSoftShare: number,
	BumpFullAdvantage: number,
	BumpEdgeShare: number,
	BumpStaggerShare: number,
}

export type BumpOutcome = {
	knockA: number,
	knockB: number,
	staggerA: number,
	staggerB: number,
}

--- A bump is a shove, well under a propel: `BumpPropelShare` of `propelSpeed` at most, whatever anyone's speed
--- or stagger, and less for a soft one. Both take it. Whoever was going faster shoves a little harder and adds a
--- little more stagger, and takes a little less of both. `knockA` and `staggerA` are what A takes.
function Combat.bumpOutcome(
	cfg: BumpSettings,
	staggerCfg: StaggerSettings,
	propelSpeed: number,
	closing: number,
	avx: number,
	avz: number,
	bvx: number,
	bvz: number
): BumpOutcome
	local speedA = math.sqrt(avx * avx + avz * avz)
	local speedB = math.sqrt(bvx * bvx + bvz * bvz)
	local edge = math.clamp(math.abs(speedA - speedB) / cfg.BumpFullAdvantage, 0, 1)
	local lead = cfg.BumpEdgeShare * edge
	local shareOnA = if speedA >= speedB then 1 - lead else 1 + lead
	local shareOnB = if speedA >= speedB then 1 + lead else 1 - lead
	local hardness = math.clamp(closing / cfg.BumpFullClosing, cfg.BumpSoftShare, 1)
	local base = propelSpeed * cfg.BumpPropelShare * hardness
	local stagger = staggerCfg.PerHit * cfg.BumpStaggerShare
	return {
		knockA = base * shareOnA,
		knockB = base * shareOnB,
		staggerA = math.floor(stagger * shareOnA * 10 + 0.5) / 10,
		staggerB = math.floor(stagger * shareOnB * 10 + 0.5) / 10,
	}
end

--- The line of a collision, as a unit vector: the way A was travelling relative to B. A
--- recoils back along it and B is pushed forward along it. Their positions only decide it
--- if neither is moving, because two fast runners can already have overlapped or passed
--- by the time a bump is noticed, which would throw them the wrong way.
function Combat.bumpDirection(
	ax: number,
	az: number,
	avx: number,
	avz: number,
	bx: number,
	bz: number,
	bvx: number,
	bvz: number
): (number, number)
	local x, z = avx - bvx, avz - bvz
	local size = math.sqrt(x * x + z * z)
	if size < 0.001 then
		x, z = bx - ax, bz - az
		size = math.sqrt(x * x + z * z)
	end
	if size < 0.001 then
		return 1, 0
	end
	return x / size, z / size
end

export type BumpContactSettings = {
	BumpDistance: number,
	BumpMinClosingSpeed: number,
	BumpPairCooldown: number,
	BumpReleaseMargin: number,
	BumpMaxSweep: number,
}

--- What the server remembers about one pair between bump checks.
export type BumpPair = {
	prevX: number?, -- the flat offset from A to B at the last check
	prevZ: number?,
	inContact: boolean,
	lastBump: number?,
}

function Combat.newBumpPair(): BumpPair
	return { prevX = nil, prevZ = nil, inContact = false, lastBump = nil }
end

-- The nearest the line from p to q passes to the origin.
local function nearestOnSegment(px: number, pz: number, qx: number, qz: number): number
	local sx, sz = qx - px, qz - pz
	local length = sx * sx + sz * sz
	local t = if length > 1e-9 then math.clamp(-(px * sx + pz * sz) / length, 0, 1) else 0
	local x, z = px + sx * t, pz + sz * t
	return math.sqrt(x * x + z * z)
end

--- One bump check for a pair. `dx, dz` is the flat offset from A to B now, `rvx, rvz` A's velocity minus
--- B's, as the server measured them. Returns the pair's new state and, if a bump starts now, how hard
--- they closed on each other (nil otherwise).
---
--- A bump is coming into contact, once: continuous contact never bumps again, and only separating past
--- `BumpDistance + BumpReleaseMargin` ends it. Contact that happened entirely between two checks (a fast
--- crossing) counts too. How hard they closed is judged along the line they approached on, the offset at
--- the previous check, because by the moment of overlap the centres can coincide or already be past each
--- other. One moving fighter is enough; matching speeds side by side, or idling inside each other, never
--- bump. A pair bumps at most once per `BumpPairCooldown`.
function Combat.stepBumpPair(
	cfg: BumpContactSettings,
	pair: BumpPair,
	dx: number,
	dz: number,
	rvx: number,
	rvz: number,
	now: number
): (BumpPair, number?)
	local distance = math.sqrt(dx * dx + dz * dz)
	local inside = distance <= cfg.BumpDistance
	local px, pz = pair.prevX, pair.prevZ
	local nextPair: BumpPair = {
		prevX = dx,
		prevZ = dz,
		inContact = pair.inContact,
		lastBump = pair.lastBump,
	}
	if pair.inContact then
		if distance > cfg.BumpDistance + cfg.BumpReleaseMargin then
			nextPair.inContact = false
		end
		return nextPair, nil
	end
	-- A jump between checks bigger than any running or knockback can make is a teleport (a respawn, a
	-- reset), not a pass through each other.
	if px ~= nil and pz ~= nil then
		local sx, sz = dx - px, dz - pz
		if math.sqrt(sx * sx + sz * sz) > cfg.BumpMaxSweep then
			px, pz = nil, nil
		end
	end
	local crossed = false
	if not inside and px ~= nil and pz ~= nil then
		crossed = nearestOnSegment(px, pz, dx, dz) <= cfg.BumpDistance
	end
	if not inside and not crossed then
		return nextPair, nil
	end
	nextPair.inContact = inside
	-- With nothing to compare against (a pair just seen for the first time), it isn't a run into anyone.
	if px == nil or pz == nil then
		return nextPair, nil
	end
	local lineX, lineZ = px, pz
	local lineSize = math.sqrt(lineX * lineX + lineZ * lineZ)
	if lineSize < 0.001 then
		lineX, lineZ, lineSize = dx, dz, distance
	end
	local closing = if lineSize < 0.001
		then math.sqrt(rvx * rvx + rvz * rvz)
		else (rvx * lineX + rvz * lineZ) / lineSize
	if closing < cfg.BumpMinClosingSpeed then
		return nextPair, nil
	end
	if pair.lastBump ~= nil and now - pair.lastBump < cfg.BumpPairCooldown then
		return nextPair, nil
	end
	nextPair.lastBump = now
	return nextPair, closing
end

--- What to do with a bump that has qualified, given the punches between the same two fighters. A punch
--- that lands on this pair is the whole impact, so the bump is dropped; while one is still being decided
--- the bump waits; a punch that misses leaves the bump to happen. It only ever concerns this one pair.
--- `pending` is whether either of the two is mid-swing, `hitSince` whether a punch between them landed
--- close enough to this bump to be the same impact, and `held` whether the bump is still inside its short
--- hold (`BumpHoldSeconds`), the moment a press made just before contact needs to reach the server.
function Combat.bumpPriority(pending: boolean, hitSince: boolean, held: boolean?): string
	if hitSince then
		return "drop"
	elseif pending or held then
		return "wait"
	end
	return "bump"
end

return Combat
