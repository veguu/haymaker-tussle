--!strict
-- KnockbackService - decides knockback for punches and bumps, and sends it to whoever
-- owns the body: the player's own client, or the dummy service for dummies.
--
-- Players don't solid-collide with each other. Solid collisions between client-owned
-- characters are the known route to accidental launches and fling cheats, so contact is
-- a server decision here: two characters closing fast both get a shove, well under a propel,
-- along the line they collided on. The faster one has a small edge. Core/Combat.bumpOutcome decides it.
--
-- KNOWN GAP: a cheating client could ignore a knockback sent to it. Not handled yet.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local BumpPredict = require(ReplicatedStorage.Shared.BumpPredict)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Knockback
local staggerCfg = GameConfig.Stagger
local COLLISION_GROUP = "HT_Characters"
-- How often pairs are checked. A crossing too fast to be seen inside the bump distance is still caught,
-- because each check also looks along the path since the last one (Combat.stepBumpPair).
local BUMP_CHECK_SECONDS = 0.05

local KnockbackService = Knit.CreateService({
	Name = "KnockbackService",
})

-- Per pair, what the last check saw (Combat.BumpPair), keyed by the pair in a fixed order.
local bumpPairs: { [Model]: { [Model]: Combat.BumpPair } } = {}
-- A bump that qualified while one of the pair was mid-swing waits here for the swing to be decided.
type Deferred = {
	at: number,
	closing: number,
	lineX: number,
	lineZ: number,
	ax: number,
	az: number,
	bx: number,
	bz: number,
}
local deferred: { [Model]: { [Model]: Deferred } } = {}
-- A dash goes from a creep to full speed in a tenth of a second. The audit's usual velocity is an
-- average over about 0.2 s, so for the first third of a dash it would still read as slow. Collisions
-- also measure over this much shorter stretch, still from positions the server saw itself.
local DASH_SPEED_WINDOW = 0.08

-- How fast this body is really going right now: the faster of the short measure and the usual one.
local function velocityOf(audit: any, dasher: Model, root: BasePart): (number, number)
	local vx, vz = audit:GetVelocity(dasher)
	local past = audit:PositionAt(dasher, DASH_SPEED_WINDOW)
	if past then
		local sx = (root.Position.X - past.X) / DASH_SPEED_WINDOW
		local sz = (root.Position.Z - past.Z) / DASH_SPEED_WINDOW
		if sx * sx + sz * sz > vx * vx + vz * vz then
			return sx, sz
		end
	end
	return vx, vz
end

local function setGroup(part: Instance)
	if part:IsA("BasePart") then
		part.CollisionGroup = COLLISION_GROUP
	end
end

--- Puts a character in the no-collide group, including parts added to it later.
function KnockbackService:RegisterBody(model: Model)
	for _, descendant in model:GetDescendants() do
		setGroup(descendant)
	end
	model.DescendantAdded:Connect(setGroup)
end

--- Launches a target. `up` applies if it's on the ground, `airUp` if it's in the air.
--- `speedKeep` is the share of running speed it keeps; left out, the normal hit rule applies.
--- `selfRecoil` marks what a punch costs its own thrower, which isn't a hit and works differently in
--- the air. The body's owner decides that, because only it really knows whether it's in the air.
function KnockbackService:Launch(
	target: Model,
	x: number,
	z: number,
	up: number,
	airUp: number,
	speedKeep: number?,
	selfRecoil: boolean?
)
	local player = Combatants.playerOf(target)
	if player then
		self._remote:FireClient(player, Vector3.new(x, up, z), airUp, speedKeep, selfRecoil)
	else
		Knit.GetService("DummyService"):ApplyKnockback(target, x, z, up, airUp, speedKeep)
	end
end

local function pairState(a: Model, b: Model): Combat.BumpPair
	bumpPairs[a] = bumpPairs[a] or {}
	local state = bumpPairs[a][b]
	if not state then
		state = Combat.newBumpPair()
		bumpPairs[a][b] = state
	end
	return state
end

-- Can these two bump at all right now? A stationary training target, anyone in a skill, in the air or in
-- a clash never does.
local function eligible(combat: any, a: Model, b: Model): boolean
	return combat:CanFight(a, b)
		and not a:GetAttribute("HT_Skill")
		and not b:GetAttribute("HT_Skill")
		and not a:GetAttribute("HT_Air")
		and not b:GetAttribute("HT_Air")
		and not a:GetAttribute("HT_Clash")
		and not b:GetAttribute("HT_Clash")
		and not a:GetAttribute(Combatants.STATIONARY_ATTRIBUTE)
		and not b:GetAttribute(Combatants.STATIONARY_ATTRIBUTE)
end

-- Both are knocked along the line A was travelling relative to B (A back, B forward), each by the other's
-- speed (Combat.bumpOutcome). A dash into someone is just this at dash speed.
local function applyBump(self: any, a: Model, b: Model, bump: Deferred)
	local outcome = Combat.bumpOutcome(
		cfg,
		staggerCfg,
		GameConfig.Movement.PropelSpeed,
		bump.closing,
		bump.ax,
		bump.az,
		bump.bx,
		bump.bz
	)
	local stagger = Knit.GetService("StaggerService")
	local round = Knit.GetService("RoundService")
	-- A player's own client already knocked them the instant they touched (BumpPredict): this would be a
	-- second, late knock. Bots, and bumps outside a round, are knocked from here.
	local predicted = BumpPredict.predicted(a, b)
	if outcome.knockA > 0 then
		round:NoteHit(a, b)
		stagger:AddAmount(a, outcome.staggerA)
	end
	if outcome.knockA > 0 and not (predicted and Combatants.playerOf(a)) then
		self:Launch(
			a,
			-bump.lineX * outcome.knockA,
			-bump.lineZ * outcome.knockA,
			0,
			0,
			outcome.keepA
		)
	end
	if outcome.knockB > 0 then
		round:NoteHit(b, a)
		stagger:AddAmount(b, outcome.staggerB)
	end
	if outcome.knockB > 0 and not (predicted and Combatants.playerOf(b)) then
		self:Launch(
			b,
			bump.lineX * outcome.knockB,
			bump.lineZ * outcome.knockB,
			0,
			0,
			outcome.keepB
		)
	end
	self._bumpHappened:FireAllClients(a, b, math.floor(outcome.knockA), math.floor(outcome.knockB))
	if workspace:GetAttribute("HaymakerCombatDebug") then
		print(
			`[Combat] bump {a.Name} and {b.Name}, closing {math.floor(bump.closing)}, knocks {math.floor(
				outcome.knockA
			)} and {math.floor(outcome.knockB)}, stagger {outcome.staggerA} and {outcome.staggerB}`
		)
	end
end

-- Decides a qualified bump against the punches between the same two. Returns true once it's settled
-- (bumped or dropped), false while it has to wait.
local function settleBump(
	self: any,
	combat: any,
	a: Model,
	b: Model,
	bump: Deferred,
	now: number
): boolean
	local verdict = Combat.bumpPriority(
		combat:PunchPendingBetween(a, b),
		combat:HitBetweenSince(a, b, bump.at - cfg.BumpPunchGuard),
		now - bump.at < cfg.BumpHoldSeconds
	)
	if verdict == "wait" then
		return now - bump.at > cfg.BumpDeferMax
	elseif verdict == "drop" then
		if workspace:GetAttribute("HaymakerCombatDebug") then
			print(`[Combat] bump {a.Name} and {b.Name} dropped: a punch landed on the same impact`)
		end
		return true
	end
	if eligible(combat, a, b) then
		applyBump(self, a, b, bump)
	end
	return true
end

function KnockbackService:_checkBumps()
	local audit = Knit.GetService("SpeedAuditService")
	local combat = Knit.GetService("CombatService")
	local list = Combatants.all()
	local now = os.clock()
	local alive: { [Model]: boolean } = {}
	for _, model in list do
		alive[model] = true
	end
	for i = 1, #list do
		local first = list[i]
		for j = i + 1, #list do
			local second = list[j]
			-- A fixed order per pair, so its remembered state is found from either side.
			local a, b = first, second
			if bumpPairs[second] and bumpPairs[second][first] then
				a, b = second, first
			end
			local rootA, rootB = Combatants.rootOf(a), Combatants.rootOf(b)
			if not rootA or not rootB then
				continue
			end
			local offset = rootB.Position - rootA.Position
			local ax, az = velocityOf(audit, a, rootA)
			local bx, bz = velocityOf(audit, b, rootB)
			local state = pairState(a, b)
			local nextState, closing =
				Combat.stepBumpPair(cfg, state, offset.X, offset.Z, ax - bx, az - bz, now)
			bumpPairs[a][b] = nextState
			if
				closing
				and math.abs(offset.Y) <= cfg.BumpVerticalLimit
				and eligible(combat, a, b)
			then
				local lineX, lineZ = Combat.bumpDirection(
					rootA.Position.X,
					rootA.Position.Z,
					ax,
					az,
					rootB.Position.X,
					rootB.Position.Z,
					bx,
					bz
				)
				local bump: Deferred = {
					at = now,
					closing = closing,
					lineX = lineX,
					lineZ = lineZ,
					ax = ax,
					az = az,
					bx = bx,
					bz = bz,
				}
				if not settleBump(self, combat, a, b, bump, now) then
					deferred[a] = deferred[a] or {}
					deferred[a][b] = bump
				end
			elseif closing then
				-- Came into contact while unable to bump: that contact is spent, as if it had bumped.
				nextState.lastBump = state.lastBump
			end
		end
	end
	-- Bumps waiting on a swing between the same two.
	for a, waiting in deferred do
		for b, bump in waiting do
			if not alive[a] or not alive[b] or settleBump(self, combat, a, b, bump, now) then
				waiting[b] = nil
			end
		end
		if next(waiting) == nil then
			deferred[a] = nil
		end
	end
	for model in bumpPairs do
		if not alive[model] and model.Parent == nil then
			bumpPairs[model] = nil
		end
	end
	for _, forModel in bumpPairs do
		for other in forModel do
			if other.Parent == nil then
				forModel[other] = nil
			end
		end
	end
end

function KnockbackService:KnitInit()
	self._remote = Net.server("Knockback")
	self._bumpHappened = Net.server("BumpHappened")
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end

function KnockbackService:KnitStart()
	local function onCharacter(character: Model)
		self:RegisterBody(character)
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

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= BUMP_CHECK_SECONDS then
			elapsed = 0
			self:_checkBumps()
		end
	end)
end

return KnockbackService
