--!strict
-- KickPromptController - the air kick's two prompts. Deliberately small: a key cap below the
-- middle of the screen. First, with someone in the air close by, the key says to jump. Then, once
-- attached to them, a ring closes in on it: press as it meets the key. The server grades the
-- timing itself. Placeholder look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local DiveKick = require(ReplicatedStorage.Shared.Core.DiveKick)
local KickResultText = require(script.Parent.Parent.Ui.KickResultText)

local cfg = GameConfig.Kick
local KEY_SIZE = 44
local RING_START = 3 -- times the key's size, when the ring first appears
local IDLE = Color3.fromRGB(235, 238, 245)
local GRADE_COLOURS: { [string]: Color3 } = {
	green = Color3.fromRGB(120, 255, 160),
	orange = Color3.fromRGB(255, 180, 70),
	red = Color3.fromRGB(255, 95, 85),
}
local KickPromptController = Knit.CreateController({
	Name = "KickPromptController",
})

local function round(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
end

function KickPromptController:KnitStart()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_KickPrompt"
	gui.DisplayOrder = 9 -- the timed cue is never under the HUD
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.72)
	holder.Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Size = UDim2.fromScale(1, 1)
	key.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	key.BackgroundTransparency = 0.25
	key.TextColor3 = IDLE
	Typography.apply(key, "Key")
	key.Parent = holder
	round(key)

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.Parent = holder
	round(ring)
	local line = Instance.new("UIStroke")
	line.Thickness = 2.5
	line.Color = IDLE
	line.Parent = ring

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.new(0.5, 0, 1, 4)
	word.Size = UDim2.fromOffset(120, 18)
	word.BackgroundTransparency = 1
	word.TextColor3 = IDLE
	word.TextStrokeTransparency = 0.5
	Typography.apply(word, "Action")
	word.Parent = holder

	self._holder = holder
	self._key = key
	self._ring = ring
	self._line = line
	self._word = word
	self._resultText = KickResultText.new(gui)
end

-- The jump is Space (Y); the timed kick once attached is a left click (R2), the punch button.
function KickPromptController:_setKeyText(timed: boolean?)
	local kind = UserInputService:GetLastInputType()
	local pad = kind.Name:find("Gamepad") ~= nil
	self._key.Text = if kind == Enum.UserInputType.Touch
		then "TAP"
		elseif pad then (if timed then "R2" else "Y")
		elseif timed then "CLICK"
		else "SPACE"
end

--- Shows the first prompt: someone is in the air close enough to jump at.
function KickPromptController:ShowJump()
	if not self._holder then
		return
	end
	self:_setKeyText()
	self._holder.Visible = true
	self._ring.Visible = false
	self._key.TextColor3 = IDLE
	self._word.Text = "JUMP"
end

--- Called every frame while touching, with seconds since touching and when the ring meets the
--- key, which differs each jump, so it has to be watched rather than learned. The ring shows what a
--- press right now would be worth.
function KickPromptController:UpdateAttach(since: number, qteAt: number)
	if not self._holder then
		return
	end
	self:_setKeyText(true)
	self._holder.Visible = true
	self._ring.Visible = true
	self._word.Text = "KICK"
	local share = math.clamp(1 - since / qteAt, -0.4, 1)
	local size = KEY_SIZE * (1 + (RING_START - 1) * math.max(share, 0))
	self._ring.Size = UDim2.fromOffset(size, size)
	local colour = GRADE_COLOURS[DiveKick.grade(cfg, since, qteAt)]
	self._line.Color = colour
	self._key.TextColor3 = colour
end

--- Hides the key.
function KickPromptController:Hide()
	if self._holder then
		self._holder.Visible = false
	end
end

--- Shows how the timing went. Called once per kick, with its final result.
function KickPromptController:ShowResult(grade: string)
	if self._resultText then
		self._resultText:Show(grade)
	end
end

--- Whether a kick cue is on screen. While it is, the HUD steps back.
function KickPromptController:IsActive(): boolean
	return self._holder ~= nil and self._holder.Visible
end

return KickPromptController
