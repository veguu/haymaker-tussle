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
	-- the lobby (assets/ui/poster_nav_*.png and friends): each is the mockup's own clip-path polygon, stretched
	navA = "rbxassetid://136856775817076", -- Classes, Ranked, More
	navB = "rbxassetid://124539778494442", -- Shop
	navD = "rbxassetid://97223561262692", -- Moves
	gear = "rbxassetid://136635326219064", -- the fight's MENU button
	close = "rbxassetid://117594119784549", -- the window's X
	class = "rbxassetid://85756694857451", -- a class tile
	classStripes = "rbxassetid://101597562657732", -- the stripes over a class you don't own
	act = "rbxassetid://81122324445766", -- an action button (Equip, Buy, Confirm)
	slab = "rbxassetid://128027657366818", -- a shop slab
	dots = "rbxassetid://99839905290934", -- one cell of the window's dot pattern, four times its size
	-- the kill leader's crown in the fighters' row: pixel art, 21 x 15 cells at 16 px (design/ui/make_crown.py);
	-- drawn with ResampleMode Pixelated. NOT tinted: it carries its own colours.
	crownPixel = "rbxassetid://112758624871088",
	-- the round-start countdown's lettering (assets/icons/poster/countdown_sheet.png, 1024 x 600, from
	-- design/ui/poster_countdown.html): see `Shapes.count`
	count = "rbxassetid://101250510173451",
	-- the letter cards' letters, A to Z and "!" (assets/icons/poster/card_letters.png, 1024 x 720, from
	-- design/ui/poster_cards.html): see `Shapes.cards`
	cards = "rbxassetid://103788059570384",
} :: { [string]: string }

-- The round-start countdown's sheet (ui-16a). TOP ROW: the numbers 3, 2, 1 in cells of `cell`, each in its own
-- colour with its outline and shadow, shown untinted. FROM `letterTop` DOWN: the TUSSLE! cards' letters in cells
-- of `letterCell`, WHITE (tinted where used), drawn `letterScale` times the mockup's 128 px; `width` is each
-- letter's own width at 128 px as the browser measures it.
Shapes.count = {
	cell = Vector2.new(256, 400),
	numbers = { [3] = 0, [2] = 1, [1] = 2 },
	letterCell = Vector2.new(128, 200),
	letterTop = 400,
	letterScale = 1.25,
	letters = {
		T = { cell = 0, width = 57 },
		U = { cell = 1, width = 75.3 },
		S = { cell = 2, width = 65.8 },
		L = { cell = 3, width = 56.7 },
		E = { cell = 4, width = 57.2 },
		["!"] = { cell = 5, width = 32.9 },
	} :: { [string]: { cell: number, width: number } },
}

-- The window's drifting word: one TILE per word, from design/ui/make_word_tiles.py (the browser draws them in
-- the mockup's font). A tile is one word-and-gap wide and two rows (168) tall, its second row set 140 to the
-- left, so repeated it is the mockup's wall of words. A word that isn't listed draws no words.
Shapes.words = {
	Base = { id = "rbxassetid://103610338234574", width = 203 },
	Bruiser = { id = "rbxassetid://113485940305771", width = 323 },
	Inferno = { id = "rbxassetid://89122730886452", width = 312 },
	Beast = { id = "rbxassetid://133110655645176", width = 238 },
	Trickster = { id = "rbxassetid://129372346850451", width = 388 },
	Dragon = { id = "rbxassetid://85888752360197", width = 309 },
	Frost = { id = "rbxassetid://124805599592276", width = 240 },
	Tempest = { id = "rbxassetid://86888317908588", width = 319 },
	Shop = { id = "rbxassetid://97270319505585", width = 218 },
	Ranked = { id = "rbxassetid://91327796862187", width = 298 },
	Moves = { id = "rbxassetid://86763183912944", width = 256 },
	More = { id = "rbxassetid://89104050580662", width = 222 },
	Settings = { id = "rbxassetid://102397341024255", width = 337 },
} :: { [string]: { id: string, width: number } }

-- LETTERING AS IMAGES (owner, 2026-11-17, for an exact match): the big display words, drawn by the browser in the
-- mockup's own font at twice its size (design/ui/make_lettering.py -> assets/ui/poster_titles_<n>.png and
-- poster_words_<n>.png). Where each word is on its sheet is in the generated Ui/LetterRects; Poster.word and
-- Poster.figures draw them. `titles` are full colour (the window's title with its outline and shadow); `words`
-- are white, tinted where used (menu strip labels, the ULTIMATE letters, the stamps, class names, upright
-- digits). IMAGE TEXT CANNOT BE TRANSLATED OR RESIZED BY THE ENGINE: a new or changed word means drawing and
-- uploading the sheet again. Anything long or changing stays real text.
Shapes.letters = {
	titles = {
		"rbxassetid://87365915153934",
		"rbxassetid://118820953416670",
		"rbxassetid://139550002196137",
	},
	words = { "rbxassetid://140543979882744" },
} :: { [string]: { string } }

-- The letter cards' sheet (ui-17a): A to Z and "!" in cells of `cell`, `perRow` to a row, WHITE (tinted where
-- used), drawn `scale` times the reference `size` (the mockup's 128 px). `width` is each letter's own width at
-- that size as the browser measures it.
Shapes.cards = {
	cell = Vector2.new(144, 180),
	perRow = 7,
	scale = 1.125,
	size = 128,
	letters = {
		A = { cell = 0, width = 70.5 },
		B = { cell = 1, width = 75.3 },
		C = { cell = 2, width = 72.1 },
		D = { cell = 3, width = 75 },
		E = { cell = 4, width = 57.2 },
		F = { cell = 5, width = 55.6 },
		G = { cell = 6, width = 74.5 },
		H = { cell = 7, width = 78.1 },
		I = { cell = 8, width = 38.5 },
		J = { cell = 9, width = 44.7 },
		K = { cell = 10, width = 72.6 },
		L = { cell = 11, width = 56.7 },
		M = { cell = 12, width = 90.1 },
		N = { cell = 13, width = 71.8 },
		O = { cell = 14, width = 75 },
		P = { cell = 15, width = 73.1 },
		Q = { cell = 16, width = 75 },
		R = { cell = 17, width = 76.8 },
		S = { cell = 18, width = 65.8 },
		T = { cell = 19, width = 57 },
		U = { cell = 20, width = 75.3 },
		V = { cell = 21, width = 67.3 },
		W = { cell = 22, width = 89.2 },
		X = { cell = 23, width = 65.9 },
		Y = { cell = 24, width = 63.1 },
		Z = { cell = 25, width = 55.4 },
		["!"] = { cell = 26, width = 32.9 },
	} :: { [string]: { cell: number, width: number } },
}

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
