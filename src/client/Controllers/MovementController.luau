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
-- and the steering of a launched body (Core/DiveKick). A knock ends a burst and any recovery lift.

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
local ActiveArena = require(ReplicatedStorage.Shared.ActiveArena)
local Pond = require(ReplicatedStorage.Shared.Core.Pond)
local AirRecovery = require(ReplicatedStorage.Shared.Core.AirRecovery)
local Clash = require(ReplicatedStorage.Shared.Core.Clash)
local BumpPredict = require(ReplicatedStorage.Shared.BumpPredict)
local Combat = require(ReplicatedStorage.Shared.Core.Combat)
local DiveKick = require(ReplicatedStorage.Shared.Core.DiveKick)
local AimAssist = require(ReplicatedStorage.Shared.Core.AimAssist)
local Jump = require(ReplicatedStorage.Shared.Core.Jump)
local Momentum = require(ReplicatedStorage.Shared.Core.Momentum)
local SkillMove = require(ReplicatedStorage.Shared.Core.SkillMove)
local Net = require(ReplicatedStorage.Shared.Net)

local STEP_NAME = "HaymakerMovement"
local JUMP_ACTION = "HaymakerJump"
local STEP_PRIORITY = Enum.RenderPriority.Input.Value + 1
local INPUT_STALE_SECONDS = 0.25
local MIN_LIFT = 1 -- below this a knock isn't a lift, just the floor's own tiny motion
local LAND_CHECK_SECONDS = 0.25 -- a jump can't count as landed this soon
local PUSH_GRACE_SECONDS = 0.05 -- a body gets this long to catch up with its own push
local SKILL_MOVE_WAIT = 0.15 -- a kit move the step can't start within this long is dropped
local UNDO_SECONDS = 1 -- a refused punch's push is taken back only if the answer comes this soon

local cfg = GameConfig.Movement
local kickCfg = GameConfig.Kick
local airCfg = GameConfig.AirRecovery
local jumpCfg = GameConfig.Jump
local punchCfg = GameConfig.Punch
local GLIDE_LAND_SECONDS = 0.05 -- an air punch's glide can't count as landed this soon

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
		jumpReadyAt = 0, -- when Space can jump again
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
	-- The dash goes on the press, always a plain one: there is no charging it (user, 2026-11-12).
	local propelRequested = false
	-- A kit's mobility skill, or an attack skill's lunge, waiting for the next step (Core/SkillMove).
	-- `id` is the skill to show and tell the server about; a lunge has none.
	local skillMove: { id: string?, cfg: any, at: number }? = nil
	local knockGraceUntil = 0
	local thrownAt = -math.huge -- when a knockback last reached this body (a drag gives way to it)
	-- The M1 lock holding this body: who, how far in front of them (fixed when it began), and when it was
	-- last seen, so a string's next punch carries on the same lock rather than starting a new one.
	local lockBy: Model? = nil
	local lockAhead = 0
	local lockSeenAt = -math.huge
	-- The last ground punch's press: for Punch.MoveSeconds after it you run no faster than Punch.MoveSpeed
	-- (Combat.stringSpeed). M1s don't stop you or step you any more (2026-11-16, kits-5b).
	local punchPressedAt: number? = nil
	-- A dash pressed while a punch's stun held you: it goes off as the stun ends (Combat.dashBuffered).
	local dashPressedInStun: number? = nil
	local jumpRequested = false
	-- THE JUMP (Space): up, and forward in an arc that grows with speed (Core/Jump), flown as an air run.
	-- THE AIR PUNCH (2026-11-15): a punch thrown in the air glides the body
	-- straight toward what the cursor is on, up to Punch.AirReach studs, over Punch.AirGlideSeconds, and
	-- the punch lands as it arrives (CombatService gives it the longer AirWindup). A plain hitbox: no slam.
	local jumping = false
	local jumpReadyAt = 0
	local glide: { dir: Vector3, speed: number, t: number }? = nil
	local steerX, steerZ = 0, 0 -- a launched body's own steering, on top of its push
	local speedShare = 1 -- how much of running speed stagger leaves
	local pondShare = 1 -- how much of it wading in a pond leaves (Core/Pond), eased on its own
	-- A jump's flight: ordinary movement, but in the air.
	local airRun: { t: number, gravityScale: number, keep: number? }? = nil
	local wasSideSteering = false
	local airSeconds = 0 -- how long since the floor
	local pushX, pushZ = 0, 0 -- what punches thrown in the air are still pushing with
	local pushGraceUntil = 0
	local lift = 0 -- a punch's small lift, waiting for this step's velocity
	local punchRequested = false
	local punchIsUppercut = false -- only an uppercut gives the falling lift
	local rootedUntil = 0 -- a heavy kick's windup holds you still until then
	local lastPush: { x: number, z: number, up: number, at: number, lifted: boolean? }? = nil
	local slammed = false -- driven down by a kick, so its fall isn't lightened
	-- The falling lift: how many this fall, and until when its lighter gravity lasts.
	local lifts = AirRecovery.newLifts()
	local liftUntil = 0
	local liftSet = false -- this step sets the vertical speed to the lift's
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { character }
	local fx = Knit.GetController("FxController")

	-- Who you're locked onto, where their body is, if they're close enough for the aim assist to help.
	local function assistTarget(): BasePart?
		local target = Knit.GetController("LockOnController"):GetTarget()
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if not targetRoot or not targetRoot:IsA("BasePart") then
			return nil
		end
		if (targetRoot.Position - root.Position).Magnitude > GameConfig.LockOn.AssistRange then
			return nil
		end
		return targetRoot
	end

	local function endJump()
		airRun = nil
		jumping = false
		glide = nil
	end
	trove:Add(endJump)

	-- Only solid parts count as being in the way; fighters never do.
	local function solidParams(): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = CollectionService:GetTagged("HT_Combatant")
		params.RespectCanCollide = true
		params.IgnoreWater = true
		return params
	end

	-- Where an air punch is aimed: the spot the cursor is on (the floor, or anything solid). Without a
	-- mouse, a little ahead of where the camera looks.
	local function aimSpot(): Vector3
		local camera = workspace.CurrentCamera
		local from = root.Position
		if not camera then
			return from - Vector3.yAxis * 10
		end
		if UserInputService.MouseEnabled then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, solidParams())
			if hit then
				return hit.Position
			end
			if ray.Direction.Y < -0.01 then
				local reach = (GameConfig.Arena.CenterY - ray.Origin.Y) / ray.Direction.Y
				if reach > 0 then
					return ray.Origin + ray.Direction * reach
				end
			end
		end
		local viewing = camera.CFrame.LookVector
		local level = Vector3.new(viewing.X, 0, viewing.Z)
		local ahead = if level.Magnitude > 0.01 then level.Unit else Vector3.zero
		return from + ahead * punchCfg.AirReach - Vector3.yAxis * 4
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
		endJump()
		-- A hit's own lift and fall take over from any recovery lift still running.
		liftUntil, liftSet = 0, false
		state = Momentum.applyKnock(state, cfg, velocity.X, velocity.Z, speedKeep)
		knockGraceUntil = os.clock() + cfg.KnockbackGraceSeconds
		thrownAt = os.clock()
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
		local vx, vz = Momentum.velocity(state, speedShare * pondShare)
		-- A grounded Humanoid holds itself to the floor, which would cancel the lift.
		if rise > MIN_LIFT then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		root.AssemblyLinearVelocity = Vector3.new(vx, rise, vz)
	end

	-- The server has moved this body somewhere else. Nothing it was doing carries over, or the speed of
	-- a big launch would throw it straight off wherever it was put.
	self._bodyReset = function(face: Vector3?)
		endJump()
		slammed = false
		steerX, steerZ, pushX, pushZ, lift = 0, 0, 0, 0, 0
		punchRequested, propelRequested, jumpRequested = false, false, false
		skillMove = nil
		punchPressedAt, dashPressedInStun = nil, nil
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
	self._heavyKick = function(seconds: number)
		rootedUntil = os.clock() + seconds
	end

	-- Where an air punch glides to: a fighter you're locked onto or pointing at (stopping just short of
	-- them), else the spot the cursor is on. Never further than Punch.AirReach.
	local function airPunchGoal(): Vector3
		local from = root.Position
		local locked = assistTarget()
		if locked and (locked.Position - from).Magnitude <= punchCfg.AirReach + 3 then
			return locked.Position
		end
		local camera = workspace.CurrentCamera
		if camera and UserInputService.MouseEnabled then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character }
			params.IgnoreWater = true
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
			local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
			if model and CollectionService:HasTag(model, "HT_Combatant") then
				-- lihfolk-ignore: findfirstchild-chain (checked on the next line)
				local theirRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if theirRoot then
					return theirRoot.Position
				end
			end
		end
		return aimSpot()
	end

	self._punchThrown = function(swing: string?)
		-- In the air, the punch is the air punch: a glide toward the aim, and nothing else.
		if humanoid.FloorMaterial == Enum.Material.Air then
			local offset = airPunchGoal() - root.Position
			local distance = offset.Magnitude
			-- Stop a little short of whatever it is, so the fist meets them instead of the body.
			local travel = math.clamp(distance - 2.5, 0, punchCfg.AirReach)
			if travel > 0.5 then
				glide = {
					dir = offset.Unit,
					speed = travel / punchCfg.AirGlideSeconds,
					t = 0,
				}
				airRun = nil
			end
			return
		end
		punchRequested = true
		punchIsUppercut = swing == "Uppercut"
		-- Locked on and close, roughly in front: the punch turns you to face them.
		local targetRoot = assistTarget()
		if targetRoot then
			local to = targetRoot.Position - root.Position
			local faceX, faceZ = AimAssist.punchFacing(
				GameConfig.LockOn :: any,
				state.headingX,
				state.headingZ,
				to.X,
				to.Z
			)
			if faceX and faceZ then
				local turned = table.clone(state)
				turned.headingX, turned.headingZ = faceX, faceZ
				state = turned
				local facing = Vector3.new(faceX, 0, faceZ)
				align.CFrame = CFrame.lookAt(Vector3.zero, facing)
				root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
			end
		end
		-- On the ground an M1 keeps you running (the user, 2026-11-16: "you are mobile while doing them ... run
		-- while punching"), held to Punch.MoveSpeed for Punch.MoveSeconds (Combat.stringSpeed), so you keep up
		-- with the target your punches knock on, but can't drag anyone across the map.
		punchPressedAt = os.clock()
		-- The way the body really faces (after any turn to the locked-on target above), which is where the
		-- swing goes; the heading follows it so nothing turns the body back mid-string.
		local bodyLook = root.CFrame.LookVector
		local faceX, faceZ = Momentum.facing(state)
		if Vector3.new(bodyLook.X, 0, bodyLook.Z).Magnitude > 0.01 then
			local flatLook = Vector3.new(bodyLook.X, 0, bodyLook.Z).Unit
			faceX, faceZ = flatLook.X, flatLook.Z
			local turned = table.clone(state)
			turned.headingX, turned.headingZ = faceX, faceZ
			state = turned
		end
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

	-- The Dash skill (the Base kit's mobility, Q / B). AbilityController owns the key and calls
	-- RequestDash; the dash goes on the next step.
	self._requestDash = function()
		propelRequested = true
	end
	trove:Add(function()
		self._requestDash = nil
	end)

	-- A kit's mobility skill (Jet, Slide, Pounce, Ascend) or an attack skill's lunge: it goes on the
	-- next step, where the keys and the body's travel are known. A request the step can't get to within
	-- a moment (stunned, mid-kick) is dropped, not saved up.
	self._requestSkillMove = function(id: string?, move: any)
		skillMove = { id = id, cfg = move, at = os.clock() }
	end
	trove:Add(function()
		self._requestSkillMove = nil
	end)

	-- The nearest other fighter within `range` studs, for a move aimed at one: who, the flat offset to
	-- them, and how far.
	local function nearestFoe(range: number): (Model?, number?, number?, number?)
		local found: { Model } = {}
		local offsets: { { x: number, z: number } } = {}
		for _, other in CollectionService:GetTagged("HT_Combatant") do
			if other == character or not other:IsA("Model") then
				continue
			end
			local otherRoot = other:FindFirstChild("HumanoidRootPart")
			local otherHumanoid = other:FindFirstChildOfClass("Humanoid")
			if
				not otherRoot
				or not otherRoot:IsA("BasePart")
				or not otherHumanoid
				or otherHumanoid.Health <= 0
				or other:GetAttribute("HT_Spectating") ~= nil
			then
				continue
			end
			local offset = otherRoot.Position - root.Position
			table.insert(found, other)
			table.insert(offsets, { x = offset.X, z = offset.Z })
		end
		local index, distance = SkillMove.nearest(range, offsets)
		if index then
			return found[index], offsets[index].x, offsets[index].z, distance
		end
		return nil, nil, nil, nil
	end

	-- Space: an ordinary jump. A click in the air is the air punch.
	ContextActionService:BindActionAtPriority(
		JUMP_ACTION,
		function(_name: string, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				jumpRequested = true
			end
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:SetTitle(JUMP_ACTION, "Jump")
	trove:Add(function()
		ContextActionService:UnbindAction(JUMP_ACTION)
	end)

	-- BUMPS, the instant they happen (BumpPredict): in a round, this client watches its own body against
	-- every other fighter with the server's own contact rule (Combat.stepBumpPair, swept so a fast pass
	-- can't skip it), and on contact knocks itself back along the line of the collision at once, by the
	-- server's rule for how hard (Combat.bumpOutcome). Their reaction and the impact show here at the same
	-- moment. The server sees the collision too, for stagger, credit and bots, but leaves this body alone.
	local bumpCfg = GameConfig.Knockback
	local bumpPairs: { [Model]: Combat.BumpPair } = setmetatable({}, { __mode = "k" }) :: any
	local bumpedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
	self._bumpedAt = bumpedAt
	local function checkBumps(now: number)
		local mine = root.AssemblyLinearVelocity
		for _, other in CollectionService:GetTagged("HT_Combatant") do
			if other == character or not other:IsA("Model") then
				continue
			end
			local otherRoot = other:FindFirstChild("HumanoidRootPart")
			if not otherRoot or not otherRoot:IsA("BasePart") then
				bumpPairs[other] = nil
				continue
			end
			local offset = otherRoot.Position - root.Position
			local theirs = otherRoot.AssemblyLinearVelocity
			local pair = bumpPairs[other] or Combat.newBumpPair()
			local nextPair, closing = Combat.stepBumpPair(
				bumpCfg,
				pair,
				offset.X,
				offset.Z,
				mine.X - theirs.X,
				mine.Z - theirs.Z,
				now
			)
			bumpPairs[other] = nextPair
			if
				not closing
				or math.abs(offset.Y) > bumpCfg.BumpVerticalLimit
				or not BumpPredict.predicted(character, other)
			then
				continue
			end
			local outcome = Combat.bumpOutcome(
				bumpCfg,
				GameConfig.Stagger,
				cfg.PropelSpeed,
				closing,
				mine.X,
				mine.Z,
				theirs.X,
				theirs.Z
			)
			local lineX, lineZ = Combat.bumpDirection(
				root.Position.X,
				root.Position.Z,
				mine.X,
				mine.Z,
				otherRoot.Position.X,
				otherRoot.Position.Z,
				theirs.X,
				theirs.Z
			)
			bumpedAt[other] = now
			self._applyKnock(
				Vector3.new(-lineX * outcome.knockA, 0, -lineZ * outcome.knockA),
				0,
				outcome.keepA
			)
			fx:BumpPuff(character, other, math.max(outcome.knockA, outcome.knockB))
			local anim = Knit.GetController("AnimController")
			anim:HitLanded(nil, character, outcome.knockA)
			anim:HitLanded(nil, other, outcome.knockB)
		end
	end

	trove:BindToRenderStep(STEP_NAME, STEP_PRIORITY, function(dt: number)
		-- Off (user, 2026-11-11): running or dashing into someone does nothing at all.
		if bumpCfg.BumpsEnabled then
			checkBumps(os.clock())
		end
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local hud = self.Hud
		local flatVelocity = root.AssemblyLinearVelocity
		hud.speed = Vector3.new(flatVelocity.X, 0, flatVelocity.Z).Magnitude
		if Players.LocalPlayer:GetAttribute("HT_TrainingFree") == true then
			state.propelCooldownLeft = 0 -- free practice on the training grounds: no dash cooldown
		end
		hud.propelLeft = state.propelCooldownLeft or 0
		hud.jumpReadyAt = jumpReadyAt
		local inputX, inputZ = worldInput(input)
		-- Winding up a heavy kick: rooted to the spot, the keys do nothing.
		local rooted = os.clock() < rootedUntil
		if rooted then
			inputX, inputZ = 0, 0
		end
		local drive, side = driveOf(inputX, inputZ)
		-- Locked on: the keys lean a little toward them, when they already point roughly their way.
		do
			local targetRoot = (inputX ~= 0 or inputZ ~= 0) and assistTarget()
			if targetRoot then
				local to = targetRoot.Position - root.Position
				inputX, inputZ =
					AimAssist.bendInput(GameConfig.LockOn :: any, inputX, inputZ, to.X, to.Z)
			end
		end

		local now = os.clock()
		local air = character:GetAttribute("HT_Air")
		airSeconds = if grounded then 0 else airSeconds + dt
		if grounded then
			slammed = false
			lifts, liftUntil, liftSet = AirRecovery.newLifts(), 0, false
		end

		-- In a clash: walks to the spot the server gave, and holds there looking at the other fighter.
		-- A knock takes over at once, because the finishing punch is one.
		local clashAt = character:GetAttribute("HT_ClashAt") :: Vector3?
		if clashAt and now >= knockGraceUntil then
			jumpRequested, propelRequested, punchRequested = false, false, false
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
		-- Wading: worked out from where the body is every frame, so it can't stack, and a death or respawn
		-- (away from the water) clears it at once. It multiplies with stagger and every other speed rule.
		do
			local pondCfg: any = GameConfig.Pond
			local live = ActiveArena.get()
			local wantPond = 1
			if pondCfg.Enabled and live.Pond then
				local at = root.Position
				wantPond = Pond.speedShare(
					live.Pond,
					pondCfg.SpeedMultiplier,
					pondCfg.MaxRootAboveFloor,
					at.X - live.CenterX,
					at.Z - live.CenterZ,
					at.Y - live.CenterY
				)
			end
			pondShare += (wantPond - pondShare) * math.min(pondCfg.Ease * dt, 1)
			character:SetAttribute("HT_Wading", if wantPond < 1 then true else nil)
		end
		-- A round's countdown holds you on your spawn the same way a stun does, without the stun's look.
		local stunned = character:GetAttribute("HT_Stunned") ~= nil
			or character:GetAttribute("HT_RoundHold") ~= nil
			-- Watching a fighter's view: your own body stays where it is (SpectateController).
			or character:GetAttribute("HT_Spectating") ~= nil
		if stunned then
			-- A dash pressed in a punch's stun waits for it to end (Combat.dashBuffered), so a string can be
			-- escaped the moment it lets go (the user, 2026-11-16).
			if propelRequested and character:GetAttribute("HT_Stunned") ~= nil then
				dashPressedInStun = now
			end
			jumpRequested, propelRequested, punchRequested = false, false, false
			inputX, inputZ = 0, 0
			drive, side = "side", 0
		elseif dashPressedInStun then
			propelRequested = propelRequested
				or Combat.dashBuffered(punchCfg, dashPressedInStun, now)
			dashPressedInStun = nil
		end
		-- Frozen in ice (the Frost kit's Frostbite; StatusService): held where they are. Nothing they
		-- were doing carries on: no travel, no push, no steering. They still fall.
		if character:GetAttribute("HT_Frozen") ~= nil then
			state = Momentum.stopped(state)
			pushX, pushZ, steerX, steerZ = 0, 0, 0, 0
			skillMove = nil
		end
		-- In an ultimate (either side of it): UltimateController sets this body to the timeline. Nothing of
		-- ours moves it, and nothing carries over afterwards.
		if character:GetAttribute("HT_Ultimate") ~= nil then
			state = Momentum.stopped(state)
			pushX, pushZ, steerX, steerZ = 0, 0, 0, 0
			skillMove = nil
			glide = nil
			humanoid.WalkSpeed = 0
			humanoid:Move(Vector3.zero, false)
			return
		end
		-- Stunned by a punch of someone's M1 string (StatusService): LOCKED in front of them, facing them,
		-- for as long as the stun lasts. Nothing of your own moves you. The user, 2026-11-15: the old lock
		-- "drag[ged] the person to you and teleport[ed] them"; now it keeps the distance you were at when it
		-- began (Combat.lockDistance) and FOLLOWS the spot smoothly, carried at their speed so their punch's
		-- step moves you both together (Combat.lockFollow), never jumping.
		do
			local locked = character:FindFirstChild("HT_DraggedBy")
			local by = if locked and locked:IsA("ObjectValue") then locked.Value else nil
			local byRoot = if by and by:IsA("Model")
				then by:FindFirstChild("HumanoidRootPart") :: BasePart? -- lihfolk-ignore: findfirstchild-chain (a type cast, nil-checked on the next line)
				else nil
			if character:GetAttribute("HT_Stunned") ~= nil and byRoot and now - thrownAt > 0.35 then
				local byLook = byRoot.CFrame.LookVector
				local moving = byRoot.AssemblyLinearVelocity
				local from = byRoot.Position
				if by ~= lockBy or now - lockSeenAt > 0.4 then
					local gap = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
					lockBy = by :: Model
					lockAhead = Combat.lockDistance(punchCfg, gap.Magnitude)
				end
				lockSeenAt = now
				-- The spot the server picked for this punch (StatusService HT_LockSpot: in front of them, a step
				-- on) holds still between punches, so it's glided to with nothing to carry. Without one, the
				-- old way: in front of their body as it's seen here.
				local held = character:GetAttribute("HT_LockSpot") :: Vector3?
				local x, z
				if held then
					x, z = held.X, held.Z
					moving = Vector3.zero
				else
					x, z = Combat.lockSpot(punchCfg, from.X, from.Z, byLook.X, byLook.Z, lockAhead)
				end
				-- Never through a wall: it stops at the first solid thing between the puncher and the spot.
				local start = byRoot.Position
				local toward = Vector3.new(x - start.X, 0, z - start.Z)
				if not held and toward.Magnitude > 0.01 then
					local hit = workspace:Raycast(
						start,
						toward.Unit * (toward.Magnitude + punchCfg.LockBodyRadius),
						solidParams()
					)
					x, z = Combat.clipLock(
						punchCfg,
						start.X,
						start.Z,
						x,
						z,
						if hit then hit.Distance else nil
					)
				end
				local nx, nz = Combat.lockFollow(
					punchCfg,
					root.Position.X,
					root.Position.Z,
					x,
					z,
					moving.X,
					moving.Z,
					dt
				)
				local spot = Vector3.new(nx, root.Position.Y, nz)
				state = Momentum.stopped(state)
				pushX, pushZ, steerX, steerZ = 0, 0, 0, 0
				skillMove = nil
				glide = nil
				humanoid.WalkSpeed = 0
				humanoid:Move(Vector3.zero, false)
				local facing = Vector3.new(from.X - spot.X, 0, from.Z - spot.Z)
				local stepped = Vector3.new(nx - root.Position.X, 0, nz - root.Position.Z)
				root.CFrame = if facing.Magnitude > 0.05
					then CFrame.lookAt(spot, spot + facing)
					else CFrame.new(spot) * root.CFrame.Rotation
				if facing.Magnitude > 0.05 then
					align.CFrame = CFrame.lookAt(Vector3.zero, facing)
				end
				-- The velocity it really moved at, so everyone else's copy of this body glides too.
				local carried = if dt > 0 then stepped / dt else Vector3.zero
				root.AssemblyLinearVelocity =
					Vector3.new(carried.X, root.AssemblyLinearVelocity.Y, carried.Z)
				return
			end
		end
		-- Anywhere in the air without something else moving the body, the keys steer it.
		local freeAir = not grounded and not floating and not airRun and not stunned
		if not floating and not freeAir then
			steerX, steerZ = 0, 0
		end
		-- A push still going on landing carries on along the floor, and fades the way knockback does there.
		if grounded and (pushX ~= 0 or pushZ ~= 0) then
			state = Momentum.addPush(state, cfg, pushX, pushZ)
			pushX, pushZ = 0, 0
		end

		local pressed = jumpRequested
		jumpRequested = false
		if
			pressed
			and grounded
			and not floating
			and not stunned
			and not rooted
			and not jumping
			and now >= jumpReadyAt
			and not Knit.GetController("EndlagController"):IsBusy()
		then
			-- An ordinary jump: up, and forward with the speed you had. Not while still
			-- recovering from another move (Core/Endlag).
			local moving = root.AssemblyLinearVelocity
			local level = Vector3.new(moving.X, 0, moving.Z)
			local up, forward = Jump.launch(jumpCfg, level.Magnitude)
			-- NO JUMP COOLDOWN IN THE LOBBY (the owner, 2026-11-18): it is a fight's rule, and in
			-- the lobby, its practice end too, you may jump again as soon as you land. In a
			-- round (the server marks you HT_InRound) the cooldown stands as before.
			local inRound = Players.LocalPlayer:GetAttribute("HT_InRound") == true
			jumpReadyAt = if inRound then now + jumpCfg.Cooldown else now
			jumping = true
			if forward then
				state = Momentum.moving(state, level.X, level.Z, forward)
			end
			airRun = { t = 0, gravityScale = jumpCfg.GravityScale, keep = forward }
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			local vx, vz = Momentum.velocity(state)
			root.AssemblyLinearVelocity = Vector3.new(vx, up, vz)
		end

		if airRun then
			airRun.t += dt
			if grounded and airRun.t >= LAND_CHECK_SECONDS then
				if airRun.keep then
					state = Momentum.landed(state, cfg)
				end
				airRun = nil
				jumping = false
			end
		end

		-- A jump that lost its air run some other way is over once it's back on the floor.
		if jumping and not glide and not airRun and grounded then
			jumping = false
		end

		if glide then
			glide.t += dt
			propelRequested, punchRequested = false, false
			pushX, pushZ, lift = 0, 0, 0
			steerX, steerZ = 0, 0
			local level = Vector3.new(glide.dir.X, 0, glide.dir.Z)
			local done = (grounded and glide.t >= GLIDE_LAND_SECONDS)
				or stunned
				or glide.t >= punchCfg.AirGlideSeconds
			if done then
				-- Arrived: it carries on with a little of the glide's speed, as an ordinary fall.
				state = if level.Magnitude > 0.05
					then Momentum.moving(
						state,
						level.Unit.X,
						level.Unit.Z,
						level.Magnitude * glide.speed * 0.25
					)
					else state
				root.AssemblyLinearVelocity = glide.dir * glide.speed * 0.15
				glide = nil
			else
				humanoid.WalkSpeed = 0
				humanoid:Move(Vector3.zero, false)
				root.AssemblyLinearVelocity = glide.dir * glide.speed
				if level.Magnitude > 0.05 then
					align.CFrame = CFrame.lookAt(Vector3.zero, level)
				end
				if rootJoint then
					rootJoint.C0 = baseC0
				end
				return
			end
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

		-- A kit's mobility skill or an attack skill's lunge (Core/SkillMove). A burst is a dash with its
		-- own length, speed and steering; a leap is a jump with its own speeds, flown as an air run.
		if skillMove then
			local request = skillMove
			skillMove = nil
			local move = request.cfg
			if now - request.at <= SKILL_MOVE_WAIT then
				local moving = root.AssemblyLinearVelocity
				local faceX, faceZ = Momentum.facing(state)
				local foe: Model? = nil
				local foeX: number?, foeZ: number?, foeDistance: number? = nil, nil, nil
				if move.Aim == "foe" or move.Aim == "away" then
					foe, foeX, foeZ, foeDistance = nearestFoe(move.Range or 0)
				end
				local dirX, dirZ = SkillMove.direction(
					move.Aim,
					inputX,
					inputZ,
					cfg.InputDeadzone,
					moving.X,
					moving.Z,
					jumpCfg.MoveMinSpeed,
					faceX,
					faceZ,
					foeX,
					foeZ
				)
				if dirX and dirZ then
					if move.Kind == "leap" then
						local up, forward = SkillMove.leap(move, workspace.Gravity, foeDistance)
						state = Momentum.moving(state, dirX, dirZ, forward)
						airRun = { t = 0, gravityScale = jumpCfg.GravityScale, keep = forward }
						jumping = true
						slammed = false
						liftUntil, liftSet = 0, false
						humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
						local vx, vz = Momentum.velocity(state)
						root.AssemblyLinearVelocity = Vector3.new(vx, up, vz)
					else
						state = SkillMove.burst(
							state :: any,
							dirX,
							dirZ,
							move.Speed,
							move.Seconds or 0.2,
							move.Turn
						) :: any
					end
					if request.id then
						fx:KitMove(character, request.id, Vector3.new(dirX, 0, dirZ), foe)
						local remote = self._kitMoveRemote
						if remote then
							remote:FireServer()
						end
					end
				end
			end
		end

		if propelRequested then
			propelRequested = false
			-- A burst the way you're already going; from a standstill, the way the keys point. Always a
			-- plain one (power 0): the dash can't be charged.
			local propelled = Momentum.tryPropel(state, cfg, inputX, inputZ, drive, 0)
			if not propelled then
				self.PropelBlocked:Fire()
			else
				state = propelled
				self.Propelled:Fire()
				fx:PropelGust(character, state.dashSeconds, 0)
				fx:DashZoom(state.dashSeconds or cfg.PropelSeconds, 0)
				if propelRemote then
					propelRemote:FireServer(0)
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
			if rooted then
				state = Momentum.rootSlow(state, cfg, dt)
			end
			-- Throwing M1s: running, but no faster than Punch.MoveSpeed (a dash still goes at its own speed).
			if grounded and (state.propelLeft or 0) <= 0 then
				local capped = Combat.stringSpeed(punchCfg, state.speed, punchPressedAt, now)
				-- and never through the one you're punching: no nearer than LockMinDistance to anyone ahead
				-- (Combat.frontRoom), so you chase them like a dribbled ball instead of running past
				if punchPressedAt and now - punchPressedAt <= punchCfg.MoveSeconds and dt > 0 then
					local faceX, faceZ = Momentum.facing(state)
					local others: { { x: number, z: number } } = {}
					for _, other in CollectionService:GetTagged("HT_Combatant") do
						local otherRoot = other ~= character
							and other:FindFirstChild("HumanoidRootPart")
						if otherRoot and otherRoot:IsA("BasePart") then
							local offset = otherRoot.Position - root.Position
							if offset.Magnitude < 12 then
								table.insert(others, { x = offset.X, z = offset.Z })
							end
						end
					end
					capped = math.min(capped, Combat.frontRoom(punchCfg, faceX, faceZ, others) / dt)
				end
				if capped < state.speed then
					local slowed = table.clone(state)
					slowed.speed = capped
					state = slowed
				end
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
		-- Charging an attack skill (R held, AbilityController): you move at SkillHold.MoveShare.
		local chargeShare = if character:GetAttribute("HT_Charging") ~= nil
			then GameConfig.SkillHold.MoveShare
			else 1
		local travelShare = if airRun and airRun.keep
			then 1
			else speedShare * pondShare * chargeShare
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
--- The Dash skill: asks for a dash on the next movement step. False when there's no body to dash with.
function MovementController:RequestDash(): boolean
	local request = self._requestDash
	if request then
		request()
		return true
	end
	return false
end

--- A kit's mobility skill (`id`: Jet, Slide, Pounce, Ascend, with its numbers from
--- Config/Abilities.KitMoves), or with no id an attack skill's lunge: asks for it on the next
--- movement step. False when there's no body to move.
function MovementController:SkillMove(id: string?, move: any): boolean
	local request = self._requestSkillMove
	if request then
		request(id, move)
		return true
	end
	return false
end

function MovementController:PunchThrown(swing: string?)
	if self._punchThrown then
		self._punchThrown(swing)
	end
end

--- An attack skill that roots started: rooted for `seconds`, through its strike.
function MovementController:HeavyKickStarted(seconds: number)
	if self._heavyKick then
		self._heavyKick(seconds)
	end
end

--- Did this client already show its own bump with `other` just now (BumpPredict)? The server's word on
--- the same collision arrives later and is then only for everyone else.
function MovementController:RecentlyBumped(other: Model): boolean
	local at = self._bumpedAt and self._bumpedAt[other]
	return at ~= nil and os.clock() - at < 0.75
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
	self._kitMoveRemote = Net.client("KitMoveRequest")
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
