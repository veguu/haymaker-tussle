--!strict
-- Components - the Golden Hour building blocks every rebuilt screen is made from (UI Phase 1a, 2026-11-15; vault
-- UI Research/Design System/Shapes and Components). Each reads only Shared/Tokens and Shared/Typography: no
-- literal colours, radii or fonts here or in the screens that use them.
--   make     an instance with properties
--   text     a label in a type role and colour token
--   panel    a soft rounded surface (level 1 HUD / 2 card / 3 dialog) with an optional hairline
--   ledge    THE signature: a 2-unit lit rule on an element's top edge, inset 8, left quarter at full strength
--   meter    a rounded track and fill (+ optional ghost layer and tick marks)
--   keyCap   a small rounded cap holding a key letter or a glyph image
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

--- A surface: level 1 = HUD panel (ink.900, translucent), 2 = card / sheet (ink.800), 3 = dialog (ink.700).
--- `hairline` adds the 1-unit ivory border at 0.9.
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
			Color = colour("ivory.50"),
			Thickness = 1,
			Transparency = 0.9,
		})
	end
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

--- The Ledge: a 2-unit rule on the top edge, inset 8 from each side; its left quarter at full strength, the rest
--- at half, like light catching an edge. Returns the holder (tint it with Components.tintLedge).
function Components.ledge(parent: Instance, tone: string): Frame
	local holder = make("Frame", parent, {
		Name = "Ledge",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 0, 2),
		ZIndex = 4,
	})
	local bright = make("Frame", holder, {
		Name = "Bright",
		BackgroundColor3 = colour(tone),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.25, 1),
		ZIndex = 4,
	})
	local rest = make("Frame", holder, {
		Name = "Rest",
		BackgroundColor3 = colour(tone),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.25, 0),
		Size = UDim2.fromScale(0.75, 1),
		ZIndex = 4,
	})
	Components.corner(bright, "full")
	Components.corner(rest, "full")
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

--- A bar: rounded track and fill. `translucent` uses the ivory track at 0.85 for HUD panels over the scene;
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
		BackgroundColor3 = if translucent then colour("ivory.50") else colour("ink.600"),
		BackgroundTransparency = if translucent then 0.85 else 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, height),
		ClipsDescendants = false,
	})
	Components.corner(track, "full")
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
		Components.corner(ghostFrame :: Frame, "full")
	end
	local fill = make("Frame", track, {
		Name = "Fill",
		BackgroundColor3 = colour("ivory.50"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	})
	Components.corner(fill, "full")
	for _, share in ticks or {} do
		make("Frame", track, {
			Name = "Tick",
			BackgroundColor3 = colour("ink.900"),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(share, 0),
			Size = UDim2.new(0, 1, 1, 0),
			ZIndex = 3,
		})
	end
	return { track = track, fill = fill, ghost = ghostFrame }
end

--- A key cap: radius s, ink.700, hairline, the key in `label` (Extended 600) or a glyph image.
function Components.keyCap(parent: Instance, size: number): (Frame, TextLabel, ImageLabel)
	local cap = make("Frame", parent, {
		Name = "Cap",
		BackgroundColor3 = colour("ink.700"),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Components.corner(cap, "s")
	make("UIStroke", cap, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = colour("ivory.50"),
		Thickness = 1,
		Transparency = 0.85,
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
