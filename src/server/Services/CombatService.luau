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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local punchCfg = GameConfig.Punch
local knockCfg = GameConfig.Knockback
local staggerCfg = GameConfig.Stagger
local clashCfg = GameConfig.Clash
-- The drawing is sent whenever it could be wanted, and each client decides whether to show it.
local SHOW_DEBUG = GameConfig.Debug.ShowHitbox or GameConfig.Training.Enabled

type PunchRecord = {
	bucket: Combat.Bucket,
	lastPunch: number?,
	recovery: number,
	nextSide: string,
	refused: number,
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
}

local CombatService = Knit.CreateService({
	Name = "CombatService",
})

local records: { [Player]: PunchRecord } = {}
local lastHitAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local punches: { [Model]: Punch } = {}
local botSides: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local botLastSwing: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
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
			nextSide = "Left",
			refused = 0,
		}
		records[player] = record
	end
	return record
end

--- May these two fight each other right now? The round step adds its own rule for the 1v1 arena.
function CombatService:CanFight(a: Model, b: Model): boolean
	local round = Knit.GetService("RoundService"):AllowsFight(a, b)
	if round ~= nil then
		return round
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

-- A swing lands on someone. Only ever runs once per target per swing.
local function landHit(self: any, punch: Punch, target: Model, at: Vector3, from: Vector3)
	local audit = Knit.GetService("SpeedAuditService")
	local stagger = Knit.GetService("StaggerService")
	local knockback = Knit.GetService("KnockbackService")
	local flat = punch.flat :: Vector3
	local attackerSpeed = audit:GetTrustedSpeed(punch.attacker)
	local before = stagger:Get(target)
	local strength = Combat.punchStrength(knockCfg, staggerCfg, attackerSpeed, before)
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
	local kicks = Knit.GetService("KickService")
	if punch.side == "Uppercut" and kicks:CanLaunch(target) then
		kicks:MarkLaunched(target, punch.attacker)
	elseif punch.side == "Uppercut" then
		up, airUp = 0, 0
	end
	knockback:Launch(target, away.X * strength, away.Z * strength, up, airUp)
	self._hitConfirmed:FireAllClients(punch.attacker, target, math.floor(strength))
	punch.hits += 1
	punch.reasons[target] = "hit"
	trace(
		`{punch.attacker.Name} {punch.side} hit {target.Name}: strength {math.floor(strength)}, speed {math.floor(
			attackerSpeed
		)}, stagger {before} before`
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
	if record then
		record.recovery = if punch.hits > 0 then 0 else punchCfg.MissRecovery
	end
	sendResult(self, punch, if punch.hits > 0 then "hit" else "miss")
	if punch.hits > 0 then
		Knit.GetService("StaggerService"):Relieve(punch.attacker)
	end
	-- The puncher pays either way: a miss slows them, a hit stops them and pushes them back. A
	-- repel has already thrown them, which this would otherwise wipe out.
	if not punch.repelled then
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
		punchCfg,
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
		local found, why = Combat.sweepReach(
			punchCfg,
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
	if not other or other.wild or punch.wild then
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
	wild: boolean
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
	local side = Combat.comboSwing(punchCfg, botSides[model] or "Left", now, botLastSwing[model])
	botLastSwing[model] = now
	botSides[model] = Combat.nextSwing(side)
	self._punchStarted:FireAllClients(model, side)
	startPunch(
		self,
		model,
		nil,
		side,
		now,
		punchCfg.Windup + GameConfig.TestBot.ExtraWindup,
		0,
		wild == true
	)
end

function CombatService:KnitInit()
	self._punchRequest = Net.server("PunchRequest")
	self._punchStarted = Net.server("PunchStarted")
	self._hitConfirmed = Net.server("HitConfirmed")
	self._punchResult = Net.server("PunchResult")
	self._punchDebug = Net.server("PunchDebug")
end

function CombatService:KnitStart()
	self._punchRequest.OnServerEvent:Connect(function(player: Player, ...)
		local record = recordFor(player)
		local now = os.clock()
		-- Rate limit before anything else, so a flood costs almost nothing.
		if not Combat.takeToken(record.bucket, now, punchCfg.RequestsPerSecondLimit) then
			record.refused += 1
			return
		end
		-- A real client sends no arguments at all. Anything else is malformed.
		if select("#", ...) ~= 0 then
			record.refused += 1
			trace(`{player.Name} refused: unexpected arguments`)
			return
		end
		local attacker = player.Character
		if not attacker or not Combatants.isAlive(attacker) then
			trace(`{player.Name} refused: no living character`)
			return
		end
		-- Held on a spawn through a round's countdown.
		if attacker:GetAttribute("HT_RoundHold") then
			trace(`{player.Name} refused: round countdown`)
			self._punchResult:FireClient(player, attacker, "refused")
			return
		end
		if Knit.GetService("KickService"):IsBusy(attacker) then
			trace(`{player.Name} refused: mid-kick`)
			self._punchResult:FireClient(player, attacker, "refused")
			return
		end
		if not Combat.cooldownReady(punchCfg, now, record.lastPunch, record.recovery) then
			record.refused += 1
			trace(`{player.Name} refused: cooldown`)
			self._punchResult:FireClient(player, attacker, "refused")
			return
		end

		-- Everything is marked before the wait, so a second request can't pass the same check.
		local side = Combat.comboSwing(punchCfg, record.nextSide, now, record.lastPunch)
		record.lastPunch = now
		record.recovery = 0
		record.nextSide = Combat.nextSwing(side)
		self._punchStarted:FireAllClients(attacker, side)
		startPunch(
			self,
			attacker,
			player,
			side,
			now,
			punchCfg.Windup,
			player:GetNetworkPing(),
			false
		)
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
