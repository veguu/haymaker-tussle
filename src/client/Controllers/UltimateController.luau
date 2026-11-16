--!strict
-- UltimateController - the ultimate on this client (2026-11-15; server UltimateService, choreography
-- Core/Ultimates, looks Fx/UltimateFx and Fx/ImpactFrame, meter Ui/UltimateMeter).
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
local UltimateMeter = require(script.Parent.Parent.Ui.UltimateMeter)
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

local UltimateController = Knit.CreateController({
	Name = "UltimateController",
})

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
	UltimateMeter.start()
	SoundPicker.start()

	local windowUntil = 0
	if windowRemote then
		windowRemote.OnClientEvent:Connect(function(_target: Model, seconds: number)
			windowUntil = os.clock() + seconds
			UltimateMeter.prompt(seconds)
		end)
	end

	ContextActionService:BindAction(ACTION, function(_name: string, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin and os.clock() <= windowUntil and request then
			windowUntil = 0
			UltimateMeter.hidePrompt()
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
			UltimateMeter.hidePrompt()
			local line = Ultimates.timeline(kit)
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
			local swings = 0
			local frames = 0
			local fovBefore = if camera then camera.FieldOfView else 70
			if role and camera then
				camera.CameraType = Enum.CameraType.Scriptable
			end
			-- The cutscene's colour grade, on the fighters' screens only.
			local removeGrade: (() -> ())? = if role and line.grade
				then CutsceneScreen.grade(line.grade, GRADE_IN)
				else nil
			local dipped = false

			local connection: RBXScriptConnection? = nil
			connection = RunService.RenderStepped:Connect(function()
				local t = workspace:GetServerTimeNow() - startedAt
				-- Cues and the attacker's swings, on every screen.
				for _, cue in Ultimates.cuesBetween(line, lastT, t) do
					UltimateFx.cue(cue, ctx)
					if cue == "windup" then
						anim:HoldSwing(attacker, "Uppercut")
					elseif cue == "impact" then
						anim:PlaySwing(attacker, "Uppercut", 0.02)
					end
				end
				-- The barrage's punches: left and right in turn while it lasts.
				local barrageFrom, barrageTo = 0.34, 1.4
				if t >= barrageFrom and t < barrageTo then
					local due = math.floor((t - barrageFrom) / 0.075) + 1
					while swings < due do
						swings += 1
						anim:PlaySwing(attacker, if swings % 2 == 0 then "Left" else "Right", 0.03)
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
				-- The cinematic camera on both their screens: the timeline's shots (cuts, moves, field of view,
				-- tilt, shake), then the chase shot following the flight as it widens.
				if role and camera then
					frames += 1
					local camAt, lookAt, fov, roll, shake =
						Ultimates.shot(line, math.min(t, line.cinematic))
					local from = anchor:PointToWorldSpace(camAt)
					local toward = anchor:PointToWorldSpace(lookAt)
					if t >= line.cinematic then
						local targetRoot = rootOf(target)
						toward = if targetRoot then targetRoot.Position else flightEnd
						local share = math.clamp((t - line.cinematic) / cfg.FlightSeconds, 0, 1)
						fov += (line.flightFov - fov) * (1 - (1 - share) * (1 - share))
						shake *= 1 - share
					end
					-- Shake: a set pattern of nudges that changes every frame, never random.
					local sx = (if frames % 2 == 0 then 1 else -1) * shake
					local sy = (if frames % 3 == 0 then 1 elseif frames % 3 == 1 then -0.6 else 0.2)
						* shake
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
					if removeGrade then
						removeGrade()
					end
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
