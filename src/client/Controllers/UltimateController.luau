--!strict
-- UltimateController - the ultimate on this client (2026-11-15; server UltimateService, choreography
-- Core/Ultimates, looks Fx/UltimateFx and Fx/DrawnImpact, notice and badge Ui/UltimateNotice).
--
-- G (gamepad DPadUp, a touch button) inside the follow-up window asks for it; nothing else does.
-- When one starts (UltimateStarted), every client plays its cues and the attacker's swings. If this client
-- is the attacker or the target it also moves its own body through the timeline (the movement controller
-- stands aside while HT_Ultimate is set), runs the cinematic camera, and for the target flies the body
-- off on its scripted flight. The server's shared clock keeps every screen on the same moment.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Ultimates = require(ReplicatedStorage.Shared.Core.Ultimates)
local UltimateNotice = require(script.Parent.Parent.Ui.UltimateNotice)
local SoundPicker = require(script.Parent.Parent.Ui.SoundPicker)
local CutsceneScreen = require(script.Parent.Parent.Fx.CutsceneScreen)
local FxKit = require(script.Parent.Parent.Fx.FxKit)
local DrawnImpact = require(script.Parent.Parent.Fx.DrawnImpact)
local UltimateFx = require(script.Parent.Parent.Fx.UltimateFx)

local cfg = GameConfig.Ultimate
local ACTION = "HaymakerUltimate"
local FLIGHT_RISE = 18
-- The ending (the user picked it from the references, 2026-11-15; a cracked-screen ending was turned down):
-- the fighters' screens dip to black just before the camera is handed back, swap under the black, and fade
-- up on the normal view.
local DIP_IN, DIP_HOLD, DIP_OUT = 0.2, 0.15, 0.35
local GRADE_IN = 0.12
local HEAVY_STRENGTH = GameConfig.Animation.HitStopFullStrength

local UltimateController = Knit.CreateController({
	Name = "UltimateController",
})

-- THE CUTSCENE OWNS THE SCREEN (kits-7f, the gap study: every reference hides its HUD; ours left SHOP/CLASSES, the
-- top bars and the "ULTIMATE" / "FIGHTERS LEFT" banners over the action). On the two fighters' screens every
-- ScreenGui but the cutscene's own is switched off, AGAIN EVERY FRAME (several HUD pieces switch themselves back
-- on), and exactly those are switched back on under the end's black dip. The Roblox core UI goes too.
local StarterGui = game:GetService("StarterGui")
local CUTSCENE_GUIS: { [string]: boolean } = {
	HT_CutsceneBlack = true,
	HT_ImpactFrame = true,
	HT_ImpactWarm = true,
	HT_DrawnImpact = true,
	HT_DrawnWarm = true,
}

local function hideUi(hidden: { [ScreenGui]: boolean })
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled and not CUTSCENE_GUIS[gui.Name] then
			gui.Enabled = false
			hidden[gui] = true
		end
	end
end

local function hideCore(): { [Enum.CoreGuiType]: boolean }
	local was: { [Enum.CoreGuiType]: boolean } = {}
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			was[kind] = StarterGui:GetCoreGuiEnabled(kind)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	return was
end

local function restoreUi(hidden: { [ScreenGui]: boolean }, core: { [Enum.CoreGuiType]: boolean }?)
	for gui in hidden do
		if gui.Parent then
			gui.Enabled = true
		end
	end
	table.clear(hidden)
	for kind, on in core or {} do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, on)
	end
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function UltimateController:KnitStart()
	local player = Players.LocalPlayer
	local request = Net.client("UltimateRequest")
	local windowRemote = Net.client("UltimateWindow")
	local startedRemote = Net.client("UltimateStarted")
	local anim = Knit.GetController("AnimController")
	UltimateNotice.start()
	SoundPicker.start()

	local windowUntil = 0
	if windowRemote then
		windowRemote.OnClientEvent:Connect(function(_target: Model, seconds: number)
			windowUntil = os.clock() + seconds
			UltimateNotice.prompt(seconds)
		end)
	end

	ContextActionService:BindAction(ACTION, function(_name: string, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin and os.clock() <= windowUntil and request then
			windowUntil = 0
			UltimateNotice.hidePrompt()
			request:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle(ACTION, "Ult")

	-- One ultimate on this screen, from start to cleanup. `clock` (Studio replays only, below) stands in for the shared
	-- server clock: the cutscene time each frame. Without it: `GetServerTimeNow() - startedAt`, as every live ultimate.
	local function play(
		attacker: Model,
		target: Model,
		kit: string,
		anchor: CFrame,
		attackerStart: Vector3,
		startedAt: number,
		flightEnd: Vector3,
		clock: (() -> number)?
	)
		if not attacker or not target then
			return
		end
		UltimateNotice.hidePrompt()
		local line = Ultimates.timeline(kit)
		if not line then
			return
		end
		local me = player.Character
		local role = if me == attacker then "attacker" elseif me == target then "target" else nil
		local camera = workspace.CurrentCamera
		local ctx: UltimateFx.Context = {
			kit = kit,
			attacker = attacker,
			target = target,
			anchor = anchor,
			attackerFrom = anchor:PointToWorldSpace(attackerStart),
			mine = role ~= nil,
		}
		local _, lastTarget = Ultimates.pose(line, line.cinematic, attackerStart)
		local flightFrom = anchor:PointToWorldSpace(lastTarget)
		local ending = line.cinematic + cfg.FlightSeconds
		local lastT = -1
		local barraging = false
		local dashing = false
		local fovBefore = if camera then camera.FieldOfView else 70
		if role and camera then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		-- The cutscene's colour grade, on the fighters' screens only.
		local removeGrade: (() -> ())? = if role and line.grade
			then CutsceneScreen.grade(line.grade, GRADE_IN)
			else nil
		local dipped = false
		-- the cutscene owns the fighters' screens (hideUi): what was switched off, to switch back on
		local hiddenUi: { [ScreenGui]: boolean } = {}
		local coreWas = if role then hideCore() else nil
		-- the timeline poses both bodies: their knocked-about blends stay off so the flinches show (kits-7i)
		anim:SetCutscene(attacker, true)
		anim:SetCutscene(target, true)
		-- kits-8h, measured in a live ultimate: this body's facing constraint (MovementController's HT_Facing
		-- AlignOrientation, infinite torque) stayed on with the heading from before the ultimate and twisted the root back
		-- every physics step after it was set here, so the attacker faced 35-50 deg off the target all through the haymaker
		-- and the fist landed beside the chest (the owner: "the target is not being hit at the center of their torso").
		-- Off while the timeline owns the body; back on afterwards holding the facing the body has then.
		-- the attacker shown as the striking arm alone (Ultimates soloArm, the drawn view's close-ups), and back
		local soloShown = false
		local function setSolo(part: string, on: boolean)
			for _, item in attacker:GetDescendants() do
				if item:IsA("BasePart") and item.Name ~= part then
					item.LocalTransparencyModifier = if on then 1 else 0
				elseif item:IsA("Decal") then
					item.LocalTransparencyModifier = if on then 1 else 0
				end
			end
			soloShown = on
		end
		local myFacing: AlignOrientation? = nil
		do
			local myRoot = role and me and me:FindFirstChild("HumanoidRootPart")
			-- (its Attachment has the same name and comes first, so look for the constraint itself)
			for _, child in if myRoot then myRoot:GetChildren() else {} do
				if
					child.Name == "HT_Facing"
					and child:IsA("AlignOrientation")
					and child.Enabled
				then
					child.Enabled = false
					myFacing = child
				end
			end
		end

		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function()
			local t = if clock then clock() else workspace:GetServerTimeNow() - startedAt
			if role and t < ending + 0.1 then
				hideUi(hiddenUi)
			end
			-- Cues, the attacker's swings and the target's flinches, on every screen (the timeline's lists).
			for _, cue in Ultimates.cuesBetween(line, lastT, t) do
				UltimateFx.cue(cue, ctx)
			end
			for _, swing in Ultimates.between(line.swings, lastT, t) do
				if swing.hold then
					anim:HoldSwing(attacker, swing.side)
				else
					-- A swing noticed a frame or two late (measured at 30 fps, kits-7d: up to 0.05 s) gets that
					-- much less windup, so its fist still lands on the beat.
					local late = math.max(t - swing.t, 0)
					anim:PlaySwing(attacker, swing.side, math.max(swing.windup - late, 0.02))
				end
			end
			-- The big swings run ON THE TIMELINE'S CLOCK (kits-7f, measured: freezes waiting on the strike marker
			-- landed 0.07-0.08 s late, so the fist had swept past or not arrived). Each swing reaches its contact
			-- pose exactly at its hit, holds it through the freeze, then plays on by itself.
			for _, swing in line.swings do
				if not swing.hold and not swing.fromHold then
					local hitAt = swing.t + swing.windup
					local freeze, slow = 0, 0
					for _, blow in line.blows do
						if math.abs(blow.t - hitAt) < 0.011 then
							freeze = blow.freeze or 0
							-- past the hit the swing holds, or plays on in slow motion (kits-7m: the haymaker's
							-- fist driving through, so the weight is felt)
							slow = blow.slow or 0
						end
					end
					local releaseAt = hitAt + freeze
					if t >= swing.t and t < releaseAt then
						-- how far through the lead-in to contact: straight through, or (kits-8a, the haymaker) in
						-- three parts: up to its hold point by `loaded`, held there until `release`, then driven
						-- to the contact at the hit, so the fist stays loaded through the whole dash
						local lead = math.clamp((t - swing.t) / math.max(swing.windup, 1e-3), 0, 1)
						local loaded, release, holdShare =
							swing.loaded, swing.release, swing.holdShare
						if loaded and release and holdShare then
							if t < loaded then
								lead = holdShare
									* math.clamp(
										(t - swing.t) / math.max(loaded - swing.t, 1e-3),
										0,
										1
									)
							elseif t < release then
								lead = holdShare
							else
								lead = holdShare
									+ (1 - holdShare)
										* math.clamp(
											(t - release) / math.max(hitAt - release, 1e-3),
											0,
											1
										)
							end
						end
						anim:SyncSwing(attacker, lead, math.max(t - hitAt, 0) * slow, swing.contact)
					elseif lastT < releaseAt and t >= releaseAt then
						anim:ReleaseSwing(attacker)
					end
				end
			end
			for _, blow in Ultimates.between(line.blows, lastT, t) do
				-- a heavy blow at full strength (the most hit-stop, the heavy flinch); the rest as a
				-- string's punches, the flinch alternating light and heavy. On its time: the swing's contact
				-- pose is there on the same clock (above).
				anim:HitLanded(
					attacker,
					target,
					if blow.heavy then HEAVY_STRENGTH else 0,
					blow.step,
					blow.freeze -- a big hit's freeze (kits-7e): the hit-stop holds the whole of it
				)
				-- the smear: the striking arm drawn long for a moment on the hit (kits-7j, the owner's pick)
				if blow.arm then
					anim:StretchArm(attacker, blow.arm, 1.4, 1 / 30)
				end
			end
			-- the attacker's whole-body pose clip on the shared clock (kits-7j): the last one started, held
			local clips = line.clips
			if clips and t < line.attackerFree then
				local current
				for _, clip in clips do
					if clip.t <= t then
						current = clip
					end
				end
				if current and current.name ~= "" then
					anim:SyncClip(attacker, current.name, t - current.t)
				elseif current then
					anim:StopClip(attacker)
				end
			end
			-- the target's pose clip the same way (kits-7m: limp, dangling, through the juggle)
			local targetClips = line.targetClips
			if targetClips and t < line.cinematic then
				local current
				for _, clip in targetClips do
					if clip.t <= t then
						current = clip
					end
				end
				if current and current.name ~= "" then
					anim:SyncClip(target, current.name, t - current.t)
				elseif current then
					anim:StopClip(target)
				end
			end
			local barrage = line.barrage
			if barrage then
				local inside = t >= barrage.from and t < barrage.to
				if inside ~= barraging then
					barraging = inside
					anim:SetBarrage(attacker, inside, 0, barrage.clip)
				end
				if inside then
					anim:SyncBarrage(attacker, t - barrage.from)
				end
			end
			-- The rush in: the attacker's sprint plays while the body is set along the dash.
			local dash = line.dash
			if dash then
				local inside = t >= dash.from and t < dash.to
				if inside ~= dashing then
					dashing = inside
					anim:SetDash(attacker, inside)
				end
			end
			lastT = t

			local attackerAt, targetAt =
				Ultimates.pose(line, math.min(t, line.cinematic), attackerStart)
			-- Our own body, set to the timeline.
			local myRoot = rootOf(me)
			if role == "attacker" and myRoot and t < line.attackerFree then
				local at = anchor:PointToWorldSpace(attackerAt)
				local faces = anchor:PointToWorldSpace(targetAt)
				myRoot.CFrame = CFrame.lookAt(at, Vector3.new(faces.X, at.Y, faces.Z))
				myRoot.AssemblyLinearVelocity = Vector3.zero
			elseif role == "target" and myRoot then
				if t < line.cinematic then
					local at = anchor:PointToWorldSpace(targetAt)
					local faces = anchor:PointToWorldSpace(targetAt + Vector3.new(0, 0, 1))
					-- the whole-body reaction tilt on top (kits-7i)
					myRoot.CFrame = Ultimates.targetCFrame(at, faces, Ultimates.tilt(line, t))
					myRoot.AssemblyLinearVelocity = Vector3.zero
				elseif t < ending then
					-- on from the knockback at its speed and turn (kits-8a: no stall, no snap)
					local flying, velocity = Ultimates.flight(
						line,
						anchor,
						flightFrom,
						flightEnd,
						cfg.FlightSeconds,
						FLIGHT_RISE,
						t
					)
					myRoot.CFrame = flying
					myRoot.AssemblyLinearVelocity = velocity
				end
			end
			-- The OTHER bodies, posed here too, every frame, from the same timeline (kits-7e, measured: the other
			-- fighter's replicated body arrived ~0.1 s late, so fists met a target still on its way, and freezes
			-- showed a body still drifting). Only what this screen shows: the owner (or the server, for a bot)
			-- still moves the real body the same way.
			if role ~= "attacker" and t < line.attackerFree then
				local root = rootOf(attacker)
				if root then
					local at = anchor:PointToWorldSpace(attackerAt)
					local faces = anchor:PointToWorldSpace(targetAt)
					root.CFrame = CFrame.lookAt(at, Vector3.new(faces.X, at.Y, faces.Z))
				end
			end
			if role ~= "target" then
				local root = rootOf(target)
				if root and t < line.cinematic then
					local at = anchor:PointToWorldSpace(targetAt)
					local faces = anchor:PointToWorldSpace(targetAt + Vector3.new(0, 0, 1))
					root.CFrame = Ultimates.targetCFrame(at, faces, Ultimates.tilt(line, t))
				elseif root and t < ending then
					root.CFrame = Ultimates.flight(
						line,
						anchor,
						flightFrom,
						flightEnd,
						cfg.FlightSeconds,
						FLIGHT_RISE,
						t
					)
				end
			end
			-- The cinematic camera on both their screens: the timeline's shots (cuts, moves, field of view,
			-- tilt, shake), then the chase shot following the flight as it widens.
			if role and camera then
				local camAt, lookAt, fov, roll = Ultimates.shot(
					line,
					math.min(t, line.cinematic),
					attackerAt,
					targetAt,
					attackerStart
				)
				-- any zoom punches the timeline still has (Haymaker Rush has none since kits-7e)
				local kickFov = Ultimates.kick(line, t)
				fov -= kickFov
				local from = anchor:PointToWorldSpace(camAt)
				local toward = anchor:PointToWorldSpace(lookAt)
				if t >= line.cinematic then
					local targetRoot = rootOf(target)
					toward = if targetRoot then targetRoot.Position else flightEnd
					local share = math.clamp((t - line.cinematic) / cfg.FlightSeconds, 0, 1)
					fov += (line.flightFov - fov) * (1 - (1 - share) * (1 - share))
				end
				-- Shake (kits-7e, the camera study; the user: "the screen shake ... isnt really impactful"): the
				-- flurry's constant jitter, a new set direction every 1/30 s, and one directional jolt as each
				-- big hit's freeze ends (Ultimates.shake). It moves the camera sideways, so the aim stays put.
				local sx, sy = Ultimates.shake(line, t)
				-- the cutscene owns the camera every frame (kits-8c: anything that resets its type mid-way, such as
				-- Studio's assistant ending a call, would otherwise hand it back to the player's camera)
				if camera.CameraType ~= Enum.CameraType.Scriptable then
					camera.CameraType = Enum.CameraType.Scriptable
				end
				camera.CFrame = CFrame.lookAt(from, toward)
					* CFrame.Angles(0, 0, math.rad(roll))
					* CFrame.new(sx, sy, 0)
				camera.FieldOfView = fov
			end
			-- the drawn view's close-ups: only the attacker's striking arm (kits-8h), set every frame (Roblox's own
			-- transparency control for the local character would otherwise set it back)
			local solo = line.soloArm
			if role and solo then
				local inside = t >= solo.from and t < solo.to and attacker.Parent ~= nil
				if inside or soloShown then
					setSolo(solo.part, inside)
				end
			end
			-- The dip to black: timed so the camera swap below (at ending + 0.1) happens under full black.
			if role and not dipped and t >= ending + 0.1 - DIP_IN - DIP_HOLD * 0.5 then
				dipped = true
				CutsceneScreen.blackout(0, DIP_IN, DIP_HOLD, DIP_OUT)
			end
			if t >= ending + 0.1 or not attacker.Parent then
				if connection then
					connection:Disconnect()
				end
				if barraging then
					anim:SetBarrage(attacker, false)
				end
				if dashing then
					anim:SetDash(attacker, false)
				end
				anim:SetCutscene(attacker, false)
				anim:SetCutscene(target, false)
				anim:StopClip(attacker)
				anim:StopClip(target)
				if removeGrade then
					removeGrade()
				end
				-- under the dip's full black: the HUD comes back with the normal camera
				restoreUi(hiddenUi, coreWas)
				if role and camera then
					camera.CameraType = Enum.CameraType.Custom
					camera.FieldOfView = fovBefore
				end
				if soloShown and line.soloArm then
					setSolo(line.soloArm.part, false)
				end
				if myFacing and myFacing.Parent then
					local root = myFacing.Parent :: BasePart
					myFacing.CFrame = root.CFrame.Rotation
					myFacing.Enabled = true
				end
			end
		end)
	end

	if startedRemote then
		startedRemote.OnClientEvent:Connect(play)
	end

	-- REPLAY (kits-8c, Studio only, for reviewing the cutscene): the ultimate on THIS screen alone, on a local clock that
	-- can run slow and stop at any moment, so a recording or a still lands on exact cutscene times whatever Studio's frame
	-- rate (kits-8b: Studio rendered 7-10 fps and a recording at that rate can't show timing). Nothing goes to the
	-- server: both bodies are posed here only, and the target is put back where it was at the end.
	--   ReplicatedStorage.HT_UltReplay:Invoke(targetModel, scale?, hold?)
	-- Its attributes steer it while it plays: Scale (1 = real time), Hold (a cutscene time to stop at; nil runs on);
	-- it writes At (the cutscene time now).
	if RunService:IsStudio() then
		local replay = Instance.new("BindableFunction")
		replay.Name = "HT_UltReplay"
		replay.OnInvoke = function(target: Model, scale: number?, hold: number?): string
			local me = player.Character
			local myRoot, theirRoot = rootOf(me), rootOf(target)
			local line = Ultimates.timeline("Base")
			if not me or not myRoot or not theirRoot or not line then
				return "no bodies"
			end
			replay:SetAttribute("Scale", scale or 1)
			replay:SetAttribute("Hold", hold)
			local theirStart = theirRoot.CFrame
			local anchor = Ultimates.anchor(theirRoot.Position, myRoot.Position, nil)
			local attackerStart = anchor:PointToObjectSpace(myRoot.Position)
			local _, lastTarget = Ultimates.pose(line, line.cinematic, attackerStart)
			local flightEnd = Ultimates.flightEnd(
				cfg,
				nil,
				anchor:PointToWorldSpace(lastTarget),
				anchor.LookVector
			)
			-- the movement controller stands aside, as in a live ultimate (set here only)
			me:SetAttribute("HT_Ultimate", "attacker")
			local t, last = 0, os.clock()
			play(me, target, "Base", anchor, attackerStart, 0, flightEnd, function(): number
				local now = os.clock()
				-- a slow frame moves the clock one frame's worth at most, so nothing is skipped
				local step = math.min(now - last, 0.1)
				last = now
				local speed = tonumber(replay:GetAttribute("Scale")) or 1
				t += step * speed
				-- the effects and the drawn impact frames run on real time: slow them to the same pace
				FxKit.studySlow(1 / math.max(speed, 0.05))
				DrawnImpact.studySlow(1 / math.max(speed, 0.05))
				local stopAt = tonumber(replay:GetAttribute("Hold"))
				if stopAt and t > stopAt then
					t = stopAt
				end
				replay:SetAttribute("At", t)
				return t
			end)
			task.spawn(function()
				-- (the cutscene stops at its end + 0.1, so its clock never reads past that)
				local ending = line.cinematic + cfg.FlightSeconds + 0.05
				while (tonumber(replay:GetAttribute("At")) or 0) < ending and me.Parent do
					task.wait(0.1)
				end
				me:SetAttribute("HT_Ultimate", nil)
				FxKit.studySlow(1)
				DrawnImpact.studySlow(1)
				if theirRoot.Parent then
					theirRoot.CFrame = theirStart
				end
			end)
			return "replaying"
		end
		replay.Parent = ReplicatedStorage
	end
end

return UltimateController
