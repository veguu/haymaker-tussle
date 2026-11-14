--!strict
-- DummyService - server-owned R6 bodies. Their movement and knockback run here, on the same Momentum
-- rules as players, and they're tagged as combatants, so punches, stagger and kicks treat them exactly as
-- they treat a person.
--
-- Training dummies are passive: TrainingService gives them no brain, and the most one ever does by itself
-- is walk a marked path and go home.
--
-- The one exception is the 1v1 arena's test bot, made here when exactly one player is in the server. Its
-- spec has `fights`, so Core/BotBrain pushes a stick and presses punch, and everything after that is the
-- normal movement and combat rules. It only chases players who've finished the tutorial.
--
-- FILL BOTS (Round.BotFill, a test of a full round): the same brain, but they fight the nearest fighter in
-- the round (player or bot), only while they're in it (tagged HT_Fighter, not held, not out). They wait
-- along the lobby's viewing edge, never go home on their own, and are removed - not rebuilt - when they
-- fall out or the round ends. RoundService spawns and clears them.
--
-- Going home waits for a launch, a kick, a bounce or a combo to finish: see TrainingLayout.shouldReset.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AirRecovery = require(ReplicatedStorage.Shared.Core.AirRecovery)
local ActiveArena = require(ReplicatedStorage.Shared.ActiveArena)
local BotBrain = require(ReplicatedStorage.Shared.Core.BotBrain)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local DiveKick = require(ReplicatedStorage.Shared.Core.DiveKick)
local Momentum = require(ReplicatedStorage.Shared.Core.Momentum)
local Net = require(ReplicatedStorage.Shared.Net)
local Round = require(ReplicatedStorage.Shared.Core.Round)
local Pond = require(ReplicatedStorage.Shared.Core.Pond)
local TrainingLayout = require(ReplicatedStorage.Shared.Core.TrainingLayout)
local Combatants = require(script.Parent.Parent.Combatants)

local moveCfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local trainingCfg: any = GameConfig.Training
local botCfg = GameConfig.TestBot
local punchCfg = GameConfig.Punch
local arena = GameConfig.Arena
local ARENA_CENTER = Vector3.new(arena.CenterX, arena.CenterY, arena.CenterZ)
-- Players spawn at the 1v1 arena's centre facing -Z, so this is straight ahead, a short run away.
local BOT_SPOT = Vector3.new(0, 3, -12)
local HOME_TOLERANCE = 0.5
local PATROL_ARRIVE = 1.5
local LABEL_DISTANCE = 140
local FIGHTER_TAG = "HT_Fighter" -- RoundService's tag for everyone still in the round
local FILL_ATTRIBUTE = "HT_FillBot"
-- BOTS FROZEN (workspace attribute, set only by the owner's Bots button): every bot stops where it is - no
-- walking, no punching - so the map can be looked at in peace. Physics still applies (a flying bot lands).
local FROZEN_ATTRIBUTE = "HT_BotsFrozen"
local PARK_DROP = Vector3.new(0, 600, 0) -- how far below its home the arena's bot waits between rounds
local CAN_FREEZE_ATTRIBUTE = "HT_CanFreezeBots" -- on a player: they may press the Bots button
local FREEZE_TOGGLE_SECONDS = 0.3

local PHYSICS_COLOUR = Color3.fromRGB(255, 140, 40)
local STATIONARY_COLOUR = Color3.fromRGB(150, 205, 255)

-- The stock R6 clips Roblox's Animate script plays on players. Tracks play on the server so every
-- client sees them.
local CLIPS = { Idle = 180435571, Run = 180426354, Fall = 180436148 }
local CLIP_FADE = 0.15
local RUN_CLIP_SPEED = 14.5 -- the stock script plays the run clip at speed / 14.5

export type Patrol = { ax: number, az: number, bx: number, bz: number, speed: number }

export type Spec = {
	name: string,
	home: CFrame,
	startStagger: number,
	resetSeconds: number,
	stationary: boolean?,
	patrol: Patrol?,
	fights: boolean?, -- the test bot: chases and punches players
	fill: boolean?, -- a fill bot: fights anyone in the round, removed when out
	colour: Color3?,
	fallY: number?, -- below this it goes home; the training fall line if left out
}

type Dummy = {
	spec: Spec,
	model: Model,
	state: Momentum.State,
	lastHit: number,
	busySince: number?,
	requested: boolean,
	slammed: boolean?,
	stationary: boolean,
	parked: boolean?, -- held out of sight while there's no arena (the arena's own bot, between rounds)
	toB: boolean,
	align: AlignOrientation,
	tracks: { [string]: AnimationTrack },
	clip: string?,
	label: TextLabel?,
	steerX: number,
	steerZ: number,
	reachSince: number?,
	lastPunch: number?,
	judged: any?,
	clashSpot: Vector3?,
}

local DummyService = Knit.CreateService({
	Name = "DummyService",
})

local dummies: { [Model]: Dummy } = {}

local function freshState(home: CFrame): Momentum.State
	local look = home.LookVector
	return Momentum.new(look.X, look.Z)
end

function DummyService:ApplyKnockback(
	model: Model,
	x: number,
	z: number,
	up: number,
	airUp: number,
	speedKeep: number?
)
	local dummy = dummies[model]
	local root = Combatants.rootOf(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not dummy or not root or not humanoid then
		return
	end
	dummy.lastHit = os.clock()
	if dummy.stationary then
		return
	end
	dummy.state = Momentum.applyKnock(dummy.state, moveCfg, x, z, speedKeep)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local current = root.AssemblyLinearVelocity
	-- A negative air lift is a slam: it drives them down rather than adding to their rise. None at all
	-- leaves the fall as it was, so a hit never holds anyone up.
	local rise = if grounded
		then math.max(current.Y, up)
		elseif airUp < 0 then airUp
		elseif airUp == 0 then current.Y
		else math.max(current.Y, airUp)
	if airUp < 0 and not grounded then
		dummy.slammed = true
	elseif airUp > 0 then
		dummy.slammed = false
	end
	-- A grounded Humanoid holds itself to the floor, which would cancel the lift.
	if rise > 1 then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	-- All the knock it has, not just this hit's: a bounce adds lift, and must not stop it dead.
	local flatX, flatZ = Momentum.velocity(dummy.state)
	root.AssemblyLinearVelocity = Vector3.new(flatX, rise, flatZ)
end

local function loadTracks(humanoid: Humanoid): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in CLIPS do
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{id}`
		local track = (animator :: Animator):LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Core
		track.Looped = true
		tracks[name] = track
	end
	return tracks
end

-- Puts the root part exactly here. A rig's pivot isn't at its root, so pivoting straight to
-- this spot would sink the body into the floor until the Humanoid lifted it back out.
local function placeAt(model: Model, spot: CFrame)
	local root = Combatants.rootOf(model)
	local rootToPivot = if root
		then root.CFrame:ToObjectSpace(model:GetPivot())
		else CFrame.identity
	model:PivotTo(spot * rootToPivot)
end

local function paint(model: Model, colour: Color3)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = colour
		end
	end
end

local function labelText(dummy: Dummy): string
	return if dummy.stationary
		then `{dummy.spec.name}\nSTATIONARY, NO KNOCKBACK`
		else dummy.spec.name
end

local function addLabel(model: Model): TextLabel?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local board = Instance.new("BillboardGui")
	board.Name = "HT_DummyName"
	board.Size = UDim2.fromOffset(190, 40)
	board.StudsOffset = Vector3.new(0, 4.1, 0)
	board.MaxDistance = LABEL_DISTANCE
	board.AlwaysOnTop = true
	board.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 225, 150)
	label.TextStrokeTransparency = 0.3
	Typography.apply(label, "World")
	label.TextSize = 15
	label.TextWrapped = true
	label.Parent = board
	board.Parent = head
	return label
end

local function applyStationary(dummy: Dummy, on: boolean)
	local root = Combatants.rootOf(dummy.model)
	dummy.stationary = on
	dummy.model:SetAttribute(Combatants.STATIONARY_ATTRIBUTE, if on then true else nil)
	paint(dummy.model, if on then STATIONARY_COLOUR else PHYSICS_COLOUR)
	if dummy.label then
		dummy.label.Text = labelText(dummy)
	end
	if root then
		root.Anchored = on
		if not on then
			root:SetNetworkOwner(nil)
		end
	end
end

-- Back to the start, with nothing left over from whatever it was doing.
local function sendHome(self: any, dummy: Dummy)
	local root = Combatants.rootOf(dummy.model)
	local humanoid = dummy.model:FindFirstChildOfClass("Humanoid")
	Knit.GetService("KickService"):Release(dummy.model)
	if root then
		if not root.Anchored then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		placeAt(dummy.model, dummy.spec.home)
	end
	if humanoid and not dummy.stationary then
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	dummy.state = freshState(dummy.spec.home)
	dummy.slammed = false
	dummy.requested = false
	dummy.busySince = nil
	dummy.toB = true
	dummy.lastHit = 0
	dummy.align.CFrame = dummy.spec.home.Rotation
	dummy.steerX, dummy.steerZ = 0, 0
	dummy.clashSpot = nil
	Knit.GetService("ClashService"):EndFor(dummy.model, "fell")
	Knit.GetService("StaggerService"):Set(dummy.model, dummy.spec.startStagger, true)
	self.DummyReset:Fire(dummy.model)
end

--- Builds a dummy where the spec says. This takes a moment, because Roblox builds the rig.
function DummyService:Spawn(spec: Spec): Model
	local description = Instance.new("HumanoidDescription")
	local body = spec.colour or PHYSICS_COLOUR
	description.HeadColor = if spec.colour then Color3.fromRGB(245, 205, 170) else PHYSICS_COLOUR
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = body:Lerp(Color3.new(0, 0, 0), 0.35)
	description.RightLegColor = body:Lerp(Color3.new(0, 0, 0), 0.35)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	description:Destroy()
	model.Name = spec.name
	model:SetAttribute(Combatants.DUMMY_ATTRIBUTE, true)
	if spec.fights and not spec.fill then
		model:SetAttribute(Combatants.BOT_ATTRIBUTE, true)
	end
	if spec.fill then
		model:SetAttribute(FILL_ATTRIBUTE, true)
	end
	placeAt(model, spec.home)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Parent = workspace
	local root = model:WaitForChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil)

	-- Body facing follows the heading, the same way a player's does.
	local attachment = Instance.new("Attachment")
	attachment.Name = "HT_Facing"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "HT_Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = moveCfg.FacingResponsiveness
	align.CFrame = spec.home.Rotation
	align.Parent = root

	Knit.GetService("KnockbackService"):RegisterBody(model)
	CollectionService:AddTag(model, Combatants.TAG)
	local dummy: Dummy = {
		spec = spec,
		model = model,
		state = freshState(spec.home),
		lastHit = 0,
		requested = false,
		stationary = false,
		toB = true,
		align = align,
		tracks = loadTracks(humanoid),
		label = addLabel(model),
		steerX = 0,
		steerZ = 0,
	}
	dummies[model] = dummy
	applyStationary(dummy, spec.stationary == true)
	Knit.GetService("StaggerService"):Set(model, spec.startStagger, true)
	return model
end

--- Puts a dummy somewhere at once, facing that way, with nothing left over from what it was doing. For a
--- round putting the bot on a spawn. Its home doesn't change: falling or a reset still sends it home.
function DummyService:PlaceAt(model: Model, spot: CFrame)
	local dummy = dummies[model]
	if not dummy then
		return
	end
	local home = dummy.spec.home
	dummy.spec.home = spot
	sendHome(self, dummy)
	dummy.spec.home = home
end

--- Asks a dummy to go home as soon as it safely can.
function DummyService:RequestReset(model: Model)
	local dummy = dummies[model]
	if dummy then
		dummy.requested = true
	end
end

--- A stationary target doesn't move for anything. The same dummy can be switched to a normal one.
function DummyService:SetStationary(model: Model, on: boolean)
	local dummy = dummies[model]
	if dummy and dummy.stationary ~= on then
		applyStationary(dummy, on)
		dummy.spec.stationary = on
		sendHome(self, dummy)
	end
end

function DummyService:IsStationary(model: Model): boolean
	local dummy = dummies[model]
	return dummy ~= nil and dummy.stationary
end

--- Walking speed along its marked path.
function DummyService:SetPatrolSpeed(model: Model, speed: number)
	local dummy = dummies[model]
	if dummy and dummy.spec.patrol then
		dummy.spec.patrol.speed = speed
	end
end

local function playClip(dummy: Dummy, grounded: boolean)
	local state = dummy.state
	local name = "Idle"
	if not grounded or state.knockX then
		name = "Fall"
	elseif state.speed > moveCfg.RestSnapSpeed then
		name = "Run"
	end
	if dummy.clip ~= name then
		if dummy.clip then
			dummy.tracks[dummy.clip]:Stop(CLIP_FADE)
		end
		dummy.tracks[name]:Play(CLIP_FADE)
		dummy.clip = name
	end
	if name == "Run" then
		dummy.tracks.Run:AdjustSpeed(state.speed / RUN_CLIP_SPEED)
	end
end

function DummyService:KnitInit()
	self.DummyReset = Instance.new("BindableEvent")
end

-- The nearest player standing on the floor with the bot, who's finished the tutorial.
local function nearestPlayer(root: BasePart): BasePart?
	local tutorial = Knit.GetService("TutorialService")
	local training = Knit.GetService("TrainingService")
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local other = character and Combatants.isAlive(character) and Combatants.rootOf(character)
		if
			other
			and tutorial:IsReady(player)
			and not training:IsIn(player)
			and math.abs(other.Position.Y - root.Position.Y) <= punchCfg.VerticalLimit
		then
			local distance = (other.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- A fill bot's target: the nearest other fighter still in the round, at punching height.
local function nearestFighter(root: BasePart, self: Model): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, model in CollectionService:GetTagged(FIGHTER_TAG) do
		if model ~= self and model:IsA("Model") and model:GetAttribute("HT_Eliminated") == nil then
			local other = Combatants.isAlive(model) and Combatants.rootOf(model)
			if other and math.abs(other.Position.Y - root.Position.Y) <= punchCfg.VerticalLimit then
				local distance = (other.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

-- The nearest player anywhere, at any height: who to get away from when launched.
local function nearestInAir(root: BasePart): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local other = character and Combatants.isAlive(character) and Combatants.rootOf(character)
		if other then
			local distance = (other.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

-- One moment of thought: returns the stick direction, and presses punch if it's time.
--
-- It's beatable the way a person is. It sees where the target was a moment ago, so moving
-- makes it swing at where you were. It guesses reach differently each swing, so it sometimes
-- swings too early. It doesn't predict or track during the windup, so a sidestep dodges.
local function think(dummy: Dummy, root: BasePart, now: number): (number, number)
	local target = if dummy.spec.fill
		then nearestFighter(root, dummy.model)
		else nearestPlayer(root)
	local position = root.Position
	local seen: Vector3? = nil
	if target then
		local model = target.Parent
		local lagged = if model and model:IsA("Model")
			then Knit.GetService("SpeedAuditService"):PositionAt(model, botCfg.TrackingLag)
			else nil
		seen = lagged or target.Position
	end
	-- the live map's oval and obstacles: the edge it won't run off, and the rocks it goes round
	local live = ActiveArena.get()
	local semiX, semiZ = Round.semiAxes(live)
	local inputX, inputZ = BotBrain.steer(
		botCfg,
		live.StartRadius,
		position.X - ARENA_CENTER.X,
		position.Z - ARENA_CENTER.Z,
		if seen then seen.X - ARENA_CENTER.X else nil,
		if seen then seen.Z - ARENA_CENTER.Z else nil,
		{ semiX = semiX, semiZ = semiZ, obstacles = live.Obstacles }
	)

	local inReach = false
	local noticed = false
	if seen then
		noticed = (seen - position).Magnitude <= botCfg.NoticeDistance
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if noticed and flat.Magnitude > 0.001 then
			flat = flat.Unit
			inReach = Combat.inHitbox(
				dummy.judged or punchCfg,
				position.X,
				position.Y,
				position.Z,
				flat.X,
				flat.Z,
				seen.X,
				seen.Y,
				seen.Z
			)
		end
	end
	if not noticed then
		dummy.reachSince = nil
	elseif not dummy.reachSince then
		dummy.reachSince = now
	end
	if inReach and BotBrain.shouldPunch(botCfg, now, dummy.reachSince, dummy.lastPunch) then
		dummy.lastPunch = now
		dummy.judged = BotBrain.judgedPunch(punchCfg, botCfg.MisjudgeStuds, math.random())
		Knit.GetService("CombatService")
			:PunchAs(dummy.model, BotBrain.isWildSwing(botCfg, math.random()))
	end
	return inputX, inputZ
end

-- Should the bot fight right now? Only if someone is ready to be fought.
local function shouldFight(): boolean
	-- The attribute is for work/test-harness, which needs it to punch only on cue.
	if not botCfg.Fights or workspace:GetAttribute("HT_TestBotQuiet") then
		return false
	end
	local tutorial = Knit.GetService("TutorialService")
	for _, player in Players:GetPlayers() do
		if tutorial:IsReady(player) then
			return true
		end
	end
	return false
end

local function stepDummy(
	self: any,
	dummy: Dummy,
	root: BasePart,
	humanoid: Humanoid,
	now: number,
	dt: number
)
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local air = dummy.model:GetAttribute("HT_Air")
	-- Held on a round's spawn through the countdown, or out of the round: it stands still and leaves
	-- everyone alone.
	local held = dummy.model:GetAttribute("HT_RoundHold") ~= nil
	local stunned = dummy.model:GetAttribute("HT_Stunned") ~= nil or held
	local inRound = CollectionService:HasTag(dummy.model, FIGHTER_TAG)
	local fighting = dummy.spec.fights == true
		and (if dummy.spec.fill
			then inRound and botCfg.Fights and not workspace:GetAttribute("HT_TestBotQuiet")
			else shouldFight())
		and not held
		and dummy.model:GetAttribute("HT_Eliminated") == nil

	-- In a clash: walks to the spot it was given and holds there, looking at the other fighter.
	local clashAt = dummy.model:GetAttribute("HT_ClashAt") :: Vector3?
	if clashAt then
		local face = dummy.model:GetAttribute("HT_ClashFace") :: Vector3?
		if face then
			dummy.state = Momentum.new(face.X, face.Z)
			dummy.align.CFrame = CFrame.lookAt(Vector3.zero, face)
		end
		local offset = Vector3.new(clashAt.X - root.Position.X, 0, clashAt.Z - root.Position.Z)
		-- It gets there once, then stays. A server-run Humanoid overshoots, and chasing the spot
		-- again from the far side only makes it swing further each time.
		local walk = if dummy.clashSpot == clashAt
			then 0
			else Clash.alignSpeed(GameConfig.Clash, offset.Magnitude)
		if walk == 0 and dummy.clashSpot ~= clashAt then
			dummy.clashSpot = clashAt
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		end
		humanoid.WalkSpeed = walk
		humanoid:Move(if walk > 0 then offset.Unit else Vector3.zero, false)
		dummy.lastHit = now
		return
	end
	dummy.clashSpot = nil

	local busy = air ~= nil or stunned or (not grounded and not dummy.stationary)
	if busy then
		dummy.busySince = dummy.busySince or now
	else
		dummy.busySince = nil
	end
	local patrol = dummy.spec.patrol
	if
		TrainingLayout.shouldReset(trainingCfg, {
			fell = root.Position.Y
				< (dummy.spec.fallY or (trainingCfg.CenterY - trainingCfg.FallDepth)),
			busy = busy,
			busyFor = if dummy.busySince then now - dummy.busySince else 0,
			-- A bot that's fighting is meant to be away from home.
			displaced = patrol == nil and not fighting and not dummy.spec.fill and (
				root.Position - dummy.spec.home.Position
			).Magnitude > HOME_TOLERANCE,
			sinceHit = now - dummy.lastHit,
			requested = dummy.requested,
		}, dummy.spec.resetSeconds)
	then
		if dummy.spec.fill then
			-- out for good: the round hears it (DummyReset), then the body goes
			if root.Position.Y < (dummy.spec.fallY or -math.huge) and dummies[dummy.model] then
				dummies[dummy.model] = nil
				self.DummyReset:Fire(dummy.model)
				local model = dummy.model
				task.delay(1, function()
					model:Destroy()
				end)
			end
			return
		end
		sendHome(self, dummy)
		return
	end
	-- Stagger goes back too once it has stood still: a target that hasn't moved can still have been hit.
	if
		dummy.stationary
		and dummy.lastHit > 0
		and now - dummy.lastHit >= dummy.spec.resetSeconds
	then
		sendHome(self, dummy)
		return
	end
	if dummy.stationary then
		return
	end

	-- A launched body loses its push at the same rate as on the floor, so an uppercut
	-- carries as far as any other hit of that strength.
	local inputX, inputZ = 0, 0
	if fighting and not air and not stunned then
		inputX, inputZ = think(dummy, root, now)
	end
	if air ~= "float" then
		dummy.steerX, dummy.steerZ = 0, 0
	elseif fighting and botCfg.AirSteers then
		-- Launched, it tries to get away from whoever is nearest, like a person would.
		local nearest = if dummy.spec.fill
			then nearestFighter(root, dummy.model)
			else nearestInAir(root)
		if nearest then
			local away = Vector3.new(
				root.Position.X - nearest.Position.X,
				0,
				root.Position.Z - nearest.Position.Z
			)
			if away.Magnitude > 0.01 then
				local share = DiveKick.launchSteerShare(
					kickCfg,
					dummy.model:GetAttribute("HT_Stagger") or 0,
					GameConfig.Stagger.Max
				)
				dummy.steerX, dummy.steerZ = DiveKick.airSteer(
					dummy.steerX,
					dummy.steerZ,
					away.Unit.X,
					away.Unit.Z,
					kickCfg.LaunchSteerSpeed * share * botCfg.AirSteerShare,
					kickCfg.LaunchSteerAcceleration * share,
					dt
				)
			end
		end
	end
	dummy.state =
		Momentum.step(dummy.state, moveCfg, inputX, inputZ, grounded or air == "float", dt)
	if air == "hold" then
		dummy.lastHit = now
		dummy.state = Momentum.stopped(dummy.state)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	-- The marked path carries on once a hit has run its course. It's only ever the path.
	if
		patrol
		and patrol.speed > 0
		and grounded
		and air == nil
		and not stunned
		and not dummy.state.knockX
		and now - dummy.lastHit >= trainingCfg.Patrol.ResumeSeconds
	then
		local toB, dirX, dirZ = TrainingLayout.patrolStep(
			root.Position.X,
			root.Position.Z,
			patrol.ax,
			patrol.az,
			patrol.bx,
			patrol.bz,
			dummy.toB,
			PATROL_ARRIVE
		)
		dummy.toB = toB
		dummy.state = Momentum.moving(dummy.state, dirX, dirZ, patrol.speed)
	elseif patrol and patrol.speed <= 0 and not dummy.state.knockX then
		dummy.state = Momentum.stopped(dummy.state)
	end
	local pondCfg: any = GameConfig.Pond
	local live = ActiveArena.get()
	local wade = if pondCfg.Enabled
		then Pond.speedShare(
			live.Pond,
			pondCfg.SpeedMultiplier,
			pondCfg.MaxRootAboveFloor,
			root.Position.X - live.CenterX,
			root.Position.Z - live.CenterZ,
			root.Position.Y - live.CenterY
		)
		else 1
	local x, z = Momentum.velocity(
		dummy.state,
		Combat.staggerSpeedShare(GameConfig.Stagger, dummy.model:GetAttribute("HT_Stagger") or 0)
			* wade
	)
	if grounded then
		dummy.slammed = false
	end
	if air == "float" then
		root.AssemblyLinearVelocity = Vector3.new(
			x + dummy.steerX,
			AirRecovery.fallVelocity(
				GameConfig.AirRecovery,
				workspace.Gravity,
				kickCfg.AirGravityScale,
				root.AssemblyLinearVelocity.Y,
				dt
			),
			z + dummy.steerZ
		)
	elseif air == nil and not grounded and not dummy.slammed and not stunned then
		-- The same fall as a player's, so a launch looks the same on it.
		local moving = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(
			moving.X,
			AirRecovery.fallVelocity(GameConfig.AirRecovery, workspace.Gravity, 1, moving.Y, dt),
			moving.Z
		)
	end
	local speed = math.sqrt(x * x + z * z)
	humanoid.WalkSpeed = speed
	humanoid:Move(if speed > 0.01 then Vector3.new(x, 0, z) / speed else Vector3.zero, false)
	dummy.align.CFrame =
		CFrame.lookAt(Vector3.zero, Vector3.new(dummy.state.headingX, 0, dummy.state.headingZ))
	local face = dummy.model:GetAttribute("HT_HoldFace") :: Vector3?
	if air == "hold" and face then
		dummy.align.CFrame = CFrame.lookAt(Vector3.zero, face)
	end
end

--- Builds fill bots at these spots (they wait there until a round places them). Yields while the rigs are
--- built. `colours` cycles.
function DummyService:SpawnFill(
	spots: { CFrame },
	colours: { Color3 },
	startIndex: number
): { Model }
	local made: { Model } = {}
	for i, spot in spots do
		local n = startIndex + i - 1
		table.insert(
			made,
			self:Spawn({
				name = `Bot {n}`,
				home = spot,
				startStagger = 0,
				resetSeconds = botCfg.ReturnSeconds,
				fights = true,
				fill = true,
				colour = colours[(n - 1) % #colours + 1],
				fallY = arena.CenterY - arena.EliminationDepth,
			})
		)
	end
	return made
end

--- Every fill bot that's still here.
function DummyService:FillBots(): { Model }
	local list: { Model } = {}
	for model, dummy in dummies do
		if dummy.spec.fill and model.Parent then
			table.insert(list, model)
		end
	end
	return list
end

--- Removes every fill bot (a round has ended).
function DummyService:ClearFill()
	for model, dummy in dummies do
		if dummy.spec.fill then
			dummies[model] = nil
			model:Destroy()
		end
	end
end

--- A fill bot's new home: where a round put it, so nothing ever sends it back to the lobby.
function DummyService:SetHome(model: Model, spot: CFrame)
	local dummy = dummies[model]
	if dummy and dummy.spec.fill then
		dummy.spec.home = spot
	end
end

--- Takes a body away for good, without it being rebuilt.
function DummyService:Remove(model: Model)
	dummies[model] = nil
	model:Destroy()
end

-- Studio, or the place's owners: group rank 254+ (the group's owner and its top admins), or the user who owns it.
local function mayFreeze(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank >= 254
	end
	return player.UserId == game.CreatorId
end

function DummyService:KnitStart()
	local freezeToggle = Net.server("BotsFreezeToggle")
	local lastFreeze: { [Player]: number } = {}
	local function grant(player: Player)
		if mayFreeze(player) then
			player:SetAttribute(CAN_FREEZE_ATTRIBUTE, true)
		end
	end
	Players.PlayerAdded:Connect(grant)
	for _, player in Players:GetPlayers() do
		task.spawn(grant, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastFreeze[player] = nil
	end)
	freezeToggle.OnServerEvent:Connect(function(player: Player)
		if player:GetAttribute(CAN_FREEZE_ATTRIBUTE) ~= true then
			return
		end
		local now = os.clock()
		if now - (lastFreeze[player] or -math.huge) < FREEZE_TOGGLE_SECONDS then
			return
		end
		lastFreeze[player] = now
		workspace:SetAttribute(
			FROZEN_ATTRIBUTE,
			if workspace:GetAttribute(FROZEN_ATTRIBUTE) then nil else true
		)
	end)

	-- The 1v1 arena's bot is only for someone alone in the server. Anyone else has real people to fight.
	if GameConfig.Debug.TestFloor then
		local bot: Model? = nil
		local building = false
		local function syncBot()
			local alone = #Players:GetPlayers() == 1 and botCfg.Enabled
			if not alone and bot then
				self:Remove(bot)
				bot = nil
			elseif alone and not bot and not building then
				building = true
				task.spawn(function()
					local position = ARENA_CENTER + BOT_SPOT
					bot = self:Spawn({
						name = "TestBot1",
						home = CFrame.lookAt(position, position + Vector3.zAxis),
						startStagger = 0,
						resetSeconds = botCfg.ReturnSeconds,
						fights = true,
						fallY = arena.CenterY - arena.EliminationDepth,
					})
					building = false
					-- Building takes a moment, and someone may have joined meanwhile.
					if #Players:GetPlayers() ~= 1 and bot then
						self:Remove(bot)
						bot = nil
					end
				end)
			end
		end
		Players.PlayerAdded:Connect(function()
			task.defer(syncBot)
		end)
		Players.PlayerRemoving:Connect(function()
			task.defer(syncBot)
		end)
		self.DummyReplaced.Event:Connect(function(old: Model, new: Model)
			if old == bot then
				bot = new
			end
		end)
		syncBot()
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local frozen = workspace:GetAttribute(FROZEN_ATTRIBUTE) == true
		local noArena = not ActiveArena.hasArena()
		for model, dummy in dummies do
			local root = Combatants.rootOf(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and model.Parent then
				-- A bot whose home is the arena (the Studio test bot) has nothing under it between rounds: it's
				-- held still, far below its home and out of sight, until an arena is back (then it's home
				-- again, or on the spawn the round gives it). Fill bots and practice dummies are never parked.
				local park = noArena and dummy.spec.fights == true and not dummy.spec.fill
				if park ~= (dummy.parked == true) then
					dummy.parked = park
					root.AssemblyLinearVelocity = Vector3.zero
					placeAt(model, if park then dummy.spec.home - PARK_DROP else dummy.spec.home)
					if not dummy.stationary then
						root.Anchored = park
						if not park then
							root:SetNetworkOwner(nil)
						end
					end
				end
				if frozen or dummy.parked then
					humanoid.WalkSpeed = 0
					humanoid:Move(Vector3.zero, false)
				else
					stepDummy(self, dummy, root, humanoid, now, dt)
				end
				playClip(dummy, humanoid.FloorMaterial ~= Enum.Material.Air)
			else
				-- Never left permanently broken: a new body takes over the same spot. (A fill bot is just
				-- gone: the round already counts it out.)
				dummies[model] = nil
				if dummy.spec.fill then
					self.DummyReset:Fire(model)
					model:Destroy()
					continue
				end
				model:Destroy()
				task.spawn(function()
					local replacement = self:Spawn(dummy.spec)
					self.DummyReplaced:Fire(model, replacement)
				end)
			end
		end
	end)
end

DummyService.DummyReplaced = Instance.new("BindableEvent")

return DummyService
