--!strict
-- MovementController - runs the local character's momentum.
--
-- THE MODEL. This client owns and simulates its own character so movement is
-- instant. Core/Momentum decides speed and heading; the Humanoid is then told
-- exactly that with WalkSpeed and Move, so it keeps doing floor contact, gravity
-- and collisions and has nothing to fight. This is the only place that writes
-- WalkSpeed. The server will measure real speed itself and never asks for it.
--
-- Input comes from the stock PlayerModule (keyboard, thumbstick and gamepad),
-- layered on top rather than forked: its ControlModule hands every move to a
-- `moveFunction` field, so we replace that one field to receive the input
-- instead of moving the character. This controller is then the only Move caller.
-- That field is not a documented API, so a missing one warns loudly at startup.
--
-- Also here, because they all shape this one body's movement: Q's short, hard-to-steer burst
-- (Core/Momentum), the recovery lift on a punch thrown while falling off the edge (Core/AirRecovery),
-- and the follow-up snap (Core/DiveKick). A knock ends a burst and any recovery lift. The kick takes
-- the body over entirely until it's done.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AirRecovery = require(ReplicatedStorage.Shared.Core.AirRecovery)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local DiveKick = require(ReplicatedStorage.Shared.Core.DiveKick)
local Momentum = require(ReplicatedStorage.Shared.Core.Momentum)
local TrainingLayout = require(ReplicatedStorage.Shared.Core.TrainingLayout)
local Lobby = require(ReplicatedStorage.Shared.Core.Lobby)
local Net = require(ReplicatedStorage.Shared.Net)

local STEP_NAME = "HaymakerMovement"
local PROPEL_ACTION = "HaymakerPropel"
local KICK_ACTION = "HaymakerKick"
local STEP_PRIORITY = Enum.RenderPriority.Input.Value + 1
local INPUT_STALE_SECONDS = 0.25
local MIN_LIFT = 1 -- below this a knock isn't a lift, just the floor's own tiny motion
local LAND_CHECK_SECONDS = 0.25 -- a jump can't count as landed this soon
local PUSH_GRACE_SECONDS = 0.05 -- a body gets this long to catch up with its own push
local UNDO_SECONDS = 1 -- a refused punch's push is taken back only if the answer comes this soon

local cfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local airCfg = GameConfig.AirRecovery

local MovementController = Knit.CreateController({
	Name = "MovementController",
	-- Fires when the local player starts a propel.
	Propelled = Signal.new(),
	-- A propel press that the rules turned down (still cooling down, stunned, held). The HUD shows it
	-- without touching the cooldown it's already drawing.
	PropelBlocked = Signal.new(),
	-- What the HUD reads, written once per movement step from the real state. Never read back by
	-- movement itself. Times are os.clock().
	Hud = {
		speed = 0, -- real flat speed, studs/s, from the root's velocity
		propelLeft = 0, -- seconds of propel cooldown left
		kickReadyAt = 0,
		kickTarget = false, -- someone in the air this body could jump at right now
		kicking = false,
	},
})

type Input = { move: Vector3, cameraRelative: boolean, at: number }

local function worldInput(input: Input): (number, number)
	-- A stale input means the stock controls stopped reporting (disabled, or a
	-- menu): treat that as no input rather than running on forever.
	if os.clock() - input.at > INPUT_STALE_SECONDS then
		return 0, 0
	end
	local move = input.move
	if move.Magnitude < 0.001 then
		return 0, 0
	end
	if not input.cameraRelative then
		return move.X, move.Z
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return 0, 0
	end
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.001 then
		-- Camera pointing straight down or up: fall back to its up vector.
		local up = camera.CFrame.UpVector
		forward = Vector3.new(up.X, 0, up.Z)
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	-- Camera-relative input is -Z forward, +X right.
	local world = forward * -move.Z + right * move.X
	return world.X, world.Z
end

-- Works out W, S or A/D from the world direction, relative to where the camera
-- looks. Also returns how much of it points right (-1 left to +1 right).
local function driveOf(x: number, z: number): (Momentum.Drive, number)
	local camera = workspace.CurrentCamera
	local length = math.sqrt(x * x + z * z)
	if not camera or length < 0.001 then
		return "side", 0
	end
	local look = camera.CFrame.LookVector
	local flat = math.sqrt(look.X * look.X + look.Z * look.Z)
	if flat < 0.001 then
		return "forward", 0
	end
	local forwardX, forwardZ = look.X / flat, look.Z / flat
	local share = (x * forwardX + z * forwardZ) / length
	local side = (x * -forwardZ + z * forwardX) / length
	if share > cfg.ForwardInputThreshold then
		return "forward", side
	elseif share < -cfg.ForwardInputThreshold then
		return "back", side
	end
	return "side", side
end

-- Current Studio keeps the stock module directly under StarterPlayer; older places
-- copy it into PlayerScripts. Use whichever exists, and never make a second copy.
local function findPlayerModule(player: Player): any
	local playerScripts = player:WaitForChild("PlayerScripts")
	while true do
		local found = playerScripts:FindFirstChild("PlayerModule")
			or StarterPlayer:FindFirstChild("PlayerModule")
		if found then
			return found
		end
		task.wait(0.1)
	end
end

local function makeReadout(): TextLabel?
	if not GameConfig.Debug.MoveReadout then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_MoveReadout"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 8)
	label.Size = UDim2.fromOffset(340, 28)
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Parent = gui
	return label
end

local function hookInput(player: Player): Input
	local input: Input = { move = Vector3.zero, cameraRelative = false, at = 0 }
	local playerModule = findPlayerModule(player)
	local controlScript = playerModule:WaitForChild("ControlModule")
	local control: any = require(controlScript)
	if control.moveFunction == nil then
		warn("[Haymaker Tussle] ControlModule has no moveFunction; movement input will not work")
		return input
	end
	control.moveFunction = function(_player: Player, move: Vector3, cameraRelative: boolean?)
		input.move = move
		input.cameraRelative = cameraRelative == true
		input.at = os.clock()
	end
	return input
end

function MovementController:_bind(
	character: Model,
	input: Input,
	readout: TextLabel?,
	propelRemote: RemoteEvent?
)
	local trove = Trove.new()
	trove:AttachToInstance(character)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.AutoRotate = false
	if not cfg.JumpEnabled then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end

	-- Body facing follows the heading, so a turn is seen as a turn.
	local attachment = trove:Add(Instance.new("Attachment"))
	attachment.Name = "HT_Facing"
	attachment.Parent = root
	local align = trove:Add(Instance.new("AlignOrientation"))
	align.Name = "HT_Facing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.MaxAngularVelocity = math.huge
	align.Responsiveness = cfg.FacingResponsiveness
	align.Parent = root

	-- Lean is on the root joint for now, which only this client sees. The
	-- LeanLeft and LeanRight clips make it visible to everyone in the animation step.
	local rootJoint = root:FindFirstChild("RootJoint") :: Motor6D?
	local baseC0 = if rootJoint then rootJoint.C0 else CFrame.identity
	if rootJoint then
		trove:Add(function()
			rootJoint.C0 = baseC0
		end)
	end

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
	local state = Momentum.new(flat.X, flat.Z)
	local lean = 0
	local propelRequested = false
	-- Holding the propel key charges it: when the hold began, whether the key is still down, and whether
	-- the rules have had their say on it yet. The dash goes on release, or at a full charge.
	local chargeAt: number? = nil
	local chargeHeld = false
	local chargeChecked = false
	local knockGraceUntil = 0
	local kick: DiveKick.State? = nil
	local kickTarget: Model? = nil
	local kickRequested = false
	local kickAwaiting = false -- the timing is over, and waiting for the server's verdict
	local kickReadyAt = 0
	local steerX, steerZ = 0, 0 -- a launched body's own steering, on top of its push
	local speedShare = 1 -- how much of running speed stagger leaves
	-- After a missed jump or a kick's rebound: ordinary movement, but in the air.
	local airRun: { t: number, gravityScale: number, keep: number? }? = nil
	local wasSideSteering = false
	local airSeconds = 0 -- how long since the floor
	local pushX, pushZ = 0, 0 -- what punches thrown in the air are still pushing with
	local pushGraceUntil = 0
	local lift = 0 -- a punch's small lift, waiting for this step's velocity
	local punchRequested = false
	local punchIsUppercut = false -- only an uppercut gives the falling lift
	local lastPush: { x: number, z: number, up: number, at: number, lifted: boolean? }? = nil
	local slammed = false -- driven down by a kick, so its fall isn't lightened
	-- The falling lift: how many this fall, and until when its lighter gravity lasts.
	local lifts = AirRecovery.newLifts()
	local liftUntil = 0
	local liftSet = false -- this step sets the vertical speed to the lift's
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { character }
	local kickAccepted = false
	local kickSnap = false -- the server's word: the locked-on snap, or the slower guided leap
	local lockSent: Model? = nil
	local fx = Knit.GetController("FxController")
	local prompt = Knit.GetController("KickPromptController")
	local kickRemotes = {
		request = Net.client("KickRequest"),
		attach = Net.client("KickAttach"),
		commit = Net.client("KickCommit"),
		lockOn = Net.client("LockOnState"),
	}

	-- A charge that was building is dropped, along with what shows it.
	local function dropCharge()
		if chargeAt then
			chargeAt = nil
			fx:PropelCharge(character, nil)
		end
	end
	trove:Add(dropCharge)

	local function endKick()
		kick = nil
		kickTarget = nil
		kickAwaiting = false
		kickAccepted = false
		airRun = nil
		prompt:Hide()
	end
	trove:Add(endKick)

	-- Only solid parts count as being in the way; fighters never do.
	local function solidParams(): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = CollectionService:GetTagged("HT_Combatant")
		params.RespectCanCollide = true
		params.IgnoreWater = true
		return params
	end

	-- Who you can follow up, by the same rule the server uses: anyone floating within range with nothing
	-- solid in between, picked by distance and how far off where you face they are. The server makes
	-- the real pick and says so; this only decides whether to show the prompt.
	local function jumpTarget(position: Vector3): Model?
		local myId = Players.LocalPlayer.UserId
		local params = solidParams()
		local models: { Model } = {}
		local candidates: { DiveKick.Candidate } = {}
		for _, other in CollectionService:GetTagged("HT_Combatant") do
			local otherRoot = other:FindFirstChild("HumanoidRootPart") :: BasePart?
			if other ~= character and otherRoot and other:GetAttribute("HT_Air") == "float" then
				local at = otherRoot.Position
				local own = other:GetAttribute("HT_AirBy") == myId
				local range = if own then kickCfg.FollowUpOwnRange else kickCfg.FollowUpRange
				if
					(own or kickCfg.FollowUpOthers)
					and (at - position).Magnitude <= range
					and workspace:Raycast(position, at - position, params) == nil
				then
					table.insert(models, other :: Model)
					table.insert(candidates, {
						x = at.X,
						y = at.Y,
						z = at.Z,
						own = own,
					})
				end
			end
		end
		local facing = root.CFrame.LookVector
		local index = DiveKick.pickFollowUp(
			kickCfg,
			position.X,
			position.Y,
			position.Z,
			facing.X,
			facing.Z,
			candidates
		)
		return if index then models[index] else nil
	end

	-- Where a perfect kick should send them: toward the spot on the floor under the cursor, as a flat
	-- direction from the target. Without a mouse (touch, gamepad), or with the cursor on the sky, it's
	-- the way the camera looks.
	local function kickAim(targetRoot: BasePart?): Vector3?
		local camera = workspace.CurrentCamera
		if not camera or not targetRoot then
			return nil
		end
		local from = targetRoot.Position
		if UserInputService.MouseEnabled then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local floorY = GameConfig.Arena.CenterY
			if ray.Direction.Y < -0.01 then
				local reach = (floorY - ray.Origin.Y) / ray.Direction.Y
				local spot = ray.Origin + ray.Direction * reach
				local toSpot = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z)
				if reach > 0 and toSpot.Magnitude > 1 then
					return toSpot.Unit
				end
			end
		end
		local viewing = camera.CFrame.LookVector
		local level = Vector3.new(viewing.X, 0, viewing.Z)
		return if level.Magnitude > 0.01 then level.Unit else nil
	end

	-- The server's pick for the follow-up. It only counts for a squat waiting on it, so a late answer
	-- can never start anything.
	local function onKickAccepted(target: Model, snap: boolean?)
		if kick and kick.phase == "squat" and not kickAccepted and target and target.Parent then
			kickTarget = target
			kickSnap = snap == true
			kickAccepted = true
		end
	end
	self._kickAccepted = onKickAccepted
	trove:Add(function()
		if self._kickAccepted == onKickAccepted then
			self._kickAccepted = nil
		end
	end)

	-- The server says this kick connected. Stay on the frozen pose through the stop, then push off them:
	-- backward from where you face at a propel's speed, held until you land, and upward by how well you
	-- timed it. This is your rebound. It isn't the bounce a green kick gives them off the floor. From
	-- here it's normal movement, so the keys still steer, and pushing against it slows you.
	self._kickConnected = function(stop: number)
		if kick and kick.phase == "flip" then
			task.delay(stop, function()
				if kick and kick.phase == "flip" then
					local facing = root.CFrame.LookVector
					local at = root.Position
					-- Whichever platform this is: the rebound lands on the one you kicked from.
					local lobbyCfg: any = GameConfig.Lobby
					local arena = if lobbyCfg.Enabled and Lobby.contains(lobbyCfg, at.X, at.Z)
						then Lobby.disc(lobbyCfg)
						else TrainingLayout.platformAt(
							GameConfig.Training,
							GameConfig.Arena,
							at.X,
							at.Z
						)
					local plan = DiveKick.planRebound(
						kickCfg,
						character:GetAttribute("HT_KickGrade") or "red",
						{
							x = at.X,
							z = at.Z,
							height = at.Y - arena.y - humanoid.HipHeight - root.Size.Y / 2,
							backX = -facing.X,
							backZ = -facing.Z,
							centerX = arena.x,
							centerZ = arena.z,
							radius = arena.radius,
							speed = cfg.PropelSpeed,
							gravity = workspace.Gravity * kickCfg.ReboundGravityScale,
							-- The rebound falls on the same lighter gravity as everything else, so
							-- the landing is planned on that fall.
							fallTime = function(up: number, height: number): number
								return AirRecovery.timeToDrop(
									airCfg,
									workspace.Gravity,
									kickCfg.ReboundGravityScale,
									up,
									height
								)
							end,
						}
					)
					kick = nil
					kickTarget = nil
					state = Momentum.moving(state, plan.dirX, plan.dirZ, plan.speed)
					airRun = {
						t = 0,
						gravityScale = kickCfg.ReboundGravityScale,
						keep = plan.speed,
					}
					local vx, vz = Momentum.velocity(state)
					root.AssemblyLinearVelocity = Vector3.new(vx, plan.up, vz)
				end
			end)
		end
	end

	-- The snap, at the end of the squat, once the server has accepted it: straight at the target it
	-- picked, timed by the distance. Arriving on your side of them, so the kick sends them the way you
	-- came unless the keys swing you round.
	local function snapJump(squat: DiveKick.State, targetRoot: BasePart): DiveKick.State
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		-- Right here for your own jump: waiting to hear it back from the server would put it in mid-air.
		fx:JumpBreak(character, GameConfig.Effects.GroundBreakOwnReach)
		local offset = root.Position - targetRoot.Position
		local approach = DiveKick.approachSeconds(kickCfg, offset.Magnitude)
		return DiveKick.snap(squat, offset.X, offset.Z, approach, approach + kickCfg.JumpMissGrace)
	end

	-- The guided leap, for when you aren't locked onto them: a real jump on an arc, a good deal slower
	-- than the snap, but re-aimed at them the whole way, so it gets there on its own. The server isn't
	-- holding them, so they keep falling and steering while you're on your way.
	local function guidedJump(squat: DiveKick.State, targetRoot: BasePart): DiveKick.State
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		fx:JumpBreak(character, GameConfig.Effects.GroundBreakOwnReach)
		local offset = root.Position - targetRoot.Position
		local guide = DiveKick.leapSeconds(kickCfg, offset.Magnitude)
		return DiveKick.leap(squat, offset.X, offset.Z, guide, guide + kickCfg.JumpMissGrace)
	end

	-- The server decides knockback, and this client applies it because it owns the body.
	-- `selfRecoil` is what a punch costs the one who threw it. In the air that's no slowdown and nothing
	-- ended: a whiff costs nothing at all, and a hit a share of its recoil. The vertical speed is left alone.
	self._applyKnock = function(
		velocity: Vector3,
		airUp: number,
		speedKeep: number?,
		selfRecoil: boolean?
	)
		if selfRecoil and humanoid.FloorMaterial == Enum.Material.Air then
			if velocity.X ~= 0 or velocity.Z ~= 0 then
				state = Momentum.addPush(
					state,
					cfg,
					velocity.X * airCfg.HitRecoilShare,
					velocity.Z * airCfg.HitRecoilShare
				)
				pushGraceUntil = os.clock() + PUSH_GRACE_SECONDS
			end
			return
		end
		endKick()
		-- A hit's own lift and fall take over from any recovery lift still running.
		liftUntil, liftSet = 0, false
		state = Momentum.applyKnock(state, cfg, velocity.X, velocity.Z, speedKeep)
		knockGraceUntil = os.clock() + cfg.KnockbackGraceSeconds
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local current = root.AssemblyLinearVelocity
		-- Never adds lift to someone already rising, so repeated hits can't fly them upward.
		-- A negative air lift is a slam: it drives them down rather than adding to their rise. None at
		-- all leaves the fall exactly as it was, so a hit never holds anyone up.
		local rise = if grounded
			then math.max(current.Y, velocity.Y)
			elseif airUp < 0 then airUp
			elseif airUp == 0 then current.Y
			else math.max(current.Y, airUp)
		if airUp < 0 and not grounded then
			slammed = true
		elseif airUp > 0 then
			slammed = false
		end
		pushX, pushZ = 0, 0
		local vx, vz = Momentum.velocity(state, speedShare)
		-- A grounded Humanoid holds itself to the floor, which would cancel the lift.
		if rise > MIN_LIFT then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		root.AssemblyLinearVelocity = Vector3.new(vx, rise, vz)
	end

	-- The server has moved this body somewhere else. Nothing it was doing carries over, or the speed of
	-- a big launch would throw it straight off wherever it was put.
	self._bodyReset = function(face: Vector3?)
		endKick()
		slammed = false
		steerX, steerZ, pushX, pushZ, lift = 0, 0, 0, 0, 0
		punchRequested, propelRequested, kickRequested = false, false, false
		dropCharge()
		lastPush = nil
		lifts, liftUntil, liftSet = AirRecovery.newLifts(), 0, false
		state = if face and face.Magnitude > 0.01
			then Momentum.new(face.X, face.Z)
			else Momentum.stopped(state)
		root.AssemblyLinearVelocity = Vector3.zero
		knockGraceUntil = 0
	end

	-- An accepted punch, from CombatController. The push is worked out at the next step, from the keys
	-- at that moment. This is the only place one starts, so there's one per punch thrown.
	self._punchThrown = function(swing: string?)
		punchRequested = true
		punchIsUppercut = swing == "Uppercut"
	end
	-- The server refused that punch, so it never happened: its push goes back too.
	self._punchRefused = function()
		punchRequested = false
		local pushed = lastPush
		lastPush = nil
		if pushed and os.clock() - pushed.at <= UNDO_SECONDS then
			pushX -= pushed.x
			pushZ -= pushed.z
			lift -= pushed.up
			if pushed.lifted then
				-- The rise it already gave can't be taken back, but its lighter gravity stops, and it
				-- doesn't count against the fall's allowance.
				liftUntil, liftSet = 0, false
				lifts = {
					count = math.max(lifts.count - 1, 0),
					lastAt = -math.huge,
				}
			end
		end
	end

	-- Pressing starts the charge and letting go dashes: a tap is the plain dash, a longer hold a harder
	-- one, up to PropelChargeSeconds, when it goes by itself.
	ContextActionService:BindActionAtPriority(
		PROPEL_ACTION,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				propelRequested = true
				chargeHeld = true
			elseif
				inputState == Enum.UserInputState.End
				or inputState == Enum.UserInputState.Cancel
			then
				chargeHeld = false
			end
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:SetTitle(PROPEL_ACTION, "Propel")
	trove:Add(function()
		ContextActionService:UnbindAction(PROPEL_ACTION)
	end)

	-- Space jumps at someone in the air, and pressing again once attached is the timed press.
	ContextActionService:BindActionAtPriority(
		KICK_ACTION,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				kickRequested = true
			end
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:SetTitle(KICK_ACTION, "Kick")
	trove:Add(function()
		ContextActionService:UnbindAction(KICK_ACTION)
	end)

	trove:BindToRenderStep(STEP_NAME, STEP_PRIORITY, function(dt: number)
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local hud = self.Hud
		local flatVelocity = root.AssemblyLinearVelocity
		hud.speed = Vector3.new(flatVelocity.X, 0, flatVelocity.Z).Magnitude
		hud.propelLeft = state.propelCooldownLeft or 0
		hud.kickReadyAt = kickReadyAt
		hud.kicking = kick ~= nil
		hud.kickTarget = false
		local inputX, inputZ = worldInput(input)
		local drive, side = driveOf(inputX, inputZ)

		local now = os.clock()
		local air = character:GetAttribute("HT_Air")
		-- A hold carries its own deadline, so even a release that never arrives can't keep anyone stuck.
		local holdUntil = character:GetAttribute("HT_HoldUntil") :: number?
		if air == "hold" and holdUntil and workspace:GetServerTimeNow() >= holdUntil then
			air = "float"
		end
		airSeconds = if grounded then 0 else airSeconds + dt
		if grounded then
			slammed = false
			lifts, liftUntil, liftSet = AirRecovery.newLifts(), 0, false
		end

		-- Hung in the air while someone is attached. The kick's own knock takes over at once.
		if air == "hold" and now >= knockGraceUntil then
			kickRequested, propelRequested, punchRequested = false, false, false
			dropCharge()
			pushX, pushZ, lift = 0, 0, 0
			state = Momentum.stopped(state)
			humanoid.WalkSpeed = 0
			humanoid:Move(Vector3.zero, false)
			root.AssemblyLinearVelocity = Vector3.zero
			local face = character:GetAttribute("HT_HoldFace") :: Vector3?
			if face then
				align.CFrame = CFrame.lookAt(Vector3.zero, face)
			end
			prompt:Hide()
			if readout then
				readout.Text = `Held   Stagger {character:GetAttribute("HT_Stagger") or 0}`
			end
			return
		end

		-- In a clash: walks to the spot the server gave, and holds there looking at the other fighter.
		-- A knock takes over at once, the same as above, because the finishing punch is one.
		local clashAt = character:GetAttribute("HT_ClashAt") :: Vector3?
		if clashAt and now >= knockGraceUntil then
			kickRequested, propelRequested, punchRequested = false, false, false
			dropCharge()
			pushX, pushZ, lift = 0, 0, 0
			local face = character:GetAttribute("HT_ClashFace") :: Vector3?
			if face then
				state = Momentum.new(face.X, face.Z)
				align.CFrame = CFrame.lookAt(Vector3.zero, face)
			else
				state = Momentum.stopped(state)
			end
			local offset = Vector3.new(clashAt.X - root.Position.X, 0, clashAt.Z - root.Position.Z)
			local walk = Clash.alignSpeed(GameConfig.Clash, offset.Magnitude)
			humanoid.WalkSpeed = walk
			humanoid:Move(if walk > 0 then offset.Unit else Vector3.zero, false)
			prompt:Hide()
			if readout then
				readout.Text = `Clash   Stagger {character:GetAttribute("HT_Stagger") or 0}`
			end
			return
		end

		local floating = air == "float"
		-- Eased, so speed follows stagger smoothly, both when it's added and as it recovers.
		local wantShare =
			Combat.staggerSpeedShare(GameConfig.Stagger, character:GetAttribute("HT_Stagger") or 0)
		speedShare += (wantShare - speedShare) * math.min(GameConfig.Stagger.SpeedShareEase * dt, 1)
		-- A round's countdown holds you on your spawn the same way a stun does, without the stun's look.
		local stunned = character:GetAttribute("HT_Stunned") ~= nil
			or character:GetAttribute("HT_RoundHold") ~= nil
			-- Watching a fighter's view: your own body stays where it is (SpectateController).
			or character:GetAttribute("HT_Spectating") ~= nil
		if stunned then
			kickRequested, propelRequested, punchRequested = false, false, false
			dropCharge()
			inputX, inputZ = 0, 0
			drive, side = "side", 0
		end
		-- Anywhere in the air without something else moving the body, the keys steer it.
		local freeAir = not grounded and not floating and not airRun and not kick and not stunned
		if not floating and not freeAir then
			steerX, steerZ = 0, 0
		end
		-- A push still going on landing carries on along the floor, and fades the way knockback does there.
		if grounded and (pushX ~= 0 or pushZ ~= 0) then
			state = Momentum.addPush(state, cfg, pushX, pushZ)
			pushX, pushZ = 0, 0
		end

		local pressed = kickRequested
		kickRequested = false
		-- The server needs to know who you're locked onto: only that makes a follow-up the snap.
		if kickRemotes.lockOn then
			local lockedNow = Knit.GetController("LockOnController"):GetTarget()
			if lockedNow ~= lockSent then
				lockSent = lockedNow
				kickRemotes.lockOn:FireServer(lockedNow)
			end
		end

		if not kick then
			local canJump = grounded and not floating and kickRemotes.request ~= nil
			local target = if canJump and now >= kickReadyAt then jumpTarget(root.Position) else nil
			hud.kickTarget = target ~= nil
			if target then
				if pressed then
					kickReadyAt = now + kickCfg.Cooldown
					-- Only a guess until the server says which target it picked.
					kickTarget = target
					kickAccepted = false
					kick = DiveKick.start()
					state = Momentum.stopped(state)
					prompt:Hide()
					kickRemotes.request:FireServer()
				else
					prompt:ShowJump()
				end
			else
				prompt:Hide()
			end
		elseif pressed and kick.phase == "attach" then
			if kickRemotes.commit then
				local aimAt = kickTarget and kickTarget:FindFirstChild("HumanoidRootPart")
				kickRemotes.commit:FireServer(
					kickAim(if aimAt and aimAt:IsA("BasePart") then aimAt else nil)
				)
			end
			kick = DiveKick.press(kick)
			kickAwaiting = true
			prompt:Hide()
		end

		-- The server grades the timing. Only its answer shows, so both sides always agree.
		if kickAwaiting then
			local skill = character:GetAttribute("HT_Skill")
			if skill == "flip" or skill == "kick" then
				kickAwaiting = false
				prompt:ShowResult(character:GetAttribute("HT_KickGrade") or "red")
			elseif skill == nil then
				endKick()
			end
		end

		-- A jump that has missed, or has nothing left to reach, stops being a jump. It's back to ordinary
		-- movement with a little of its speed, a small lift and a slower fall, to get back to the platform.
		if kick and kick.phase == "chase" then
			if character:GetAttribute("HT_Skill") == nil and kick.t >= LAND_CHECK_SECONDS then
				kick = DiveKick.giveUp(kick)
			end
			if DiveKick.hasMissed(kick) then
				local flight = root.AssemblyLinearVelocity
				local level = Vector3.new(flight.X, 0, flight.Z)
				state = Momentum.moving(
					state,
					level.X,
					level.Z,
					math.min(level.Magnitude, kickCfg.MissCarryKeep)
				)
				airRun = {
					t = 0,
					gravityScale = kickCfg.MissGravityScale,
				}
				root.AssemblyLinearVelocity =
					Vector3.new(flight.X, math.max(flight.Y, kickCfg.MissLift), flight.Z)
				kick = nil
			end
		end

		if airRun then
			airRun.t += dt
			if grounded and airRun.t >= LAND_CHECK_SECONDS then
				if airRun.keep then
					state = Momentum.landed(state, cfg)
				end
				airRun = nil
				kickTarget = nil
			elseif
				kickTarget
				and character:GetAttribute("HT_Skill") == "chase"
				and kickTarget:GetAttribute("HT_Air") ~= nil
			then
				-- Still got there in the end: it still counts.
				local targetRoot = kickTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
				local offset = if targetRoot then root.Position - targetRoot.Position else nil
				if offset and DiveKick.isTouching(kickCfg, offset.X, offset.Y, offset.Z) then
					local qteAt = character:GetAttribute("HT_KickAt") :: number?
					kick = DiveKick.attach(
						DiveKick.spring(DiveKick.start(), 0, 0, 0),
						offset.X,
						offset.Z,
						qteAt or DiveKick.pickQte(kickCfg, 0.5)
					)
					airRun = nil
					state = Momentum.stopped(state)
					if kickRemotes.attach then
						kickRemotes.attach:FireServer()
					end
				end
			end
		end

		if kick then
			local gravity = workspace.Gravity * kickCfg.AirGravityScale
			local skill = character:GetAttribute("HT_Skill")
			local targetRoot = kickTarget
				and kickTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
			local before = kick.phase
			propelRequested = false -- no propel during the committed jump or the kick
			dropCharge()
			punchRequested = false
			pushX, pushZ, lift = 0, 0, 0
			-- The jump is a jump, and lasts until you land, whatever happens to anyone else. Once
			-- aligned, losing the target or being hit out of it ends the move.
			local over = (before == "chase" and kick.t >= LAND_CHECK_SECONDS and grounded)
				or ((before == "attach" or before == "flip") and (skill == nil or not targetRoot))
				-- Never accepted: nothing happened, and it can be tried again shortly.
				or (before == "squat" and not kickAccepted and kick.t >= kickCfg.AcceptWaitSeconds)
			if over and before == "squat" then
				kickReadyAt = now + LAND_CHECK_SECONDS
			end
			-- During the timing the keys aim the kick, unless in shift lock, when the camera does.
			local stepX, stepZ = inputX, inputZ
			if before == "attach" and Knit.GetController("ShiftLockController"):IsLocked() then
				local camera = workspace.CurrentCamera
				local viewing = if camera then camera.CFrame.LookVector else Vector3.zero
				local level = Vector3.new(viewing.X, 0, viewing.Z)
				if level.Magnitude > 0.01 then
					stepX, stepZ = level.Unit.X, level.Unit.Z
				end
			end
			local nextKick = if over
				then nil
				else DiveKick.step(kick, kickCfg, dt, gravity, stepX, stepZ)
			state = Momentum.step(state, cfg, 0, 0, grounded, dt)
			humanoid.WalkSpeed = 0
			humanoid:Move(Vector3.zero, false)
			if rootJoint then
				rootJoint.C0 = baseC0
			end
			if nextKick == nil then
				endKick()
			else
				-- The squat ends in the snap, but only once the server has said yes and which target.
				if
					nextKick.phase == "squat"
					and nextKick.t >= kickCfg.JumpSquatSeconds
					and kickAccepted
					and targetRoot
				then
					-- Locked onto them: the fast snap straight to them. Otherwise a slower leap, guided to them.
					nextKick = if kickSnap
						then snapJump(nextKick, targetRoot)
						else guidedJump(nextKick, targetRoot)
				end
				if before == "attach" and nextKick.phase == "flip" then
					-- The ring ran out with no press. The kick still comes, as a red.
					kickAwaiting = true
					prompt:Hide()
				end
				local position = root.Position
				-- The server holds them from the moment it accepts, so "hold" is the usual case here.
				if
					nextKick.phase == "chase"
					and skill == "chase"
					and targetRoot
					and kickTarget
					and kickTarget:GetAttribute("HT_Air") ~= nil
				then
					local offset = position - targetRoot.Position
					if DiveKick.isTouching(kickCfg, offset.X, offset.Y, offset.Z) then
						local qteAt = character:GetAttribute("HT_KickAt") :: number?
						nextKick = DiveKick.attach(
							nextKick,
							offset.X,
							offset.Z,
							qteAt or DiveKick.pickQte(kickCfg, 0.5)
						)
						if kickRemotes.attach then
							kickRemotes.attach:FireServer()
						end
					end
				end
				kick = nextKick
				if nextKick.phase == "attach" then
					prompt:UpdateAttach(nextKick.t, nextKick.qteAt)
				end
				local at = if targetRoot then targetRoot.Position else position
				local moving = if targetRoot
					then targetRoot.AssemblyLinearVelocity
					else Vector3.zero
				local vx, vy, vz = DiveKick.velocity(
					nextKick,
					kickCfg,
					position.X,
					position.Y,
					position.Z,
					at.X,
					at.Y,
					at.Z,
					moving.X,
					moving.Y,
					moving.Z
				)
				if vx and vy and vz then
					root.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
				end
				-- From the snap on you face them. In the rebound you keep looking the way you kicked.
				local faceTo = Vector3.zero
				if
					nextKick.phase == "chase"
					or nextKick.phase == "attach"
					or nextKick.phase == "flip"
				then
					faceTo = Vector3.new(at.X - position.X, 0, at.Z - position.Z)
				end
				if faceTo.Magnitude > 0.5 then
					align.CFrame = CFrame.lookAt(Vector3.zero, faceTo)
				end
			end
			if readout then
				readout.Text =
					`Speed {math.floor(root.AssemblyLinearVelocity.Magnitude + 0.5)} / {cfg.MaxSpeed}   Kick   Stagger {character:GetAttribute(
						"HT_Stagger"
					) or 0}`
			end
			return
		end

		-- A punch in the air gives one push, added to whatever the body is already doing.
		if punchRequested then
			punchRequested = false
			lastPush = nil
			if airSeconds >= airCfg.MinAirSeconds then
				local airMoving = root.AssemblyLinearVelocity
				local faceX, faceZ = Momentum.facing(state)
				local dirX, dirZ =
					AirRecovery.direction(inputX, inputZ, faceX, faceZ, cfg.InputDeadzone)
				-- Distance from the feet down to anything solid, or nil with none in reach.
				local feet = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
				local hit = workspace:Raycast(
					root.Position,
					Vector3.new(0, -(root.Position.Y - feet + airCfg.LiftFloorCheck), 0),
					floorParams
				)
				local floorBelow = if hit then math.max(feet - hit.Position.Y, 0) else nil
				local lifted = punchIsUppercut
					and (floating or freeAir or airRun ~= nil)
					and AirRecovery.canLift(airCfg, lifts, airMoving.Y, floorBelow, slammed, now)
				local addX, addZ = AirRecovery.push(
					airCfg,
					airMoving.X,
					airMoving.Z,
					dirX,
					dirZ,
					if lifted then airCfg.LiftForwardSpeed else nil
				)
				local up = if slammed or lifted then 0 else AirRecovery.lift(airCfg, airMoving.Y)
				if lifted then
					lifts = AirRecovery.usedLift(lifts, now)
					liftUntil = now + airCfg.LiftSeconds
					liftSet = true
				end
				pushX += addX
				pushZ += addZ
				lift += up
				pushGraceUntil = now + PUSH_GRACE_SECONDS
				lastPush = { x = addX, z = addZ, up = up, at = now, lifted = lifted }
				fx:AirPunchGust(character, Vector3.new(dirX, 0, dirZ))
			end
		end

		if propelRequested then
			propelRequested = false
			chargeAt = now
			chargeChecked = false
		end
		if chargeAt and not chargeChecked then
			chargeChecked = true
			-- Still cooling down, or one already running: turned down at the press, with nothing to charge.
			if (state.propelCooldownLeft or 0) > 0 or (state.propelLeft or 0) > 0 then
				chargeAt = nil
				self.PropelBlocked:Fire()
			end
		end
		if chargeAt then
			local power = Momentum.chargePower(cfg, now - chargeAt)
			if chargeHeld and power < 1 then
				fx:PropelCharge(character, power)
			else
				chargeAt = nil
				fx:PropelCharge(character, nil)
				-- A burst the way you're already going; from a standstill, the way the keys point.
				local propelled = Momentum.tryPropel(state, cfg, inputX, inputZ, drive, power)
				if not propelled then
					self.PropelBlocked:Fire()
				end
				if propelled then
					state = propelled
					self.Propelled:Fire()
					fx:PropelGust(character, state.dashSeconds, power)
					fx:DashZoom(state.dashSeconds or cfg.PropelSeconds, power)
					if propelRemote then
						propelRemote:FireServer(power)
					end
				end
			end
		end
		if floating then
			-- The push fades at the same rate as on the floor, so an uppercut carries as far as any
			-- other hit of that strength. Steering sits on top and doesn't cancel it, and the more
			-- staggered they are, the less of it they have.
			-- A propel out of it is allowed, and steers the way a propel normally does.
			local propelling = (state.propelLeft or 0) > 0
			state = Momentum.step(
				state,
				cfg,
				if propelling then inputX else 0,
				if propelling then inputZ else 0,
				true,
				dt,
				drive,
				side
			)
			local share = DiveKick.launchSteerShare(
				kickCfg,
				character:GetAttribute("HT_Stagger") or 0,
				GameConfig.Stagger.Max
			)
			steerX, steerZ = DiveKick.airSteer(
				steerX,
				steerZ,
				inputX,
				inputZ,
				kickCfg.LaunchSteerSpeed * share,
				kickCfg.LaunchSteerAcceleration * share,
				dt
			)
		else
			-- Letting go of A or D only keeps the coast if you're still heading the way the camera looks.
			-- It's checked at that one moment, so looking around during a forward coast can't end it.
			local nothingHeld = inputX == 0 and inputZ == 0
			if nothingHeld and wasSideSteering and not airRun and (state.propelLeft or 0) <= 0 then
				local viewing = workspace.CurrentCamera
					and workspace.CurrentCamera.CFrame.LookVector
				local viewFlat = viewing and Vector3.new(viewing.X, 0, viewing.Z)
				if viewFlat and viewFlat.Magnitude > 0.001 then
					local forward = viewFlat.Unit
					state = Momentum.endSidewaysCoast(state, cfg, forward.X, forward.Z)
				end
			end
			wasSideSteering = not nothingHeld and drive == "side"
			-- In an air run the controls work just as they do on the floor.
			state = Momentum.step(
				state,
				cfg,
				inputX,
				inputZ,
				grounded or airRun ~= nil,
				dt,
				drive,
				side
			)
			-- Charging a dash roots you to a creep.
			if chargeAt then
				state = Momentum.chargeSlow(state, cfg, dt)
			end
			if airRun and airRun.keep then
				state, airRun.keep = Momentum.airKeep(state, airRun.keep, inputX, inputZ)
			end
			if freeAir then
				local share = DiveKick.launchSteerShare(
					kickCfg,
					character:GetAttribute("HT_Stagger") or 0,
					GameConfig.Stagger.Max
				)
				steerX, steerZ = DiveKick.airSteer(
					steerX,
					steerZ,
					inputX,
					inputZ,
					kickCfg.LaunchSteerSpeed * share,
					kickCfg.LaunchSteerAcceleration * share,
					dt
				)
			end
		end

		-- Walls and other obstacles really stop you: momentum can't run on
		-- further than the character is actually moving. It's the whole velocity that counts, so
		-- steering or punching against a launch isn't taken for a wall.
		local velocity = root.AssemblyLinearVelocity
		-- The falling lift sets the vertical speed once, then lightens gravity for a moment.
		local function liftedFall(fall: number): number
			if liftSet then
				return airCfg.LiftSpeed
			elseif now < liftUntil then
				return AirRecovery.liftVelocity(airCfg, workspace.Gravity, velocity.Y, dt)
			end
			return fall
		end
		local realSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		-- Stagger doesn't shorten a rebound: where it lands was worked out at full speed.
		local travelShare = if airRun and airRun.keep then 1 else speedShare
		local wantX, wantZ = Momentum.velocity(state, travelShare)
		pushX, pushZ = AirRecovery.fade(airCfg, pushX, pushZ, dt)
		pushX, pushZ = AirRecovery.limit(airCfg, pushX, pushZ, wantX + steerX, wantZ + steerZ)
		local totalX, totalZ = wantX + steerX + pushX, wantZ + steerZ + pushZ
		local wanted = math.sqrt(totalX * totalX + totalZ * totalZ)
		if
			wanted > realSpeed + cfg.WallSpeedMargin
			and not Momentum.isPropelBuilding(state, cfg)
			and now >= knockGraceUntil
			and now >= pushGraceUntil
		then
			local share = (realSpeed + cfg.WallSpeedMargin) / wanted
			local clamped = table.clone(state)
			clamped.speed = state.speed * share
			clamped.knockX = if state.knockX then state.knockX * share else nil
			clamped.knockZ = if state.knockZ then state.knockZ * share else nil
			state = clamped
			steerX, steerZ = steerX * share, steerZ * share
			pushX, pushZ = pushX * share, pushZ * share
			wantX, wantZ = Momentum.velocity(state, travelShare)
			totalX, totalZ = wantX + steerX + pushX, wantZ + steerZ + pushZ
			wanted = math.sqrt(totalX * totalX + totalZ * totalZ)
		end

		if floating then
			-- Rises on the launch's own lighter gravity, falls on the general rule, and the flat speed is
			-- exactly what the knock says.
			local fall = AirRecovery.fallVelocity(
				airCfg,
				workspace.Gravity,
				kickCfg.AirGravityScale,
				velocity.Y,
				dt
			)
			root.AssemblyLinearVelocity = Vector3.new(totalX, liftedFall(fall) + lift, totalZ)
		elseif airRun then
			-- The Humanoid barely moves itself in the air, so the speed is set exactly. Up on its own
			-- gravity, down on the general falling rule like every other body in the air.
			local fall = AirRecovery.fallVelocity(
				airCfg,
				workspace.Gravity,
				airRun.gravityScale,
				velocity.Y,
				dt
			)
			root.AssemblyLinearVelocity = Vector3.new(totalX, liftedFall(fall) + lift, totalZ)
		elseif freeAir then
			-- A slam keeps all its gravity, so a kick still drives them down as hard as it meant to.
			local fall = if slammed
				then velocity.Y
				else AirRecovery.fallVelocity(airCfg, workspace.Gravity, 1, velocity.Y, dt)
			root.AssemblyLinearVelocity = Vector3.new(totalX, liftedFall(fall) + lift, totalZ)
		end
		lift = 0
		liftSet = false

		local faceX, faceZ = Momentum.facing(state)
		local heading = Vector3.new(faceX, 0, faceZ)
		humanoid.WalkSpeed = wanted
		humanoid:Move(
			if wanted > 0.01 then Vector3.new(totalX, 0, totalZ) / wanted else Vector3.zero,
			false
		)
		align.CFrame = CFrame.lookAt(Vector3.zero, heading)

		if rootJoint then
			local leanShare = math.clamp(state.speed / cfg.MaxSpeed, 0, 1)
			local targetLean = state.turn * leanShare * cfg.LeanMaxDegrees
			lean += (targetLean - lean) * math.min(cfg.LeanResponsiveness * dt, 1)
			-- Positive turn is a right turn; a negative angle about the root's Z tips the head right.
			rootJoint.C0 = CFrame.Angles(0, 0, math.rad(-lean)) * baseC0
		end

		if readout then
			local wait = state.propelCooldownLeft or 0
			local propelText = if wait > 0
				then string.format("Propel %.1f", wait)
				else "Propel ready"
			readout.Text =
				`Speed {math.floor(realSpeed + 0.5)} / {cfg.MaxSpeed}   {propelText}   Stagger {character:GetAttribute(
					"HT_Stagger"
				) or 0}`
		end
	end)
end

--- A punch has just been thrown. In the air it pushes the body, once. `swing` is Left, Right or
--- Uppercut; only an uppercut can give the falling lift.
function MovementController:PunchThrown(swing: string?)
	if self._punchThrown then
		self._punchThrown(swing)
	end
end

--- The server refused the last punch, so its push is taken back.
function MovementController:PunchRefused()
	if self._punchRefused then
		self._punchRefused()
	end
end

function MovementController:KnitStart()
	local player = Players.LocalPlayer
	if not RunService:IsClient() or not player then
		return
	end
	local knockRemote = Net.client("Knockback")
	if knockRemote then
		knockRemote.OnClientEvent:Connect(
			function(velocity: Vector3, airUp: number, speedKeep: number?, selfRecoil: boolean?)
				if self._applyKnock then
					self._applyKnock(velocity, airUp, speedKeep, selfRecoil)
				end
			end
		)
	else
		warn("[Haymaker Tussle] knockback remote missing")
	end
	local propelRemote = Net.client("PropelRequest")
	local bodyReset = Net.client("BodyReset")
	if bodyReset then
		bodyReset.OnClientEvent:Connect(function(face: Vector3?)
			if self._bodyReset then
				self._bodyReset(face)
			end
		end)
	end
	local propelStarted = Net.client("PropelStarted")
	if propelStarted then
		propelStarted.OnClientEvent:Connect(function(other: Player, power: number?)
			if other and other.Character then
				Knit.GetController("FxController")
					:PropelGust(other.Character, cfg.PropelSeconds, power)
			end
		end)
	end
	local kickAccepted = Net.client("KickAccepted")
	if kickAccepted then
		kickAccepted.OnClientEvent:Connect(function(target: Model, snap: boolean?)
			if self._kickAccepted then
				self._kickAccepted(target, snap)
			end
		end)
	end
	local kickImpact = Net.client("KickImpact")
	if kickImpact then
		kickImpact.OnClientEvent:Connect(
			function(attacker: Model, _target, _at, _hit, _share, stop: number)
				if attacker == player.Character and self._kickConnected and stop > 0 then
					self._kickConnected(stop)
				end
			end
		)
	end
	local input = hookInput(player)
	local readout = makeReadout()

	local function onCharacter(character: Model)
		self:_bind(character, input, readout, propelRemote)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return MovementController
