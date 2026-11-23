--!strict
-- AnimController - plays the boxer's clips on every fighter this client can see, the bot too.
--
-- The clips are uploaded animations, whose ids are in Config/AnimAssetIds. Runtime-registered ids play
-- nothing in a live game, with no error, so those are only ever used in Studio, to preview a clip that
-- hasn't been uploaded yet. Each client drives every fighter's clips itself, from what already
-- replicates: velocity, and the server's PunchStarted.
--
-- Layers, lowest first: the stock walk and run (Core), the guard and standing stance (Idle), the
-- sprint (Movement), the brake and landing (Action), the swings (Action2), the kick (Action3), the
-- reactions to being hit (Action4).
--
-- Hit stop and shake are purely visual: the pose freezes and the body shakes through the root joint's
-- C1, which the movement code leaves alone and which doesn't replicate. Nothing the server or physics
-- cares about ever moves or waits. See the vault's Nintendo-Inspired Combat Animation Research.

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AnimClips = require(ReplicatedStorage.Shared.Config.AnimClips)
local AnimAssetIds = require(ReplicatedStorage.Shared.Config.AnimAssetIds)
local AnimSequence = require(ReplicatedStorage.Shared.AnimSequence)
local AnimVariants = require(ReplicatedStorage.Shared.AnimVariants)
local Net = require(ReplicatedStorage.Shared.Net)

local cfg = GameConfig.Animation
-- Every clip that is played: the baked ones, and each kit's own punches made from them
-- (Shared/AnimVariants).
local Clips: any = AnimVariants.all(AnimClips :: any)
-- The ultimate's own clips (kits-7d: BarrageUp, HaymakerUp) live in their own module, because AnimClips is at
-- Studio's size limit.
for name, clip in require(ReplicatedStorage.Shared.Config.AnimClipsUltimate) :: any do
	Clips[name] = clip
end
-- Hand-keyed clips (the .blend files in animations/hand, written by animations/export_hand_clips.py). STUDIO ONLY
-- for now (jab-1, a test piece): none is uploaded, so in a live game they could not play.
if RunService:IsStudio() then
	for name, clip in require(ReplicatedStorage.Shared.Config.AnimClipsHand) :: any do
		Clips[name] = clip
	end
end

-- The kit a fighter is wearing, for the punches it throws. Nil for bots and bodies with no player.
local function kitOf(model: Model): string?
	local player = game:GetService("Players"):GetPlayerFromCharacter(model)
	local kit = player and player:GetAttribute("HT_Kit")
	return if typeof(kit) == "string" then kit else nil
end
local maxSpeed = GameConfig.Movement.MaxSpeed
local COMBATANT_TAG = "HT_Combatant"
local OFF_WEIGHT = 0.001 -- a looping track stays running and in step, without showing
local SWING_FADE = 0.033
local SKILL_FADE = 0.033
local KICK_FADE = 0.016 -- the kick's first frame is its big pose: it has to arrive at once
local FAST_FADE = 0.05
local STRIKE_EVENT = AnimSequence.STRIKE_EVENT
local TIP_LIFE = 0.5 -- seconds the fist's position stays useful after the strike

-- The kick's phases, from the server's attribute on the character.
local SKILL_CLIPS: { [string]: string } = {
	chase = "KickLeap",
	attach = "KickAim",
	flip = "KickSpin",
	kick = "KickDown",
	dive = "KickDown", -- the dive kick out of a jump: the same heel-down pose, all the way to the floor
}
local SWING_ARMS: { [string]: string } = {
	Left = "Left Arm",
	Right = "Right Arm",
	Uppercut = "Right Arm",
	Cyclone = "Right Arm",
	HaymakerUp = "Right Arm",
}

local SWING_CLIPS: { [string]: string } = {
	Left = "HookLeft",
	Right = "HookRight",
	Uppercut = "Uppercut",
	-- The Cyclone is the right hook thrown while the whole body turns once round (the spin is added on
	-- the root joint, below): AnimClips has no room for a clip of its own.
	Cyclone = "HookRight",
	-- the ultimate's rising haymaker, up and away (Haymaker Rush, held then let go)
	HaymakerUp = "HaymakerUp",
}
-- How long each heavy swing takes to strike; the rest use the punch's windup.
local SWING_WINDUPS: { [string]: number } = {
	Uppercut = GameConfig.Uppercut.Windup,
	Cyclone = Abilities.Cyclone.Windup,
}
-- The newer kits' attack skills (Config/Abilities.KitSwings) borrow a swing clip each, stretched to
-- their own windup: AnimClips has no room for more clips.
for skillId, swing in Abilities.KitSwings :: { [string]: any } do
	SWING_ARMS[skillId] = swing.Arm
	SWING_CLIPS[skillId] = swing.Clip
	SWING_WINDUPS[skillId] = swing.Windup
end
-- Someone else charging an attack skill (R held), from the server's attribute (the skill it will be).
local READY_ATTRIBUTE = "HT_ChargingSkill"

local AnimController = Knit.CreateController({
	Name = "AnimController",
})

type Fighter = {
	tracks: { [string]: AnimationTrack },
	runTime: number,
	lastSpeed: number,
	brakingFor: number,
	skill: string?,
	strikePending: { () -> () }?,
	strikeArm: string?,
	strikeTip: Vector3?,
	strikeAt: number,
	rootJoint: Motor6D?,
	baseC1: CFrame,
	offsetting: boolean,
	swingName: string?,
	heldSwing: string?, -- the swing track waiting drawn back while a punch is held
	readySeen: string?, -- someone else's held punch, from the server's attribute
	lastSide: string?,
	stopUntil: number,
	stopped: { AnimationTrack },
	shakeStart: number,
	shakeUntil: number,
	shakeStuds: number,
	hitAt: number,
	floorHitAt: number,
	wasAirborne: boolean,
	lastRise: number,
	wasBraking: boolean,
	brakeSpeed: number,
	tiltAxis: Vector3,
	tiltAngle: number,
	tiltSpeed: number,
	skidding: boolean,
	spinAt: number, -- when a Cyclone's body spin started
	spinSeconds: number,
	barrageClip: string?, -- the barrage loop playing now (SetBarrage)
	dashing: boolean, -- a scripted sprint (SetDash): the run shows though the body is set, not moving
	-- in an ultimate's cutscene (SetCutscene, kits-7i): the timeline poses the body, so the knocked-about blends
	-- (AirTumble, Slammed, HitSkid) stay off and the flinches show (the gap study: AirTumble averaged them away)
	cutscene: boolean,
	clipName: string?, -- the whole-body pose clip the ultimate's timeline is driving (SyncClip)
	stretched: { part: BasePart, size: Vector3, joint: Motor6D?, c1: CFrame }?, -- an arm mid-smear (StretchArm)
}

local animations: { [string]: Animation } = {}
local fighters: { [Model]: Fighter } = {}
local baseC1s: { [Motor6D]: CFrame } = {}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function setUpFighter(model: Model): Fighter?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local rootJoint = root and root:FindFirstChild("RootJoint") :: Motor6D?
	if rootJoint and not baseC1s[rootJoint] then
		baseC1s[rootJoint] = rootJoint.C1
	end
	local fighter: Fighter = {
		tracks = {},
		runTime = 0,
		lastSpeed = 0,
		brakingFor = 0,
		strikeAt = 0,
		rootJoint = rootJoint,
		baseC1 = if rootJoint then baseC1s[rootJoint] else CFrame.identity,
		offsetting = false,
		stopUntil = 0,
		stopped = {},
		shakeStart = 0,
		shakeUntil = 0,
		shakeStuds = 0,
		hitAt = -math.huge,
		floorHitAt = -math.huge,
		wasAirborne = false,
		lastRise = 0,
		wasBraking = false,
		brakeSpeed = 0,
		tiltAxis = Vector3.xAxis,
		tiltAngle = 0,
		tiltSpeed = 0,
		skidding = false,
		spinAt = -math.huge,
		spinSeconds = 1,
		dashing = false,
		cutscene = false,
	}
	for name, animation in animations do
		local track = (animator :: Animator):LoadAnimation(animation)
		fighter.tracks[name] = track
		if Clips[name].strike then
			track:GetMarkerReachedSignal(STRIKE_EVENT):Connect(function()
				-- The lead-in was slowed to the windup. From the strike on, the swing plays at its own pace.
				if track.Speed > 0 and track.Speed < 1 then
					track:AdjustSpeed(1)
				end
				local arm = fighter.strikeArm
					and model:FindFirstChild(fighter.strikeArm) :: BasePart?
				if arm then
					fighter.strikeTip = (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position
					fighter.strikeAt = os.clock()
				end
				local waiting = fighter.strikePending
				fighter.strikePending = nil
				if waiting then
					for _, callback in waiting do
						callback()
					end
				end
			end)
		end
	end
	-- These run the whole time and are only ever faded, so they never restart mid-stride.
	for _, name in { "Guard", "Stance", "Sprint", "Brake", "AirTumble", "Slammed", "HitSkid" } do
		local track = fighter.tracks[name]
		if track then
			track:Play(0, OFF_WEIGHT)
		end
	end
	fighters[model] = fighter
	return fighter
end

local function updateSkill(model: Model, fighter: Fighter)
	local skill = model:GetAttribute("HT_Skill") :: string?
	if skill == fighter.skill then
		return
	end
	local old = fighter.skill and SKILL_CLIPS[fighter.skill]
	if old and fighter.tracks[old] then
		fighter.tracks[old]:Stop(SKILL_FADE)
	end
	fighter.skill = skill
	-- The squat's end is the spring, for everyone watching. Your own jump shows it from
	-- MovementController, at the exact moment you leave the floor.
	if skill == "chase" and model ~= game:GetService("Players").LocalPlayer.Character then
		task.delay(GameConfig.Kick.JumpSquatSeconds, function()
			if model.Parent then
				Knit.GetController("FxController")
					:JumpBreak(model, GameConfig.Effects.GroundBreakWatchReach)
			end
		end)
	end
	local clip = skill and SKILL_CLIPS[skill]
	if clip and fighter.tracks[clip] then
		fighter.tracks[clip]:Play(if skill == "kick" then KICK_FADE else SKILL_FADE, 1, 1)
	end
end

local function setWeight(track: AnimationTrack?, weight: number, fade: number?)
	if track then
		track:AdjustWeight(math.max(weight, OFF_WEIGHT), fade or cfg.FadeSeconds)
	end
end

-- A running swing's body turn, at this moment in its clip. It's in degrees toward the punch.
local function swingTurn(fighter: Fighter): number
	local name = fighter.swingName
	local clip = name and Clips[name]
	local track = name and fighter.tracks[name]
	if not clip or not clip.turn or not track or not track.IsPlaying then
		return 0
	end
	local turn = clip.turn
	local t = track.TimePosition
	for index = 2, #turn do
		local before, after = turn[index - 1], turn[index]
		if t <= after[1] then
			local share = (t - before[1]) / math.max(after[1] - before[1], 0.001)
			return before[2] + (after[2] - before[2]) * clamp01(share)
		end
	end
	return turn[#turn][2]
end

-- What the root joint adds on top of the animation: hit shake, and a running swing's body turn. A
-- swing can't turn the torso over a run, because the legs hang off it, so the whole body turns.
local function applyBodyOffset(fighter: Fighter, now: number, airborne: boolean, dt: number)
	local joint = fighter.rootJoint
	if not joint then
		return
	end
	local turn = swingTurn(fighter)
	-- A Cyclone: the whole body goes once round, fastest at the start so the fist comes through as the
	-- swing strikes, easing out to where it began.
	local spun = (now - fighter.spinAt) / math.max(fighter.spinSeconds, 0.01)
	if spun >= 0 and spun < 1 then
		turn += 360 * (1 - (1 - spun) ^ 2)
	end
	local shaking = now < fighter.shakeUntil
	-- Thrown over by a hit, then springing back past upright and settling: the bounce in a reaction.
	-- It runs on a capped step, so a slow frame can't blow the spring up.
	if fighter.tiltAngle ~= 0 or fighter.tiltSpeed ~= 0 then
		local step = math.min(dt, 1 / 30)
		local pull = -cfg.HitTiltStiffness * fighter.tiltAngle
			- cfg.HitTiltDamping * fighter.tiltSpeed
		fighter.tiltSpeed += pull * step
		fighter.tiltAngle += fighter.tiltSpeed * step
		if math.abs(fighter.tiltAngle) < 0.002 and math.abs(fighter.tiltSpeed) < 0.02 then
			fighter.tiltAngle, fighter.tiltSpeed = 0, 0
		end
	end
	if not shaking and turn == 0 and fighter.tiltAngle == 0 then
		if fighter.offsetting then
			fighter.offsetting = false
			joint.C1 = fighter.baseC1
		end
		return
	end
	fighter.offsetting = true
	local offset = Vector3.zero
	if shaking then
		-- Large at first and dying away. Sideways on the floor, in every direction in the air, since
		-- going up and down on the floor would sink the feet into it.
		local left = (fighter.shakeUntil - now)
			/ math.max(fighter.shakeUntil - fighter.shakeStart, 0.001)
		local size = fighter.shakeStuds * left
		offset = Vector3.new(
			(math.random() * 2 - 1) * size,
			if airborne then (math.random() * 2 - 1) * size else 0,
			(math.random() * 2 - 1) * size
		)
	end
	joint.C1 = CFrame.new(offset)
		* CFrame.Angles(0, math.rad(-turn), 0)
		* CFrame.fromAxisAngle(fighter.tiltAxis, -fighter.tiltAngle)
		* fighter.baseC1
end

local function shake(fighter: Fighter, seconds: number, studs: number)
	local now = os.clock()
	-- A bigger shake isn't cut short by a smaller one.
	if now < fighter.shakeUntil and fighter.shakeStuds > studs then
		return
	end
	fighter.shakeStart = now
	fighter.shakeUntil = now + seconds
	fighter.shakeStuds = studs
end

-- Freezes whichever attack poses this fighter is showing. They creep rather than stop dead, and a
-- longer stop always beats a shorter one. Movement underneath carries on.
local function freezePose(fighter: Fighter, seconds: number)
	fighter.stopUntil = math.max(fighter.stopUntil, os.clock() + seconds)
	local names = { fighter.swingName, if fighter.skill then SKILL_CLIPS[fighter.skill] else nil }
	for _, name in names do
		local track = name and fighter.tracks[name]
		if track and track.IsPlaying and not table.find(fighter.stopped, track) then
			track:AdjustSpeed(cfg.HitStopCreep)
			table.insert(fighter.stopped, track)
		end
	end
end

local function updateFighter(model: Model, dt: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local fighter = fighters[model]
	-- The stock Animate script clears every track on a character when it starts, which can be
	-- after we set up. If the always-on guard has stopped, load them all again.
	if fighter and fighter.tracks.Guard and not fighter.tracks.Guard.IsPlaying then
		fighter = nil
	end
	fighter = fighter or setUpFighter(model)
	if not fighter then
		return
	end

	updateSkill(model, fighter)
	if model ~= game:GetService("Players").LocalPlayer.Character then
		local ready = model:GetAttribute(READY_ATTRIBUTE) :: string?
		if ready ~= fighter.readySeen then
			fighter.readySeen = ready
			if ready then
				AnimController:HoldSwing(model, ready)
			elseif fighter.heldSwing then
				-- Thrown, the swing itself takes over; dropped, this lets go a moment later.
				task.delay(0.25, function()
					if fighter.readySeen == nil and fighter.heldSwing then
						fighter.heldSwing = nil
						AnimController:CancelSwing(model)
					end
				end)
			end
		end
	end
	-- A held punch waits drawn back at its clip's hold point.
	local heldTrack = fighter.heldSwing and fighter.tracks[fighter.heldSwing]
	local holdAt = fighter.heldSwing and Clips[fighter.heldSwing].hold
	if
		heldTrack
		and holdAt
		and heldTrack.IsPlaying
		and heldTrack.Speed > 0
		and heldTrack.TimePosition >= holdAt
	then
		heldTrack:AdjustSpeed(0)
		heldTrack.TimePosition = holdAt
	end

	local now = os.clock()
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	-- A held punch follows how you're moving NOW, not how you were when you pressed. The standing clip poses
	-- the legs and torso too (a planted stance), and it waits frozen above the run's priority, so held while
	-- you then ran it pinned the legs still. Once the hold has settled, moving swaps it for the arms-and-head
	-- variant (the run moves the legs) and stopping swaps it back, cross-faded at the same drawn-back pose.
	if heldTrack and holdAt and heldTrack.IsPlaying and heldTrack.Speed == 0 then
		local name = fighter.heldSwing :: string
		local base = if string.sub(name, -3) == "Run" then string.sub(name, 1, -4) else name
		local want = name
		if speed >= cfg.HoldMoveSpeed then
			want = `{base}Run`
		elseif speed <= cfg.HoldStandSpeed then
			want = base
		end
		local other = fighter.tracks[want]
		local otherHold = other and Clips[want].hold
		if want ~= name and other and otherHold then
			other:Play(cfg.HoldSwapFade, 1, 0)
			other.TimePosition = otherHold
			heldTrack:Stop(cfg.HoldSwapFade)
			fighter.heldSwing = want
			fighter.swingName = want
		end
	end
	local state = humanoid:GetState()
	local grounded = state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.FallingDown
		and state ~= Enum.HumanoidStateType.Ragdoll
	local airborne = not grounded or math.abs(velocity.Y) > 12

	-- The hit stop ends.
	if now >= fighter.stopUntil and #fighter.stopped > 0 then
		for _, track in fighter.stopped do
			if track.IsPlaying then
				track:AdjustSpeed(1)
			end
		end
		table.clear(fighter.stopped)
	end

	-- A swing that has run its course fades into whatever is underneath, so it never pops.
	local swing = fighter.swingName and fighter.tracks[fighter.swingName]
	if swing and swing.IsPlaying and swing.TimePosition >= swing.Length - cfg.SwingEndFade then
		swing:Stop(cfg.SwingEndFade)
		fighter.swingName = nil
	end

	applyBodyOffset(fighter, now, airborne, dt)

	-- Being knocked about in the air: stretched while launched, trailing when driven down.
	local air = model:GetAttribute("HT_Air")
	local knocked = air ~= nil
		or model:GetAttribute("HT_Stunned") ~= nil
		or (airborne and now - fighter.hitAt < cfg.RecentHitSeconds)
	knocked = knocked and fighter.skill == nil and not fighter.cutscene
	local slammed = knocked and air == nil and velocity.Y < -cfg.SlammedFallSpeed
	local onFloorHit = now - fighter.floorHitAt < 0.26
	setWeight(
		fighter.tracks.AirTumble,
		if knocked and airborne and not slammed and not onFloorHit then 1 else 0,
		FAST_FADE
	)
	setWeight(fighter.tracks.Slammed, if slammed then 1 else 0, FAST_FADE)
	if fighter.tracks.AirTumble then
		fighter.tracks.AirTumble:AdjustSpeed(if air == "hold" then 0.25 else 1)
	end

	-- Knocked backward along the floor: heels dug in. When the slide ends, the weight rocks forward.
	local look = root.CFrame.LookVector
	local sliding = Vector3.new(velocity.X, 0, velocity.Z):Dot(Vector3.new(look.X, 0, look.Z))
	local skidding = not airborne
		and now - fighter.hitAt < cfg.SkidHoldSeconds
		and sliding < -cfg.SkidMinSpeed
		and fighter.skill == nil
	setWeight(fighter.tracks.HitSkid, if skidding and not fighter.cutscene then 1 else 0, FAST_FADE)
	if fighter.skidding and not skidding and not airborne and fighter.tracks.BrakeSettle then
		fighter.tracks.BrakeSettle:Play(FAST_FADE, 0.8, 1)
	end
	fighter.skidding = skidding

	-- Coming down hard, unless the floor's arrival already had its own moment.
	if
		fighter.wasAirborne
		and not airborne
		and fighter.lastRise <= -cfg.LandMinFallSpeed
		and not onFloorHit
		and fighter.tracks.Land
	then
		local still = 1 - clamp01(speed / cfg.LandFullStillSpeed)
		fighter.tracks.Land:Play(KICK_FADE, math.max(still, cfg.LandWeightMin), 1)
	end
	fighter.wasAirborne = airborne
	fighter.lastRise = velocity.Y

	-- The longer the run at speed, the faster the stride, and it winds back down when you stop.
	if grounded and speed >= maxSpeed * cfg.RunRampMinShare then
		fighter.runTime = math.min(fighter.runTime + dt, cfg.RunRampSeconds)
	else
		fighter.runTime = math.max(fighter.runTime - dt * cfg.RunRampFallRate, 0)
	end
	local ramp = cfg.RunRampStart
		+ (cfg.RunRampEnd - cfg.RunRampStart) * clamp01(fighter.runTime / cfg.RunRampSeconds)
	local pace = math.clamp(speed / maxSpeed, cfg.RunPaceMin, cfg.RunPaceMax)

	-- Braking is read from the slowdown itself, so it works for every fighter on this client.
	-- It has to last a moment, because a hit or a bump is one sudden drop, not a brake.
	local slowing = dt > 0 and (fighter.lastSpeed - speed) / dt or 0
	fighter.lastSpeed = speed
	-- Above top speed it's a propel fading, not a brake.
	if
		grounded
		and speed >= cfg.BrakeMinSpeed
		and speed <= maxSpeed * 1.05
		and slowing >= cfg.BrakeDeceleration
	then
		fighter.brakingFor += dt
	elseif speed < cfg.BrakeMinSpeed or slowing < cfg.BrakeDeceleration * 0.5 then
		fighter.brakingFor = 0
	end
	local braking = fighter.brakingFor >= cfg.BrakeHoldSeconds

	local sprint = fighter.tracks.Sprint
	if sprint then
		if fighter.dashing then
			-- a scripted dash (the ultimate's rush): full sprint at the top stride, whatever the body's velocity says
			setWeight(sprint, 1, FAST_FADE)
			sprint:AdjustSpeed(cfg.RunRampEnd * cfg.RunPaceMax)
		else
			local blend =
				clamp01((speed - cfg.SprintBlendLow) / (cfg.SprintBlendHigh - cfg.SprintBlendLow))
			setWeight(sprint, if grounded and not braking then blend else 0)
			sprint:AdjustSpeed(ramp * pace)
		end
	end
	setWeight(
		fighter.tracks.Stance,
		if grounded and speed < cfg.StanceMaxSpeed and not fighter.dashing then 1 else 0
	)
	setWeight(fighter.tracks.Guard, 1)

	-- The skid shows at once, as strongly as how fast you were going. When it ends the momentum rocks
	-- you forward over your feet, unless you're running again, which simply takes over.
	if braking and not fighter.wasBraking then
		fighter.brakeSpeed = speed
	end
	local brakeShare = clamp01(fighter.brakeSpeed / maxSpeed)
	if braking then
		setWeight(fighter.tracks.Brake, math.max(cfg.BrakeWeightMin, brakeShare), cfg.BrakeFadeIn)
	else
		setWeight(fighter.tracks.Brake, 0, cfg.BrakeFadeOut)
	end
	local settle = fighter.tracks.BrakeSettle
	if settle then
		if
			fighter.wasBraking
			and not braking
			and brakeShare >= cfg.BrakeSettleMinShare
			and grounded
		then
			settle:Play(FAST_FADE, math.max(cfg.BrakeWeightMin, brakeShare), 1)
		elseif settle.IsPlaying and speed > cfg.SprintBlendLow and slowing < 0 then
			-- Only speeding back up cuts it short. It always starts with some speed left.
			settle:Stop(cfg.FadeSeconds)
		end
	end
	fighter.wasBraking = braking
end

--- Throws a swing on a fighter. `side` is the server's: Left, Right or Uppercut.
function AnimController:PlaySwing(model: Model, side: string, windupOverride: number?)
	-- An ordinary punch is the kit's own, when the kit has one (only the look: the swing is the same).
	local clip = AnimVariants.swing(kitOf(model), side) or SWING_CLIPS[side]
	local fighter = fighters[model]
	if not clip or not fighter then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = 0
	if root then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	end
	local chosen = if (speed >= cfg.RunVariantSpeed or fighter.dashing)
			and fighter.tracks[`{clip}Run`]
		then `{clip}Run`
		else clip
	local held = fighter.heldSwing
	fighter.heldSwing = nil
	-- A held swing carries on as it is, even if the run variant would now be the other one.
	if
		held
		and string.sub(held, 1, #clip) == clip
		and fighter.tracks[held]
		and fighter.tracks[held].IsPlaying
	then
		chosen = held
	end
	-- Every other swing stops: the boxer's and the kits' alike (a swing clip is one with a strike).
	for name, other in fighter.tracks do
		if name ~= chosen and Clips[name].strike and other.IsPlaying then
			other:Stop(SWING_FADE)
		end
	end
	local track = fighter.tracks[chosen]
	if track then
		-- Hits waiting on the swing this replaces shouldn't be lost.
		local waiting = fighter.strikePending
		fighter.strikePending = nil
		if waiting then
			for _, callback in waiting do
				callback()
			end
		end
		fighter.swingName = chosen
		fighter.lastSide = side
		fighter.strikeArm = SWING_ARMS[side]
		fighter.strikePending = {}
		fighter.strikeTip = nil
		-- The lead-in to the strike is stretched over the whole windup, so the fist lands when the server
		-- decides the hit.
		local strike = Clips[chosen].strike or 0
		local windup =
			math.max(windupOverride or SWING_WINDUPS[side] or GameConfig.Punch.Windup, 0.01)
		if side == "Cyclone" then
			fighter.spinAt = os.clock()
			fighter.spinSeconds = Abilities.Cyclone.SpinSeconds
		else
			-- A kit swing that spins the body too (the Trickster's Backfist).
			local kitSwing = (Abilities.KitSwings :: any)[side]
			if kitSwing and kitSwing.Spin then
				fighter.spinAt = os.clock()
				fighter.spinSeconds = kitSwing.Spin
			end
		end
		if held == chosen and track.IsPlaying then
			-- Let go of a held attack skill (R): it carries on from where it waited.
			track:AdjustSpeed(1)
		else
			track:Play(SWING_FADE, 1, if strike > 0 then math.min(strike / windup, 1) else 1)
		end
	end
end

--- A punch held back: its swing plays up to the clip's hold point (where the arm is drawn back) and
--- waits there until it's thrown (PlaySwing carries on from there) or let go (CancelSwing).
function AnimController:HoldSwing(model: Model, side: string)
	local clip = AnimVariants.swing(kitOf(model), side) or SWING_CLIPS[side]
	local fighter = fighters[model]
	if not clip or not fighter then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = 0
	if root then
		local velocity = root.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	end
	local chosen = if speed >= cfg.RunVariantSpeed and fighter.tracks[`{clip}Run`]
		then `{clip}Run`
		else clip
	local track = fighter.tracks[chosen]
	if not track or not Clips[chosen].hold then
		return
	end
	if fighter.swingName and fighter.swingName ~= chosen then
		local old = fighter.tracks[fighter.swingName]
		if old and old.IsPlaying then
			old:Stop(SWING_FADE)
		end
	end
	fighter.heldSwing = chosen
	fighter.swingName = chosen
	track:Play(SWING_FADE, 1, 1)
end

--- A swing the server refused or that got beaten stops here, so it doesn't play through someone.
--- Anything waiting on its strike still gets shown, because that came from the server.
function AnimController:CancelSwing(model: Model?)
	local fighter = model and fighters[model]
	if not fighter or not fighter.swingName then
		return
	end
	local track = fighter.tracks[fighter.swingName]
	if track and track.IsPlaying then
		track:Stop(FAST_FADE)
	end
	fighter.swingName = nil
	local waiting = fighter.strikePending
	fighter.strikePending = nil
	if waiting then
		for _, callback in waiting do
			callback()
		end
	end
end

--- Starts or stops a barrage loop on a fighter: the clash barrage, or `clip` (the ultimate's BarrageUp).
--- `phase` is how far into the loop to start, so two fighters half a loop apart alternate their punches.
function AnimController:SetBarrage(model: Model?, playing: boolean, phase: number?, clip: string?)
	local fighter = model and fighters[model]
	if not fighter then
		return
	end
	local old = fighter.barrageClip and fighter.tracks[fighter.barrageClip]
	if
		old
		and old.IsPlaying
		and (not playing or fighter.barrageClip ~= (clip or "ClashBarrage"))
	then
		old:Stop(FAST_FADE)
	end
	fighter.barrageClip = nil
	local track = fighter.tracks[clip or "ClashBarrage"]
	if not track or not playing then
		return
	end
	-- the ultimate's loop: a swing still playing would fight it for the arms (the clash keeps its old behaviour)
	if clip and fighter.swingName and fighter.tracks[fighter.swingName] then
		fighter.tracks[fighter.swingName]:Stop(FAST_FADE)
		fighter.swingName = nil
	end
	fighter.barrageClip = clip or "ClashBarrage"
	track:Play(FAST_FADE, 1, 1)
	track.TimePosition = (phase or 0) * track.Length
end

--- Keeps a playing barrage loop on the shared clock: `seconds` since it started. A slow frame or a hitch can't
--- let the fists drift off the hits' beat (the flurry's hits are timed on the server's clock).
function AnimController:SyncBarrage(model: Model?, seconds: number)
	local fighter = model and fighters[model]
	local track = fighter and fighter.barrageClip and fighter.tracks[fighter.barrageClip]
	if not track or not track.IsPlaying or track.Length <= 0 then
		return
	end
	local want = seconds % track.Length
	local off = math.abs(track.TimePosition - want)
	if math.min(off, track.Length - off) > 0.02 then
		track.TimePosition = want
	end
end

--- A cutscene's swing on the shared clock (kits-7f, measured: the strike marker's freeze landed 0.07-0.08 s late
--- and a frame rate drop delayed swings, so fists missed). `lead` 0..1 is how far through the lead-in to contact,
--- `after` seconds past the held contact; `contact` moves the contact pose off the clip's strike (seconds, as
--- measured in play). The track is held at that time; ReleaseSwing lets it run on.
function AnimController:SyncSwing(model: Model?, lead: number, after: number, contact: number?)
	local fighter = model and fighters[model]
	local name = fighter and fighter.swingName
	local track = name and fighter and fighter.tracks[name]
	if not track or not track.IsPlaying then
		return
	end
	local hold = (Clips[name].strike or 0) + (contact or 0)
	track:AdjustSpeed(0)
	track.TimePosition = math.clamp(lead * hold + after, 0, math.max(track.Length - 0.02, 0))
end

--- Lets a SyncSwing'd swing play on by itself from where it is.
function AnimController:ReleaseSwing(model: Model?)
	local fighter = model and fighters[model]
	local name = fighter and fighter.swingName
	local track = name and fighter and fighter.tracks[name]
	if track and track.IsPlaying then
		track:AdjustSpeed(1)
	end
end

--- Drives a whole-body pose clip (Config/AnimClipsUltimate: RushIn, UpperSet, LeapUp) on the shared clock:
--- `seconds` into it, held on its last frame past its end (kits-7j). Switching to another clip cross-fades.
function AnimController:SyncClip(model: Model?, name: string, seconds: number)
	local fighter = model and fighters[model]
	if not fighter then
		return
	end
	if fighter.clipName ~= name then
		local old = fighter.clipName and fighter.tracks[fighter.clipName]
		if old and old.IsPlaying then
			old:Stop(FAST_FADE)
		end
		fighter.clipName = name
	end
	local track = fighter.tracks[name]
	if not track then
		return
	end
	if not track.IsPlaying then
		track:Play(FAST_FADE, 1, 0)
	end
	track:AdjustSpeed(0)
	track.TimePosition = math.clamp(seconds, 0, math.max(track.Length - 0.02, 0))
end

--- Stops the pose clip SyncClip is driving.
function AnimController:StopClip(model: Model?)
	local fighter = model and fighters[model]
	local track = fighter and fighter.clipName and fighter.tracks[fighter.clipName]
	if track and track.IsPlaying then
		track:Stop(SWING_FADE)
	end
	if fighter then
		fighter.clipName = nil
	end
end

--- THE SMEAR (kits-7j, the owner's pick from the gap study, B12): the striking arm drawn ~1.4x long for a moment on
--- the strike, as an anime smear frame; the shoulder stays put (the joint is moved down the longer arm). Only what
--- this client shows; it springs back after `seconds`.
function AnimController:StretchArm(model: Model?, armName: string, factor: number, seconds: number)
	local fighter = model and fighters[model]
	-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next lines)
	local arm = model and model:FindFirstChild(armName) :: BasePart?
	local torso = model and model:FindFirstChild("Torso")
	if not fighter or not arm or not arm:IsA("BasePart") then
		return
	end
	local function restore()
		local was = fighter.stretched
		if was then
			fighter.stretched = nil
			if was.part.Parent then
				was.part.Size = was.size
			end
			if was.joint and was.joint.Parent then
				was.joint.C1 = was.c1
			end
		end
	end
	restore()
	local jointName = if armName == "Right Arm" then "Right Shoulder" else "Left Shoulder"
	local found = if torso then torso:FindFirstChild(jointName) else nil
	local joint: Motor6D? = if found and found:IsA("Motor6D") then found else nil
	local size = arm.Size
	fighter.stretched =
		{ part = arm, size = size, joint = joint, c1 = if joint then joint.C1 else CFrame.identity }
	local grow = size.Y * (factor - 1)
	arm.Size = Vector3.new(size.X, size.Y + grow, size.Z)
	if joint then
		-- the arm's top moved up by half the growth in its own space: move the joint with it
		joint.C1 = joint.C1 + Vector3.new(0, grow / 2, 0)
	end
	task.delay(seconds, function()
		if fighter.stretched and fighter.stretched.part == arm then
			restore()
		end
	end)
end

--- Marks a fighter as posed by an ultimate's cutscene (or not): its knocked-about blends stay off meanwhile.
function AnimController:SetCutscene(model: Model?, on: boolean)
	local fighter = model and fighters[model]
	if fighter then
		fighter.cutscene = on
	end
end

--- A scripted sprint on a body that is being set, not moved (the ultimate's rush): the run plays at its top
--- stride while `on`, and a swing thrown meanwhile is its running variant.
function AnimController:SetDash(model: Model?, on: boolean)
	local fighter = model and fighters[model]
	if fighter then
		fighter.dashing = on
	end
end

--- Runs `callback` when this fighter's swing reaches its Hit event, or at once if no swing is
--- on its way there. The server already decided the hit; this is only when to show it.
function AnimController:AtStrike(model: Model?, callback: () -> ())
	local fighter = model and fighters[model]
	if fighter and fighter.strikePending then
		table.insert(fighter.strikePending, callback)
		return
	end
	callback()
end

--- Where the fist was at the strike, if that was just now.
--- The arm this fighter's current (or last) swing is thrown with, for effects that ride the fist.
--- The last swing this fighter threw: Left, Right, Uppercut or Kick.
function AnimController:LastSwing(model: Model?): string?
	local fighter = model and fighters[model]
	return fighter and fighter.lastSide
end

function AnimController:SwingArm(model: Model?): BasePart?
	local fighter = model and fighters[model]
	local arm = fighter and fighter.strikeArm and (model :: Model):FindFirstChild(fighter.strikeArm)
	return if arm and arm:IsA("BasePart") then arm else nil
end

function AnimController:StrikeTip(model: Model?): Vector3?
	local fighter = model and fighters[model]
	if fighter and fighter.strikeTip and os.clock() - fighter.strikeAt <= TIP_LIFE then
		return fighter.strikeTip
	end
	return nil
end

--- A hit has landed: the puncher's pose freezes for a moment sized to the hit. The one hit takes a
--- pained pose that says how hard and from where, frozen on its first frame through the stop while
--- they shake, and their whole body is thrown over away from the hit and springs back. All of it is
--- only what this client shows.
function AnimController:HitLanded(
	attacker: Model?,
	target: Model,
	strength: number,
	step: number?,
	stopSeconds: number? -- a cutscene's freeze (Ultimates Blow.freeze): the hit-stop holds this long instead
)
	local share = clamp01(strength / cfg.HitStopFullStrength)
	local stop = stopSeconds or (cfg.HitStopMin + (cfg.HitStopMax - cfg.HitStopMin) * share)
	local attackerFighter = attacker and fighters[attacker]
	if attackerFighter then
		if attackerFighter.lastSide == "Uppercut" then
			stop += cfg.UppercutHitStopExtra
		end
		freezePose(attackerFighter, stop)
		shake(attackerFighter, stop, cfg.AttackerShakeStuds)
	end
	local fighter = fighters[target]
	if not fighter then
		return
	end
	fighter.hitAt = os.clock()
	shake(fighter, stop * cfg.VictimShakeShare, cfg.VictimShakeStuds * (0.6 + 0.4 * share))

	-- Where the hit came from, in the body's own terms. Without an attacker it's from the front.
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fromBehind = false
	if root and attackerRoot then
		local away = root.CFrame:VectorToObjectSpace(root.Position - attackerRoot.Position)
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude > 0.01 then
			flat = flat.Unit
			fromBehind = flat.Z < -0.3 -- pushed toward where it's facing
			-- Up crossed with the push: turning about this tips the head away from the hit.
			fighter.tiltAxis = Vector3.new(flat.Z, 0, -flat.X)
			fighter.tiltAngle = 0
			-- A kick of speed rather than a set angle, so it swings over and back on its own.
			local peak = math.rad(cfg.HitTiltDegrees) * (0.35 + 0.65 * share)
			-- not in an ultimate's cutscene (kits-7k): the timeline turns the body there, and 16 flurry hits of this
			-- spring stacked up and laid the target flat over the striker's head
			fighter.tiltSpeed = if fighter.cutscene
				then 0
				else peak * math.sqrt(cfg.HitTiltStiffness)
		end
	end

	-- A string's stunning punches (strength 0, `step` 1-3) alternate the light and the heavy flinch, so every
	-- hit of a fast combo reads as its own blow (the user, 2026-11-16: "hit animations of the victim reacting
	-- to each hit").
	local stringHit = strength <= 0 and step ~= nil and step > 0
	local name = if fromBehind
		then "HitFlinchBack"
		elseif stringHit and (step :: number) % 2 == 0 then "HitFlinchHeavy"
		elseif share >= cfg.HeavyHitShare then "HitFlinchHeavy"
		else "HitFlinch"
	for _, other in { "HitFlinch", "HitFlinchHeavy", "HitFlinchBack" } do
		local track = fighter.tracks[other]
		if track and track.IsPlaying and other ~= name then
			track:Stop(cfg.FlinchFade)
		end
	end
	-- no flinch while a cutscene's pose clip holds the body (kits-7m: the target limp and dangling in the juggle; the
	-- flinches stiffened it), only the shake
	local flinch = if fighter.cutscene and fighter.clipName then nil else fighter.tracks[name]
	if flinch then
		flinch:Play(cfg.FlinchFade, 1, cfg.HitStopCreep)
		fighter.stopUntil = math.max(fighter.stopUntil, os.clock() + stop)
		if not table.find(fighter.stopped, flinch) then
			table.insert(fighter.stopped, flinch)
		end
	end
end

--- The air kick has landed. `stop` comes from the server, which really does hold both for that long.
function AnimController:KickLanded(attacker: Model?, target: Model?, stop: number, share: number)
	local attackerFighter = attacker and fighters[attacker]
	if attackerFighter then
		freezePose(attackerFighter, stop)
		shake(attackerFighter, stop, cfg.AttackerShakeStuds * 2 * share)
	end
	local fighter = target and fighters[target]
	if fighter then
		fighter.hitAt = os.clock()
		shake(fighter, stop * cfg.VictimShakeShare, cfg.VictimShakeStuds * 1.5 * share)
	end
end

--- Someone a kick sent down has hit the floor: flattened, then up off it.
function AnimController:FloorArrived(target: Model)
	local fighter = fighters[target]
	if fighter then
		fighter.floorHitAt = os.clock()
		fighter.hitAt = os.clock()
		shake(fighter, 0.12, cfg.VictimShakeStuds)
		local hit = fighter.tracks.FloorHit
		if hit then
			hit:Play(KICK_FADE, 1, 1)
		end
	end
end

function AnimController:KnitStart()
	local missing = {}
	for name, clip in Clips do
		local animation = Instance.new("Animation")
		animation.Name = name
		local id = AnimAssetIds[name]
		if id then
			animation.AnimationId = `rbxassetid://{id}`
			animations[name] = animation
		else
			table.insert(missing, name)
			if RunService:IsStudio() then
				local ok, result = pcall(function()
					return KeyframeSequenceProvider:RegisterKeyframeSequence(
						AnimSequence.build(name, clip)
					)
				end)
				if ok then
					animation.AnimationId = result
					animations[name] = animation
				end
			end
		end
	end
	if #missing > 0 then
		table.sort(missing)
		warn(
			`[Haymaker Tussle] not uploaded, so these won't play in a live game: {table.concat(
				missing,
				", "
			)}`
		)
	end

	-- Server swings for everyone but ourselves; our own swing already played on the click.
	local started = Net.client("PunchStarted")
	if started then
		started.OnClientEvent:Connect(
			function(attacker: Model, side: string, _step: number?, windup: number?)
				if
					attacker
					and attacker.Parent
					and attacker ~= game:GetService("Players").LocalPlayer.Character
				then
					self:PlaySwing(attacker, side, windup)
				end
			end
		)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local seen: { [Model]: boolean } = {}
		for _, instance in CollectionService:GetTagged(COMBATANT_TAG) do
			if instance:IsA("Model") then
				seen[instance] = true
				updateFighter(instance, dt)
			end
		end
		for model in fighters do
			if not seen[model] then
				fighters[model] = nil
			end
		end
	end)
end

return AnimController
