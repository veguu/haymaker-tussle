--!strict
-- AfkController - the AFK button, top left. A lobby setting: switched on, you aren't put in the next
-- rounds until you switch it off. It never moves you. While you're in a round it's locked (the server
-- refuses it too). The server owns the state (player attributes HT_AFK and HT_InRound, set by
-- RoundService); this only asks to switch it and shows what the server says.
--
-- State is shown in words as well as colour: "AFK OFF / playing" on the dark panel, "AFK ON / sitting
-- out" on the yellow, and "AFK / locked in round" dimmed while you're fighting. Mouse, touch and gamepad
-- all press it (it's a normal selectable button).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local AFK = "HT_AFK"
local IN_ROUND = "HT_InRound"
local C = HudTheme.Colour
local S = HudTheme.Afk

local AfkController = Knit.CreateController({
	Name = "AfkController",
})

function AfkController:KnitStart()
	if not GameConfig.Round.Enabled or not GameConfig.Round.AfkEnabled then
		return
	end
	local player = Players.LocalPlayer
	local toggle = Net.client("AfkToggle")
	if not toggle then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Afk"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = false

	local button = Instance.new("TextButton")
	button.Name = "AfkButton"
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromOffset(HudTheme.Size.Edge, S.Top)
	button.Size = UDim2.fromOffset(S.Width, S.Height)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Text = ""
	button.Selectable = true
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, S.Corner)
	corner.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local press = Instance.new("UIScale")
	press.Parent = button

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.Position = UDim2.fromScale(0, 0.05)
	title.Text = "<unbound>"
	Typography.apply(title, "Button")
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, 0, 0.4, 0)
	sub.Position = UDim2.fromScale(0, 0.58)
	sub.Text = ""
	Typography.apply(sub, "Label")
	sub.Parent = button

	local function show()
		local on = player:GetAttribute(AFK) == true
		if player:GetAttribute(IN_ROUND) == true then
			button.Active = false
			button.BackgroundColor3 = C.Panel
			button.BackgroundTransparency = HudTheme.Transparency.Stepped
			title.Text = "AFK"
			title.TextColor3 = C.Dim
			sub.Text = "locked in round"
			sub.TextColor3 = C.Dim
			return
		end
		button.Active = true
		button.BackgroundColor3 = if on then C.Accent else C.Panel
		button.BackgroundTransparency = if on then 0 else HudTheme.Transparency.Panel
		title.Text = if on then "AFK ON" else "AFK OFF"
		title.TextColor3 = if on then C.OnAccent else C.Text
		sub.Text = if on then "sitting out" else "playing"
		sub.TextColor3 = if on then C.OnAccent else C.Muted
	end

	local function layout()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else HudTheme.Scale.Reference
		local ref = HudTheme.Scale.Reference
		scale.Scale = math.clamp(
			math.min(view.X / ref.X, view.Y / ref.Y),
			HudTheme.Scale.Min,
			HudTheme.Scale.Max
		)
	end

	local function tweenPress(value: number, seconds: number)
		if GuiService.ReducedMotionEnabled then
			press.Scale = 1
			return
		end
		TweenService
			:Create(
				press,
				TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Scale = value,
				}
			)
			:Play()
	end

	button.MouseButton1Down:Connect(function()
		tweenPress(S.PressScale, S.PressSeconds)
	end)
	button.MouseButton1Up:Connect(function()
		tweenPress(1, S.ReleaseSeconds)
	end)
	button.MouseLeave:Connect(function()
		tweenPress(1, S.ReleaseSeconds)
	end)
	button.Activated:Connect(function()
		if player:GetAttribute(IN_ROUND) ~= true then
			toggle:FireServer()
		end
	end)

	player:GetAttributeChangedSignal(AFK):Connect(show)
	player:GetAttributeChangedSignal(IN_ROUND):Connect(show)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	show()
	layout()
	gui.Parent = player:WaitForChild("PlayerGui")
end

return AfkController
