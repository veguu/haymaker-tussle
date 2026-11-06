--!strict
-- DummyService - passive R6 bodies to practise on. TrainingService says where they go. The server owns
-- them, so their movement and knockback run here, on the same Momentum rules as players, and they're
-- tagged as combatants, so punches, stagger and kicks treat them exactly as they treat a person.
--
-- They never attack. There is no brain, no target and no way for one to throw a punch. The most a dummy
-- ever does by itself is walk a marked path and go home.
--
-- Going home waits for a launch, a kick, a bounce or a combo to finish: see TrainingLayout.shouldReset.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AirRecovery = require(ReplicatedStorage.Shared.Core.AirRecovery)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local Momentum = require(ReplicatedStorage.Shared.Core.Momentum)
local TrainingLayout = require(ReplicatedStorage.Shared.Core.TrainingLayout)
local Combatants = require(script.Parent.Parent.Combatants)

local moveCfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local trainingCfg: any = GameConfig.Training
local HOME_TOLERANCE = 0.5
local PATROL_ARRIVE = 1.5
local LABEL_DISTANCE = 140

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
	toB: boolean,
	align: AlignOrientation,
	tracks: { [string]: AnimationTrack },
	clip: string?,
	label: TextLabel?,
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
	label.Font = Enum.Font.GothamBold
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
	Knit.GetService("StaggerService"):Set(dummy.model, dummy.spec.startStagger, true)
	self.DummyReset:Fire(dummy.model)
end

--- Builds a dummy where the spec says. This takes a moment, because Roblox builds the rig.
function DummyService:Spawn(spec: Spec): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = PHYSICS_COLOUR
	description.TorsoColor = PHYSICS_COLOUR
	description.LeftArmColor = PHYSICS_COLOUR
	description.RightArmColor = PHYSICS_COLOUR
	description.LeftLegColor = PHYSICS_COLOUR
	description.RightLegColor = PHYSICS_COLOUR
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	description:Destroy()
	model.Name = spec.name
	model:SetAttribute(Combatants.DUMMY_ATTRIBUTE, true)
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
	}
	dummies[model] = dummy
	applyStationary(dummy, spec.stationary == true)
	Knit.GetService("StaggerService"):Set(model, spec.startStagger, true)
	return model
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
	local stunned = dummy.model:GetAttribute("HT_Stunned") ~= nil
	local busy = air ~= nil or stunned or (not grounded and not dummy.stationary)
	if busy then
		dummy.busySince = dummy.busySince or now
	else
		dummy.busySince = nil
	end
	local patrol = dummy.spec.patrol
	if
		TrainingLayout.shouldReset(trainingCfg, {
			fell = root.Position.Y < trainingCfg.CenterY - trainingCfg.FallDepth,
			busy = busy,
			busyFor = if dummy.busySince then now - dummy.busySince else 0,
			displaced = patrol == nil
				and (root.Position - dummy.spec.home.Position).Magnitude > HOME_TOLERANCE,
			sinceHit = now - dummy.lastHit,
			requested = dummy.requested,
		}, dummy.spec.resetSeconds)
	then
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
	dummy.state = Momentum.step(dummy.state, moveCfg, 0, 0, grounded or air == "float", dt)
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
	local x, z = Momentum.velocity(
		dummy.state,
		Combat.staggerSpeedShare(GameConfig.Stagger, dummy.model:GetAttribute("HT_Stagger") or 0)
	)
	if grounded then
		dummy.slammed = false
	end
	if air == "float" then
		root.AssemblyLinearVelocity = Vector3.new(
			x,
			AirRecovery.fallVelocity(
				GameConfig.AirRecovery,
				workspace.Gravity,
				kickCfg.AirGravityScale,
				root.AssemblyLinearVelocity.Y,
				dt
			),
			z
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

function DummyService:KnitStart()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for model, dummy in dummies do
			local root = Combatants.rootOf(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and model.Parent then
				stepDummy(self, dummy, root, humanoid, now, dt)
				playClip(dummy, humanoid.FloorMaterial ~= Enum.Material.Air)
			else
				-- Never left permanently broken: a new body takes over the same spot.
				dummies[model] = nil
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