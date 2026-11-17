--!strict
-- UltimateNotice - your ultimate on the fight-poster HUD (2026-11-16; rules in Core/UltimateMeter, server in
-- UltimateService). It replaces the ultimate BAR, which the owner asked to be removed: there is no meter on
-- screen. It reads the Player's HT_UltReady.
--
--   earned   the notice (Ui/Callouts.ultimate: cut-out letters, READY and the key, confetti, the edge bars), then
--   ready    a small badge above the skills, "ULT READY" with the key, in your class colour. It pops in on the
--            spring and breathes slowly while it waits (the mockup's `.ultb`).
--   window   when a hit opens the follow-up window the badge says PRESS and a line under it runs out with the
--            window (the mockup has no window; this is the game's own rule, drawn in the same style).
--
-- SOUND: the ready sound is SoundBank "ult_ready" (the owner's pick, kits-5f). The owner's spoken "Ultimate
-- ready!" must not play over it, so once that line has an id (Config/VoiceLines) the line plays instead.
-- Nothing here runs per frame while the badge is hidden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local VoiceLines = require(ReplicatedStorage.Shared.Config.VoiceLines)
local Callouts = require(script.Parent.Callouts)
local HudMotion = require(script.Parent.HudMotion)
local HudTheme = require(script.Parent.HudTheme)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)

local UltimateNotice = {}

local colour = Tokens.colour
-- the mockup's badge: 192 x 52, 26 from the right, 20 above the skill tiles, a 4-unit outline, a hard shadow
local SIZE = Vector2.new(192, 52)
local RIGHT, ABOVE_TILES, TILE, TILE_BOTTOM = 26, 20, 104, 24
local LINE = 4

type Device = "mouse" | "gamepad" | "touch"
type Parts = {
	holder: Frame,
	holderScale: UIScale,
	box: Frame,
	boxScale: UIScale,
	fill: ImageLabel,
	words: Poster.Word,
	cap: Frame,
	capText: TextLabel,
	capGlyph: ImageLabel,
	drain: Frame,
}

local parts: Parts? = nil
local shown = false
local windowOpen = false
local windowToken = 0

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function device(): Device
	local kind = UserInputService:GetLastInputType()
	if kind == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(kind.Name, "Gamepad") then
		return "gamepad"
	end
	return "mouse"
end

local function classColour(): Color3
	local kit = Players.LocalPlayer:GetAttribute("HT_Kit")
	local hex = if typeof(kit) == "string" then Tokens.hex[`class.{kit}`] else nil
	return if hex then Color3.fromHex(hex) else colour("coral.500")
end

local function build(): Parts
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = make("ScreenGui", playerGui, {
		Name = "HT_UltimateBadge",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local holder = make("Frame", gui, {
		Name = "Badge",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		Visible = false,
	})
	local holderScale = make("UIScale", holder, {})
	-- the badge itself turns and scales about its own centre
	local box = make("Frame", holder, {
		Name = "Box",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	})
	local boxScale = make("UIScale", box, {})
	local shadow = HudTheme.Tile.Shadow
	Shapes.image(box, "badge", shadow.tone, {
		Name = "Shadow",
		Position = UDim2.fromOffset(shadow.x, shadow.y),
		ImageTransparency = shadow.transparency,
	})
	Shapes.image(box, "badge", "ink.900", { Name = "Line", ZIndex = 1 })
	local fill = Shapes.image(box, "badge", "coral.500", {
		Name = "Fill",
		Position = UDim2.fromOffset(LINE, LINE),
		Size = UDim2.new(1, -2 * LINE, 1, -2 * LINE),
		ZIndex = 2,
	})
	local row = make("Frame", box, {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	make("UIListLayout", row, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	-- the words are images of themselves in the mockup's own font (Ui/Shapes.letters)
	local words = Poster.word(row, "words", "badge:ULT READY", 24, "ink.900", {
		Name = "Words",
		LayoutOrder = 1,
	})
	local cap = make("Frame", row, {
		Name = "Cap",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(42, 30),
	})
	local capText = Poster.text(cap, "display", 18, "ink.900", {
		Size = UDim2.fromScale(1, 1),
		Text = "G",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local capGlyph = make("ImageLabel", cap, {
		Name = "Glyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	-- the follow-up window running out: an ink line under the badge
	local drain = make("Frame", holder, {
		Name = "Window",
		BackgroundColor3 = colour("ink.900"),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 6, 1, 8),
		Size = UDim2.new(1, -12, 0, 6),
		Visible = false,
	})
	return {
		holder = holder,
		holderScale = holderScale,
		box = box,
		boxScale = boxScale,
		fill = fill,
		words = words,
		cap = cap,
		capText = capText,
		capGlyph = capGlyph,
		drain = drain,
	}
end

-- Where the badge stands: above the skill tiles on desktop; on touch (where the real Ult button is the control)
-- under the strip at the top, out of the thumbs' way. Its key cap follows the device.
local function layout(made: Parts)
	local camera = workspace.CurrentCamera
	local ref = HudTheme.Scale.Reference
	local view = if camera then camera.ViewportSize else ref
	local scale = HudTheme.scaleFor(view)
	made.holderScale.Scale = scale
	local kind = device()
	if kind == "touch" then
		made.holder.AnchorPoint = Vector2.new(0.5, 0)
		made.holder.Position = UDim2.new(0.5, 0, 0, 100 * scale)
	else
		made.holder.AnchorPoint = Vector2.new(1, 1)
		made.holder.Position =
			UDim2.new(1, -RIGHT, 1, -(TILE_BOTTOM + (TILE + ABOVE_TILES) * scale))
	end
	made.cap.Visible = kind ~= "touch"
	local glyph = if kind == "gamepad"
		then UserInputService:GetImageForKeyCode(Enum.KeyCode.DPadUp)
		else ""
	made.capGlyph.Image = glyph
	made.capGlyph.Visible = glyph ~= ""
	made.capText.Visible = glyph == ""
	made.cap.BackgroundTransparency = if glyph ~= "" then 1 else 0
end

-- The badge's slow breath while it waits (`ub`: to 1.1 times and 3 degrees over 0.6 s, and back, for ever).
local function breathe(made: Parts, out: boolean)
	if not shown or HudMotion.reduced() then
		made.boxScale.Scale = 1
		made.box.Rotation = 0
		return
	end
	Poster.run(made.box, 0.6, function(t: number)
		local e = PosterEase.easeInOut(t)
		local share = if out then e else 1 - e
		made.boxScale.Scale = 1 + 0.1 * share
		made.box.Rotation = -3 * share
	end, function()
		breathe(made, not out)
	end)
end

-- The badge arriving (`bin`: from nothing, turned 50 degrees, settling on the spring over 0.7 s).
local function popIn(made: Parts)
	made.holder.Visible = true
	Poster.run(made.box, 0.7, function(t: number)
		local s = PosterEase.spring(t)
		made.boxScale.Scale = math.max(s, 0.001)
		made.box.Rotation = -50 * (1 - s)
	end, function()
		breathe(made, true)
	end)
end

local function show(made: Parts)
	made.fill.ImageColor3 = classColour()
	layout(made)
	if not shown then
		shown = true
		popIn(made)
	end
end

local function hide(made: Parts)
	shown = false
	windowOpen = false
	Poster.stop(made.box)
	Poster.stop(made.drain)
	made.holder.Visible = false
	made.drain.Visible = false
	Poster.setWord(made.words, "badge:ULT READY")
end

--- Builds the badge and follows the player's HT_UltReady: the notice when it is earned, the badge while it lasts.
function UltimateNotice.start()
	local player = Players.LocalPlayer
	Callouts.start()
	local made = build()
	parts = made
	local function ready(): boolean
		return player:GetAttribute("HT_UltReady") == true
	end
	local wasReady = false
	local function changed()
		local now = ready()
		if now and not wasReady then
			-- its sound, once (the owner's pick: left to glow 2.6 s, nothing under it); the spoken line takes
			-- its place when there is one, so the two never play together
			local spoken = VoiceLines.UltimateLineReplacesSound and VoiceLines.has("ultimate-ready")
			if not spoken then
				Sfx.play("ult_ready", nil, nil, { cut = 2.6 })
			end
			local kind = device()
			Callouts.ultimate(classColour(), if kind == "touch" then nil else "G", function()
				if ready() then
					show(made)
				end
			end)
		elseif not now and wasReady then
			hide(made)
		end
		wasReady = now
	end
	player:GetAttributeChangedSignal("HT_UltReady"):Connect(changed)
	UserInputService.LastInputTypeChanged:Connect(function()
		if shown then
			layout(made)
		end
	end)
	local function watchViewport()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if shown then
					layout(made)
				end
			end)
		end
	end
	watchViewport()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
	changed()
end

--- The follow-up window is open for `seconds`: the badge says PRESS and a line under it runs out.
function UltimateNotice.prompt(seconds: number)
	local made = parts
	if not made then
		return
	end
	show(made)
	windowOpen = true
	windowToken += 1
	local mine = windowToken
	Poster.setWord(made.words, if device() == "touch" then "badge:ULT NOW" else "badge:PRESS")
	made.drain.Visible = true
	made.drain.Size = UDim2.new(1, -12, 0, 6)
	if not HudMotion.reduced() then
		Poster.run(made.drain, seconds, function(t: number)
			made.drain.Size = UDim2.new(1 - t, -12 * (1 - t), 0, 6)
		end)
	end
	task.delay(seconds, function()
		if windowToken == mine and windowOpen then
			UltimateNotice.hidePrompt()
		end
	end)
end

--- The window closed (used, run out, or the ultimate started): back to the waiting badge, or away.
function UltimateNotice.hidePrompt()
	local made = parts
	if not made then
		return
	end
	windowOpen = false
	Poster.stop(made.drain)
	made.drain.Visible = false
	Poster.setWord(made.words, "badge:ULT READY")
	if Players.LocalPlayer:GetAttribute("HT_UltReady") ~= true then
		hide(made)
	end
end

return UltimateNotice
