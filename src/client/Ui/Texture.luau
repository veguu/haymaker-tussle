--!strict
-- Texture - the surface of every button and card (ui-21a, 2026-11-20). The owner: "the buttons NEED textures,
-- find every button that this applies to, it doesnt feel complete the way it is ... the textures need to be
-- animated". Every rounded fill (Shapes.image of a ROUND shape named "Fill") gets three layers, all clipped to its
-- own shape, none needing an upload:
--   depth  a UIGradient on the fill itself: full colour at the top, a little darker at the bottom, so a flat
--          plate reads as a raised tile;
--   gloss  a soft white sheen over the top of the face, fading out by its middle (static);
--   grain  the SPARKLES pattern (ui-21b, the owner's pick of six: Shapes.ids.sparkles, design/ui/
--          make_button_patterns.py) tiled over the face, white on a coloured face and ink on a light one, always
--          shown at one strength and DRIFTING up and to the right one tile every few seconds, never stopping;
--   shine  a soft white band that sweeps across now and then (staggered, never all at once) and at once when the
--          pointer comes onto a pressable (Texture.shine, from PosterKit.pressable).
-- The grain sits in a clipping frame the size of the fill: the frame is square-cornered, but the fill's corners lie
-- inside the ink outline, and ink dots on ink do not show.
-- COST: the drift is one TweenService tween per fill (native, no Lua per frame); the shine is one task loop for
-- all fills. Phones (Drift.lite): no shine. Reduced Motion: nothing moves. Measuring switch: workspace attribute
-- HT_TextureOff = true pauses every drift and stops the shine.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Drift = require(script.Parent.Drift)
local HudMotion = require(script.Parent.HudMotion)

local Texture = {}

local TILE = 44 -- units per pattern tile (the dots of ui-21a were 13; 56 left them too sparse)
local GRAIN_CLEAR = 0.58 -- white sparkles on a coloured face (0.74 read too faint, seen enlarged)
local GRAIN_CLEAR_INK = 0.76 -- ink sparkles on a light face (cream, white)
local LIGHT = 0.86 -- a face whose average channel is above this counts as light
local DRIFT_SECONDS = 8 -- one tile
local SHADE = Color3.fromRGB(200, 200, 200) -- the fill's colour is multiplied down to this at the bottom
local SHINE_SECONDS = 0.7
local SHINE_EVERY = { 5, 11 } -- seconds between one fill's idle shines, picked at random in this range
local SHINE_CHECK = 0.25

local OFF = "HT_TextureOff"
local function off(): boolean
	return workspace:GetAttribute(OFF) == true
end

type Made = { shine: UIGradient, nextAt: number, busy: boolean }
-- each drift, and whether it may run now (not while its face is turned: see Texture.apply)
local drifts: { [Tween]: () -> boolean } = setmetatable({}, { __mode = "k" }) :: any
local shines: { [ImageLabel]: Made } = setmetatable({}, { __mode = "k" }) :: any
local loopStarted = false

local function play(made: Made)
	if made.busy then
		return
	end
	made.busy = true
	made.shine.Offset = Vector2.new(-1, 0)
	local tween = TweenService:Create(
		made.shine,
		TweenInfo.new(SHINE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Offset = Vector2.new(1, 0) }
	)
	tween.Completed:Once(function()
		made.busy = false
	end)
	tween:Play()
end

local function startLoop()
	if loopStarted then
		return
	end
	loopStarted = true
	task.spawn(function()
		while true do
			task.wait(SHINE_CHECK)
			if not off() and not HudMotion.reduced() then
				local now = os.clock()
				for fill, made in shines do
					if now >= made.nextAt then
						made.nextAt = now
							+ SHINE_EVERY[1]
							+ math.random() * (SHINE_EVERY[2] - SHINE_EVERY[1])
						-- (only on screen: an unparented or hidden fill keeps its turn for later)
						if fill.Parent ~= nil and fill.Visible then
							play(made)
						end
					end
				end
			end
		end
	end)
	workspace:GetAttributeChangedSignal(OFF):Connect(function()
		for tween, free in drifts do
			if off() then
				tween:Pause()
			elseif free() then
				tween:Play()
			end
		end
	end)
end

--- Gives a rounded fill its depth, gloss, drifting sparkles and shine. `pattern` is the tile's image id.
function Texture.apply(fill: ImageLabel, pattern: string)
	if fill:FindFirstChild("Grain") then
		return
	end
	local depth = Instance.new("UIGradient")
	depth.Name = "Depth"
	depth.Color = ColorSequence.new(Color3.new(1, 1, 1), SHADE)
	depth.Rotation = 90
	depth.Parent = fill

	local grain = Instance.new("Frame")
	grain.Name = "Grain"
	grain.BackgroundTransparency = 1
	grain.BorderSizePixel = 0
	grain.Size = UDim2.fromScale(1, 1)
	grain.ClipsDescendants = true
	grain.ZIndex = 1
	local field = Instance.new("ImageLabel")
	field.Name = "Dots"
	field.BackgroundTransparency = 1
	field.Image = pattern
	field.ScaleType = Enum.ScaleType.Tile
	field.TileSize = UDim2.fromOffset(TILE, TILE)
	-- white on a coloured face, ink on a light one; it follows the face when its colour changes (states)
	local base = GRAIN_CLEAR
	local function tint()
		local c = fill.ImageColor3
		local light = (c.R + c.G + c.B) / 3 > LIGHT
		field.ImageColor3 = if light then Tokens.colour("ink.900") else Color3.new(1, 1, 1)
		base = if light then GRAIN_CLEAR_INK else GRAIN_CLEAR
		field.ImageTransparency = base
	end
	tint()
	fill:GetPropertyChangedSignal("ImageColor3"):Connect(tint)
	field.Size = UDim2.new(1, TILE, 1, TILE)
	field.Position = UDim2.fromOffset(-TILE, 0)
	field.Parent = grain
	grain.Parent = fill

	local gloss = Instance.new("ImageLabel")
	gloss.Name = "Gloss"
	gloss.BackgroundTransparency = 1
	gloss.Image = fill.Image
	gloss.ScaleType = fill.ScaleType
	gloss.SliceCenter = fill.SliceCenter
	gloss.SliceScale = fill.SliceScale
	gloss.ImageColor3 = Color3.new(1, 1, 1)
	gloss.Size = UDim2.fromScale(1, 1)
	gloss.ZIndex = 2
	local sheen = Instance.new("UIGradient")
	sheen.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.22, 0.8),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sheen.Rotation = 90
	sheen.Parent = gloss
	gloss.Parent = fill

	local shine = Instance.new("ImageLabel")
	shine.Name = "Shine"
	shine.BackgroundTransparency = 1
	shine.Image = fill.Image
	shine.ScaleType = fill.ScaleType
	shine.SliceCenter = fill.SliceCenter
	shine.SliceScale = fill.SliceScale
	shine.ImageColor3 = Color3.new(1, 1, 1)
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = 3
	local band = Instance.new("UIGradient")
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Rotation = 20
	band.Offset = Vector2.new(-1, 0)
	band.Parent = shine
	shine.Parent = fill

	-- the drift: one cell right and one cell up, looping without a seam
	local turned = false -- (see TURNED below)
	local tween: Tween? = nil
	if not HudMotion.reduced() then
		tween = TweenService:Create(
			field,
			TweenInfo.new(DRIFT_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Position = UDim2.fromOffset(0, -TILE) }
		)
		drifts[tween :: Tween] = function(): boolean
			return not turned
		end
		if not off() then
			(tween :: Tween):Play()
		end
	end
	-- TURNED (ui-24a; the owner: "whenever u open the ui, the sparkle textures can be seen extruding outside the
	-- frame but after a second its fixed"): Roblox IGNORES ClipsDescendants while the frame or ANY ancestor is
	-- turned (seen in Studio 2026-11-20: a button turned 12 degrees showed its whole drifting field, a tile wider
	-- and taller than the face), and everything that pops in turns from -18 degrees to its rest over 0.6 s. So
	-- while anything above the face is turned, the field is cut to the face's own size and stands still; when all
	-- is straight again it is a tile bigger again and drifts on from one tile back, which is the same picture, so
	-- nothing jumps as the pop settles.
	local function setTurned(now: boolean)
		if now == turned then
			return
		end
		turned = now
		if now then
			if tween then
				tween:Cancel()
			end
			field.Size = UDim2.fromScale(1, 1)
			field.Position = UDim2.new()
		else
			field.Size = UDim2.new(1, TILE, 1, TILE)
			field.Position = UDim2.fromOffset(-TILE, 0)
			if tween and not off() then
				tween:Play()
			end
		end
	end
	local watching: { RBXScriptConnection } = {}
	local function check()
		local node: Instance? = fill
		local now = false
		while node and not node:IsA("LayerCollector") do
			if node:IsA("GuiObject") and node.Rotation ~= 0 then
				now = true
				break
			end
			node = node.Parent
		end
		setTurned(now)
	end
	local function unwatch()
		for _, connection in watching do
			connection:Disconnect()
		end
		table.clear(watching)
	end
	-- one Rotation signal on the face and each of its ancestors up to its ScreenGui, hooked again when it moves
	local function watch()
		unwatch()
		if fill.Parent == nil then
			return
		end
		local node: Instance? = fill
		while node and not node:IsA("LayerCollector") do
			if node:IsA("GuiObject") then
				table.insert(watching, node:GetPropertyChangedSignal("Rotation"):Connect(check))
			end
			node = node.Parent
		end
		check()
	end
	fill.AncestryChanged:Connect(watch)
	fill.Destroying:Connect(unwatch)
	watch()
	if HudMotion.reduced() then
		return
	end
	-- (no twinkle: a breathing strength made the sparkles fade in and out, and the owner wants them to stay and
	-- just keep flowing, 2026-11-20)
	if Drift.lite then
		return
	end
	shines[fill] = {
		shine = band,
		nextAt = os.clock() + 1 + math.random() * SHINE_EVERY[2],
		busy = false,
	}
	startLoop()
end

-- THE IN-GAME FINISH (ui-23a, 2026-11-20; the owner: "not EVERYTHING needs the texture, like the countdown, when
-- swapping between training area and lobby, etc, ONLY the main hud when ur in the lobby, so everything else
-- ingame can be replaced with something more fitting"). My pick for "more fitting": comic-print shading, a still
-- halftone of small ink dots that grows toward the bottom of the face, like a comic panel's shadow. Nothing moves,
-- nothing to animate in a fight.
local HALFTONE_TILE = 9
local HALFTONE_CLEAR = 0.8

--- Gives a rounded fill the in-game comic shading (still). `dots` is the halftone cell's image id.
function Texture.comic(fill: ImageLabel, dots: string)
	if fill:FindFirstChild("Halftone") then
		return
	end
	local clip = Instance.new("Frame")
	clip.Name = "Halftone"
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	local field = Instance.new("ImageLabel")
	field.Name = "Dots"
	field.BackgroundTransparency = 1
	field.Image = dots
	field.ScaleType = Enum.ScaleType.Tile
	field.TileSize = UDim2.fromOffset(HALFTONE_TILE, HALFTONE_TILE)
	field.ImageColor3 = Tokens.colour("ink.900")
	field.ImageTransparency = HALFTONE_CLEAR
	field.Size = UDim2.fromScale(1, 1)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	fade.Parent = field
	field.Parent = clip
	clip.Parent = fill
end

--- The PLAIN finish (ui-23a; the owner: "this x button doesn't really need the spark, anything miscellaneous like
--- that"): the small utility controls (the window's X, page arrows, key caps, the lobby's tool tiles, the in-round
--- cog and CONTROLS chip) keep the button's shading and gloss, but no sparkles and no shine. Nothing moves.
function Texture.plain(fill: ImageLabel)
	if fill:FindFirstChild("Depth") then
		return
	end
	local depth = Instance.new("UIGradient")
	depth.Name = "Depth"
	depth.Color = ColorSequence.new(Color3.new(1, 1, 1), SHADE)
	depth.Rotation = 90
	depth.Parent = fill
	local gloss = Instance.new("ImageLabel")
	gloss.Name = "Gloss"
	gloss.BackgroundTransparency = 1
	gloss.Image = fill.Image
	gloss.ScaleType = fill.ScaleType
	gloss.SliceCenter = fill.SliceCenter
	gloss.SliceScale = fill.SliceScale
	gloss.ImageColor3 = Color3.new(1, 1, 1)
	gloss.Size = UDim2.fromScale(1, 1)
	gloss.ZIndex = 2
	local sheen = Instance.new("UIGradient")
	sheen.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.22, 0.8),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sheen.Rotation = 90
	sheen.Parent = gloss
	gloss.Parent = fill
end

--- Sweeps the shine across a textured fill now (the pointer came onto it).
function Texture.shine(fill: ImageLabel?)
	if not fill or HudMotion.reduced() or off() then
		return
	end
	local made = shines[fill]
	if made then
		play(made)
	end
end

return Texture
