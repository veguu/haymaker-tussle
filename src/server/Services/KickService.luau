--!strict
-- KickService - owns the air kick, and who counts as launched. As with punches, a client never
-- says who it hit. It only says "I jumped", "I reached them" and "I pressed", with no arguments.
-- The server keeps its own cooldown and clock, picks the target itself and checks every distance.
--
-- An uppercut that lands marks the target with the HT_Air attribute: "float" lightens gravity on
-- whoever owns that body, "hold" hangs them still while someone is following them up. It clears on
-- landing. HT_AirBy says whose uppercut it was, which counts a little in their favour when picking.
-- THE FOLLOW-UP. The server picks the target itself, by the same rule the client shows
-- (DiveKick.pickFollowUp): someone floating, fightable, within FollowUpRange, with nothing solid in the
-- way. The moment it accepts, the target is held ("hold", with HT_HoldUntil as a deadline its own client
-- also respects) so it can't drift out of the snap, and the jumper is told which target it is
-- (KickAccepted). The hold ends the moment the kick lands, misses, is cancelled or times out
-- (HoldTimeout), whichever is first. A target held by one follow-up can't be taken by another.
-- THE FINISHER. A kick graded in FinisherGrades launches the target hard away from the kicker and up,
-- with a short loss of control (FinisherStunSeconds). Only a perfect (green) press is a finisher by
-- default; anything else slams them down, a knockdown.
-- WHOSE LAUNCH. Only the one whose uppercut put a target in the air can follow it up (FollowUpOthers
-- off): nobody takes someone else's launch.
-- THE AIM. A perfect (green) kick sends them toward where the kicker's cursor points instead of straight
-- away from the kicker. The press carries that direction, and it's only ever a direction: it's
-- flattened and made a unit vector here, and used for nothing but which way a green kick throws them.
-- THE CRASH. A body an air kick has sent flying is dangerous to whoever it flies into for a moment
-- (CrashSeconds): they're thrown the way it was going and staggered, once, and the kicker is credited.
-- HT_Stunned is the loss of control: a finisher's short one, a knockdown's from the slam until
-- KnockdownSeconds after landing, or a green slam's (when green isn't a finisher) until they've landed
-- from the bounce. Every path out of it clears on a timer too.
--
-- KNOWN GAP, the same as all movement here: the client owns its body, so a cheat could fly
-- somewhere false during the chase, or ignore its own HT_Air. The clock limits for how long.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local DiveKick = require(ReplicatedStorage.Shared.Core.DiveKick)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Kick
local staggerCfg = GameConfig.Stagger
local SKILL_ATTRIBUTE = "HT_Skill"
local AIR_ATTRIBUTE = "HT_Air"
local AIR_BY_ATTRIBUTE = "HT_AirBy" -- the launcher's user id, or 0 for a server-run fighter
local FACE_ATTRIBUTE = "HT_HoldFace" -- which way a held body turns, to face whoever locked on
local QTE_ATTRIBUTE = "HT_KickAt" -- seconds after touching that this jump's ring meets the key
local STUN_ATTRIBUTE = "HT_Stunned"
local GRADE_ATTRIBUTE = "HT_KickGrade" -- red, orange or green, once the kick's timing is known
local HOLD_UNTIL_ATTRIBUTE = "HT_HoldUntil" -- server time a hold ends by, whatever else happens
local FACE_EVERY = 0.1 -- how often a held body turns to follow whoever is aiming around it
local CLOCK_TOLERANCE = 0.3 -- forgives honest lag between the client's clock and ours
local RING_RUN_OUT_LAG = 0.06 -- an unpressed ring waits this much longer, for a press on its way
local FLOOR_CONTACT_STUDS = 4.5 -- a body's centre this close to the floor has hit it
local RANGE_TOLERANCE = 8 -- forgives both bodies being slightly old on the server
-- A jumper's own client is ahead of what the server sees, and it sees the target a moment late, so
-- at speed the two can disagree by a lot. "I reached them" gets this much room, plus this many
-- seconds of how fast both bodies are moving.
local ATTACH_TOLERANCE = 12
local ATTACH_LAG_SECONDS = 0.35
local AIR_CHECK_STUDS = 4.5 -- this far above the floor counts as in the air
local LIFTOFF_SECONDS = 0.5 -- nobody counts as landed this soon after leaving the floor
local JUMP_ALLOWANCE = 15 -- a jump's message arrives after the body has already risen this far
local AIR_LIMIT_SECONDS = 8 -- nothing floats for longer than this, whatever went wrong
local TELEPORT_STUDS = 30 -- further than this in one frame, a body was moved rather than travelling
local SLAM_WATCH_SECONDS = 3 -- gives up waiting for a kicked body to reach the floor
local FLIGHT_WATCH_SECONDS = 6 -- gives up waiting for a body a finisher threw to come down

local KickService = Knit.CreateService({
	Name = "KickService",
})

type Record = {
	character: Model,
	target: Model,
	phase: string,
	phaseAt: number,
	startedAt: number,
	held: boolean,
	heldAt: number,
	snap: boolean, -- the locked-on follow-up: held and snapped to. Otherwise a free jump they steer.
	startGap: number,
	qteAt: number,
	facedAt: number,
	grade: DiveKick.Grade,
	stopUntil: number,
	aim: Vector3?, -- where the kicker's cursor pointed at the press, flat and unit
}

local active: { [Player]: Record } = {}
-- Who each player says they're locked onto. Only ever used to choose between the snap and the free
-- jump at someone the server would have let them jump at anyway.
local lockedOn: { [Player]: Model } = setmetatable({}, { __mode = "k" }) :: any
local lastUse: { [Player]: number } = {}
local launched: { [Model]: number } = {}
local stunTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextStunToken = 0

-- A stun that ends on its own, without ending a later one early.
local function stunFor(target: Model, seconds: number)
	nextStunToken += 1
	local token = nextStunToken
	stunTokens[target] = token
	target:SetAttribute(STUN_ATTRIBUTE, true)
	task.delay(seconds, function()
		if stunTokens[target] == token then
			stunTokens[target] = nil
			if target.Parent then
				target:SetAttribute(STUN_ATTRIBUTE, nil)
			end
		end
	end)
end

local function hold(record: Record, now: number)
	record.held = true
	record.heldAt = now
	record.target:SetAttribute(AIR_ATTRIBUTE, "hold")
	record.target:SetAttribute(HOLD_UNTIL_ATTRIBUTE, workspace:GetServerTimeNow() + cfg.HoldTimeout)
end

local function letGo(target: Model)
	target:SetAttribute(FACE_ATTRIBUTE, nil)
	target:SetAttribute(HOLD_UNTIL_ATTRIBUTE, nil)
end

local function trace(message: string)
	if workspace:GetAttribute("HaymakerCombatDebug") then
		print(`[Kick] {message}`)
	end
end

local function setPhase(record: Record, phase: string)
	record.phase = phase
	record.phaseAt = os.clock()
	record.character:SetAttribute(SKILL_ATTRIBUTE, phase)
end

local function finish(player: Player)
	local record = active[player]
	if record then
		record.character:SetAttribute(SKILL_ATTRIBUTE, nil)
		record.character:SetAttribute(QTE_ATTRIBUTE, nil)
		record.character:SetAttribute(GRADE_ATTRIBUTE, nil)
		if record.held then
			-- Let go without a kick: they carry on falling.
			if record.target:GetAttribute(AIR_ATTRIBUTE) == "hold" then
				record.target:SetAttribute(AIR_ATTRIBUTE, "float")
			end
			letGo(record.target)
			launched[record.target] = os.clock()
		end
		active[player] = nil
	end
end

local function isAirborne(root: BasePart, allowance: number?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	local reach = AIR_CHECK_STUDS + 3 + (allowance or 0)
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), params) == nil
end

local function touchingFloor(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	return workspace:Raycast(root.Position, Vector3.new(0, -FLOOR_CONTACT_STUDS, 0), params) ~= nil
end

--- Can't punch: doing the air kick, held by one, stunned by a green kick, or in a clash. Merely being
--- launched doesn't stop a punch, because punching is how a launched body gets back.
function KickService:IsBusy(model: Model): boolean
	local air = model:GetAttribute(AIR_ATTRIBUTE)
	return model:GetAttribute(SKILL_ATTRIBUTE) ~= nil
		or air == "hold"
		or (air ~= nil and not GameConfig.AirRecovery.PunchWhileLaunched)
		or model:GetAttribute(STUN_ATTRIBUTE) ~= nil
		or model:GetAttribute("HT_Clash") ~= nil
end

--- Someone a green kick has stunned can still be hit, but not thrown back up. Otherwise a stun
--- could be chained forever.
function KickService:CanLaunch(target: Model): boolean
	return target:GetAttribute(STUN_ATTRIBUTE) == nil
		and target:GetAttribute(Combatants.STATIONARY_ATTRIBUTE) == nil
end

--- Being punched out of the air ends the move.
function KickService:Cancel(model: Model)
	local player = Combatants.playerOf(model)
	if player then
		finish(player)
	end
end

--- An uppercut landed: this target now floats, and can be jumped at, until it lands.
function KickService:MarkLaunched(target: Model, attacker: Model)
	launched[target] = os.clock()
	local player = Combatants.playerOf(attacker)
	target:SetAttribute(AIR_BY_ATTRIBUTE, if player then player.UserId else 0)
	target:SetAttribute(AIR_ATTRIBUTE, "float")
end

local function clearAir(target: Model)
	launched[target] = nil
	target:SetAttribute(AIR_ATTRIBUTE, nil)
	target:SetAttribute(AIR_BY_ATTRIBUTE, nil)
	letGo(target)
end

--- Whatever a kick or a launch has left on this body, gone, for when it's being moved somewhere else.
function KickService:Release(model: Model)
	clearAir(model)
	model:SetAttribute(STUN_ATTRIBUTE, nil)
	self:Cancel(model)
end

-- Bodies an air kick has just sent flying: who kicked them, until when they're dangerous, where they were
-- last frame (their speed is measured here, not taken from their client), and who they've hit already.
type Flight = {
	kicker: Model,
	untilAt: number,
	last: Vector3?,
	lastAt: number,
	struck: { [Model]: boolean },
}
local flights: { [Model]: Flight } = setmetatable({}, { __mode = "k" }) :: any

local function startFlight(target: Model, kicker: Model)
	if cfg.CrashSeconds > 0 then
		flights[target] = {
			kicker = kicker,
			untilAt = os.clock() + cfg.CrashSeconds,
			last = nil,
			lastAt = os.clock(),
			struck = {},
		}
	end
end

-- One frame of every flight: anyone the flying body reaches while it's still moving fast is hit.
local function stepFlights(self: any, now: number)
	for body, flight in flights do
		local root = Combatants.rootOf(body)
		if now >= flight.untilAt or not root or body.Parent == nil then
			flights[body] = nil
			continue
		end
		local at = root.Position
		local last = flight.last
		local dt = now - flight.lastAt
		flight.last, flight.lastAt = at, now
		if not last or dt <= 0 then
			continue
		end
		local travel = at - last
		local speed = travel.Magnitude / dt
		if speed < cfg.CrashMinSpeed or speed > TELEPORT_STUDS / dt then
			continue
		end
		local combat = Knit.GetService("CombatService")
		for _, other in Combatants.all() do
			local otherRoot = other ~= body
				and other ~= flight.kicker
				and not flight.struck[other]
				and Combatants.rootOf(other)
			if
				otherRoot
				and (otherRoot.Position - at).Magnitude <= cfg.CrashDistance
				and Combatants.isAlive(other)
				and other:GetAttribute(AIR_ATTRIBUTE) ~= "hold"
				and combat:CanFight(body, other)
			then
				flight.struck[other] = true
				local flat = Vector3.new(travel.X, 0, travel.Z)
				if flat.Magnitude < 0.05 then
					flat = Vector3.new(otherRoot.Position.X - at.X, 0, otherRoot.Position.Z - at.Z)
				end
				local way = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
				trace(`{body.Name} crashed into {other.Name} at {math.floor(speed)}`)
				Knit.GetService("StaggerService"):AddAmount(other, cfg.CrashStagger)
				combat:MarkHit(other)
				Knit.GetService("RoundService"):NoteHit(other, flight.kicker)
				Knit.GetService("KnockbackService")
					:Launch(other, way.X * cfg.CrashPush, way.Z * cfg.CrashPush, cfg.CrashLift, 0)
				self._crash:FireAllClients(body, other, cfg.CrashPush)
			end
		end
	end
end

-- The kick connects, and the timing decides how hard: outward away from the kicker, down, and in
-- stagger, all together. Full force is the same push as a regular punch, so that a good kick wins
-- the arena's edge the way any other hit does. A green kick bounces them off the floor when they
-- actually reach it, keeping their outward speed.
function KickService:_impact(player: Player, record: Record)
	local root = Combatants.rootOf(record.character)
	local target = record.target
	local targetRoot = Combatants.rootOf(target)
	-- Whatever happened to them since, a target that's no longer valid is never hit, and nobody else is.
	if
		not root
		or not targetRoot
		or not Combatants.isAlive(target)
		or not Knit.GetService("CombatService"):CanFight(record.character, target)
	then
		trace(`{player.Name}'s kick found no valid target: nothing landed`)
		finish(player)
		return
	end
	local finisher = (cfg.FinisherGrades :: { [string]: boolean })[record.grade] == true
	local share = DiveKick.gradeShare(cfg, record.grade)
	local stagger = Knit.GetService("StaggerService")
	local before = stagger:Get(target)
	local push = Combat.punchStrength(GameConfig.Knockback, staggerCfg, 0, before) * share
	if finisher then
		push = math.min(push * cfg.FinisherPushScale, cfg.FinisherMaxSpeed)
	end
	stagger:AddAmount(target, math.floor(cfg.StaggerAdded * share + 0.5))
	Knit.GetService("CombatService"):MarkHit(target)

	local stop = DiveKick.gradeStop(cfg, record.grade)
	setPhase(record, "kick")
	record.held = false
	record.stopUntil = os.clock() + stop

	local position = targetRoot.Position
	local flat = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
	local away = if flat.Magnitude > 0.01
		then flat.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	-- A perfect kick goes where the kicker pointed.
	if record.grade == "green" and record.aim then
		away = record.aim
	end
	local slam = if finisher then 0 else cfg.SlamSpeed * share
	trace(
		`{player.Name} kicked {target.Name}: {record.grade}{if finisher then " finisher" else ""}, {math.floor(
			push
		)} outward, {math.floor(slam)} down, {stop} s stop`
	)
	local knockback = Knit.GetService("KnockbackService")
	self._hitConfirmed:FireAllClients(record.character, target, math.floor(push))
	stagger:Relieve(record.character)
	self._impactEvent:FireAllClients(
		record.character,
		target,
		position,
		true,
		share,
		stop,
		finisher
	)

	-- A true hit stop: both are held in the air already, so they simply stay held a moment longer
	-- with the kick's pose on show. Then the launch, once. A finisher sends them flying away and up,
	-- and they get control back shortly after to try to recover. Otherwise the floor takes the slam
	-- when they arrive; past the edge, there's no floor to take it.
	local character = record.character
	if finisher then
		task.delay(stop, function()
			clearAir(target)
			if target.Parent == nil or not Combatants.isAlive(target) then
				return
			end
			stunFor(target, cfg.FinisherStunSeconds)
			Knit.GetService("RoundService"):NoteHit(target, character)
			knockback:Launch(
				target,
				away.X * push,
				away.Z * push,
				cfg.FinisherLift,
				cfg.FinisherLift
			)
			startFlight(target, character)
			-- Wherever they come down, the floor takes it: the same landing a slam gets, so every kicked
			-- body breaks the ground it hits. Past the edge there is no floor, and nothing happens.
			local started = os.clock()
			local last = targetRoot.Position
			local moved = false
			task.wait(LIFTOFF_SECONDS)
			repeat
				task.wait()
				moved = (targetRoot.Position - last).Magnitude > TELEPORT_STUDS
				last = targetRoot.Position
			until target.Parent == nil
				or moved
				or touchingFloor(targetRoot)
				or os.clock() - started >= FLIGHT_WATCH_SECONDS
			if target.Parent and not moved and touchingFloor(targetRoot) and character.Parent then
				trace(`{target.Name} hit the floor after a finisher`)
				self._impactEvent:FireAllClients(
					character,
					target,
					targetRoot.Position,
					true,
					share,
					0
				)
			end
		end)
		task.delay(cfg.RecoverSeconds, function()
			if active[player] == record then
				finish(player)
			end
		end)
		return
	end
	local bounces = record.grade == "green"
	-- Any other slam is a knockdown: no control from the slam until KnockdownSeconds after landing.
	local knockdown = not bounces and cfg.KnockdownSeconds > 0
	task.delay(stop, function()
		clearAir(target)
		if target.Parent == nil then
			return
		end
		if bounces or knockdown then
			target:SetAttribute(STUN_ATTRIBUTE, true)
			task.delay(cfg.StunMaxSeconds, function()
				if target.Parent then
					target:SetAttribute(STUN_ATTRIBUTE, nil)
				end
			end)
		end
		Knit.GetService("RoundService"):NoteHit(target, character)
		knockback:Launch(target, away.X * push, away.Z * push, 0, -slam)
		startFlight(target, character)
		local started = os.clock()
		local last = targetRoot.Position
		local moved = false -- sent somewhere else, such as home after falling off
		repeat
			task.wait()
			moved = (targetRoot.Position - last).Magnitude > TELEPORT_STUDS
			last = targetRoot.Position
		until target.Parent == nil
			or moved
			or touchingFloor(targetRoot)
			or os.clock() - started >= SLAM_WATCH_SECONDS
		if target.Parent and not moved and touchingFloor(targetRoot) then
			if bounces then
				trace(`{target.Name} bounced off the floor`)
				knockback:Launch(target, 0, 0, cfg.BounceLift, cfg.BounceLift)
			end
			if character.Parent then
				self._impactEvent:FireAllClients(
					character,
					target,
					targetRoot.Position,
					true,
					share,
					0
				)
			end
			if bounces then
				-- Up off the floor, back down onto it, and only then control comes back.
				task.wait(LIFTOFF_SECONDS)
				repeat
					task.wait()
				until target.Parent == nil
					or touchingFloor(targetRoot)
					or target:GetAttribute(STUN_ATTRIBUTE) == nil
				task.wait(cfg.StunAfterLanding)
			elseif knockdown then
				trace(`{target.Name} was knocked down`)
				task.wait(cfg.KnockdownSeconds)
			end
		end
		if target.Parent then
			target:SetAttribute(STUN_ATTRIBUTE, nil)
		end
	end)

	task.delay(cfg.RecoverSeconds, function()
		if active[player] == record then
			finish(player)
		end
	end)
end

-- The timing is settled: the flip starts, and the kick is coming whatever the result.
local function beginFlip(record: Record, grade: DiveKick.Grade)
	record.grade = grade
	record.character:SetAttribute(GRADE_ATTRIBUTE, grade)
	setPhase(record, "flip")
end

-- Is anything solid between these two points? Fighters and anything that doesn't collide don't count.
local function clearPath(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Combatants.TAG)
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return workspace:Raycast(from, to - from, params) == nil
end

-- Who this body can follow up: everyone floating that it may fight, in range, with a clear path, picked
-- by the shared rule. The range has RANGE_TOLERANCE of slack, since both bodies are slightly old here.
local function jumpTarget(player: Player, character: Model, root: BasePart): (Model?, boolean)
	local combat = Knit.GetService("CombatService")
	local models: { Model } = {}
	local candidates: { DiveKick.Candidate } = {}
	for target in launched do
		local other = Combatants.rootOf(target)
		if
			other
			and target ~= character
			and target:GetAttribute(AIR_ATTRIBUTE) == "float"
			and (cfg.FollowUpOthers or target:GetAttribute(AIR_BY_ATTRIBUTE) == player.UserId)
			and Combatants.isAlive(target)
			and combat:CanFight(character, target)
			and clearPath(root.Position, other.Position)
		then
			table.insert(models, target)
			table.insert(candidates, {
				x = other.Position.X,
				y = other.Position.Y,
				z = other.Position.Z,
				own = target:GetAttribute(AIR_BY_ATTRIBUTE) == player.UserId,
			})
		end
	end
	-- Locked onto one of them: that's the one, and it's the snap.
	local locked = lockedOn[player]
	if locked and table.find(models, locked) then
		return locked, true
	end
	local look = root.CFrame.LookVector
	local index = DiveKick.pickFollowUp(
		cfg,
		root.Position.X,
		root.Position.Y,
		root.Position.Z,
		look.X,
		look.Z,
		candidates,
		RANGE_TOLERANCE
	)
	return if index then models[index] else nil, false
end

-- Turns a held body to face whoever is touching it.
local function faceJumper(record: Record, root: BasePart, targetRoot: BasePart)
	local offset = root.Position - targetRoot.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > 0.5 then
		record.target:SetAttribute(FACE_ATTRIBUTE, flat.Unit)
	end
end

function KickService:KnitInit()
	self._request = Net.server("KickRequest")
	self._attach = Net.server("KickAttach")
	self._commit = Net.server("KickCommit")
	self._impactEvent = Net.server("KickImpact")
	self._hitConfirmed = Net.server("HitConfirmed")
	self._accepted = Net.server("KickAccepted")
	self._lockOn = Net.server("LockOnState")
	self._crash = Net.server("DashHit")
end

function KickService:KnitStart()
	self._lockOn.OnServerEvent:Connect(function(player: Player, ...)
		local target = ...
		if select("#", ...) > 1 then
			return
		end
		if
			typeof(target) == "Instance"
			and target:IsA("Model")
			and table.find(Combatants.all(), target)
		then
			lockedOn[player] = target
		else
			lockedOn[player] = nil
		end
	end)

	self._request.OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 or active[player] then
			return
		end
		local now = os.clock()
		local character = player.Character
		local root = character and Combatants.rootOf(character)
		if
			not character
			or not root
			or not Combatants.isAlive(character)
			or isAirborne(root, JUMP_ALLOWANCE)
		then
			return
		end
		local target, snap = jumpTarget(player, character, root)
		if not target then
			return
		end
		local last = lastUse[player]
		if last and now - last < cfg.Cooldown - GameConfig.Punch.CooldownTolerance then
			return
		end
		lastUse[player] = now
		local targetRoot = Combatants.rootOf(target) :: BasePart
		local record: Record = {
			character = character,
			target = target,
			phase = "chase",
			phaseAt = now,
			startedAt = now,
			held = false,
			heldAt = now,
			snap = snap,
			startGap = (targetRoot.Position - root.Position).Magnitude,
			qteAt = DiveKick.pickQte(cfg, math.random()),
			facedAt = 0,
			grade = "red",
			stopUntil = 0,
		}
		trace(`{player.Name} follows up {target.Name} from {math.floor(record.startGap)} studs`)
		character:SetAttribute(QTE_ATTRIBUTE, record.qteAt)
		active[player] = record
		-- Locked on: held from now, so they can't move out of the snap. A held target is nobody else's
		-- to take. Not locked on: nothing is held, and the jumper has to get there on their own arc.
		if snap then
			hold(record, now)
			faceJumper(record, root, targetRoot)
		end
		setPhase(record, "chase")
		self._accepted:FireClient(player, target, snap)
	end)

	self._attach.OnServerEvent:Connect(function(player: Player, ...)
		local record = active[player]
		if select("#", ...) ~= 0 or not record or record.phase ~= "chase" then
			return
		end
		local target = record.target
		local root = Combatants.rootOf(record.character)
		local targetRoot = Combatants.rootOf(target)
		if
			not root
			or not targetRoot
			or target:GetAttribute(AIR_ATTRIBUTE) ~= (if record.held then "hold" else "float")
			or not Combatants.isAlive(target)
		then
			return
		end
		local gap = (targetRoot.Position - root.Position).Magnitude
		local closing = root.AssemblyLinearVelocity.Magnitude
			+ targetRoot.AssemblyLinearVelocity.Magnitude
		local allowed = cfg.TouchFlat
			+ cfg.TouchTall
			+ ATTACH_TOLERANCE
			+ closing * ATTACH_LAG_SECONDS
		-- The snap is far faster than this server sees it, so while it can still be on its way, being no
		-- further than where it started (the target is held) is enough. It was in range and clear then.
		local since = os.clock() - record.phaseAt
		if
			record.snap
			and since <= cfg.ApproachMaxSeconds + cfg.JumpMissGrace + CLOCK_TOLERANCE
		then
			allowed = math.max(allowed, record.startGap + ATTACH_TOLERANCE)
		end
		if gap > allowed then
			trace(`{player.Name} attach refused: {math.floor(gap)} studs away`)
			return
		end
		trace(`{player.Name} attached at {math.floor(gap)} studs`)
		faceJumper(record, root, targetRoot)
		if not record.held then
			hold(record, os.clock())
		end
		setPhase(record, "attach")
	end)

	self._commit.OnServerEvent:Connect(function(player: Player, ...)
		local record = active[player]
		if select("#", ...) > 1 or not record or record.phase ~= "attach" then
			return
		end
		local aim = ...
		if typeof(aim) == "Vector3" then
			local x, z = DiveKick.aimDirection(aim.X, aim.Z)
			if x and z then
				record.aim = Vector3.new(x, 0, z)
			end
		end
		-- Both messages are delayed by the same trip, so the gap between them is the real timing.
		local since = os.clock() - record.phaseAt
		local grade = DiveKick.grade(cfg, since, record.qteAt)
		trace(
			`{player.Name} pressed {string.format("%.2f", since)} s after touching, wanted {string.format(
				"%.2f",
				record.qteAt
			)}: {grade}`
		)
		beginFlip(record, grade)
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		stepFlights(self, now)
		for target, since in launched do
			-- Whatever interrupted it, nobody stays held in the air without someone holding them.
			if target:GetAttribute(AIR_ATTRIBUTE) == "hold" then
				local holding = false
				for _, record in active do
					if record.target == target and (record.held or now < record.stopUntil) then
						holding = true
					end
				end
				if not holding then
					target:SetAttribute(AIR_ATTRIBUTE, "float")
					target:SetAttribute(FACE_ATTRIBUTE, nil)
					launched[target] = now
				end
			end
			local root = Combatants.rootOf(target)
			local gone = not root or not Combatants.isAlive(target)
			local down = root ~= nil
				and target:GetAttribute(AIR_ATTRIBUTE) ~= "hold"
				and now - since >= LIFTOFF_SECONDS
				and (not isAirborne(root) or now - since >= AIR_LIMIT_SECONDS)
			if gone or down then
				clearAir(target)
			end
		end
		for player, record in active do
			local root = Combatants.rootOf(record.character)
			local gone = player.Character ~= record.character
				or not root
				or not Combatants.isAlive(record.character)
			local waited = now - record.phaseAt
			local target = record.target
			-- The target stopped being valid: nobody is hit, and nobody else is taken instead.
			local over = target.Parent == nil or not Combatants.isAlive(target)
			if record.held and now - record.heldAt >= cfg.HoldTimeout then
				trace(`{player.Name}'s hold on {target.Name} timed out`)
				over = true
			end
			if record.phase == "chase" then
				over = over
					or waited >= (if record.snap then cfg.ChaseSeconds else cfg.LeapChaseSeconds) + CLOCK_TOLERANCE
					or launched[target] == nil
					or (
						root ~= nil
						and waited >= LIFTOFF_SECONDS + cfg.ApproachMaxSeconds
						and not isAirborne(root)
					)
			elseif record.phase == "attach" then
				over = over or launched[record.target] == nil
				if waited >= DiveKick.ringEnd(cfg, record.qteAt) + RING_RUN_OUT_LAG then
					trace(`{player.Name} never pressed: red`)
					beginFlip(record, "red")
				end
				local targetRoot = Combatants.rootOf(record.target)
				if root and targetRoot and now - record.facedAt >= FACE_EVERY then
					record.facedAt = now
					faceJumper(record, root, targetRoot)
				end
			end
			if gone or over then
				finish(player)
			elseif record.phase == "flip" and waited >= cfg.FlipSeconds then
				self:_impact(player, record)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		finish(player)
		lastUse[player] = nil
	end)
end

return KickService
