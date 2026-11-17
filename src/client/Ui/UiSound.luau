--!strict
-- UiSound - the fight-poster UI's soft sounds (the mockup's `sfx()`), by SoundBank role.
--
-- Flat 2D sounds, never from a character. One voice per sound: a repeat cuts the one still playing. Three of
-- them vary their pitch by 4 % each way on every play, as the mockup does. Everything goes through Sfx, which
-- fails inert: a missing sound never stops a press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(ReplicatedStorage.Shared.Sfx)

local UiSound = {}

local VARY: { [string]: number } = {
	ui_press = 0.04,
	ui_page = 0.04,
	ring_out = 0.04,
}

-- the least time between two plays of a sound: a refused key can be retried many times a second
local GAP: { [string]: number } = {
	ui_deny = 0.25,
	skill_ready = 0.25,
}
local lastAt: { [string]: number } = {}

local playing: { [string]: Sound } = {}
-- when anything but the hover last played: a press redraws the page under the pointer, and the new buttons
-- must not answer that as a hover
local lastOther = -math.huge
local HOVER_QUIET = 0.3

--- Plays a UI sound by its SoundBank role.
function UiSound.play(role: string)
	local now = os.clock()
	local gap = GAP[role]
	if gap and now - (lastAt[role] or -math.huge) < gap then
		return
	end
	lastAt[role] = now
	if role ~= "ui_hover" then
		lastOther = now
	end
	local old = playing[role]
	if old then
		Sfx.stop(old)
	end
	playing[role] = Sfx.play(role, nil, VARY[role]) :: any
end

--- The pointer came onto a button. Silent on touch (a tap is a press, not a hover) and right after a press.
function UiSound.hover()
	if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		return
	end
	if os.clock() - lastOther < HOVER_QUIET then
		return
	end
	UiSound.play("ui_hover")
end

--- Plays it only if `object` is really on screen (it and everything above it visible).
function UiSound.playIfShown(role: string, object: GuiObject)
	local at: Instance? = object
	while at do
		if at:IsA("GuiObject") and not at.Visible then
			return
		elseif at:IsA("ScreenGui") then
			if not at.Enabled then
				return
			end
			break
		end
		at = at.Parent
	end
	if at then
		UiSound.play(role)
	end
end

return UiSound
