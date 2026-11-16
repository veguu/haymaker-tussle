--!strict
-- UltimateMeter - the ultimate meter bar, just above your vitals at the bottom middle, and the G prompt
-- when the follow-up window opens (2026-11-15; rules in Core/UltimateMeter, server in UltimateService).
-- It reads the Player's HT_Ult and HT_UltReady. Full, the bar turns gold and pulses with a G key cap.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Typography = require(ReplicatedStorage.Shared.Typography)
local HudTheme = require(script.Parent.HudTheme)

local cfg = GameConfig.Ultimate
local WIDTH, HEIGHT = 300, 12
local GOLD = Color3.fromRGB(255, 200, 70)
local GOLD_HOT = Color3.fromRGB(255, 244, 196)

local UltimateMeter = {}

type Parts = {
	gui: ScreenGui,
	plate: Frame,
	fill: Frame,
	cap: TextLabel,
	prompt: Frame,
	promptRing: Frame,
}

local parts: Parts? = nil

local function corner(parent: Instance, radius: number)
	local made = Instance.new("UICorner")
	made.CornerRadius = UDim.new(0, radius)
	made.Parent = parent
end

local function build(player: Player): Parts
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_UltimateMeter"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 1)
	plate.Position = UDim2.new(0.5, 0, 1, -112)
	plate.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	plate.BackgroundColor3 = HudTheme.Colour.Panel
	plate.BackgroundTransparency = HudTheme.Transparency.Panel
	plate.BorderSizePixel = 0
	plate.Parent = gui
	corner(plate, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = plate

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.Parent = plate
	corner(fill, 4)

	local cap = Instance.new("TextLabel")
	cap.Name = "Cap"
	cap.AnchorPoint = Vector2.new(0, 0.5)
	cap.Position = UDim2.new(1, 8, 0.5, 0)
	cap.Size = UDim2.fromOffset(26, 26)
	cap.BackgroundColor3 = GOLD
	cap.TextColor3 = Color3.fromRGB(30, 22, 6)
	cap.Text = "G"
	cap.Visible = false
	Typography.apply(cap, "Stat")
	cap.TextSize = 16
	cap.Parent = plate
	corner(cap, 5)

	-- The window's prompt: a big G and ULTIMATE, with a ring closing on it for the window's length.
	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.Position = UDim2.fromScale(0.5, 0.66)
	prompt.Size = UDim2.fromOffset(84, 84)
	prompt.BackgroundTransparency = 1
	prompt.Visible = false
	prompt.Parent = gui
	local key = Instance.new("TextLabel")
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.fromScale(0.5, 0.5)
	key.Size = UDim2.fromOffset(56, 56)
	key.BackgroundColor3 = GOLD
	key.TextColor3 = Color3.fromRGB(30, 22, 6)
	key.Text = "G"
	Typography.apply(key, "Stat")
	key.TextSize = 34
	key.Parent = prompt
	corner(key, 10)
	local word = Instance.new("TextLabel")
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.new(0.5, 0, 1, 4)
	word.Size = UDim2.fromOffset(240, 30)
	word.BackgroundTransparency = 1
	word.Text = "ULTIMATE"
	word.TextColor3 = GOLD_HOT
	word.TextStrokeTransparency = 0.1
	Typography.apply(word, "Stat")
	word.TextSize = 24
	word.Parent = prompt
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1.6, 1.6)
	ring.BackgroundTransparency = 1
	ring.Parent = prompt
	corner(ring, 999)
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = GOLD_HOT
	ringStroke.Thickness = 3
	ringStroke.Parent = ring

	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, plate = plate, fill = fill, cap = cap, prompt = prompt, promptRing = ring }
end

--- Builds the meter and keeps it showing the player's HT_Ult.
function UltimateMeter.start()
	local player = Players.LocalPlayer
	local made = build(player)
	parts = made
	local wasReady = false
	RunService.RenderStepped:Connect(function()
		local value = (player:GetAttribute("HT_Ult") :: number?) or 0
		local ready = player:GetAttribute("HT_UltReady") == true
		-- Full: its sound, once, as it fills. A short sting, not a cue that plays on (the user, 2026-11-15).
		if ready and not wasReady then
			-- Short and powerful (the user, 2026-11-16): the sting cut at 1 s, a sub thump under it.
			Sfx.play("ult_ready", nil, nil, { cut = 1 })
			Sfx.play("punch_sub", nil, nil, { volume = 1.1, pitch = 0.8, cut = 0.4 })
		end
		wasReady = ready
		local share = math.clamp(value / cfg.Max, 0, 1)
		made.fill.Size = made.fill.Size:Lerp(UDim2.fromScale(share, 1), 0.25)
		made.cap.Visible = ready
		if ready then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			made.fill.BackgroundColor3 = GOLD:Lerp(GOLD_HOT, pulse)
		else
			made.fill.BackgroundColor3 = GOLD:Lerp(HudTheme.Colour.Muted, 0.35)
		end
	end)
end

--- Shows the G prompt for `seconds`, its ring closing as the window runs out.
function UltimateMeter.prompt(seconds: number)
	local made = parts
	if not made then
		return
	end
	made.prompt.Visible = true
	made.promptRing.Size = UDim2.fromScale(1.6, 1.6)
	TweenService:Create(
		made.promptRing,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0.75, 0.75) }
	):Play()
	local shown = os.clock()
	made.prompt:SetAttribute("Shown", shown)
	task.delay(seconds, function()
		if made.prompt:GetAttribute("Shown") == shown then
			made.prompt.Visible = false
		end
	end)
end

--- Hides the prompt (used, or the ultimate started).
function UltimateMeter.hidePrompt()
	if parts then
		parts.prompt.Visible = false
	end
end

return UltimateMeter
