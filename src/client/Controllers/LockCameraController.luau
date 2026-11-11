--!strict
-- LockCameraController - the camera's half of a lock-on: aim assist, not an aim lock. While you're locked
-- onto someone, the camera is turned a little toward them each frame (Core/AimAssist.cameraYaw), around
-- your character, so they drift toward the middle of the view. You keep full control: moving the camera
-- yourself weakens the pull to a fraction, and someone well off to the side isn't pulled toward at all.
--
-- The stock camera keeps running and this step runs straight after it, only adjusting what it produced.
-- The stock camera reads the camera back next frame, so the turn sticks, and letting go is simply not
-- turning any more. It only touches the camera: never a velocity, a jump or a hit. The step is bound only
-- while a lock is on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local AimAssist = require(ReplicatedStorage.Shared.Core.AimAssist)

local cfg = GameConfig.LockOn
local STEP_NAME = "HT_LockAssist"
-- Straight after the stock camera. A camera kick runs after this, so its shake still shows.
local STEP_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local STEER_PIXELS = 1 -- the mouse moving more than this in a frame counts as you turning the camera
local STEER_STICK = 0.2 -- the right stick pushed further than this does too
local STEER_HOLD = 0.25 -- and the pull stays weak this long after you stop

local LockCameraController = Knit.CreateController({
	Name = "LockCameraController",
})

function LockCameraController:KnitInit()
	self._engaged = false
	self._point = Vector3.zero
	self._stick = Vector3.zero
end

--- Starts leaning the camera toward this point.
function LockCameraController:Engage(point: Vector3)
	self._point = point
	self._engaged = true
	self:_bind()
end

--- The opponent's position, while they can be seen. During a loss of sight this isn't called, so the camera
--- only ever leans toward where they were last seen and gives nothing away.
function LockCameraController:SetPoint(point: Vector3)
	self._point = point
end

--- Stops leaning. The camera stays wherever it is.
function LockCameraController:Release()
	self._engaged = false
	RunService:UnbindFromRenderStep(STEP_NAME)
end

function LockCameraController:_bind()
	RunService:UnbindFromRenderStep(STEP_NAME)
	local steeredAt = -math.huge
	RunService:BindToRenderStep(STEP_NAME, STEP_PRIORITY, function(dt: number)
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		if not self._engaged or not camera or not character then
			return
		end
		local now = os.clock()
		if
			UserInputService:GetMouseDelta().Magnitude > STEER_PIXELS
			or self._stick.Magnitude > STEER_STICK
		then
			steeredAt = now
		end
		local view = camera.CFrame
		local focus = camera.Focus.Position
		local look = view.LookVector
		local to = self._point - focus
		local angle = AimAssist.turnBetween(look.X, look.Z, to.X, to.Z)
		local turn = AimAssist.cameraYaw(cfg, angle, dt, now - steeredAt <= STEER_HOLD)
		if turn ~= 0 then
			-- Around a vertical line through what the camera follows, so your character stays put on screen.
			camera.CFrame = CFrame.new(focus)
				* CFrame.Angles(0, turn, 0)
				* CFrame.new(-focus)
				* view
		end
	end)
end

function LockCameraController:KnitStart()
	-- The right stick's position, to tell when a gamepad player is turning the camera themselves.
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			self._stick = input.Position
		end
	end)
end

return LockCameraController
