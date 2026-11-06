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
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Net = require(ReplicatedStorage.Shared.Net)
local Combatants = require(script.Parent.Parent.Combatants)

local cfg = GameConfig.Knockback
local staggerCfg = GameConfig.Stagger
local COLLISION_GROUP = "HT_Characters"
-- Short enough that two full-speed runners can't pass through the bump distance unseen.
local BUMP_CHECK_SECONDS = 0.05

local KnockbackService = Knit.CreateService({
	Name = "KnockbackService",
})

local bumpTimes: { [Model]: { [Model]: number } } = {}

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

local function pairOnCooldown(a: Model, b: Model, now: number): boolean
	local forA = bumpTimes[a]
	local last = forA and forA[b]
	return last ~= nil and now - last < cfg.BumpPairCooldown
end

local function markPair(a: Model, b: Model, now: number)
	bumpTimes[a] = bumpTimes[a] or {}
	bumpTimes[b] = bumpTimes[b] or {}
	bumpTimes[a][b] = now
	bumpTimes[b][a] = now
end

function KnockbackService:_checkBumps()
	local audit = Knit.GetService("SpeedAuditService")
	local combat = Knit.GetService("CombatService")
	local list = Combatants.all()
	local now = os.clock()
	for i = 1, #list do
		local a = list[i]
		local rootA = Combatants.rootOf(a)
		for j = i + 1, #list do
			local b = list[j]
			local rootB = Combatants.rootOf(b)
			if
				rootA
				and rootB
				and combat:CanFight(a, b)
				and not pairOnCooldown(a, b, now)
				and not a:GetAttribute("HT_Skill")
				and not b:GetAttribute("HT_Skill")
				and not a:GetAttribute("HT_Air")
				and not b:GetAttribute("HT_Air")
				and not a:GetAttribute("HT_Clash")
				and not b:GetAttribute("HT_Clash")
				and not a:GetAttribute(Combatants.STATIONARY_ATTRIBUTE)
				and not b:GetAttribute(Combatants.STATIONARY_ATTRIBUTE)
			then
				local offset = rootB.Position - rootA.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if
					flat.Magnitude <= cfg.BumpDistance
					and math.abs(offset.Y) <= cfg.BumpVerticalLimit
				then
					local ax, az = audit:GetVelocity(a)
					local bx, bz = audit:GetVelocity(b)
					local closing = Combat.closingSpeed(
						rootA.Position.X,
						rootA.Position.Z,
						ax,
						az,
						rootB.Position.X,
						rootB.Position.Z,
						bx,
						bz
					)
					if closing >= cfg.BumpMinClosingSpeed then
						markPair(a, b, now)
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
						local stagger = Knit.GetService("StaggerService")
						local outcome = Combat.bumpOutcome(
							cfg,
							staggerCfg,
							GameConfig.Movement.PropelSpeed,
							closing,
							ax,
							az,
							bx,
							bz
						)
						stagger:AddAmount(a, outcome.staggerA)
						stagger:AddAmount(b, outcome.staggerB)
						self:Launch(
							a,
							-lineX * outcome.knockA,
							-lineZ * outcome.knockA,
							0,
							0,
							cfg.BumpSpeedKeep
						)
						self:Launch(
							b,
							lineX * outcome.knockB,
							lineZ * outcome.knockB,
							0,
							0,
							cfg.BumpSpeedKeep
						)
						self._bumpHappened:FireAllClients(
							a,
							b,
							math.floor(outcome.knockA),
							math.floor(outcome.knockB)
						)
						if workspace:GetAttribute("HaymakerCombatDebug") then
							print(
								`[Combat] bump {a.Name} and {b.Name}, closing {math.floor(closing)}, knocks {math.floor(
									outcome.knockA
								)} and {math.floor(outcome.knockB)}, stagger {outcome.staggerA} and {outcome.staggerB}`
							)
						end
					end
				end
			end
		end
	end
	for model in bumpTimes do
		if model.Parent == nil then
			bumpTimes[model] = nil
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