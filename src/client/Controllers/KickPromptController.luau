--!strict
-- KickPromptController - the air kick's two prompts. First, with someone in the air close by, a small key
-- cap below the middle of the screen says to jump. Then, once attached to them, the timing meter
-- (Ui/KickMeterBar): a marker runs along a red-to-green-to-red bar, and the press records where it is.
-- The server scores the timing itself; the bar shows the server's answer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Typography = require(ReplicatedStorage.Shared.Typography)
local Knit = require(ReplicatedStorage.Packages.Knit)
local KickMeter = require(ReplicatedStorage.Shared.Core.KickMeter)
local KickMeterBar = require(script.Parent.Parent.Ui.KickMeterBar)

local KEY_SIZE = 44
local IDLE = Color3.fromRGB(235, 238, 245)
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
	self._word = word
	self._meter = KickMeterBar.new(gui)
end

-- The jump is Space (Y); the timed kick once attached is a left click (R2), the punch button.
function KickPromptController:_keyText(timed: boolean?): string
	local kind = UserInputService:GetLastInputType()
	local pad = kind.Name:find("Gamepad") ~= nil
	return if kind == Enum.UserInputType.Touch
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
	self._key.Text = self:_keyText()
	self._holder.Visible = true
	self._key.TextColor3 = IDLE
	self._word.Text = "JUMP"
end

--- Called every frame while touching, with the seconds since touching and this kick's marker plan (from the
--- server). Opens the meter and runs its marker.
function KickPromptController:UpdateMeter(since: number, plan: KickMeter.Plan)
	if not self._meter then
		return
	end
	if self._holder then
		self._holder.Visible = false
	end
	self._meter:Update(since, plan, self:_keyText(true))
end

--- Whether a press counts yet: the bar has finished arriving and the marker is running.
function KickPromptController:MeterLive(): boolean
	return self._meter ~= nil and self._meter:IsLive()
end

--- The press, or the meter running out: the marker stops at once and the bar waits for the server's score.
function KickPromptController:FreezeMeter()
	if self._meter then
		self._meter:Freeze()
	end
end

--- The server's score for this kick: the HT_KickScore attribute (marker position, quality, tier; tier 0 is a
--- meter that ran out). Shown once per kick.
function KickPromptController:ShowScore(score: any)
	if not self._meter then
		return
	end
	if typeof(score) ~= "Vector3" then
		self._meter:Cancel()
		return
	end
	local name = if score.Z < 0.5 then "late" else KickMeter.tierAt(score.Z)
	self._meter:Result(score.X, name)
end

--- Hides the jump key, and calls off a meter that's still timing (one showing its result finishes by itself).
function KickPromptController:Hide()
	if self._holder then
		self._holder.Visible = false
	end
	if self._meter then
		self._meter:Cancel()
	end
end

--- Whether a kick cue is on screen. While it is, the HUD steps back.
function KickPromptController:IsActive(): boolean
	return (self._holder ~= nil and self._holder.Visible)
		or (self._meter ~= nil and self._meter:IsActive())
end

--- For tests: the meter's state name and drawn marker position.
function KickPromptController:PeekMeter(): (string, number)
	if self._meter then
		return self._meter:Peek()
	end
	return "none", 0
end

return KickPromptController
