--!strict
-- TrainingPanel - the optional testing display: a small list of readings at the side of the screen, in
-- its own ScreenGui, kept apart from the combat UI. It only shows what it's handed, and decides nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Typography = require(ReplicatedStorage.Shared.Typography)

local TrainingPanel = {}
TrainingPanel.__index = TrainingPanel

local WIDTH = 270
local ROW_HEIGHT = 20
local BUTTON_HEIGHT = 40
local PAD = 8
local INK = Color3.fromRGB(16, 18, 26)
local ACCENT = Color3.fromRGB(255, 200, 80)
local ROWS =
	{ "Station", "Attack", "Hits", "Target", "Stagger", "Knockback", "Height", "Kick", "Recovery" }

export type Panel = typeof(setmetatable({} :: any, TrainingPanel))

local function makeButton(parent: Instance, text: string, x: number, width: number): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(width, BUTTON_HEIGHT)
	button.Position = UDim2.fromOffset(x, 0)
	button.BackgroundColor3 = Color3.fromRGB(50, 58, 78)
	button.TextColor3 = Color3.new(1, 1, 1)
	Typography.apply(button, "Button")
	button.TextSize = 14
	button.Text = text
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.Parent = parent
	return button
end

function TrainingPanel.new(parent: Instance): Panel
	local self = setmetatable({}, TrainingPanel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_TrainingPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -12, 0.38, 0)
	local height = PAD * 3 + #ROWS * ROW_HEIGHT + BUTTON_HEIGHT
	frame.Size = UDim2.fromOffset(WIDTH, height)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.22
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	frame.Parent = gui

	self._values = {}
	for index, name in ROWS do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(PAD, PAD + (index - 1) * ROW_HEIGHT)
		row.Size = UDim2.fromOffset(WIDTH - PAD * 2, ROW_HEIGHT)
		Typography.apply(row, "Body")
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.RichText = true
		row.Parent = frame
		self._values[name] = row
		self:Set(name, "-")
	end

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Position = UDim2.fromOffset(PAD, height - PAD - BUTTON_HEIGHT)
	buttons.Size = UDim2.fromOffset(WIDTH - PAD * 2, BUTTON_HEIGHT)
	buttons.Parent = frame
	local half = (WIDTH - PAD * 3) / 2
	self.HitboxButton = makeButton(buttons, "Hitboxes", 0, half)
	self.HideButton = makeButton(buttons, "Hide", half + PAD, half)

	-- What's left on screen when it's hidden, so it can be brought back.
	local tab = Instance.new("TextButton")
	tab.AnchorPoint = Vector2.new(1, 0.5)
	tab.Position = UDim2.new(1, -12, 0.38, 0)
	tab.Size = UDim2.fromOffset(120, BUTTON_HEIGHT)
	tab.BackgroundColor3 = INK
	tab.BackgroundTransparency = 0.22
	tab.TextColor3 = ACCENT
	Typography.apply(tab, "Button")
	tab.TextSize = 14
	tab.Text = "Testing display"
	tab.Visible = false
	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 8)
	tabCorner.Parent = tab
	tab.Parent = gui
	self.ShowButton = tab

	self._gui = gui
	self._frame = frame
	return self
end

function TrainingPanel:Set(name: string, value: string)
	local row = self._values[name]
	if row then
		local text = `<font color="#FFC850">{name}</font>  {value}`
		if row.Text ~= text then
			row.Text = text
		end
	end
end

--- `inArea` is whether the player is in training at all; `open` is whether they want the readings.
function TrainingPanel:Show(inArea: boolean, open: boolean)
	self._gui.Enabled = inArea
	self._frame.Visible = open
	self.ShowButton.Visible = not open
end

return TrainingPanel
