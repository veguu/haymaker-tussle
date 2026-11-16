--!strict
-- SoundPicker - Studio only: audition the sound candidates (Config/SoundCandidates) and pick one per role,
-- live (2026-11-15). F7 in a Studio play test shows or hides it. Clicking a letter plays that option and
-- makes it the one the game uses for this test session (Sfx.setRole), so an ultimate played next sounds
-- with it. The picks are printed to Output: tell them to Claude, who bakes them into Config/SoundBank.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sfx = require(ReplicatedStorage.Shared.Sfx)
local SoundCandidates = require(ReplicatedStorage.Shared.Config.SoundCandidates)
local Typography = require(ReplicatedStorage.Shared.Typography)

local SoundPicker = {}

local ROW = 34
local WIDTH = 540 -- room for six options a row
local PICKED = Color3.fromRGB(255, 200, 70)
local IDLE = Color3.fromRGB(52, 52, 60)

local picks: { [string]: string } = {}

local function report()
	local parts = {}
	for _, role in SoundCandidates.ORDER do
		table.insert(parts, `{role}={picks[role] or "A"}`)
	end
	print(`[SoundPicker] picks: {table.concat(parts, "  ")}`)
end

local function label(parent: Instance, text: string, size: number, x: number, w: number): TextLabel
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.Position = UDim2.fromOffset(x, 0)
	made.Size = UDim2.new(0, w, 1, 0)
	made.TextXAlignment = Enum.TextXAlignment.Left
	made.TextColor3 = Color3.new(1, 1, 1)
	made.Text = text
	Typography.apply(made, "Body")
	made.TextSize = size
	made.Parent = parent
	return made
end

--- Builds the picker (Studio only) and binds F7.
function SoundPicker.start()
	if not RunService:IsStudio() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_SoundPicker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(170, 80)
	panel.Size = UDim2.fromOffset(WIDTH, 44 + #SoundCandidates.ORDER * (ROW + 6))
	panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 30)
	title.Parent = panel
	label(title, "SOUND PICKER  (click a letter to hear and pick it; F7 hides)", 15, 0, WIDTH - 24)

	for index, role in SoundCandidates.ORDER do
		local options = SoundCandidates.OPTIONS[role]
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(12, 40 + (index - 1) * (ROW + 6))
		row.Size = UDim2.new(1, -24, 0, ROW)
		row.Parent = panel
		label(row, `{role}`, 14, 0, 110)
		local about = label(row, SoundCandidates.ABOUT[role] or "", 11, 110, 170)
		about.TextColor3 = Color3.fromRGB(180, 180, 190)
		about.TextWrapped = true
		local buttons: { TextButton } = {}
		if #options == 0 then
			local none = label(row, "none found yet: paste an id", 12, 290, 160)
			none.TextColor3 = Color3.fromRGB(255, 160, 120)
		end
		for slot, option in options do
			local button = Instance.new("TextButton")
			button.Position = UDim2.fromOffset(290 + (slot - 1) * 38, 2)
			button.Size = UDim2.fromOffset(32, ROW - 4)
			button.BackgroundColor3 = if slot == 1 then PICKED else IDLE
			button.TextColor3 = if slot == 1 then Color3.fromRGB(30, 22, 6) else Color3.new(1, 1, 1)
			button.Text = option.label
			Typography.apply(button, "Stat")
			button.TextSize = 16
			button.Parent = row
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0, 5)
			round.Parent = button
			table.insert(buttons, button)
			button.Activated:Connect(function()
				Sfx.setRole(role, {
					takes = option.takes,
					looped = false,
					name = option.name,
					creator = option.creator,
				})
				local audition = SoundCandidates.AUDITION[role]
				local playOptions = if audition then audition.options :: any else { cut = 2.5 }
				-- a rhythm varies a little per hit, like the game; a one-off sting plays as it is
				local beats = if audition and audition.beats then audition.beats else nil
				local with = if audition then audition.with else nil
				for _, at in beats or { 0 } do
					task.delay(at, Sfx.play, role, nil, if beats then 0.03 else nil, playOptions)
					if with then
						task.delay(at, Sfx.play, with.role, nil, nil, with.options :: any)
					end
				end
				picks[role] = option.label
				for other, otherButton in buttons do
					otherButton.BackgroundColor3 = if other == slot then PICKED else IDLE
					otherButton.TextColor3 = if other == slot
						then Color3.fromRGB(30, 22, 6)
						else Color3.new(1, 1, 1)
				end
				print(`[SoundPicker] {role} = {option.label}: {option.name} ({option.creator})`)
				report()
			end)
		end
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ContextActionService:BindAction("HaymakerSoundPicker", function(_, state)
		if state == Enum.UserInputState.Begin then
			gui.Enabled = not gui.Enabled
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F7)
end

return SoundPicker
