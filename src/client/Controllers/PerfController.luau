--!strict
-- PerfController - the owner's performance readout, top left under the Bots button, for testing on real
-- devices (phones especially). Only shown to whoever may use the Bots button (HT_CanFreezeBots: Studio, or the
-- place's owner), so players never see it. Tap it to hide or show the detail line.
--
-- Twice a second: average FPS and frame time, the WORST frame in the last 2 seconds (a hitch shows there even
-- when the average is fine), client memory, the graphics level (Roblox's 1-10; "auto" when automatic), and
-- whether this device counts as a phone for the game's lighter paths (touch with no keyboard).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Typography = require(game:GetService("ReplicatedStorage").Shared.Typography)
local HudTheme = require(script.Parent.Parent.Ui.HudTheme)

local CAN = "HT_CanFreezeBots"
local WINDOW = 2 -- seconds of frames kept for the worst frame
local C = HudTheme.Colour

local PerfController = Knit.CreateController({
	Name = "PerfController",
})

local function graphicsLevel(): string
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return "?"
	end
	if level == Enum.SavedQualitySetting.Automatic then
		return "auto"
	end
	return tostring(level.Value)
end

function PerfController:KnitStart()
	local player = Players.LocalPlayer
	local built = false

	local function build()
		if built or player:GetAttribute(CAN) ~= true then
			return
		end
		built = true

		local gui = Instance.new("ScreenGui")
		gui.Name = "HT_Perf"
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.DisplayOrder = 5

		local top = HudTheme.Afk.Top
			+ HudTheme.Afk.Height
			+ HudTheme.Spectate.Gap
			+ HudTheme.Spectate.Height
			+ HudTheme.BotsFreeze.Gap
			+ HudTheme.BotsFreeze.Height
			+ HudTheme.BotsFreeze.Gap
		local panel = Instance.new("TextButton")
		panel.Name = "PerfPanel"
		panel.Position = UDim2.fromOffset(HudTheme.Size.Edge, top)
		panel.Size = UDim2.fromOffset(HudTheme.BotsFreeze.Width, 44)
		panel.AutomaticSize = Enum.AutomaticSize.X
		panel.BackgroundColor3 = C.Panel
		panel.BackgroundTransparency = HudTheme.Transparency.Panel
		panel.BorderSizePixel = 0
		panel.AutoButtonColor = false
		panel.Text = ""
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, HudTheme.BotsFreeze.Corner)
		corner.Parent = panel
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = panel
		local scale = Instance.new("UIScale")
		scale.Parent = panel

		local main = Instance.new("TextLabel")
		main.BackgroundTransparency = 1
		main.Size = UDim2.new(0, 0, 0.55, 0)
		main.AutomaticSize = Enum.AutomaticSize.X
		main.Position = UDim2.fromScale(0, 0.04)
		main.TextXAlignment = Enum.TextXAlignment.Left
		Typography.apply(main, "Button")
		main.TextColor3 = C.Text
		main.Text = "-- fps"
		main.Parent = panel
		local detail = Instance.new("TextLabel")
		detail.BackgroundTransparency = 1
		detail.Size = UDim2.new(0, 0, 0.4, 0)
		detail.AutomaticSize = Enum.AutomaticSize.X
		detail.Position = UDim2.fromScale(0, 0.56)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		Typography.apply(detail, "Label")
		detail.TextColor3 = C.Muted
		detail.Text = ""
		detail.Parent = panel

		panel.Activated:Connect(function()
			detail.Visible = not detail.Visible
		end)

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
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()

		-- frame times: a ring of (time, dt) kept for WINDOW seconds
		local times: { number } = {}
		local dts: { number } = {}
		local nextShow = 0
		local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		RunService.Heartbeat:Connect(function(dt)
			local now = os.clock()
			table.insert(times, now)
			table.insert(dts, dt)
			while #times > 0 and now - times[1] > WINDOW do
				table.remove(times, 1)
				table.remove(dts, 1)
			end
			if now < nextShow then
				return
			end
			nextShow = now + 0.5
			local sum, worst = 0, 0
			for _, d in dts do
				sum += d
				worst = math.max(worst, d)
			end
			local avg = sum / math.max(#dts, 1)
			main.Text = string.format(
				"%d fps  %.1f ms",
				math.floor(1 / math.max(avg, 1e-4) + 0.5),
				avg * 1000
			)
			main.TextColor3 = if avg > 1 / 30 then Color3.fromRGB(255, 120, 110) else C.Text
			detail.Text = string.format(
				"worst %d ms · %d MB · gfx %s%s",
				math.floor(worst * 1000 + 0.5),
				math.floor(Stats:GetTotalMemoryUsageMb() + 0.5),
				graphicsLevel(),
				if phone then " · phone" else ""
			)
		end)

		gui.Parent = player:WaitForChild("PlayerGui")
	end

	player:GetAttributeChangedSignal(CAN):Connect(build)
	build()
end

return PerfController
