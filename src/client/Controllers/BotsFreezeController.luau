--!strict
-- BotsFreezeController - the owner's Bots button, top left under Spectate. Only shown when the server has
-- marked you as allowed (player attribute HT_CanFreezeBots: in Studio, or the place's owner). Pressing it
-- asks the server to stop or restart every bot; the server owns the state (workspace attribute
-- HT_BotsFrozen) and this only shows it: "BOTS ON / fighting" or, on the yellow, "BOTS STOPPED / inspecting".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local FROZEN = "HT_BotsFrozen"
local CAN = "HT_CanFreezeBots"
local C = HudTheme.Colour
local S = HudTheme.BotsFreeze

local BotsFreezeController = Knit.CreateController({
	Name = "BotsFreezeController",
})

function BotsFreezeController:KnitStart()
	local player = Players.LocalPlayer
	local built = false

	local function build()
		if built or player:GetAttribute(CAN) ~= true then
			return
		end
		local toggle = Net.client("BotsFreezeToggle")
		if not toggle then
			return
		end
		built = true

		local gui = Instance.new("ScreenGui")
		gui.Name = "HT_BotsFreeze"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.DisplayOrder = 5

		local top = HudTheme.Afk.Top
			+ HudTheme.Afk.Height
			+ HudTheme.Spectate.Gap
			+ HudTheme.Spectate.Height
			+ S.Gap
		local button = Instance.new("TextButton")
		button.Name = "BotsButton"
		button.Position = UDim2.fromOffset(HudTheme.Size.Edge, top)
		button.Size = UDim2.fromOffset(S.Width, S.Height)
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.Text = ""
		button.Selectable = true
		button.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, S.Corner)
		corner.Parent = button
		local scale = Instance.new("UIScale")
		scale.Parent = button

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0.6, 0)
		title.Position = UDim2.fromScale(0, 0.05)
		Typography.apply(title, "Button")
		title.Parent = button
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.new(1, 0, 0.4, 0)
		sub.Position = UDim2.fromScale(0, 0.58)
		Typography.apply(sub, "Label")
		sub.Parent = button

		local function show()
			local on = workspace:GetAttribute(FROZEN) == true
			button.BackgroundColor3 = if on then C.Accent else C.Panel
			button.BackgroundTransparency = if on then 0 else HudTheme.Transparency.Panel
			title.Text = if on then "BOTS STOPPED" else "BOTS ON"
			title.TextColor3 = if on then C.OnAccent else C.Text
			sub.Text = if on then "inspecting" else "fighting"
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

		button.Activated:Connect(function()
			toggle:FireServer()
		end)
		workspace:GetAttributeChangedSignal(FROZEN):Connect(show)
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		show()
		layout()
		gui.Parent = player:WaitForChild("PlayerGui")
	end

	player:GetAttributeChangedSignal(CAN):Connect(build)
	build()
end

return BotsFreezeController
