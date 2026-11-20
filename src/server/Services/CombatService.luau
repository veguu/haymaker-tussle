--!strict
-- CombatService - owns punches. A client only ever says "I pressed punch": no target,
-- no strength, no position. The server rate limits it, checks the cooldown on its own
-- clock, then waits out the windup and keeps the swing live for a short active window,
-- checking it every frame, so a body crossing fast can't slip between checks. Each target
-- is reached once per swing, however many frames overlap it.
--
-- Lag compensation: targets are looked up where they were when the attacker saw them,
-- up to a capped rewind. Only targets rewind, never the attacker.
--
-- Punches are resolved together in the order they really strike, by the estimated moment
-- each player's swing lands, never by which server callback came first. Two that strike
-- at effectively the same moment and reach each other go to ClashService instead of one
-- cancelling the other. See Core/Clash.
--
-- THE M1 STRING (2026-11-15; mobile since 2026-11-16, kits-5b). Punches go in a string of Punch.ComboHits (4).
-- The first three STUN briefly (StatusService, Punch.StunSeconds: shorter than the gap to the next punch, so a
-- string is never a true combo and a dash pressed in the stun escapes) and KNOCK the target on by Punch.Push,
-- held in front of the puncher while the stun lasts (lockSpotFor). The puncher runs on, capped at MoveSpeed.
-- Only the last knocks back (Combat.punchStrength: a fixed strength times stagger; speed adds nothing).
-- A miss, or Punch.ComboResetSeconds without a hit, starts the string over. Every swing goes out
-- on the press: there is no holding a punch.
-- IN THE AIR, a punch is the air punch: the client glides toward its aim (Punch.AirReach) through a
-- longer windup (Punch.AirWindup), and it is always the string's FIRST punch. Plain hitbox, no area.
--
-- THE ATTACK SKILLS (R) are held (the user, 2026-11-15): pressing winds up, letting go throws, and it goes
-- by itself after SkillHold.MaxHoldSeconds (3). How long it was held changes NOTHING about it: no
-- charge, no timing. SkillChargeStart (no arguments) marks the wind-up so everyone sees it coming;
-- getting hit while holding cancels it. The hold is the wind-up: after the release a skill strikes after
-- only SkillHold.ReleaseWindup.
--   the Uppercut (UppercutRequest), side "Uppercut"; the Cyclone (CycloneRequest), "Cyclone", all round;
--   the newer kits' skills (KitSwingRequest; Config/Abilities.KitSwings), side = the skill id.
-- Each throws in an arc on its own numbers (Combat.uppercutArc, times the charge). A skill with
-- `Roots` keeps its thrower still through the strike (HT_KickWindup marks it).
-- The launching kick and the air kick that followed it are gone (the user, 2026-11-15).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local punchCfg = GameConfig.Punch
local knockCfg = GameConfig.Knockback
local staggerCfg = GameConfig.Stagger
local clashCfg = GameConfig.Clash
local holdCfg = GameConfig.SkillHold
local KICK_WINDUP_ATTRIBUTE = "HT_KickWindup"
-- On a fighter charging an attack skill: the skill, for everyone else to see the wind-up.
local CHARGE_ATTRIBUTE = "HT_ChargingSkill"
local upperCfg = GameConfig.Uppercut
local upperHitbox = table.clone(punchCfg) :: any
upperHitbox.Range = upperCfg.Range
upperHitbox.UppercutDegrees = upperCfg.Degrees
-- The Cyclone (Tempest's attack skill): the same shape, reaching all the way round.
local cycloneCfg: any = Abilities.Cyclone
local cycloneHitbox = table.clone(punchCfg) :: any
cycloneHitbox.Range = cycloneCfg.Range
cycloneHitbox.UppercutDegrees = cycloneCfg.Degrees
-- The attack skills: their own button, hitbox and cooldown. `skill` is the kit skill a player needs to
-- throw it.
local HEAVY: { [string]: { cfg: any, hitbox: any, skill: string? } } = {
	Uppercut = { cfg = upperCfg, hitbox = upperHitbox, skill = "Uppercut" },
	Cyclone = { cfg = cycloneCfg, hitbox = cycloneHitbox, skill = "Cyclone" },
}
-- The newer kits' attack skills (Config/Abilities.KitSwings: Comet, Glacier, Maul, Breath): each a heavy
-- move of its own, side = its skill id, all asked for through the one KitSwingRequest remote.
local kitSwings = Abilities.KitSwings :: { [string]: any }
for skillId, swing in kitSwings do
	local hitbox = table.clone(punchCfg) :: any
	hitbox.Range = swing.Range
	hitbox.UppercutDegrees = swing.Degrees
	HEAVY[skillId] = { cfg = swing, hitbox = hitbox, skill = skillId }
end
-- The drawing is sent whenever it could be wanted, and each client decides whether to show it.
local SHOW_DEBUG = GameConfig.Debug.ShowHitbox or GameConfig.Training.Enabled

type PunchRecord = {
	bucket: Combat.Bucket,
	lastPunch: number?,
	recovery: number,
	nextSide: string,
	nextStep: number, -- which punch of the string comes next
	lastComboHit: number?, -- when a punch of the string last landed
	refused: number,
	chargeAt: number?, -- when the server saw this player start charging their attack skill
	chargeCancelled: boolean?, -- a hit landed on them while they charged
	lastHeavy: { [string]: number }?, -- when each attack skill was last thrown
}

-- Someone a swing has reached, waiting on whether it's a hit or a clash.
type Contact = {
	target: Model,
	at: Vector3, -- where the target was at the moment of contact
	from: Vector3, -- where the attacker was at that same moment
	decideAt: number,
}

-- A swing from the press to the end of its active window. One per attacker.
type Punch = {
	attacker: Model,
	player: Player?,
	side: string,
	pressedAt: number, -- when they really pressed, as best the server can tell
	impactAt: number, -- when their swing really strikes, on the same estimate
	acceptedAt: number, -- when the server accepted the press; no contact before this counts
	activeFrom: number,
	activeUntil: number,
	checkedTo: number?, -- how far the swept contact check has looked
	ping: number,
	rewind: number,
	wild: boolean,
	sampled: boolean,
	reached: { [Model]: boolean },
	contacts: { Contact },
	reasons: { [Model]: string },
	tested: { [Model]: Vector3 },
	hits: number,
	awayX: number,
	awayZ: number,
	repelled: boolean,
	flat: Vector3?,
	origin: Vector3?,
	cfg: any, -- the hitbox settings for this swing: Punch, or an attack skill's
	step: number, -- a punch's place in the string (1 to ComboHits); 0 for an attack skill
	power: number, -- a multiplier on an attack skill's throw (1 unless something sets it)
	dragging: boolean?, -- this punch already drags someone (only one is dragged)
}

local CombatService = Knit.CreateService({
	Name = "CombatService",
})

local records: { [Player]: PunchRecord } = {}
local lastHitAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local punches: { [Model]: Punch } = {}
local botSides: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local botLastSwing: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local botSteps: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local botLastComboHit: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
-- When a punch last landed between two fighters, either way round. A bump on the same pair at the same
-- impact gives way to it (KnockbackService).
local pairHits: { [Model]: { [Model]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function notePairHit(a: Model, b: Model, now: number)
	pairHits[a] = pairHits[a] or setmetatable({}, { __mode = "k" }) :: any
	pairHits[b] = pairHits[b] or setmetatable({}, { __mode = "k" }) :: any
	pairHits[a][b] = now
	pairHits[b][a] = now
end

local function trace(message: string)
	if workspace:GetAttribute("HaymakerCombatDebug") then
		print(`[Combat] {message}`)
	end
end

local function recordFor(player: Player): PunchRecord
	local record = records[player]
	if not record then
		record = {
			bucket = { tokens = punchCfg.RequestsPerSecondLimit, at = os.clock() },
			lastPunch = nil,
			recovery = 0,
			nextSide = "Right",
			nextStep = 1,
			refused = 0,
		}
		records[player] = record
	end
	return record
end

--- A kit skill that is not a swing lands on `target` (a blast, a slam, a cast: AbilityService and
--- SkillCastService decide who it reaches). `away` is the flat unit way they are thrown, `strength`
--- the speed, `up` the lift. It is a hit like any other: refused between fighters who may not fight,
--- it adds stagger and is multiplied by it, credits the attacker, breaks ice and is shrugged off by
--- armour. Returns whether it landed.
function CombatService:SkillHit(
	attacker: Model,
	target: Model,
	away: Vector3,
	strength: number,
	up: number
): boolean
	if
		target == attacker
		or not Combatants.isAlive(target)
		or not Combatants.isAlive(attacker)
		or not self:CanFight(attacker, target)
	then
		return false
	end
	local stagger = Knit.GetService("StaggerService")
	local before = stagger:Get(target)
	local out = strength * Combat.staggerMultiplier(staggerCfg, before)
	local lift = up
	stagger:AddHit(target)
	self:MarkHit(target)
	notePairHit(attacker, target, os.clock())
	Knit.GetService("RoundService"):NoteHit(target, attacker)
	if Knit.GetService("StatusService"):Shatter(target) then
		local bonus = (Abilities.KitMoves :: any).Frostbite.Freeze.ShatterBonus
		out *= bonus
		lift *= bonus
	end
	local armored = Knit.GetService("AbilityService"):TakeArmor(target)
	if armored then
		out *= armored
		lift *= armored
	end
	Knit.GetService("KnockbackService"):Launch(target, away.X * out, away.Z * out, lift, lift)
	local ultimate = Knit.GetService("UltimateService")
	ultimate:Gain(attacker, GameConfig.Ultimate.SkillHitGain)
	ultimate:OpenWindow(attacker, target)
	self._hitConfirmed:FireAllClients(attacker, target, math.floor(out))
	trace(
		`{attacker.Name} skill hit {target.Name}: strength {math.floor(out)}, lift {math.floor(lift)}`
	)
	return true
end

--- May these two fight each other right now? The round step adds its own rule for the 1v1 arena.
function CombatService:CanFight(a: Model, b: Model): boolean
	-- Nobody touches either side of an ultimate while it plays.
	local ultimate = Knit.GetService("UltimateService")
	if ultimate:IsBusy(a) or ultimate:IsBusy(b) then
		return false
	end
	local round = Knit.GetService("RoundService"):AllowsFight(a, b)
	if round ~= nil then
		return round
	end
	local lobby = Knit.GetService("LobbyService"):AllowsFight(a, b)
	if lobby ~= nil then
		return lobby
	end
	return Knit.GetService("TrainingService"):AllowsFight(a, b)
end

-- Is anything solid between these two points? Characters don't count.
local function hasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return workspace:Raycast(from, to - from, params) == nil
end

-- Is any of the target's body in view? One ray to its centre would call a half-covered body blocked.
local function bodyInView(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	if hasLineOfSight(from, to, ignore) then
		return true
	end
	local line = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if line.Magnitude < 0.01 then
		return false
	end
	local side = Vector3.new(-line.Z, 0, line.X).Unit * punchCfg.TargetRadius
	return hasLineOfSight(from, to + side, ignore) or hasLineOfSight(from, to - side, ignore)
end

local function flatLook(root: BasePart): Vector3?
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 0.001 then flat.Unit else nil
end

-- Tells the one who threw it how it went, so their client can stop a swing the server has
-- refused or that got beaten, and owe the recovery of a whiff. Everyone needs to see a beaten
-- swing stop, or it looks like a punch passing straight through someone.
local function sendResult(self: any, punch: Punch, kind: string)
	if kind == "cancelled" or kind == "clash" then
		self._punchResult:FireAllClients(punch.attacker, kind)
	elseif punch.player then
		self._punchResult:FireClient(punch.player, punch.attacker, kind)
	end
end

local function sendDebug(self: any, punch: Punch, phase: string)
	if not SHOW_DEBUG or not punch.origin or not punch.flat then
		return
	end
	local verdicts = {}
	if phase == "end" then
		for target, why in punch.reasons do
			table.insert(verdicts, { target = target, why = why, at = punch.tested[target] })
		end
	end
	self._punchDebug:FireAllClients(
		punch.attacker,
		phase,
		punch.side,
		punch.origin,
		punch.flat,
		verdicts,
		punch.hits
	)
end

-- How far in front each held target is, per puncher, fixed when the hold began (Combat.lockDistance).
local holdAhead: { [Model]: { by: Model, ahead: number } } = setmetatable({}, { __mode = "k" }) :: any

-- Where a stunning punch holds its target (2026-11-16, kits-5b; the user: M1s are mobile, "the target should be
-- locked in front of the player", and "each hit should knockback the enemy by a small amount but it wont push the
-- player who hit them ... like dribbling a soccer ball"). Picked HERE, once per punch, from the puncher's own spot
-- and facing: as far in front as the target already was (kept between LockMinDistance and LockMaxDistance) plus
-- the knock (Combat.hitPush, Punch.Push), clipped at a wall. The target's body glides there during the short stun
-- (Combat.lockFollow); the puncher is never moved. Nil when either body is missing.
local function lockSpotFor(attacker: Model, target: Model): Vector3?
	local from = Combatants.rootOf(attacker)
	local body = Combatants.rootOf(target)
	if not from or not body then
		return nil
	end
	local look = Vector3.new(from.CFrame.LookVector.X, 0, from.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local held = holdAhead[target]
	local still = held and held.by == attacker and target:FindFirstChild("HT_DraggedBy") ~= nil
	local ahead = if still and held
		then held.ahead
		else Combat.lockDistance(
			punchCfg,
			Vector3.new(body.Position.X - from.Position.X, 0, body.Position.Z - from.Position.Z).Magnitude
		)
	holdAhead[target] = { by = attacker, ahead = ahead }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local reach = punchCfg.Push + punchCfg.LockDistance + 2 * punchCfg.LockBodyRadius
	local wall = workspace:Raycast(from.Position, look * reach, params)
	local push = Combat.hitPush(punchCfg, if wall then wall.Distance else nil)
	local x, z =
		Combat.lockSpot(punchCfg, from.Position.X, from.Position.Z, look.X, look.Z, ahead + push)
	local toward = Vector3.new(x - from.Position.X, 0, z - from.Position.Z)
	if toward.Magnitude > 0.01 then
		local hit = workspace:Raycast(
			from.Position,
			toward.Unit * (toward.Magnitude + punchCfg.LockBodyRadius),
			params
		)
		x, z = Combat.clipLock(
			punchCfg,
			from.Position.X,
			from.Position.Z,
			x,
			z,
			if hit then hit.Distance else nil
		)
	end
	return Vector3.new(x, body.Position.Y, z)
end

-- A swing lands on someone. Only ever runs once per target per swing.
local function landHit(self: any, punch: Punch, target: Model, at: Vector3, from: Vector3)
	local stagger = Knit.GetService("StaggerService")
	local knockback = Knit.GetService("KnockbackService")
	local flat = punch.flat :: Vector3
	local before = stagger:Get(target)
	local strength = Combat.punchStrength(knockCfg, staggerCfg, before)
	stagger:AddHit(target)
	self:MarkHit(target)
	notePairHit(punch.attacker, target, os.clock())
	Knit.GetService("RoundService"):NoteHit(target, punch.attacker)
	-- Away from where the attacker was at the contact; inside each other, the way the punch was thrown.
	local awayX, awayZ = Combat.punchAway(punchCfg, at.X - from.X, at.Z - from.Z, flat.X, flat.Z)
	local away = Vector3.new(awayX, 0, awayZ)
	punch.awayX += away.X
	punch.awayZ += away.Z
	local up, airUp = Combat.swingLift(knockCfg, punch.side, strength)
	local heavy = HEAVY[punch.side]
	if heavy then
		-- An attack skill: an arc on its own numbers, times the charge and the target's stagger.
		strength, up =
			Combat.uppercutArc(heavy.cfg, Combat.staggerMultiplier(staggerCfg, before), punch.power)
		airUp = up
	elseif not Combat.isFinisher(punchCfg :: any, punch.step) then
		-- A punch before the last of the string: no knockback. They're stunned and DRAGGED: whoever moves
		-- their body (their own client, or DummyService) keeps them in front of the puncher for as long
		-- as the stun lasts (Combat.lockSpot, LOCKED in front), so a string thrown on the run carries them.
		-- Only the first fighter a punch reaches is dragged: everyone dragged to the one spot in front of the
		-- puncher piled up and stun-locked each other (seen with bots, 2026-11-15). Others are stunned in place.
		local drags = not punch.dragging
		punch.dragging = true
		Knit.GetService("StatusService"):Stun(
			target,
			punchCfg.StunSeconds,
			if drags then punch.attacker else nil,
			if drags then lockSpotFor(punch.attacker, target) else nil
		)
		Knit.GetService("UltimateService"):Gain(punch.attacker, GameConfig.Ultimate.StunHitGain)
		self._hitConfirmed:FireAllClients(punch.attacker, target, 0, punch.step)
		punch.hits += 1
		punch.reasons[target] = "hit"
		trace(`{punch.attacker.Name} punch {punch.step} stunned {target.Name}`)
		return
	end
	-- Frozen in ice (the Frost kit's Frostbite): the hit breaks it, and throws them harder for it.
	if Knit.GetService("StatusService"):Shatter(target) then
		local bonus = (Abilities.KitMoves :: any).Frostbite.Freeze.ShatterBonus
		strength *= bonus
		up *= bonus
		airUp *= bonus
	end
	-- Mid-Charge (the Bruiser's Q), the first hit is mostly shrugged off.
	local armored = Knit.GetService("AbilityService"):TakeArmor(target)
	if armored then
		strength *= armored
		up *= armored
		airUp *= armored
	end
	-- Whatever stun the string left on them ends: they fly.
	Knit.GetService("StatusService"):Unstun(target)
	knockback:Launch(target, away.X * strength, away.Z * strength, up, airUp)
	-- The ultimate meter: a string's last punch or an attack skill. Either opens the follow-up window.
	local ultimate = Knit.GetService("UltimateService")
	ultimate:Gain(
		punch.attacker,
		if heavy then GameConfig.Ultimate.SkillHitGain else GameConfig.Ultimate.FinisherGain
	)
	ultimate:OpenWindow(punch.attacker, target)
	self._hitConfirmed:FireAllClients(punch.attacker, target, math.floor(strength), punch.step)
	punch.hits += 1
	punch.reasons[target] = "hit"
	trace(
		`{punch.attacker.Name} {punch.side} hit {target.Name}: strength {math.floor(strength)}, power {punch.power}, stagger {before} before`
	)
end

-- The swing's window is over, and everyone it reached has been decided.
local function finishPunch(self: any, punch: Punch)
	punches[punch.attacker] = nil
	for target, why in punch.reasons do
		if why ~= "hit" then
			trace(`{punch.attacker.Name} miss {target.Name}: {why}`)
		end
	end
	trace(`{punch.attacker.Name} {punch.side} punch resolved: {punch.hits} hit(s)`)
	sendDebug(self, punch, "end")

	local record = punch.player and records[punch.player]
	local now = os.clock()
	if record then
		record.recovery = if punch.hits > 0 then 0 else punchCfg.MissRecovery
	end
	-- The string moves on after a hit and starts over after a miss. Attack skills leave it alone.
	if punch.step > 0 then
		local after = Combat.comboAfter(punchCfg :: any, punch.step, punch.hits)
		if record then
			record.nextStep = after
			if punch.hits > 0 then
				record.lastComboHit = now
			end
		elseif not punch.player then
			botSteps[punch.attacker] = after
			if punch.hits > 0 then
				botLastComboHit[punch.attacker] = now
			end
		end
	end
	sendResult(self, punch, if punch.hits > 0 then "hit" else "miss")
	if punch.hits > 0 then
		Knit.GetService("StaggerService"):Relieve(punch.attacker)
		-- It landed: the endlag is cut from the whiff's to the hit's.
		Knit.GetService("EndlagService"):Landed(
			punch.attacker,
			if HEAVY[punch.side] then punch.side else "Punch",
			punch.acceptedAt,
			os.clock()
		)
	end
	-- The puncher pays either way: a miss slows them, a hit stops them and pushes them back. A
	-- repel has already thrown them, which this would otherwise wipe out.
	-- A heavy move that doesn't root (the uppercut) costs nothing either: its thrower keeps their momentum.
	-- Nor does any M1 (2026-11-16): the puncher keeps running (capped at Punch.MoveSpeed by their own
	-- movement) and is never pushed by their own hit.
	local heavy = HEAVY[punch.side]
	local keepsMomentum = (heavy ~= nil and heavy.cfg.Roots == false)
		or (heavy == nil and punch.step > 0)
	if not punch.repelled and not keepsMomentum then
		local flat = punch.flat or Vector3.new(0, 0, -1)
		local pushX, pushZ, keep =
			Combat.punchAftermath(punchCfg, punch.hits, punch.awayX, punch.awayZ, flat.X, flat.Z)
		Knit.GetService("KnockbackService"):Launch(punch.attacker, pushX, pushZ, 0, 0, keep, true)
	end
end

-- Could this swing reach this target right now? Fills in why not.
local function reaches(
	punch: Punch,
	origin: Vector3,
	flat: Vector3,
	at: Vector3,
	everyone: { Instance }
): (boolean, string?)
	local inside, why = Combat.inHitbox(
		punch.cfg,
		origin.X,
		origin.Y,
		origin.Z,
		flat.X,
		flat.Z,
		at.X,
		at.Y,
		at.Z,
		punch.side
	)
	if not inside then
		return false, why
	end
	if not bodyInView(origin, at, everyone) then
		return false, "blocked"
	end
	return true, nil
end

-- One frame of a live swing: who has it just reached? It looks back over every moment since the last
-- look (Combat.contactWindow), not only this frame, using where the server saw both bodies at each of
-- those moments: the attacker as it was, the target rewound for what the attacker saw. So contact
-- between two server frames counts, and so does a crossing in the short grace before the active frames.
local function sample(self: any, punch: Punch, root: BasePart, now: number)
	local flat = flatLook(root)
	if not flat then
		return
	end
	punch.flat = flat
	punch.origin = root.Position
	if not punch.sampled then
		punch.sampled = true
		sendDebug(self, punch, "active")
	end
	if punch.wild then
		return
	end
	local from, to = Combat.contactWindow(
		punchCfg,
		punch.acceptedAt,
		punch.activeFrom,
		punch.activeUntil,
		punch.checkedTo,
		now
	)
	if not from or not to then
		return
	end
	punch.checkedTo = to
	local audit = Knit.GetService("SpeedAuditService")
	local clash = Knit.GetService("ClashService")
	local everyone: { Instance } = CollectionService:GetTagged(Combatants.TAG)
	local times = Combat.sweepTimes(from, to, punchCfg.SweepStep)
	local attackerAt: { Vector3? } = {}
	for index, moment in times do
		attackerAt[index] = audit:PositionAtTime(punch.attacker, moment)
	end
	-- The list holds each target once, and `reached` keeps it to once across the whole window.
	for _, target in Combatants.all() do
		if
			target == punch.attacker
			or punch.reached[target]
			or not self:CanFight(punch.attacker, target)
		then
			continue
		end
		local targetPlayer = Combatants.playerOf(target)
		-- The bot leaves players alone until they finish the tutorial.
		if
			not punch.player
			and targetPlayer
			and not Knit.GetService("TutorialService"):IsReady(targetPlayer)
		then
			continue
		end
		local samples: { Combat.SweepSample } = {}
		local seen: { { Vector3 } } = {}
		for index, moment in times do
			local a = attackerAt[index]
			local b = audit:PositionAtTime(target, moment - punch.rewind)
			if a and b then
				table.insert(
					samples,
					{ ax = a.X, ay = a.Y, az = a.Z, tx = b.X, ty = b.Y, tz = b.Z }
				)
				table.insert(seen, { a, b })
			end
		end
		if #samples == 0 then
			continue
		end
		punch.tested[target] = seen[#seen][2]
		-- The swing's own hitbox (punch.cfg): a heavy move's reach and arc, not the plain punch's.
		local found, why = Combat.sweepReach(
			punch.cfg,
			samples,
			flat.X,
			flat.Z,
			punch.side,
			function(index: number): boolean
				return bodyInView(seen[index][1], seen[index][2], everyone)
			end
		)
		if not found then
			punch.reasons[target] = why or "range"
			continue
		end
		local hitFrom, at = seen[found][1], seen[found][2]
		punch.reached[target] = true
		punch.reasons[target] = "reached"
		-- A validated attack on someone in a clash bounces off. It does nothing else.
		if clash:IsIn(target) then
			punch.reasons[target] = "repelled"
			if clash:Repel(punch.attacker, target) then
				punch.repelled = true
			end
			continue
		end
		local targetPing = if targetPlayer then targetPlayer:GetNetworkPing() else 0
		table.insert(punch.contacts, {
			target = target,
			at = at,
			from = hitFrom,
			decideAt = os.clock()
				+ Clash.holdSeconds(clashCfg, punchCfg.Windup, punch.ping, targetPing),
		})
	end
end

-- Do these two punches qualify as a clash? Their strikes have to be at the same moment, on the same
-- rule for everyone, and the other swing has to really reach back. If so, both swings end here.
local function tryClash(self: any, punch: Punch, target: Model): boolean
	local other = punches[target]
	if not other or other.wild or punch.wild or HEAVY[punch.side] or HEAVY[other.side] then
		return false
	end
	if not Clash.simultaneous(clashCfg, punch.impactAt, other.impactAt, punch.ping, other.ping) then
		return false
	end
	local clash = Knit.GetService("ClashService")
	if not clash:CanPair(punch.attacker, target) then
		return false
	end
	local otherRoot = Combatants.rootOf(target)
	local otherFlat = otherRoot and flatLook(otherRoot)
	local at = Knit.GetService("SpeedAuditService"):PositionAt(punch.attacker, other.rewind)
	if not otherRoot or not otherFlat or not at then
		return false
	end
	local everyone: { Instance } = CollectionService:GetTagged(Combatants.TAG)
	local inside, why = reaches(other, otherRoot.Position, otherFlat, at, everyone)
	if not inside then
		trace(
			`{punch.attacker.Name} and {target.Name} no clash: {target.Name} doesn't reach back, {why}`
		)
		return false
	end
	punches[punch.attacker] = nil
	punches[target] = nil
	sendResult(self, punch, "clash")
	sendResult(self, other, "clash")
	clash:Begin(punch.attacker, target)
	return true
end

local function hasContactOn(punch: Punch, target: Model): boolean
	for _, contact in punch.contacts do
		if contact.target == target then
			return true
		end
	end
	return false
end

-- Settles everyone this swing has reached. Returns false if the swing has ended here.
local function settleContacts(self: any, punch: Punch, now: number): boolean
	local clash = Knit.GetService("ClashService")
	for index = #punch.contacts, 1, -1 do
		local contact = punch.contacts[index]
		local target = contact.target
		if tryClash(self, punch, target) then
			return false
		end
		-- An earlier swing of theirs that has reached us, still on hold, goes first and beats this one.
		local other = punches[target]
		local beaten = other
			and other.impactAt < punch.impactAt
			and hasContactOn(other, punch.attacker)
		if now >= contact.decideAt and not beaten then
			table.remove(punch.contacts, index)
			if clash:IsIn(target) then
				punch.reasons[target] = "repelled"
				if clash:Repel(punch.attacker, target) then
					punch.repelled = true
				end
			elseif Combatants.isAlive(target) then
				landHit(self, punch, target, contact.at, contact.from)
			end
		end
	end
	return true
end

local function stepPunch(self: any, punch: Punch, now: number)
	local attacker = punch.attacker
	if Combat.punchCancelled(punchCfg, punch.pressedAt, lastHitAt[attacker]) then
		trace(`{attacker.Name} {punch.side} punch cancelled: hit first`)
		punches[attacker] = nil
		sendResult(self, punch, "cancelled")
		return
	end
	if
		(punch.player and punch.player.Character ~= attacker) or not Combatants.isAlive(attacker)
	then
		trace(`{attacker.Name} punch dropped: attacker gone at impact`)
		punches[attacker] = nil
		return
	end
	-- A swing thrown just before being caught by a kick doesn't land from inside it.
	if attacker:GetAttribute("HT_Air") == "hold" or attacker:GetAttribute("HT_Stunned") ~= nil then
		trace(`{attacker.Name} {punch.side} punch dropped: caught by a kick`)
		punches[attacker] = nil
		sendResult(self, punch, "cancelled")
		return
	end
	local root = Combatants.rootOf(attacker)
	if not root then
		punches[attacker] = nil
		return
	end
	-- A slow frame can't skip a swing, or the end of one: looking continues until the whole window has
	-- been looked at, however late the frame.
	if
		now >= punch.activeFrom
		and (not punch.sampled or (punch.checkedTo or -math.huge) < punch.activeUntil)
	then
		sample(self, punch, root, now)
	end
	if not settleContacts(self, punch, now) then
		return
	end
	if now >= punch.activeUntil and #punch.contacts == 0 then
		finishPunch(self, punch)
	end
end

-- Earliest strike first, so who's beaten by whom comes from when the swings land, whatever order
-- the server happened to hear about them.
local function stepAll(self: any)
	if next(punches) == nil then
		return
	end
	local now = os.clock()
	local order: { Punch } = {}
	for _, punch in punches do
		table.insert(order, punch)
	end
	table.sort(order, function(a: Punch, b: Punch)
		if a.impactAt ~= b.impactAt then
			return a.impactAt < b.impactAt
		end
		return a.attacker.Name < b.attacker.Name
	end)
	for _, punch in order do
		if punches[punch.attacker] == punch then
			stepPunch(self, punch, now)
		end
	end
end

-- Starts a swing. A new swing on the same attacker closes the old one first.
local function startPunch(
	self: any,
	attacker: Model,
	player: Player?,
	side: string,
	now: number,
	windup: number,
	ping: number,
	wild: boolean,
	cfg: any?,
	step: number?,
	power: number?
)
	local old = punches[attacker]
	if old then
		finishPunch(self, old)
	end
	local oneWay = math.clamp(ping / 2, 0, punchCfg.MaxRewindSeconds)
	punches[attacker] = {
		attacker = attacker,
		player = player,
		side = side,
		pressedAt = now - oneWay,
		impactAt = now - oneWay + windup,
		acceptedAt = now,
		activeFrom = now + windup,
		activeUntil = now + windup + punchCfg.ActiveSeconds,
		ping = ping,
		rewind = if player
			then math.clamp(ping + punchCfg.InterpolationSeconds, 0, punchCfg.MaxRewindSeconds)
			else 0,
		wild = wild,
		sampled = false,
		reached = {},
		contacts = {},
		reasons = {},
		tested = {},
		hits = 0,
		awayX = 0,
		awayZ = 0,
		repelled = false,
		cfg = cfg or punchCfg,
		step = step or 0,
		power = power or 1,
	}
end

--- Someone was just hit: any punch they're winding up is beaten, and a kick in progress ends.
--- Is either of these two mid-swing, with the swing still to be decided? A bump between them waits on it.
function CombatService:PunchPendingBetween(a: Model, b: Model): boolean
	local pa, pb = punches[a], punches[b]
	return (pa ~= nil and not pa.wild) or (pb ~= nil and not pb.wild)
end

--- Did a punch land between these two, either way round, at or after `since` (os.clock())?
function CombatService:HitBetweenSince(a: Model, b: Model, since: number): boolean
	local forA = pairHits[a]
	local at = forA and forA[b]
	return at ~= nil and at >= since
end

function CombatService:MarkHit(target: Model)
	lastHitAt[target] = os.clock()
	-- Getting hit cancels an attack skill being charged.
	local hitPlayer = Combatants.playerOf(target)
	local hitRecord = hitPlayer and records[hitPlayer]
	if hitRecord and hitRecord.chargeAt then
		hitRecord.chargeAt = nil
		hitRecord.chargeCancelled = true
		target:SetAttribute(CHARGE_ATTRIBUTE, nil)
	end
	Knit.GetService("KickService"):Cancel(target)
end

--- Sets a fighter's punch cooldown going, as if they'd just thrown one, with nothing extra owed. A
--- clash ends like this for both, so nobody comes out of one with a free swing.
function CombatService:PunchLockout(model: Model)
	local now = os.clock()
	local player = Combatants.playerOf(model)
	local record = player and records[player]
	if record then
		record.lastPunch = now
		record.recovery = 0
	end
	botLastSwing[model] = now
end

--- Tells everyone a hit landed, for the things only clients draw.
function CombatService:ConfirmHit(attacker: Model, target: Model, strength: number)
	self._hitConfirmed:FireAllClients(attacker, target, math.floor(strength))
end

--- A punch by the test bot, which its own brain decides to throw. The same hit rules as a player's,
--- but slower to land so it can be dodged. A `wild` swing goes wide and hits nobody, and pays for the
--- miss like anyone else.
function CombatService:PunchAs(model: Model, wild: boolean?)
	local now = os.clock()
	-- A stunned bot can't punch any more than a stunned player can.
	if model:GetAttribute("HT_Stunned") ~= nil then
		return
	end
	local side = Combat.comboSwing(punchCfg, botSides[model] or "Right", now, botLastSwing[model])
	local step = Combat.comboStep(punchCfg :: any, botSteps[model], now, botLastComboHit[model])
	botLastSwing[model] = now
	botSides[model] = Combat.nextSwing(side)
	self._punchStarted:FireAllClients(model, side, step)
	startPunch(
		self,
		model,
		nil,
		side,
		now,
		punchCfg.Windup + GameConfig.TestBot.ExtraWindup,
		0,
		wild == true,
		nil,
		step
	)
end

function CombatService:KnitInit()
	self._punchRequest = Net.server("PunchRequest")
	self._skillChargeStart = Net.server("SkillChargeStart")
	self._uppercutRequest = Net.server("UppercutRequest")
	self._cycloneRequest = Net.server("CycloneRequest")
	self._kitSwingRequest = Net.server("KitSwingRequest")
	self._punchStarted = Net.server("PunchStarted")
	self._hitConfirmed = Net.server("HitConfirmed")
	self._punchResult = Net.server("PunchResult")
	self._punchDebug = Net.server("PunchDebug")
	-- Server-side: a player's ordinary punch was accepted (attacker, player). The lobby's bell listens (2026-11-20).
	self.PunchThrown = Instance.new("BindableEvent")
end

function CombatService:KnitStart()
	-- The checks every swing request shares. Returns the attacker, or nil after saying why not. Any
	-- argument the request carried has already been taken off: what is left must be nothing.
	local function acceptable(player: Player, record: PunchRecord, now: number, ...): Model?
		-- Rate limit before anything else, so a flood costs almost nothing.
		if not Combat.takeToken(record.bucket, now, punchCfg.RequestsPerSecondLimit) then
			record.refused += 1
			return nil
		end
		if select("#", ...) ~= 0 then
			record.refused += 1
			trace(`{player.Name} refused: unexpected arguments`)
			return nil
		end
		local attacker = player.Character
		if not attacker or not Combatants.isAlive(attacker) then
			trace(`{player.Name} refused: no living character`)
			return nil
		end
		-- Held on a spawn through a round's countdown.
		if attacker:GetAttribute("HT_RoundHold") then
			trace(`{player.Name} refused: round countdown`)
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		-- In an ultimate (either side of it): nothing else.
		if Knit.GetService("UltimateService"):IsBusy(attacker) then
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		-- Stunned (a punch of someone's string, or ice): nothing at all.
		if attacker:GetAttribute("HT_Stunned") ~= nil then
			trace(`{player.Name} refused: stunned`)
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		if Knit.GetService("KickService"):IsBusy(attacker) then
			trace(`{player.Name} refused: mid-kick`)
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		if not Combat.cooldownReady(punchCfg, now, record.lastPunch, record.recovery) then
			record.refused += 1
			trace(`{player.Name} refused: cooldown`)
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		-- Still recovering from the last move (Core/Endlag): nothing new starts.
		if Knit.GetService("EndlagService"):IsBusy(attacker, now) then
			record.refused += 1
			trace(`{player.Name} refused: endlag`)
			self._punchResult:FireClient(player, attacker, "refused")
			return nil
		end
		return attacker
	end

	-- Is this body off the floor? A short ray down from its root, ignoring every fighter.
	local function airborne(attacker: Model): boolean
		local root = Combatants.rootOf(attacker)
		if not root then
			return false
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
		params.IgnoreWater = true
		return workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), params) == nil
	end

	self._punchRequest.OnServerEvent:Connect(function(player: Player, ...)
		local record = recordFor(player)
		local now = os.clock()
		local attacker = acceptable(player, record, now, ...)
		if not attacker then
			return
		end
		-- Everything is marked before the wait, so a second request can't pass the same check.
		local side = Combat.comboSwing(punchCfg, record.nextSide, now, record.lastPunch)
		local air = airborne(attacker)
		-- In the air it is the air punch, always the string's first.
		local step = if air
			then 1
			else Combat.comboStep(punchCfg :: any, record.nextStep, now, record.lastComboHit)
		local windup = if air then punchCfg.AirWindup else punchCfg.Windup
		record.lastPunch = now
		record.recovery = 0
		record.nextSide = Combat.nextSwing(side)
		self._punchStarted:FireAllClients(attacker, side, step)
		self.PunchThrown:Fire(attacker, player)
		trace(`{player.Name} {side} thrown, step {step}{if air then " (air)" else ""}`)
		Knit.GetService("EndlagService")
			:Start(attacker, "Punch", now, windup + punchCfg.ActiveSeconds)
		startPunch(
			self,
			attacker,
			player,
			side,
			now,
			windup,
			player:GetNetworkPing(),
			false,
			nil,
			step
		)
	end)

	-- "I've started charging my attack skill": the start of the hold, on the server's clock.
	self._skillChargeStart.OnServerEvent:Connect(function(player: Player, ...)
		local record = recordFor(player)
		local now = os.clock()
		if not Combat.takeToken(record.bucket, now, punchCfg.RequestsPerSecondLimit) then
			record.refused += 1
			return
		end
		local attacker = player.Character
		if
			select("#", ...) ~= 0
			or not attacker
			or not Combatants.isAlive(attacker)
			or attacker:GetAttribute("HT_Stunned") ~= nil
		then
			return
		end
		record.chargeAt = now
		record.chargeCancelled = nil
		-- Everyone else sees the wind-up: the swing of the skill this kit gives, drawn back and held.
		local abilities = Knit.GetService("AbilityService")
		local book: any = Abilities
		local kitAttack = (book.Kits[abilities:KitOf(player)] or book.Kits.Base).attack.id
		if HEAVY[kitAttack] then
			attacker:SetAttribute(CHARGE_ATTRIBUTE, kitAttack)
			-- Never left showing: a charge can't outlast its longest hold.
			task.delay(holdCfg.MaxHoldSeconds + 0.5, function()
				if record.chargeAt == now and attacker.Parent then
					attacker:SetAttribute(CHARGE_ATTRIBUTE, nil)
				end
			end)
		end
	end)

	-- An attack skill released: its own cooldown on top of the punch's.
	local function heavy(side: string, player: Player, ...)
		local move = HEAVY[side]
		local record = recordFor(player)
		local now = os.clock()
		local chargeAt, cancelled = record.chargeAt, record.chargeCancelled
		record.chargeAt, record.chargeCancelled = nil, nil
		if player.Character then
			player.Character:SetAttribute(CHARGE_ATTRIBUTE, nil)
		end
		local attacker = acceptable(player, record, now, ...)
		if not attacker then
			return
		end
		-- Hit while charging: the charge is gone, and nothing is thrown.
		if cancelled then
			trace(`{player.Name} {side} cancelled: hit while charging`)
			self._punchResult:FireClient(player, attacker, "cancelled")
			return
		end
		local lastHeavy = record.lastHeavy or {}
		record.lastHeavy = lastHeavy
		local last = lastHeavy[side]
		if
			last
			and now - last < move.cfg.Cooldown - punchCfg.CooldownTolerance
			and player:GetAttribute("HT_TrainingFree") ~= true -- free practice: no cooldown
		then
			record.refused += 1
			trace(`{player.Name} refused: {side} cooldown`)
			self._punchResult:FireClient(player, attacker, "refused")
			return
		end
		lastHeavy[side] = now
		record.lastPunch = now
		record.recovery = 0
		-- How long it was held changes nothing about it (the user, 2026-11-15: no timing).
		local held = if chargeAt then now - chargeAt else 0
		local windup = holdCfg.ReleaseWindup
		if move.cfg.Roots ~= false then
			attacker:SetAttribute(KICK_WINDUP_ATTRIBUTE, true)
			task.delay(windup + move.cfg.RootAfter, function()
				if attacker.Parent then
					attacker:SetAttribute(KICK_WINDUP_ATTRIBUTE, nil)
				end
			end)
		end
		self._punchStarted:FireAllClients(attacker, side, 0, windup)
		trace(`{player.Name} {side} released after {string.format("%.2f", held)} s`)
		local cast = move.cfg.Cast
		Knit.GetService("EndlagService"):Start(
			attacker,
			side,
			now,
			windup + punchCfg.ActiveSeconds + (if cast then cast.Lead or 0 else 0)
		)
		-- A swing with a cast is not a swing: what happens after the windup is the cast's. The hold was the
		-- wind-up, so it strikes after only the release windup.
		if cast then
			local released = table.clone(move.cfg)
			released.Windup = windup
			Knit.GetService("SkillCastService"):Start(attacker, side, released)
			return
		end
		startPunch(
			self,
			attacker,
			player,
			side,
			now,
			windup,
			player:GetNetworkPing(),
			false,
			move.hitbox,
			0
		)
	end
	-- A kit's attack skill: only someone wearing a kit with it can throw it.
	local function kitHeavy(side: string, player: Player, ...)
		local skill = HEAVY[side].skill
		if skill and not Knit.GetService("AbilityService"):HasSkill(player, skill) then
			trace(`{player.Name} refused: no {skill} in their kit`)
			return
		end
		heavy(side, player, ...)
	end
	self._uppercutRequest.OnServerEvent:Connect(function(player: Player, ...)
		kitHeavy("Uppercut", player, ...)
	end)
	self._cycloneRequest.OnServerEvent:Connect(function(player: Player, ...)
		kitHeavy("Cyclone", player, ...)
	end)
	-- A newer kit's attack skill. The request names nothing: the server looks up which swing the kit
	-- this player is wearing gives, if any.
	self._kitSwingRequest.OnServerEvent:Connect(function(player: Player, ...)
		local side = Knit.GetService("AbilityService"):KitSwingOf(player)
		if side and HEAVY[side] then
			kitHeavy(side, player, ...)
		end
	end)

	RunService.Heartbeat:Connect(function()
		stepAll(self)
	end)

	-- Studio only: how work/test-harness throws the bot's punch, or starts a clash, on cue.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("HT_TestPunch"):Connect(function()
			local name = workspace:GetAttribute("HT_TestPunch")
			local model = name and workspace:FindFirstChild(name)
			if model and model:IsA("Model") then
				self:PunchAs(model)
			end
		end)
		workspace:GetAttributeChangedSignal("HT_TestClash"):Connect(function()
			local names = workspace:GetAttribute("HT_TestClash")
			if not names then
				return
			end
			local first, second = string.match(names, "^(.+)|(.+)$")
			local a = first and workspace:FindFirstChild(first)
			local b = second and workspace:FindFirstChild(second)
			if a and b then
				Knit.GetService("ClashService"):Begin(a, b)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
	end)

	local function onCharacter(character: Model)
		CollectionService:AddTag(character, Combatants.TAG)
		Knit.GetService("StaggerService"):Reset(character)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CombatService
