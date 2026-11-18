--!strict
-- UltimateController - the ultimate on this client (2026-11-15; server UltimateService, choreography
-- Core/Ultimates, looks Fx/UltimateFx and Fx/ImpactFrame, notice and badge Ui/UltimateNotice).
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
local CUTSCENE_GUIS: { [string]: boolean } = { HT_CutsceneBlack = true, HT_ImpactFrame = true }

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

	if not startedRemote then
		return
	end
	startedRemote.OnClientEvent:Connect(
		function(
			attacker: Model,
			target: Model,
			kit: string,
			anchor: CFrame,
			attackerStart: Vector3,
			startedAt: number,
			flightEnd: Vector3
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

			local connection: RBXScriptConnection? = nil
			connection = RunService.RenderStepped:Connect(function()
				local t = workspace:GetServerTimeNow() - startedAt
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
						local freeze = 0
						for _, blow in line.blows do
							if math.abs(blow.t - hitAt) < 0.011 then
								freeze = blow.freeze or 0
							end
						end
						local releaseAt = hitAt + freeze
						if t >= swing.t and t < releaseAt then
							anim:SyncSwing(
								attacker,
								math.clamp((t - swing.t) / math.max(swing.windup, 1e-3), 0, 1),
								0,
								swing.contact
							)
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
						myRoot.CFrame = CFrame.lookAt(at, Vector3.new(faces.X, at.Y, faces.Z))
						myRoot.AssemblyLinearVelocity = Vector3.zero
					elseif t < ending then
						local share = (t - line.cinematic) / cfg.FlightSeconds
						local at = Ultimates.flightPoint(flightFrom, flightEnd, share, FLIGHT_RISE)
						myRoot.CFrame = CFrame.new(at) * CFrame.Angles(share * 14, share * 6, 0)
						myRoot.AssemblyLinearVelocity = (flightEnd - flightFrom) / cfg.FlightSeconds
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
						root.CFrame = CFrame.lookAt(at, Vector3.new(faces.X, at.Y, faces.Z))
					elseif root and t < ending then
						local share = (t - line.cinematic) / cfg.FlightSeconds
						local at = Ultimates.flightPoint(flightFrom, flightEnd, share, FLIGHT_RISE)
						root.CFrame = CFrame.new(at) * CFrame.Angles(share * 14, share * 6, 0)
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
					camera.CFrame = CFrame.lookAt(from, toward)
						* CFrame.Angles(0, 0, math.rad(roll))
						* CFrame.new(sx, sy, 0)
					camera.FieldOfView = fov
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
					if removeGrade then
						removeGrade()
					end
					-- under the dip's full black: the HUD comes back with the normal camera
					restoreUi(hiddenUi, coreWas)
					if role and camera then
						camera.CameraType = Enum.CameraType.Custom
						camera.FieldOfView = fovBefore
					end
				end
			end)
		end
	)
end

return UltimateController
