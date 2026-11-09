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
	HurtboxBelow: number,
	HurtboxAbove: number,
	HookBandLow: number,
	HookBandHigh: number,
	UppercutBandLow: number,
	UppercutBandHigh: number,
	SweepStepStuds: number,
	SweepMaxSteps: number,
	ActiveSeconds: number?,
	MissRecovery: number?,
	BufferSeconds: number?,
}

export type KnockbackSettings = {
	BaseSpeed: number,
	SpeedBonusPerStud: number,
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
	local base = knock.BaseSpeed + knock.SpeedBonusPerStud * math.max(attackerSpeed, 0)
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

--- The heights a swing's volume covers, in studs from the attacker's root part: low, high. A hook sweeps across
--- at chest height; an uppercut's fist rises above the head.
function Combat.swingBand(cfg: PunchSettings, side: string?): (number, number)
	if side == "Uppercut" then
		return cfg.UppercutBandLow, cfg.UppercutBandHigh
	end
	return cfg.HookBandLow, cfg.HookBandHigh
end

--- Does the target's hurtbox, at root height `ty`, overlap the swing's height band from a root at `ay`?
function Combat.heightOverlaps(cfg: PunchSettings, ay: number, ty: number, side: string?): boolean
	local low, high = Combat.swingBand(cfg, side)
	return ty - cfg.HurtboxBelow <= ay + high and ty + cfg.HurtboxAbove >= ay + low
end

--- Does this swing reach the target? Facing is a flat unit vector. Returns the answer and, when it's no,
--- why. Line of sight is checked separately by the service.
---
--- The target is its hurtbox: an upright capsule of TargetRadius from HurtboxBelow under its root to
--- HurtboxAbove over it, with no regard for accessories or effects. The attack is a volume spanning the swing's
--- height band (swingBand) over three flat shapes together, and it connects when the hurtbox touches any of them:
--- - the swing's reach, a sector of Range over the arc from swingArc,
--- - a close sector of CloseRange over CloseDegrees either way, for someone at your side,
--- - a contact disc of OverlapRadius, centre to centre, for bodies touching or inside each other.
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
	if not Combat.heightOverlaps(cfg, ay, ty, side) then
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
---
--- With `bare`, it's the attack volume on its own instead, the same rule with the hurtbox's radius taken
--- out: a hit is then exactly that shape touching a hurtbox cylinder, which is how the debug display draws it.
function Combat.hitboxOutline(
	cfg: PunchSettings,
	segments: number,
	side: string?,
	bare: boolean?
): { { x: number, z: number } }
	local rule = cfg
	if bare then
		rule = table.clone(cfg)
		rule.TargetRadius = 0
		rule.OverlapRadius = math.max(cfg.OverlapRadius - cfg.TargetRadius, 0)
	end
	local reach = rule.Range + rule.TargetRadius
	local outline = {}
	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		local dirX, dirZ = math.sin(angle), -math.cos(angle)
		local low, high = 0, reach
		for _ = 1, 14 do
			local middle = (low + high) / 2
			if Combat.inHitbox(rule, 0, 0, 0, 0, -1, dirX * middle, 0, dirZ * middle, side) then
				low = middle
			else
				high = middle
			end
		end
		outline[index] = { x = dirX * low, z = dirZ * low }
	end
	return outline
end

--- A flat facing as an angle, so a turn can be followed smoothly between two server frames. 0 is -Z, the way
--- hitboxOutline draws, and positive turns toward +X.
function Combat.yawOf(fx: number, fz: number): number
	return math.atan2(fx, -fz)
end

function Combat.facingOf(yaw: number): (number, number)
	return math.sin(yaw), -math.cos(yaw)
end

--- Partway from one angle to another, the short way round.
function Combat.yawLerp(from: number, to: number, share: number): number
	local turn = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + turn * share
end

--- How many steps a stretch of the active swing between two server frames is checked in, so that nothing
--- moves further than SweepStepStuds in one: not the attacker, not the target, and not the edge of the reach as
--- the attacker turns. A fast crossing therefore can't pass between two checks, at any frame rate.
function Combat.sweepSteps(
	cfg: PunchSettings,
	attackerMove: number,
	targetMove: number,
	turn: number
): number
	local travel = attackerMove + targetMove + math.abs(turn) * (cfg.Range + cfg.TargetRadius)
	return math.clamp(math.ceil(travel / cfg.SweepStepStuds), 1, cfg.SweepMaxSteps)
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
		staggerA = math.floor(stagger * shareOnA + 0.5),
		staggerB = math.floor(stagger * shareOnB + 0.5),
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

return Combat
