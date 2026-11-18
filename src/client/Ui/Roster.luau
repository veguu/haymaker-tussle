--!strict
-- Roster - the fighters' row at the top of the screen (the owner, 2026-11-18): one small rough-cut tile for
-- everyone still standing, in place of the "18 / 25 STANDING" count. His words: "all players' Roblox profile
-- pictures in a row across the top ... a border with the same colour as their class ... the player with the most
-- kills should stand out ... when a player dies, a red X being drawn over their picture, then their box fading
-- downward while the remaining players smoothly move toward the centre ... animations NEED to be smooth".
--
-- A TILE: a picture FRAME (a style from Config/RosterFrames: an ink outline, a wide band in the fighter's CLASS
-- COLOUR, a thin ink line, on a hard ink shadow) round the Roblox head shot (a bot, which has none, shows a
-- plain head and shoulders); bottom right a small plate with the fighter's ring-outs, from 0. Your own picture
-- has a cream line round it.
-- THE CROWN: whoever has the most ring-outs stands a little larger, wears the pixel crown and their plate turns
-- yellow.
-- OUT: two red strokes are DRAWN corner to corner, the tile gives one small kick, the picture goes grey; then the
-- tile sinks and fades, and the others close the gap.
--
-- SMOOTH, AND CHEAP. Every tile's place and the row's size ride a critically damped spring toward where they
-- should be (Core/RosterLogic.spring): each sets off gently, slows into its place and never overshoots, and a
-- second ring-out while the row is still closing just bends the motion, its speed carried over: nothing
-- restarts or jumps. That frame connection exists ONLY while something is still moving. Nothing here is a
-- CanvasGroup (they blur when drawn small): the fade is written to each part. Under Reduced Motion everything
-- simply takes its place.
--
-- The rules (sizes, places, the crown) are Core/RosterLogic, with specs. Who is in the row, their colours and
-- their ring-outs are the caller's business (HudController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PosterEase = require(ReplicatedStorage.Shared.Core.PosterEase)
local RosterFrames = require(ReplicatedStorage.Shared.Config.RosterFrames)
local RosterLogic = require(ReplicatedStorage.Shared.Core.RosterLogic)
local Tokens = require(ReplicatedStorage.Shared.Tokens)
local HudMotion = require(script.Parent.HudMotion)
local Poster = require(script.Parent.Poster)
local Shapes = require(script.Parent.Shapes)

local colour = Tokens.colour

local Roster = {}

-- Sizes, in the row's own units (the caller scales the row with the HUD).
local SIZE = {
	Tile = 52, -- the side a tile is BUILT at: every part inside it is measured against this
	-- How big it is DRAWN: as big as the row's room allows, up to Most (the owner, 2026-11-18: "the profiles
	-- are TOO small ... more visible", but not so big that the row takes the screen over). A full round is held
	-- down by the screen's width; from about 18 standing the tiles are at Most.
	Most = 72,
	Least = 28,
	Gap = 6,
	Crown = 18, -- room over the tiles for the crown
	Shadow = Vector2.new(3, 4),
	Boost = 1.14, -- how much larger the crowned tile stands
}
-- Motion.
local MOVE = {
	Rate = 11, -- the crowned tile's growing: 1 - e^-11t of what is left
	Stiff = 14, -- a tile's slide and the row's resizing, on a critically damped spring: there in about half a second
	In = 0.5, -- a tile's pop when it joins the row
	InStep = 0.02, -- one after another at the start of a round
	Stroke = 0.14, -- each stroke of the X
	Second = 0.11, -- when the second stroke starts
	Kick = 0.28,
	Hold = 0.5, -- the X stands this long before the tile sinks
	Sink = 0.45,
	Close = 0.72, -- when the others start to close the gap: once the sinking tile is half gone
	Plain = 0.4, -- leaving with no X (the round ended under it)
}

export type Entry = {
	id: any, -- whatever names this fighter to the caller (their body)
	name: string,
	userId: number?, -- a real account: its head shot is shown
	frame: string?, -- the picture frame's style (Config/RosterFrames); nil is the default one
	colour: Color3, -- the class colour
	me: boolean,
}

type Faded = { inst: Instance, prop: string, base: number }
type Tile = {
	entry: Entry,
	root: Frame,
	scale: UIScale,
	body: Frame,
	portrait: ImageLabel,
	plate: Frame,
	plateText: TextLabel,
	bars: { Frame },
	border: number, -- how far in the picture starts: the frame's layers together
	faded: { Faded },
	x: number,
	to: number,
	speed: number, -- of its slide (Core/RosterLogic.spring)
	boost: number,
	boostTo: number,
	pop: number, -- its own passing scale: the entrance pop, the kick, the sink
	dying: boolean,
}

local function make(class: string, parent: Instance?, props: { [string]: any }): any
	local instance = Instance.new(class) :: any
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

--- Builds an empty row in `parent`. Place and scale `holder` (its top centre is the row's top centre).
function Roster.new(parent: Instance)
	local holder = make("Frame", parent, {
		Name = "Roster",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(0, SIZE.Crown + SIZE.Tile + SIZE.Shadow.Y),
		ZIndex = 2,
		Visible = false,
	})
	local holderScale = make("UIScale", holder, {})

	local tiles: { [any]: Tile } = {} -- every tile on screen, the ones on their way out too
	local order: { Tile } = {} -- the ones still standing, left to right
	local room = 800
	local size, sizeTo, sizeSpeed = 1, 1, 0 -- every tile's scale: SIZE.Tile at 1
	local moving: RBXScriptConnection? = nil
	local crowned: Tile? = nil

	-- THE CROWN: a bar and three diamonds in the coin yellow with an ink line, standing on the crowned tile.
	local crown = make("Frame", nil, {
		Name = "Crown",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 1),
		Size = UDim2.fromOffset(26, 12),
		ZIndex = 6,
	})
	local crownScale = make("UIScale", crown, {})
	local crownImage: string? = (Shapes.ids :: any).crownPixel
	if crownImage then
		-- the pixel crown (design/ui/make_crown.py, in the manner of the owner's reference, 2026-11-18): 21 x 15
		-- cells, drawn with hard pixels at any size
		crown.Size = UDim2.fromOffset(28, 20)
		crown.Position = UDim2.new(0.5, 0, 0, 4)
		make("ImageLabel", crown, {
			Name = "Pixels",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = crownImage,
			ResampleMode = Enum.ResamplerMode.Pixelated,
		})
	else
		-- (until that image is uploaded: a bar and three diamonds)
		local gold, ink = colour("gold.400"), colour("ink.900")
		local function piece(props: { [string]: any })
			props.BackgroundColor3 = gold
			props.BorderSizePixel = 0
			local made = make("Frame", crown, props)
			make("UIStroke", made, { Color = ink, Thickness = 1.5 })
			return made
		end
		for index, spike in { { 4, 5 }, { 13, 7 }, { 22, 5 } } do
			piece({
				Name = `Spike{index}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(spike[1], 5),
				Size = UDim2.fromOffset(spike[2], spike[2]),
				Rotation = 45,
			})
		end
		piece({
			Name = "Band",
			Position = UDim2.fromOffset(1, 7),
			Size = UDim2.fromOffset(24, 5),
			ZIndex = 2,
		})
	end

	local function apply(tile: Tile)
		-- (the room over the tiles grows with them: the crown is part of the tile and is drawn as big)
		tile.root.Position = UDim2.new(0.5, tile.x, 0, SIZE.Crown * SIZE.Boost * size)
		tile.scale.Scale = math.max(size * tile.boost * tile.pop, 0.01)
	end

	-- The one loop: every tile eases toward its place and its size, and the loop ends itself when all are there.
	local function step(dt: number)
		local still = true
		size, sizeSpeed = RosterLogic.spring(size, sizeSpeed, sizeTo, dt, MOVE.Stiff, 0.001)
		if size ~= sizeTo then
			still = false
		end
		for _, tile in tiles do
			tile.x, tile.speed =
				RosterLogic.spring(tile.x, tile.speed, tile.to, dt, MOVE.Stiff, 0.05)
			tile.boost = RosterLogic.approach(tile.boost, tile.boostTo, dt, MOVE.Rate, 0.002)
			if tile.x ~= tile.to or tile.boost ~= tile.boostTo then
				still = false
			end
			apply(tile)
		end
		if still and moving then
			moving:Disconnect()
			moving = nil
		end
	end
	local function move()
		if HudMotion.reduced() then
			size, sizeSpeed = sizeTo, 0
			for _, tile in tiles do
				tile.x, tile.boost, tile.speed = tile.to, tile.boostTo, 0
				apply(tile)
			end
			return
		end
		if not moving then
			moving = RunService.RenderStepped:Connect(step)
		end
	end

	-- Where everyone still standing belongs, and how big.
	local function reflow()
		local side, pitch = RosterLogic.fit(#order, room, SIZE.Most, SIZE.Least, SIZE.Gap)
		sizeTo = side / SIZE.Tile
		for index, tile in order do
			tile.to = RosterLogic.slot(index, #order, pitch)
		end
		move()
	end

	local function setFade(tile: Tile, away: number)
		for _, part in tile.faded do
			(part.inst :: any)[part.prop] = part.base + (1 - part.base) * away
		end
	end

	local function build(entry: Entry): Tile
		local ink = colour("ink.900")
		local faded: { Faded } = {}
		local function fades(inst: Instance, prop: string)
			table.insert(faded, { inst = inst, prop = prop, base = (inst :: any)[prop] })
		end
		local root = make("Frame", holder, {
			Name = "Tile",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(SIZE.Tile, SIZE.Tile),
		})
		local scale = make("UIScale", root, {})
		local body = make("Frame", root, {
			Name = "Body",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		})
		-- THE FRAME: its style's layers, outside in (Config/RosterFrames says what each is for)
		local style = RosterFrames.get(entry.frame)
		local border = style.outline + style.band + style.inner
		local band = if style.bandTone then colour(style.bandTone) else entry.colour
		local shadow = Shapes.image(body, style.shape, "ink.900", {
			Name = "Shadow",
			Position = UDim2.fromOffset(style.shadow.X, style.shadow.Y),
			ImageTransparency = style.shadowTransparency,
		})
		fades(shadow, "ImageTransparency")
		local outline =
			Shapes.image(body, style.shape, style.outlineTone, { Name = "Outline", ZIndex = 1 })
		fades(outline, "ImageTransparency")
		local line = Shapes.image(body, style.shape, "ink.900", {
			Name = "Band",
			Position = UDim2.fromOffset(style.outline, style.outline),
			Size = UDim2.new(1, -2 * style.outline, 1, -2 * style.outline),
			ZIndex = 1,
		})
		line.ImageColor3 = band
		fades(line, "ImageTransparency")
		local innerAt = style.outline + style.band
		local inner = make("Frame", body, {
			Name = "Inner",
			BackgroundColor3 = colour(style.innerTone),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(innerAt, innerAt),
			Size = UDim2.fromOffset(SIZE.Tile - 2 * innerAt, SIZE.Tile - 2 * innerAt),
			ZIndex = 1,
		})
		fades(inner, "BackgroundTransparency")
		-- the picture, on the ink mixed a little toward the frame's colour (a head shot has a clear background)
		local back = ink:Lerp(band, style.back)
		local portrait = make("ImageLabel", body, {
			Name = "Picture",
			BackgroundColor3 = back,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(border, border),
			Size = UDim2.fromOffset(SIZE.Tile - 2 * border, SIZE.Tile - 2 * border),
			Image = if entry.userId and entry.userId > 0
				then `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=150&h=150`
				else "",
			-- the middle of the head shot only: Roblox leaves air round the head, and a small picture has none
			-- to spare (the face is about a fifth larger this way)
			ImageRectOffset = Vector2.new(14, 6),
			ImageRectSize = Vector2.new(122, 122),
			ZIndex = 2,
		})
		fades(portrait, "BackgroundTransparency")
		fades(portrait, "ImageTransparency")
		if portrait.Image == "" then
			-- no account, no picture (a bot): a plain head and shoulders, a shade lighter than the backdrop
			local figure = back:Lerp(colour("ivory.50"), 0.42)
			for _, part in
				{
					{ name = "Head", at = Vector2.new(0.5, 0.4), size = Vector2.new(0.42, 0.42) },
					{
						name = "Shoulders",
						at = Vector2.new(0.5, 1.06),
						size = Vector2.new(0.8, 0.66),
					},
				}
			do
				local made = make("Frame", portrait, {
					Name = part.name,
					BackgroundColor3 = figure,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(part.at.X, part.at.Y),
					Size = UDim2.fromScale(part.size.X, part.size.Y),
					ZIndex = 2,
				})
				make("UICorner", made, { CornerRadius = UDim.new(0.5, 0) })
				fades(made, "BackgroundTransparency")
			end
		end
		if entry.me then
			-- a cream line just INSIDE the picture's edge (round the outside it covered the class colour)
			local ring = make("Frame", portrait, {
				Name = "Me",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(1.5, 1.5),
				Size = UDim2.new(1, -3, 1, -3),
				ZIndex = 3,
			})
			local line2 = make("UIStroke", ring, {
				Color = colour("ivory.50"),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 1.5,
			})
			fades(line2, "Transparency")
		end
		-- THE KILL COUNTER: a small plate hung on the middle of the frame's bottom edge, so it lies on the frame
		-- and under it, not on the picture (on the bottom right corner it covered a quarter of the face).
		-- Everyone starts at 0 and it is always there (the owner, 2026-11-18).
		local plate = make("Frame", body, {
			Name = "Count",
			BackgroundColor3 = ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 8),
			Size = UDim2.fromOffset(22, 17),
			ZIndex = 4,
		})
		local plateEdge = make("UIStroke", plate, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = colour("ivory.50"),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 1,
		})
		fades(plate, "BackgroundTransparency")
		fades(plateEdge, "Transparency")
		local plateText = Poster.text(plate, "display", 13, "ivory.50", {
			Size = UDim2.fromScale(1, 1),
			Text = "0",
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		fades(plateText, "TextTransparency")
		-- the X: two red strokes with an ink line, drawn when the fighter goes out
		local bars: { Frame } = {}
		for index = 1, 2 do
			local bar = make("Frame", body, {
				Name = `Stroke{index}`,
				BackgroundColor3 = colour("stop.400"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = if index == 1 then 45 else -45,
				Visible = false,
				ZIndex = 5,
			})
			local edge = make("UIStroke", bar, { Color = ink, Thickness = 1.5 })
			fades(bar, "BackgroundTransparency")
			fades(edge, "Transparency")
			bars[index] = bar
		end
		return {
			entry = entry,
			root = root,
			scale = scale,
			body = body,
			portrait = portrait,
			plate = plate,
			plateText = plateText,
			bars = bars,
			border = border,
			faded = faded,
			x = 0,
			to = 0,
			speed = 0,
			boost = 1,
			boostTo = 1,
			pop = 1,
			dying = false,
		}
	end

	-- One stroke of the X, `share` of the way drawn from its own top corner to the opposite bottom one.
	local function stroke(tile: Tile, index: number, share: number)
		local bar = tile.bars[index]
		bar.Visible = share > 0
		if share <= 0 then
			return
		end
		local inset = tile.border + 1
		local from = Vector2.new(if index == 1 then inset else SIZE.Tile - inset, inset)
		local to = Vector2.new(if index == 1 then SIZE.Tile - inset else inset, SIZE.Tile - inset)
		local reach = (to - from) * share
		local mid = from + reach / 2
		bar.Position = UDim2.fromOffset(mid.X, mid.Y)
		bar.Size = UDim2.fromOffset(reach.Magnitude, 5)
	end

	local function remove(tile: Tile)
		if tiles[tile.entry.id] == tile then
			tiles[tile.entry.id] = nil
		end
		Poster.stop(tile)
		if crowned == tile then
			crown.Parent = nil
			crowned = nil
		end
		tile.root:Destroy()
	end

	local row = {}
	row.holder = holder
	row.scale = holderScale
	--- The row's height in its own units, shadow and crown room included.
	-- (at the LARGEST the tiles are drawn, crown and counter included: what stands under the row keeps one
	-- place and does not creep as the tiles grow)
	row.tall = (SIZE.Crown * SIZE.Boost + SIZE.Tile + 8) * SIZE.Most / SIZE.Tile

	--- How wide the row may run, in its own units.
	function row.setRoom(width: number)
		if width ~= room then
			room = width
			reflow()
		end
	end

	--- How many are still standing in the row.
	function row.count(): number
		return #order
	end

	--- Everyone still standing, left to right.
	function row.ids(): { any }
		local ids = table.create(#order)
		for index, tile in order do
			ids[index] = tile.entry.id
		end
		return ids
	end

	--- Whether this fighter is in the row and still standing.
	function row.has(id: any): boolean
		local tile = tiles[id]
		return tile ~= nil and not tile.dying
	end

	--- The fighter still standing whose name this is, if any (a ring-out names its fighters).
	function row.find(name: string): any?
		for _, tile in order do
			if tile.entry.name == name then
				return tile.entry.id
			end
		end
		return nil
	end

	--- Adds a fighter at the right end. `wait` delays its pop (the round's first row arrives one after another).
	function row.add(entry: Entry, wait: number?)
		if tiles[entry.id] then
			return
		end
		local tile = build(entry)
		tiles[entry.id] = tile
		table.insert(order, tile)
		reflow()
		-- it starts where it belongs, not at the row's middle
		tile.x, tile.speed = tile.to, 0
		tile.pop = 0.01
		apply(tile)
		Poster.run(tile, MOVE.In, function(t: number)
			tile.pop = math.max(PosterEase.spring(t), 0.01)
			tile.body.Rotation = -14 * (1 - PosterEase.spring(t))
			apply(tile)
		end, nil, wait)
	end

	--- A fighter is out. `crossed`: with the red X (a ring-out); without, the tile just sinks away.
	function row.out(id: any, crossed: boolean)
		local tile = tiles[id]
		if not tile or tile.dying then
			return
		end
		tile.dying = true
		tile.body.Rotation = 0
		if crowned == tile then
			crown.Parent = nil
			crowned = nil
		end
		local closed = false
		local function close()
			if closed then
				return
			end
			closed = true
			local at = table.find(order, tile)
			if at then
				table.remove(order, at)
			end
			reflow()
		end
		if HudMotion.reduced() then
			close()
			remove(tile)
			return
		end
		local hold = if crossed then MOVE.Hold else 0
		local shut = if crossed then MOVE.Close else 0.08
		local whole = hold + (if crossed then MOVE.Sink else MOVE.Plain)
		local grey = Color3.fromRGB(120, 116, 132)
		Poster.run(tile, whole, function(t: number)
			local at = t * whole
			local pop = 1
			if crossed then
				local first = PosterEase.easeOut(math.clamp(at / MOVE.Stroke, 0, 1))
				local second =
					PosterEase.easeOut(math.clamp((at - MOVE.Second) / MOVE.Stroke, 0, 1))
				stroke(tile, 1, first)
				stroke(tile, 2, second)
				tile.portrait.ImageColor3 = Color3.new(1, 1, 1):Lerp(grey, first)
				pop += 0.16 * math.sin(math.pi * math.clamp(at / MOVE.Kick, 0, 1))
			end
			local sink = PosterEase.easeIn(math.clamp((at - hold) / (whole - hold), 0, 1))
			tile.body.Position = UDim2.fromOffset(0, SIZE.Tile * 0.75 * sink)
			tile.pop = pop * (1 - 0.14 * sink)
			setFade(tile, sink)
			apply(tile)
			if at >= shut then
				close()
			end
		end, function()
			close()
			remove(tile)
		end)
	end

	--- A fighter's ring-outs. The plate shows from the first one.
	function row.kills(id: any, count: number)
		local tile = tiles[id]
		if not tile then
			return
		end
		tile.plateText.Text = tostring(math.min(count, 99))
	end

	--- Who wears the crown (nil: nobody). It lands on the tile with a small pop, and the tile stands larger.
	function row.crown(id: any?)
		local tile: Tile? = if id ~= nil then tiles[id] else nil
		if tile and tile.dying then
			tile = nil
		end
		if tile == crowned then
			return
		end
		local was = crowned
		if was then
			was.boostTo = 1
			was.plate.BackgroundColor3 = colour("ink.900")
			was.plateText.TextColor3 = colour("ivory.50")
		end
		crowned = tile
		if tile then
			tile.boostTo = SIZE.Boost
			tile.plate.BackgroundColor3 = colour("gold.400")
			tile.plateText.TextColor3 = colour("ink.900")
			crown.Parent = tile.body
			Poster.run(crown, 0.5, function(t: number)
				local s = PosterEase.spring(t)
				crownScale.Scale = math.max(s, 0.01)
				crown.Rotation = -30 * (1 - s)
			end)
		else
			Poster.stop(crown)
			crown.Parent = nil
		end
		move()
	end

	--- Empties the row at once (the round is over, or you left it).
	function row.clear()
		for _, tile in table.clone(tiles) do
			remove(tile)
		end
		table.clear(tiles)
		table.clear(order)
		crown.Parent = nil
		crowned = nil
		size, sizeTo, sizeSpeed = 1, 1, 0
		if moving then
			moving:Disconnect()
			moving = nil
		end
	end

	return row
end

return Roster
