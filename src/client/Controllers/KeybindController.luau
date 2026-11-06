--!strict
-- KeybindController - a small panel in the bottom right listing the controls, for whichever
-- input is in use. Touch players have labelled on-screen buttons there, so it hides for them.
-- Placeholder look until the interface step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local KeybindController = Knit.CreateController({
	Name = "KeybindController",
})

local ROWS = {
	mouse = {
		{ key = "Click", action = "Punch" },
		{ key = "Q", action = "Propel" },
		{ key = "Space", action = "Air kick" },
		{ key = "Shift", action = "Shift lock: camera aims the kick" },
		{ key = if RunService:IsStudio() then "E" else "Alt", action = "Lock on" },
	},
	gamepad = {
		{ key = "R2", action = "Punch" },
		{ key = "B", action = "Propel" },
		{ key = "Y", action = "Air kick" },
		{ key = "L1", action = "Lock on" },
	},
}
local ROW_HEIGHT = 30
local KEY_WIDTH = 66
local PADDING = 8

local function deviceOf(kind: Enum.UserInputType): string?
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif kind.Name:find("Gamepad") then
		return "gamepad"
	elseif kind == Enum.UserInputType.Keyboard or kind.Name:find("Mouse") then
		return "mouse"
	end
	return nil
end

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local function makeRow(parent: Instance, order: number): (TextLabel, TextLabel)
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.Parent = parent

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Size = UDim2.fromOffset(KEY_WIDTH, ROW_HEIGHT - 4)
	key.Position = UDim2.fromOffset(0, 2)
	key.BackgroundColor3 = Color3.fromRGB(235, 238, 245)
	key.TextColor3 = Color3.fromRGB(30, 34, 44)
	key.Font = Enum.Font.GothamBold
	key.TextSize = 14
	key.Parent = row
	corner(key, 6)

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Size = UDim2.new(1, -(KEY_WIDTH + PADDING), 1, 0)
	action.Position = UDim2.fromOffset(KEY_WIDTH + PADDING, 0)
	action.BackgroundTransparency = 1
	action.TextColor3 = Color3.new(1, 1, 1)
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.Font = Enum.Font.GothamMedium
	action.TextSize = 15
	action.Parent = row
	return key, action
end

function KeybindController:KnitStart()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_Keybinds"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -16)
	panel.Size = UDim2.fromOffset(160, ROW_HEIGHT * #ROWS.mouse + PADDING * 2)
	panel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	corner(panel, 10)

	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, PADDING)
	inset.PaddingBottom = UDim.new(0, PADDING)
	inset.PaddingLeft = UDim.new(0, PADDING)
	inset.PaddingRight = UDim.new(0, PADDING)
	inset.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local labels = {}
	for order = 1, #ROWS.mouse do
		local key, action = makeRow(panel, order)
		labels[order] = { key = key, action = action }
	end

	local function show(device: string)
		local rows = (ROWS :: any)[device]
		panel.Visible = rows ~= nil
		if rows then
			for order, row in rows do
				labels[order].key.Text = row.key
				labels[order].action.Text = row.action
			end
		end
	end

	show(deviceOf(UserInputService:GetLastInputType()) or "mouse")
	UserInputService.LastInputTypeChanged:Connect(function(kind)
		local device = deviceOf(kind)
		if device then
			show(device)
		end
	end)
end

return KeybindController