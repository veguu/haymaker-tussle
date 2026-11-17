--!strict
-- Shapes - the fight-poster look's slanted and rough-cut shapes (2026-11-16), by name, in ONE place.
--
-- Roblox can't skew a frame or clip it to a polygon, so each shape is a white image tinted where it is used.
-- Sources: assets/ui/poster_*.png, drawn by design/ui/draw_poster_shapes.py (the digits by the browser, from
-- design/ui/poster_digits.html). TO CHANGE ONE: redraw it, upload it, then change its id here. Nothing else in
-- the code names a shape's asset id.
--
--   wedge    a right triangle: the slanted end of a plate leaning like "/". Shapes.slant builds a plate of any
--            size from this wedge, a plain body and `wedgeEnd`, the same wedge turned half round (turning it
--            in Roblox leaves a hairline seam). It is NOT a 9-slice: Roblox mis-slices an image it draws small
--            and the lean goes (measured 2026-11-16).
--   segOn    a lit stagger segment (20 tall, leaning 20 degrees); segOff an unlit one (14 tall). Stretched.
--   tile     the skill tile's rough-cut quad (256 x 256), stretched to the tile. The same image inset by the
--            outline's width is the tile's fill.
--   stripes  diagonal stripes inside the same quad: the "can't use" pattern.
--   digits   0 to 9 as the browser draws the mockup's stagger number (Oswald 700, slanted), 900 x 400. Roblox
--            has no slanted Oswald.
--   badge    the ULT READY badge's quad (384 x 104), stretched; inset by the outline's width it is the fill.
--   last     the last-players popups' big numbers 5, 4, 3, 2 with their outline and shadow, from
--            design/ui/poster_last_digits.html (1024 x 400).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = require(ReplicatedStorage.Shared.Tokens)

local Shapes = {}

Shapes.ids = {
	wedge = "rbxassetid://109222334678409",
	wedgeEnd = "rbxassetid://136069994270465",
	segOn = "rbxassetid://99676058564854",
	segOff = "rbxassetid://124249913040388",
	tile = "rbxassetid://97000035819964",
	stripes = "rbxassetid://98179049591933",
	digits = "rbxassetid://73013783840248",
	badge = "rbxassetid://101402484359518",
	last = "rbxassetid://134576604933482",
} :: { [string]: string }

-- The last-players numbers' sheet: cells in the order 5, 4, 3, 2, each number's own box in the middle of its
-- cell. Full colour (cream, ink outline and shadow), so it is shown untinted.
Shapes.last = { cell = Vector2.new(256, 400) }

-- How the digit sheet is laid out: cells five to a row (0-4, then 5-9), drawn at `font` pixels, each digit
-- starting `origin` pixels into its cell with its baseline `baseline` pixels down. `advance` is each digit's
-- width per 100 px of font size, as the browser measures it, and `tracking` the mockup's letter spacing in em.
Shapes.digits = {
	cell = Vector2.new(180, 200),
	font = 192,
	origin = 30,
	baseline = 186.8,
	advance = { 55.0, 38.5, 51.4, 51.4, 52.4, 50.9, 53.8, 43.9, 52.1, 53.8 },
	tracking = 0.02,
}

--- A stretched shape image in a colour token, filling its parent until sized.
function Shapes.image(
	parent: Instance?,
	name: string,
	tone: string,
	props: { [string]: any }?
): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = Shapes.ids[name] or ""
	image.ImageColor3 = Tokens.colour(tone)
	for key, value in props or {} do
		(image :: any)[key] = value
	end
	image.Parent = parent
	return image
end

local function lay(plate: Frame, lean: number)
	local left = plate:FindFirstChild("Left") :: ImageLabel
	local right = plate:FindFirstChild("Right") :: ImageLabel
	local body = plate:FindFirstChild("Body") :: Frame
	left.Size = UDim2.new(0, lean, 1, 0)
	right.Size = UDim2.new(0, lean, 1, 0)
	-- the body runs half a unit under each wedge, so no line of background shows where they meet
	body.Position = UDim2.fromOffset(lean - 0.5, 0)
	body.Size = UDim2.new(1, 1 - 2 * lean, 1, 0)
end

--- A slanted plate in a colour token, filling its parent until sized: a clear Frame holding a wedge, a body
--- and a wedge turned round. `lean` is how far the top sits to the right of the bottom, in units, whatever the
--- plate's size. Recolour it with Shapes.paint, not by its own properties.
function Shapes.slant(
	parent: Instance?,
	tone: string,
	lean: number,
	props: { [string]: any }?
): Frame
	local plate = Instance.new("Frame")
	plate.Name = "Slant"
	plate.BackgroundTransparency = 1
	plate.BorderSizePixel = 0
	plate.Size = UDim2.fromScale(1, 1)
	Shapes.image(plate, "wedge", tone, { Name = "Left" })
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Tokens.colour(tone)
	body.BorderSizePixel = 0
	body.Parent = plate
	Shapes.image(plate, "wedgeEnd", tone, {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
	})
	lay(plate, lean)
	for key, value in props or {} do
		(plate :: any)[key] = value
	end
	plate.Parent = parent
	return plate
end

--- Changes a slanted plate's lean.
function Shapes.setLean(plate: Frame, lean: number)
	lay(plate, lean)
end

--- Recolours a slanted plate.
function Shapes.paint(plate: Frame, colour: Color3)
	local left = plate:FindFirstChild("Left") :: ImageLabel
	local right = plate:FindFirstChild("Right") :: ImageLabel
	local body = plate:FindFirstChild("Body") :: Frame
	left.ImageColor3 = colour
	right.ImageColor3 = colour
	body.BackgroundColor3 = colour
end

return Shapes
