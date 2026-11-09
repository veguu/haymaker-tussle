--!strict
-- ShiftLockController - this game's own shift lock. Roblox's is switched off completely: the place's
-- StarterPlayer.EnableMouseLockOption is false, and its Shift action is held off here too in case that setting
-- is ever lost, since a script isn't allowed to change it. This one has its own Shift key and its
-- own on or off state, always starts off, keeps the camera straight behind the character and shows a white dot
-- just above the head in place of a cursor.
--
-- The stock camera still does the turning. It's told it's mouse locked through its own SetIsMouseLocked, which
-- is all it needs. That isn't a documented API, so if a Roblox update removes it, this warns and Shift does nothing.
--
-- This also owns the mouse and the cursor whenever the lock-on camera wants them, so the two can't fight. While
-- the camera is locked on it wins: Shift does nothing and the dot hides. Whatever shift lock was doing comes back
-- on letting go. Nothing here writes the mouse: the stock camera sets it every frame from its mouse-locked flag,
-- so both locks just set that flag. A direct write gets undone by it every frame, and it also remembers
-- whatever it finds as "normal", which is how a mouse could end up stuck in the centre with shift lock off.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local cfg = GameConfig.ShiftLock
local OFFSET = Vector3.new(cfg.CameraOffsetX, 0, 0)
local ACTION = "HaymakerShiftLock"

local ShiftLockController = Knit.CreateController({
	Name = "ShiftLockController",
})

--- Is the player in shift lock right now? This is what makes the camera aim the air kick.
function ShiftLockController:IsLocked(): boolean
	return self._locked == true
end

--- For the lock-on camera, every frame it needs the mouse captured. Shift does nothing until ReleaseMouse.
function ShiftLockController:HoldMouse()
	if not self._mouseHeld then
		self._mouseHeld = true
		if self._tellCamera then
			self._tellCamera()
		end
	end
end

--- Hands the mouse back: locked if shift lock is on, free if not.
function ShiftLockController:ReleaseMouse()
	if self._mouseHeld then
		self._mouseHeld = false
		if self._tellCamera then
			self._tellCamera()
		end
	end
end

function ShiftLockController:KnitStart()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_ShiftLockDot"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- so it lines up with where the camera says the head is
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(cfg.DotSize, cfg.DotSize)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	-- A dark edge, so it reads against a bright sky too.
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Thickness = 1
	edge.Transparency = 0.35
	edge.Parent = dot

	-- Current Studio keeps the stock module directly under StarterPlayer; older places copy it.
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
		or StarterPlayer:WaitForChild("PlayerModule", 10)
	local cameraScript = playerModule and playerModule:WaitForChild("CameraModule", 10)
	local ok, cameras: any = pcall(function()
		return cameraScript and require(cameraScript :: any)
	end)
	if not ok or not cameras then
		warn("[Haymaker Tussle] couldn't reach the stock camera; shift lock keeps its stock offset")
		cameras = nil
	end

	self._cameras = cameras

	self._locked = false
	local contexts = playerModule and playerModule:FindFirstChild("InputContexts")
	local context = contexts and contexts:FindFirstChild("CameraContext")
	local stockAction: any = context and context:FindFirstChild("MouseLockSwitchAction")

	-- Tells the stock camera, which may have been replaced since last time, and applies the mouse at once.
	local function tellCamera()
		local camera = cameras and cameras.activeCameraController
		if not camera or not camera.SetIsMouseLocked then
			return
		end
		local wanted = self._locked or self._mouseHeld == true
		local changed = camera:GetIsMouseLocked() ~= wanted
		camera:SetIsMouseLocked(wanted)
		if camera.SetMouseLockOffset then
			camera:SetMouseLockOffset(OFFSET)
		end
		if changed and camera.UpdateMouseBehavior then
			camera:UpdateMouseBehavior()
		end
	end
	self._tellCamera = tellCamera

	if
		not cameras
		or not cameras.activeCameraController
		or not cameras.activeCameraController.SetIsMouseLocked
	then
		warn("[Haymaker Tussle] the stock camera changed; shift lock won't work")
	end

	-- One press is one toggle. Roblox's own binding is off, so nothing else can flip it.
	ContextActionService:BindActionAtPriority(
		ACTION,
		function(_name: string, state: Enum.UserInputState)
			if
				state == Enum.UserInputState.Begin
				and not self._mouseHeld
				and not GuiService.MenuIsOpen
			then
				self._locked = not self._locked
				tellCamera()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift
	)

	local iconHidden = false

	RunService.RenderStepped:Connect(function()
		-- Roblox's own toggle stays off, even if the place's setting gets turned back on.
		if stockAction and stockAction.Enabled then
			stockAction.Enabled = false
		end
		tellCamera()

		local locked = self:IsLocked()
		if player:GetAttribute("HT_ShiftLocked") ~= locked then
			player:SetAttribute("HT_ShiftLocked", locked)
		end
		local held = self._mouseHeld == true
		if (locked or held) ~= iconHidden then
			iconHidden = locked or held
			UserInputService.MouseIconEnabled = not iconHidden
		end

		local shown = false
		if locked and not held then
			local character = player.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?
			local view = workspace.CurrentCamera
			if head and view then
				local top = head.Position + Vector3.yAxis * (head.Size.Y / 2 + cfg.DotAboveHead)
				local point, onScreen = view:WorldToViewportPoint(top)
				if onScreen then
					shown = true
					dot.Position = UDim2.fromOffset(point.X, point.Y)
				end
			end
		end
		dot.Visible = shown
	end)
end

return ShiftLockController
