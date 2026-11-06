--!strict
-- LockCameraController - points the camera at a locked-on opponent. It only sets the camera: it never touches
-- a velocity, a jump or a hit. Movement already reads the camera's flat direction, so W heads toward where
-- you're looking, and that's the whole of the help this gives you.
--
-- The stock camera keeps running underneath, and this step runs straight after it and replaces what it
-- produced. The stock camera reads the camera back next frame, so it follows along, and letting go is just
-- a blend back to what it's already producing. This step is only bound while it's in use.
--
-- It never writes the mouse itself: ShiftLockController owns the mouse, the cursor and the shift lock key, and is
-- told when the camera lock needs them.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local LockCamera = require(ReplicatedStorage.Shared.Core.LockCamera)

local cfg = GameConfig.LockCamera
local STEP_NAME = "HT_LockCamera"
-- Straight after the stock camera. A camera kick runs after this, so its shake still shows.
local STEP_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local COMBATANT_TAG = "HT_Combatant"

local LockCameraController = Knit.CreateController({
	Name = "LockCameraController",
})

function LockCameraController:KnitInit()
	self._bound = false
	self._engaged = false
	self._point = Vector3.zero
end

--- Starts tracking this point, easing in from wherever the camera is now.
function LockCameraController:Engage(point: Vector3)
	self._point = point
	self._engaged = true
	if not self._bound then
		self:_bind()
	end
end

--- The opponent's position, while they can be seen. During a loss of sight this simply isn't called, so the
--- camera keeps using the last place they were seen and gives nothing away.
function LockCameraController:SetPoint(point: Vector3)
	self._point = point
end

--- Eases back to the normal camera.
function LockCameraController:Release()
	self._engaged = false
end

function LockCameraController:_bind()
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		self._engaged = false
		return
	end
	self._bound = true

	local gameSettings = UserSettings():GetService("UserGameSettings")
	local focus = root.Position + Vector3.yAxis * cfg.FocusHeight
	local target = self._point
	local _, startYaw = camera.CFrame:ToOrientation()
	local startPitch = select(1, camera.CFrame:ToOrientation())
	local yaw, pitch = startYaw, startPitch
	local distance =
		math.clamp((camera.CFrame.Position - focus).Magnitude, cfg.MinDistance, cfg.MaxDistance)
	local pulled = distance
	local orbitYaw, orbitPitch = 0, 0
	local mouseMovedAt = os.clock()
	local weight = 0
	local shiftLock = Knit.GetController("ShiftLockController")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true

	local function finish()
		RunService:UnbindFromRenderStep(STEP_NAME)
		shiftLock:ReleaseMouse()
		self._bound = false
		self._engaged = false
	end

	RunService:BindToRenderStep(STEP_NAME, STEP_PRIORITY, function(dt: number)
		local view = workspace.CurrentCamera
		local body = player.Character
		local bodyRoot = body and body:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not view or not bodyRoot then
			finish()
			return
		end

		local engaged = self._engaged
		weight += dt / (if engaged then cfg.EnterSeconds else -cfg.ExitSeconds)
		if weight <= 0 then
			finish()
			return
		end
		weight = math.min(weight, 1)

		local focusWanted = bodyRoot.Position + Vector3.yAxis * cfg.FocusHeight
		focus = Vector3.new(
			LockCamera.smooth(focus.X, focusWanted.X, cfg.FocusRate, dt),
			LockCamera.smooth(focus.Y, focusWanted.Y, cfg.FocusRate, dt),
			LockCamera.smooth(focus.Z, focusWanted.Z, cfg.FocusRate, dt)
		)
		local point = self._point
		target = Vector3.new(
			LockCamera.smooth(target.X, point.X, cfg.TargetRate, dt),
			LockCamera.smooth(target.Y, point.Y, cfg.TargetRate, dt),
			LockCamera.smooth(target.Z, point.Z, cfg.TargetRate, dt)
		)

		local yawWanted, pitchWanted, flat =
			LockCamera.angleTo(focus.X, focus.Y, focus.Z, target.X, target.Y, target.Z)
		yaw = LockCamera.smoothAngle(
			yaw,
			yawWanted,
			cfg.YawRate * LockCamera.yawShare(cfg, flat),
			math.rad(cfg.YawMaxDegrees),
			dt
		)
		pitch = LockCamera.smoothAngle(
			pitch,
			pitchWanted,
			cfg.PitchRate,
			math.rad(cfg.PitchMaxDegrees),
			dt
		)
		distance = LockCamera.smooth(
			distance,
			LockCamera.zoom(cfg, (target - focus).Magnitude),
			cfg.ZoomRate,
			dt
		)

		-- The mouse nudges the view while locked, so it has to stay captured.
		local now = os.clock()
		if engaged and not GuiService.MenuIsOpen then
			shiftLock:HoldMouse()
			local moved = UserInputService:GetMouseDelta()
			if moved.Magnitude > 0 then
				local scale = cfg.MouseDegreesPerPixel * gameSettings.MouseSensitivity
				orbitYaw, orbitPitch =
					LockCamera.orbit(cfg, orbitYaw, orbitPitch, moved.X * scale, moved.Y * scale)
				mouseMovedAt = now
			end
		else
			shiftLock:ReleaseMouse()
		end
		orbitYaw = LockCamera.orbitSettle(cfg, orbitYaw, now - mouseMovedAt, dt)
		orbitPitch = LockCamera.orbitSettle(cfg, orbitPitch, now - mouseMovedAt, dt)

		local aimYaw = yaw + orbitYaw
		local aimPitch = LockCamera.finalPitch(cfg, pitch, orbitPitch)
		local lookX, lookY, lookZ = LockCamera.look(aimYaw, aimPitch)
		local look = Vector3.new(lookX, lookY, lookZ)

		-- Anything solid between the focus and the camera brings the camera in front of it.
		local ignore: { Instance } = CollectionService:GetTagged(COMBATANT_TAG)
		table.insert(ignore, body :: Model)
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Spherecast(focus, cfg.CollisionRadius, -look * distance, params)
		local clear = if hit then hit.Distance - cfg.CollisionMargin else distance
		pulled = LockCamera.pull(cfg, pulled, clear, dt)
		local position = focus - look * pulled

		-- The stock camera's result this frame is what to blend from, in yaw, pitch and position rather than
		-- as a whole rotation, which could tip the horizon on the way.
		local share = LockCamera.blendShare(weight)
		if share < 1 then
			local stock = view.CFrame
			local stockPitch, stockYaw = stock:ToOrientation()
			aimYaw = stockYaw + LockCamera.angleBetween(stockYaw, aimYaw) * share
			aimPitch = stockPitch + (aimPitch - stockPitch) * share
			position = stock.Position:Lerp(position, share)
		end
		view.CFrame = CFrame.new(position) * CFrame.fromOrientation(aimPitch, aimYaw, 0)
		view.Focus = CFrame.new(focus)
	end)
end

return LockCameraController