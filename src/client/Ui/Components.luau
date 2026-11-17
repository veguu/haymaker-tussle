--!strict
-- Components - the Voltline building blocks every rebuilt screen is made from (2026-11-16; the look is in the
-- vault's UI Research/voltline-preview.html). Each reads only Shared/Tokens and Shared/Typography: no literal
-- colours, radii or fonts here or in the screens that use them.
--   make     an instance with properties
--   text     a label in a type role and colour token
--   cut      THE shape: a panel with its top-right and bottom-left corners cut, a fill and a 2-unit border
--   panel    a plain sharp rectangle (level 1 HUD / 2 sheet / 3 dialog) for rows and old screens
--   ledge    a 2-unit accent rule on an element's top edge
--   meter    a square track and fill (+ optional ghost layer and tick marks)
--   keyCap   a small dark cap holding a key letter or a glyph image
--   corner   a UICorner from a radius token

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.Tokens)
local Typography = require(ReplicatedStorage.Shared.Typography)

local Components = {}

local colour = Tokens.colour

function Components.make(class: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end
local make = Components.make

--- A UICorner from a radius token name ("s", "m", "l", "full").
function Components.corner(parent: Instance, radius: string): UICorner
	local r = Tokens.radius[radius]
	assert(r, `unknown radius {radius}`)
	if radius == "full" then
		return make("UICorner", parent, { CornerRadius = UDim.new(0.5, 0) })
	end
	return make("UICorner", parent, { CornerRadius = UDim.new(0, r) })
end

--- A text label in a type role, coloured by a colour token. Left-aligned, centred vertically, no background.
function Components.text(
	parent: Instance,
	role: string,
	tone: string,
	props: { [string]: any }?
): TextLabel
	local label = make("TextLabel", nil, {
		BackgroundTransparency = 1,
		TextColor3 = colour(tone),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	})
	Typography.apply(label, role)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

export type Sticker = {
	holder: Frame,
	face: GuiObject,
	lip: Frame,
	stroke: UIStroke,
	depth: number,
}
export type StickerOptions = {
	fill: string?, -- colour token of the face (default ink.900)
	line: string?, -- colour token of the outline (default ink.950)
	depth: number?, -- how far the lip shows under the face (default 6; 0 for a flat panel)
	radius: string?, -- radius token (default "l")
	button: boolean?, -- the face is a TextButton (default false: a Frame)
}

--- THE Ringside shape: a rounded face with a 3-unit ink outline, sitting on a darker lip. `holder` takes
--- `props` (size, position, name); put content in `face`. A sticker made with `button` can be given
--- Components.pressable, which drops the face onto the lip while it is held.
function Components.sticker(
	parent: Instance?,
	props: { [string]: any }?,
	options: StickerOptions?
): Sticker
	local o: StickerOptions = options or {}
	local depth = o.depth or 6
	local radius = o.radius or "l"
	local holder = make("Frame", nil, { BackgroundTransparency = 1, BorderSizePixel = 0 })
	local lip = make("Frame", holder, {
		Name = "Lip",
		BackgroundColor3 = colour("ink.950"),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.fromScale(1, 1),
		Visible = depth > 0,
	})
	Components.corner(lip, radius)
	local face = make(if o.button then "TextButton" else "Frame", holder, {
		Name = "Face",
		BackgroundColor3 = colour(o.fill or "ink.900"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	if o.button then
		face.Text = ""
		face.AutoButtonColor = false
	end
	Components.corner(face, radius)
	local stroke = make("UIStroke", face, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = colour(o.line or "ink.950"),
		Thickness = 3,
	})
	for key, value in props or {} do
		(holder :: any)[key] = value
	end
	holder.Parent = parent
	return { holder = holder, face = face, lip = lip, stroke = stroke, depth = depth }
end

--- Recolours a sticker's face and outline; either may be nil to leave it.
function Components.paintSticker(sticker: Sticker, fillTone: string?, lineTone: string?)
	if fillTone then
		sticker.face.BackgroundColor3 = colour(fillTone)
	end
	if lineTone then
		sticker.stroke.Color = colour(lineTone)
	end
end

export type Cut = { frame: Frame, fill: ImageLabel, line: ImageLabel }

local function slice(image: string, tone: string, scale: number, z: number): ImageLabel
	local c = Tokens.cut.slice
	return make("ImageLabel", nil, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = image,
		ImageColor3 = colour(tone),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(c[1], c[2], c[3], c[4]),
		SliceScale = scale,
		ZIndex = z,
	})
end

--- One cut-corner image on its own ("fill" or "line"), filling its parent: for a shade over a cut tile.
function Components.cutImage(kind: string, tone: string, size: number?): ImageLabel
	local image = if kind == "line" then Tokens.cut.line else Tokens.cut.fill
	return slice(image, tone, Tokens.cut.scale * (size or 1), 0)
end

--- The cut-corner panel: a clear Frame holding `Fill` (the surface for `level`, behind everything) and `Line`
--- (the border, in `lineTone`). Two images, no strokes or corners. `size` scales the cut: 1 is a 12-unit cut
--- with a 2-unit line; small tiles and chips use less. Put the content in `frame`; tint with Components.paintCut.
function Components.cut(
	parent: Instance?,
	level: number,
	lineTone: string,
	props: { [string]: any }?,
	size: number?
): Cut
	local surface = Tokens.surface[level]
	assert(surface and surface.colour, `no surface level {level}`)
	local scale = Tokens.cut.scale * (size or 1)
	local frame = make("Frame", nil, { BackgroundTransparency = 1, BorderSizePixel = 0 })
	local fill = slice(Tokens.cut.fill, surface.colour, scale, 0)
	fill.Name = "Fill"
	fill.ImageTransparency = surface.transparency
	fill.Parent = frame
	local line = slice(Tokens.cut.line, lineTone, scale, 1)
	line.Name = "Line"
	line.Parent = frame
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return { frame = frame, fill = fill, line = line }
end

--- Recolours a cut panel: either tone may be nil to leave it.
function Components.paintCut(cut: Cut, fillTone: string?, lineTone: string?)
	if fillTone then
		cut.fill.ImageColor3 = colour(fillTone)
	end
	if lineTone then
		cut.line.ImageColor3 = colour(lineTone)
	end
end

--- A plain surface: level 1 = HUD panel (ink.900, translucent), 2 = card / sheet (ink.800), 3 = dialog (ink.700).
--- `hairline` adds a 1-unit border in line.500.
function Components.panel(
	parent: Instance,
	level: number,
	radius: string,
	props: { [string]: any }?,
	hairline: boolean?
): Frame
	local surface = Tokens.surface[level]
	assert(surface and surface.colour, `no surface level {level}`)
	local frame = make("Frame", nil, {
		BackgroundColor3 = colour(surface.colour),
		BackgroundTransparency = surface.transparency,
		BorderSizePixel = 0,
	})
	Components.corner(frame, radius)
	if hairline then
		make("UIStroke", frame, {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = colour("line.500"),
			Thickness = 1,
			Transparency = 0,
		})
	end
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

--- An accent rule: 2 units on the top edge, edge to edge. Returns the holder (tint it with tintLedge).
function Components.ledge(parent: Instance, tone: string): Frame
	local holder = make("Frame", parent, {
		Name = "Ledge",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 4,
	})
	make("Frame", holder, {
		Name = "Bright",
		BackgroundColor3 = colour(tone),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	return holder
end

function Components.tintLedge(ledge: Frame, tone: string)
	for _, piece in ledge:GetChildren() do
		if piece:IsA("Frame") then
			piece.BackgroundColor3 = colour(tone)
		end
	end
end

export type Meter = { track: Frame, fill: Frame, ghost: Frame?, gradient: UIGradient? }

--- A bar: square track and fill. `translucent` thins the dark well a little for HUD panels over the scene;
--- `ghost` adds a second layer under the fill (a value it is heading to); `ticks` are shares (0..1) marked
--- with 1-unit lines.
function Components.meter(
	parent: Instance,
	width: number,
	height: number,
	translucent: boolean,
	ghost: boolean?,
	ticks: { number }?
): Meter
	local track = make("Frame", parent, {
		Name = "Track",
		BackgroundColor3 = colour("ink.600"),
		BackgroundTransparency = if translucent then 0.15 else 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = false,
	})
	local ghostFrame: Frame? = nil
	if ghost then
		ghostFrame = make("Frame", track, {
			Name = "Ghost",
			BackgroundColor3 = colour("ivory.50"),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			Visible = false,
		})
	end
	local fill = make("Frame", track, {
		Name = "Fill",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	})
	for _, share in ticks or {} do
		make("Frame", track, {
			Name = "Tick",
			BackgroundColor3 = colour("ivory.50"),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(share, 0.5),
			Size = UDim2.new(0, 2, 1, 6),
			ZIndex = 3,
		})
	end
	return { track = track, fill = fill, ghost = ghostFrame }
end

--- A key cap: a dark well with a bright 1-unit border, the key in `label` or a glyph image.
function Components.keyCap(parent: Instance, size: number): (Frame, TextLabel, ImageLabel)
	local cap = make("Frame", parent, {
		Name = "Cap",
		BackgroundColor3 = colour("ink.600"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Components.corner(cap, "s")
	make("UIStroke", cap, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = colour("line.300"),
		Thickness = 1,
		Transparency = 0,
	})
	make("UIPadding", cap, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	local label = Components.text(cap, "Key", "ivory.50", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local glyph = make("ImageLabel", cap, {
		Name = "Glyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size - 4, size - 4),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	return cap, label, glyph
end

return Components
