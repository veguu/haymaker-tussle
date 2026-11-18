--!strict
-- ImpactFrame - an ultimate's impact frame (2026-11-15). Read from the user's references (vault: 63 VFX
-- Creation/Impact Frames - What They Are and How to Build Them in Roblox): NOT a flash. A run of drawn
-- frames: the scene cut to two tones, the fighters as hard silhouettes, the tones swapping frame to frame,
-- and shapes aimed at the hit. Second pass (the user: "the impact frame being more flashy"): a pure white
-- opening frame; the whole picture zooms and shakes frame to frame; a red and cyan split on the silhouettes;
-- a thick ring growing out from the hit; two beams crossing through it; and each frame held for a set time
-- rather than a count of rendered frames, so it lasts the same at any frame rate.
--
-- How: a full-screen ScreenGui. Each frame is a flat background; the fighters are copies inside a
-- ViewportFrame drawn with the real camera, every part one flat colour (silhouettes), plus two tinted copies
-- offset for the split; the shapes are ImageLabels and Frames centred on the hit's place on screen. Each kit
-- passes its own frame list. Angles, lengths and offsets are set on purpose, never random.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FxKit = require(script.Parent.FxKit)

local Tex = FxKit.Tex

local ImpactFrame = {}

-- FOR STUDY ONLY (kits-8c, the Studio replay in UltimateController): the cards play this many times slower, so a
-- slow-motion replay shows them at the same pace as the bodies.
local slow = 1
function ImpactFrame.studySlow(factor: number)
	slow = math.max(factor, 1)
end

export type Frame = {
	bg: Color3, -- the background
	ink: Color3, -- the silhouettes and the shapes
	figures: boolean?, -- draw the fighters (default true; false for a pure flash frame)
	lines: boolean?, -- radial ink speed lines aimed at the hit
	flares: boolean?, -- four-point flares on the hit
	burst: boolean?, -- a white glow with a hard black core on the hit
	ring: number?, -- a thick ring round the hit, this share of the screen's height across
	beams: boolean?, -- two beams crossing through the hit
	split: boolean?, -- red and cyan copies of the silhouettes, offset either side
	zoom: number?, -- the whole picture scaled about the hit (1 = none)
	shake: number?, -- the whole picture pushed this many pixels, a set way each frame
	slash: boolean?, -- one bold stroke across the screen through the hit, pointed at both ends
	hold: number?, -- seconds to hold it (default 1/30)
	-- kits-8c, the owner: "the impact frames need to be more detailed and flashy, right now they are super simple and
	-- plain". From the references' measured cards (vault: Anime Screen Effects ... Impact-frame sequences): theirs MOVE
	-- inside a card (Acheron's lines redraw every 2 frames and close in; Azure's slash thins to a sliver) and draw the
	-- fighters as INK OUTLINES as well as solid shapes (Azure 6.667). Each of these runs over the card's own hold.
	outline: boolean?, -- the fighters as line art: filled with the background, outlined in the ink
	closing: boolean?, -- the speed lines close in on the hit and redraw (a set turn every 2 frames)
	thinning: boolean?, -- the slash thins to a sliver
	shards: boolean?, -- sharp needles flying out from the hit along set angles
	zoomTo: number?, -- the picture pushes in from `zoom` to this over the card
	spin: boolean?, -- the flares turn and grow over the card
	-- kits-8e, the owner: impact frames "should look more like a sketch" and "shouldnt be still images and should be
	-- highly animated using flipbooks, just like they are in the references"
	boil: boolean?, -- line art that BOILS: the outline jumps between set offsets 24 times a second (hand-drawn)
	flips: { Flip }?, -- animated flipbook layers (ImpactFrame.BOOKS), centred on the hit
}

-- One flipbook layer on a card: `book` (a key of BOOKS), `size` its side as a share of the screen's height (default
-- 2.2: past the edges), `fps` (default 24), `behind` the figures (default in front of them), `tint` (default the card's
-- ink), `start` the frame it opens on, `spin` degrees it turns over the card, `grow` how much bigger it ends.
export type Flip = {
	book: string,
	size: number?,
	fps: number?,
	behind: boolean?,
	tint: Color3?,
	start: number?,
	spin: number?,
	grow: number?,
}

-- The flipbooks (design/vfx/draw_impact_flipbooks.ps1): sheets of 2 x 2 frames of 512 px, white on transparent, in
-- order across their sheets. An empty id leaves that layer out (not uploaded yet).
local BOOKS: { [string]: { images: { string }, frames: number } } = {
	lines = { images = { Tex.ImpactLinesA, Tex.ImpactLinesB }, frames = 8 },
	burst = { images = { Tex.ImpactBurst }, frames = 4 },
}
ImpactFrame.BOOKS = BOOKS

export type Spec = { frames: { Frame } }

local LINE_COUNT = 64
local TAG = "HT_ImpactPart" -- a live part's number while it is cloned (ImpactFrame.prepare)
local RED = Color3.fromRGB(255, 40, 70)
local CYAN = Color3.fromRGB(40, 230, 255)
-- The direction each frame's shake pushes, in turn.
local SHAKES =
	{ Vector2.new(1, -0.6), Vector2.new(-0.8, 0.9), Vector2.new(0.5, 1), Vector2.new(-1, -0.4) }

-- Strips a fighter's copy down to flat one-colour parts (no humanoid, scripts, clothes or effects).
local function flatten(copy: Model, colour: Color3)
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			item.Color = colour
			item.Material = Enum.Material.SmoothPlastic
			item.Transparency = if item.Name == "HumanoidRootPart" then 1 else 0
			if item:IsA("MeshPart") then
				item.TextureID = ""
			end
			item.Anchored = true
			item.CastShadow = false
		elseif item:IsA("SpecialMesh") then
			item.TextureId = ""
		elseif
			item:IsA("Decal")
			or item:IsA("Texture")
			or item:IsA("Script")
			or item:IsA("LocalScript")
			or item:IsA("ParticleEmitter")
			or item:IsA("Trail")
			or item:IsA("Beam")
			or item:IsA("Highlight")
			or item:IsA("BillboardGui")
			or item:IsA("SurfaceAppearance")
			or item:IsA("Shirt")
			or item:IsA("Pants")
			or item:IsA("ShirtGraphic")
			or item:IsA("Humanoid")
		then
			item:Destroy()
		end
	end
end

-- PREPARED SILHOUETTES (kits-7f, the gap study: the old way cloned both fighters again on every ink change, up to 8
-- clones with their Humanoids at the moment of the hit, the likeliest cause of the drop to ~10 fps). Each fighter
-- is cloned ONCE per layer (true, red split, cyan split), ahead of time (the wind-up); at the hit only the parts'
-- CFrames are copied from the live bodies, and the true layer is recoloured in place.
export type Prepared = {
	worlds: { [string]: WorldModel },
	pairs: { { live: BasePart, copies: { BasePart } } },
	inked: { BasePart }, -- the true layer's parts, recoloured per frame
	-- the red split layer's parts (kits-8c): recoloured to the ink when a card draws the fighters as line art (the
	-- layer is then the outline behind the filled true layer), and back to red for a split card
	outlined: { BasePart },
	outlinedCyan: { BasePart }, -- the cyan layer's, the outline's second pass (offset the other way)
}

-- The cards' textures, loaded ahead (kits-8c, the slow-motion recording: the first card's slash and shards and the
-- first stars card showed blank, because an image that is shown before it has loaded draws nothing).
local preloaded = false
local function preload()
	if preloaded then
		return
	end
	preloaded = true
	-- kept ON SCREEN, 1 pixel and all but transparent, for the whole session (measured in the replay: with PreloadAsync
	-- alone the first run's slash and stars still drew nothing and its speed lines came in 0.06 s late)
	local player = Players.LocalPlayer
	local warm = Instance.new("ScreenGui")
	warm.Name = "HT_ImpactWarm"
	warm.ResetOnSpawn = false
	warm.IgnoreGuiInset = true
	local holders = {}
	local textures = { Tex.Leaf, Tex.Needle, Tex.Star, Tex.Glow }
	for _, book in BOOKS do
		for _, sheet in book.images do
			if sheet ~= "" then
				table.insert(textures, sheet)
			end
		end
	end
	for index, texture in textures do
		local holder = Instance.new("ImageLabel")
		holder.Image = texture
		holder.BackgroundTransparency = 1
		holder.ImageTransparency = 0.98
		holder.Size = UDim2.fromOffset(1, 1)
		holder.Position = UDim2.fromOffset(index, 0)
		holder.Parent = warm
		table.insert(holders, holder)
	end
	if player then
		warm.Parent = player:WaitForChild("PlayerGui")
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(holders)
		end)
	end)
end
ImpactFrame.preload = preload

function ImpactFrame.prepare(models: { Model }): Prepared
	preload()
	local worlds: { [string]: WorldModel } = {}
	local colours = { main = Color3.new(0, 0, 0), red = RED, cyan = CYAN }
	for key in colours do
		local world = Instance.new("WorldModel")
		world.Name = key
		worlds[key] = world
	end
	local prepared: Prepared =
		{ worlds = worlds, pairs = {}, inked = {}, outlined = {}, outlinedCyan = {} }
	for _, model in models do
		if model.Parent then
			-- Each live part is tagged with its number before cloning, and its copies found by that tag (kits-8c, measured
			-- in play: matching by position in GetDescendants found NOTHING, because a character in play carries
			-- instances that don't clone and shift every index; so `inked` was empty and the silhouettes stayed black
			-- whatever a card's ink was, since kits-7f)
			local live: { BasePart } = {}
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					table.insert(live, item)
					item:SetAttribute(TAG, #live)
				end
			end
			local twins: { [string]: { [number]: BasePart } } = {}
			for key, colour in colours do
				local was = model.Archivable
				model.Archivable = true
				local copy = model:Clone()
				model.Archivable = was
				if copy then
					flatten(copy, colour)
					local found: { [number]: BasePart } = {}
					for _, item in copy:GetDescendants() do
						local number = item:GetAttribute(TAG)
						if item:IsA("BasePart") and type(number) == "number" then
							found[number] = item
							item:SetAttribute(TAG, nil)
						end
					end
					twins[key] = found
					copy.Parent = worlds[key]
				end
			end
			for number, item in live do
				item:SetAttribute(TAG, nil)
				local copies: { BasePart } = {}
				for key, found in twins do
					local twin = found[number]
					if twin then
						table.insert(copies, twin)
						if key == "main" then
							table.insert(prepared.inked, twin)
						elseif key == "red" then
							table.insert(prepared.outlined, twin)
						elseif key == "cyan" then
							table.insert(prepared.outlinedCyan, twin)
						end
					end
				end
				table.insert(prepared.pairs, { live = item, copies = copies })
			end
		end
	end
	return prepared
end

-- Puts the prepared copies where the live bodies are now.
local function pose(prepared: Prepared)
	for _, pair in prepared.pairs do
		if pair.live.Parent then
			local at = pair.live.CFrame
			for _, copy in pair.copies do
				copy.CFrame = at
			end
		end
	end
end

local function ink(prepared: Prepared, colour: Color3, viewport: ViewportFrame)
	for _, part in prepared.inked do
		part.Color = colour
	end
	viewport.Ambient = colour
	viewport.LightColor = colour
end

-- The outline layer's colour (kits-8c): the ink for line art, red again for the split.
local function outlineColour(parts: { BasePart }, colour: Color3, viewport: ViewportFrame)
	for _, part in parts do
		part.Color = colour
	end
	viewport.Ambient = colour
	viewport.LightColor = colour
end

local function image(parent: Instance, texture: string, z: number): ImageLabel
	local made = Instance.new("ImageLabel")
	made.BackgroundTransparency = 1
	made.Image = texture
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.ZIndex = z
	made.Parent = parent
	return made
end

local function viewportFor(parent: Instance, camera: Camera, z: number): ViewportFrame
	local made = Instance.new("ViewportFrame")
	made.Size = UDim2.fromScale(1, 1)
	made.BackgroundTransparency = 1
	made.CurrentCamera = camera
	made.ZIndex = z
	made.Parent = parent
	return made
end

--- Plays `spec` on this screen, centred on `at` in the world, with `models` as the silhouettes. Returns
--- once it is over (it yields for its length). `prepared` (ImpactFrame.prepare, made ahead of time) avoids
--- cloning the fighters at the moment of the hit.
function ImpactFrame.play(
	spec: Spec,
	at: Vector3,
	models: { Model },
	prepared: Prepared?,
	view: CFrame?,
	viewFov: number?
)
	local liveCamera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	if not liveCamera or not player then
		return
	end
	local size = liveCamera.ViewportSize
	-- `view` (kits-7m): the cards draw from their own camera, so a close-up live shot (the haymaker's zoom onto the
	-- fist) still gets readable whole-body silhouettes; without it they draw from the live camera, as before
	local camera: Camera = liveCamera
	local centre = Vector2.new(size.X / 2, size.Y / 2)
	if view then
		local made = Instance.new("Camera")
		made.Name = "HT_ImpactView"
		made.CFrame = view
		made.FieldOfView = viewFov or 50
		camera = made
		local rel = view:PointToObjectSpace(at)
		if rel.Z < 0 then
			local half = math.tan(math.rad(made.FieldOfView) / 2)
			local x = rel.X / -rel.Z / (half * size.X / size.Y)
			local y = rel.Y / -rel.Z / half
			centre = Vector2.new((x + 1) / 2 * size.X, (1 - (y + 1) / 2) * size.Y)
		end
	else
		local screen, onScreen = liveCamera:WorldToViewportPoint(at)
		if onScreen and screen.Z > 0 then
			centre = Vector2.new(screen.X, screen.Y)
		end
	end
	local reach = math.max(size.X, size.Y) * 1.2

	local gui = Instance.new("ScreenGui")
	gui.Name = "HT_ImpactFrame"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.ZIndex = 1
	back.Parent = gui

	-- Everything that zooms and shakes sits in one stage, pinned at the hit so it scales about it.
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(centre.X / size.X, centre.Y / size.Y)
	stage.Position = UDim2.fromOffset(centre.X, centre.Y)
	stage.Size = UDim2.fromOffset(size.X, size.Y)
	stage.ZIndex = 2
	stage.Parent = back
	local scale = Instance.new("UIScale")
	scale.Parent = stage

	-- Speed lines: bold ink strokes (the Leaf) along the rays from the hit, in three set lengths.
	local lines = {}
	-- each line's own ray, start and length, kept so a `closing` card can move them (kits-8c)
	local rays: { { angle: number, inner: number, length: number } } = {}
	local function placeLine(index: number, turn: number, close: number)
		local ray = rays[index]
		local angle = ray.angle + turn
		local mid = ray.inner * close + ray.length / 2
		local line = lines[index]
		line.Position =
			UDim2.fromOffset(centre.X + math.cos(angle) * mid, centre.Y + math.sin(angle) * mid)
		line.Rotation = math.deg(angle)
	end
	for index = 1, LINE_COUNT do
		local angle = (index - 1) / LINE_COUNT * math.pi * 2 + (if index % 2 == 0 then 0.035 else 0)
		local length = if index % 3 == 0
			then reach * 0.62
			elseif index % 3 == 1 then reach * 0.46
			else reach * 0.34
		local inner = if index % 4 == 0
			then size.Y * 0.2
			elseif index % 2 == 0 then size.Y * 0.27
			else size.Y * 0.34
		local line = image(stage, Tex.Leaf, 3)
		line.Size = UDim2.fromOffset(
			length,
			if index % 3 == 0 then 64 elseif index % 3 == 1 then 42 else 28
		)
		lines[index] = line
		rays[index] = { angle = angle, inner = inner, length = length }
		placeLine(index, 0, 1)
	end

	-- Shards (kits-8c): sharp needles flying out from the hit, each on its own set angle and length (the house rule:
	-- true sharp points, every direction chosen, never random). Moved outward over a `shards` card.
	local shards = {}
	local SHARD_ANGLES = { 8, 40, 63, 101, 128, 157, 196, 219, 247, 281, 302, 337 }
	for index, degrees in SHARD_ANGLES do
		local shard = image(stage, Tex.Needle, 8)
		local long = if index % 3 == 0 then 0.5 elseif index % 3 == 1 then 0.36 else 0.26
		shard.Size = UDim2.fromOffset(size.Y * long, size.Y * long * 0.3)
		shard.Rotation = degrees
		table.insert(
			shards,
			{ image = shard, angle = math.rad(degrees), speed = 0.7 + (index % 4) * 0.12 }
		)
	end

	-- Two beams crossing through the hit, one steep, one shallow.
	local beams = {}
	for index, angle in { 12, 74 } do
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.fromOffset(centre.X, centre.Y)
		beam.Size =
			UDim2.fromOffset(reach * 2, if index == 1 then size.Y * 0.07 else size.Y * 0.035)
		beam.Rotation = angle
		beam.BorderSizePixel = 0
		beam.ZIndex = 4
		beam.Parent = stage
		table.insert(beams, beam)
	end

	-- The slash (2026-11-16, Haymaker Rush, from the Azure Flames finisher's first frame): one long stroke,
	-- pointed at both ends, laid steeply across the screen through the hit.
	local slash = image(stage, Tex.Leaf, 4)
	slash.Size = UDim2.fromOffset(reach * 1.5, size.Y * 0.16)
	slash.Position = UDim2.fromOffset(centre.X, centre.Y)
	slash.Rotation = -34

	-- The ring: a thick circle outline round the hit.
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(centre.X, centre.Y)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 4
	ring.Parent = stage
	local ringRound = Instance.new("UICorner")
	ringRound.CornerRadius = UDim.new(0.5, 0)
	ringRound.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = size.Y * 0.045
	ringStroke.Parent = ring

	-- The silhouettes: the red and cyan split behind, the true ones on top.
	-- (kits-8c: the red layer doubles as the line art's outline, centred on the hit and drawn a little bigger behind the
	-- filled true layer, so the figures read as two bodies drawn in ink, not two blobs)
	local splitRed = viewportFor(stage, camera, 5)
	splitRed.AnchorPoint = Vector2.new(centre.X / size.X, centre.Y / size.Y)
	local redAt = UDim2.fromOffset(centre.X - size.Y * 0.018, centre.Y + size.Y * 0.006)
	local outlineScale = Instance.new("UIScale")
	outlineScale.Parent = splitRed
	local splitCyan = viewportFor(stage, camera, 5)
	splitCyan.AnchorPoint = splitRed.AnchorPoint
	local cyanAt = UDim2.fromOffset(centre.X + size.Y * 0.018, centre.Y - size.Y * 0.006)
	local cyanScale = Instance.new("UIScale")
	cyanScale.Parent = splitCyan
	-- line art: both layers in the ink, a little bigger and offset opposite ways, so the outline is full all round
	local OUTLINE_SCALE = 1.035
	local outlineShift = size.Y * 0.006
	local viewport = viewportFor(stage, camera, 6)
	if camera ~= liveCamera then
		camera.Parent = viewport
	end

	-- Flares: a big four-point one on the hit and two smaller ones beside it.
	local flares =
		{ image(stage, Tex.Star, 7), image(stage, Tex.Star, 7), image(stage, Tex.Star, 7) }
	flares[1].Size = UDim2.fromOffset(size.Y * 1.1, size.Y * 1.1)
	flares[1].Position = UDim2.fromOffset(centre.X, centre.Y)
	flares[2].Size = UDim2.fromOffset(size.Y * 0.45, size.Y * 0.45)
	flares[2].Position = UDim2.fromOffset(centre.X - size.Y * 0.28, centre.Y + size.Y * 0.16)
	flares[3].Size = UDim2.fromOffset(size.Y * 0.32, size.Y * 0.32)
	flares[3].Position = UDim2.fromOffset(centre.X + size.Y * 0.24, centre.Y - size.Y * 0.2)
	flares[3].Rotation = 45

	-- The burst: a white glow with a hard black core, BEHIND the lines, ring and silhouettes (in front it
	-- washed them grey), as in the references: black figures against a white burst.
	local glow = image(stage, Tex.Glow, 2)
	glow.ImageColor3 = Color3.new(1, 1, 1)
	glow.Size = UDim2.fromOffset(size.Y * 0.9, size.Y * 0.9)
	glow.Position = UDim2.fromOffset(centre.X, centre.Y)
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Size = UDim2.fromOffset(size.Y * 0.11, size.Y * 0.11)
	core.Position = UDim2.fromOffset(centre.X, centre.Y)
	core.BackgroundColor3 = Color3.new(0, 0, 0)
	core.BorderSizePixel = 0
	core.ZIndex = 2
	core.Parent = stage
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = core

	-- The copies, posed as the bodies are at the hit; the cyan ones never change colour, the red ones turn to the ink
	-- for line art (kits-8c).
	local ready = prepared or ImpactFrame.prepare(models)
	pose(ready)
	ready.worlds.main.Parent = viewport
	ready.worlds.red.Parent = splitRed
	ready.worlds.cyan.Parent = splitCyan
	local slashHeight = size.Y * 0.42
	-- the speed lines' set turns, one every 2 frames on a `closing` card (they "redraw")
	local LINE_TURNS = { 0, 0.024, 0.049, 0.012, 0.037 }

	-- The flipbook layers (kits-8e), made per card up front: each an ImageLabel stepping through its book's frames.
	type Layer = {
		image: ImageLabel,
		flip: Flip,
		book: { images: { string }, frames: number },
		size: number,
	}
	local layers: { [number]: { Layer } } = {}
	for index, frame in spec.frames do
		local list: { Layer } = {}
		for _, flip in frame.flips or {} do
			local book = BOOKS[flip.book]
			if book and book.images[1] and book.images[1] ~= "" then
				local made = image(stage, book.images[1], if flip.behind then 4 else 7)
				made.Visible = false
				made.ImageRectSize = Vector2.new(512, 512)
				made.Position = UDim2.fromOffset(centre.X, centre.Y)
				local side = size.Y * (flip.size or 2.2)
				made.Size = UDim2.fromOffset(side, side)
				table.insert(list, { image = made, flip = flip, book = book, size = side })
			end
		end
		layers[index] = list
	end
	local function showLayers(index: number)
		for i, list in layers do
			for _, layer in list do
				layer.image.Visible = i == index
				if i == index then
					layer.image.ImageColor3 = layer.flip.tint or spec.frames[index].ink
				end
			end
		end
	end
	-- `elapsed` seconds into card `index`, `p` 0..1 through it
	local function stepLayers(index: number, elapsed: number, p: number)
		for _, layer in layers[index] or {} do
			local flip, book = layer.flip, layer.book
			local shown = ((flip.start or 0) + math.floor(elapsed * (flip.fps or 24))) % book.frames
			local sheet = math.floor(shown / 4) + 1
			local cell = shown % 4
			layer.image.Image = book.images[math.min(sheet, #book.images)]
			layer.image.ImageRectOffset = Vector2.new((cell % 2) * 512, math.floor(cell / 2) * 512)
			local side = layer.size * (1 + ((flip.grow or 1) - 1) * p)
			layer.image.Size = UDim2.fromOffset(side, side)
			layer.image.Rotation = (flip.spin or 0) * p
		end
	end
	-- line boil (kits-8e): the outline layers' set offsets and sizes, a new one 24 times a second
	local BOIL = {
		{ 1, 1, 1.04 },
		{ -1, 1, 1.03 },
		{ 1, -1, 1.045 },
		{ -1, -1, 1.035 },
	}

	local lastInk: Color3? = nil
	local lastOutline: Color3? = nil
	local function show(index: number)
		local frame = spec.frames[index]
		back.BackgroundColor3 = frame.bg
		local figures = frame.figures ~= false
		local outline = figures and frame.outline == true
		-- line art: the true layer filled with the background, the outline layer in the ink behind it
		local fill = if outline then frame.bg else frame.ink
		if figures and lastInk ~= fill then
			ink(ready, fill, viewport)
			lastInk = fill
		end
		local red = if outline then frame.ink else RED
		if figures and lastOutline ~= red then
			outlineColour(ready.outlined, red, splitRed)
			outlineColour(ready.outlinedCyan, if outline then frame.ink else CYAN, splitCyan)
			lastOutline = red
		end
		viewport.Visible = figures
		splitRed.Visible = figures and (frame.split == true or outline)
		splitRed.Position = if outline
			then UDim2.fromOffset(centre.X + outlineShift, centre.Y + outlineShift)
			else redAt
		splitCyan.Position = if outline
			then UDim2.fromOffset(centre.X - outlineShift, centre.Y - outlineShift)
			else cyanAt
		outlineScale.Scale = if outline then OUTLINE_SCALE else 1
		cyanScale.Scale = if outline then OUTLINE_SCALE else 1
		splitCyan.Visible = figures and (frame.split == true or outline)
		for _, line in lines do
			line.Visible = frame.lines == true
			line.ImageColor3 = frame.ink
		end
		for _, beam in beams do
			beam.Visible = frame.beams == true
			beam.BackgroundColor3 = frame.ink
		end
		slash.Visible = frame.slash == true
		slash.ImageColor3 = frame.ink
		slash.Size = UDim2.fromOffset(reach * 1.5, slashHeight)
		ring.Visible = frame.ring ~= nil
		if frame.ring then
			ring.Size = UDim2.fromOffset(size.Y * frame.ring, size.Y * frame.ring)
			ringStroke.Color = frame.ink
		end
		for _, flare in flares do
			flare.Visible = frame.flares == true
			flare.ImageColor3 = frame.ink
		end
		for _, shard in shards do
			shard.image.Visible = frame.shards == true
			shard.image.ImageColor3 = frame.ink
		end
		showLayers(index)
		glow.Visible = frame.burst == true
		core.Visible = frame.burst == true
		scale.Scale = frame.zoom or 1
		local push = SHAKES[(index - 1) % #SHAKES + 1] * (frame.shake or 0)
		stage.Position = UDim2.fromOffset(centre.X + push.X, centre.Y + push.Y)
	end

	-- What moves INSIDE a card (kits-8c), `p` 0..1 through its hold, `drawn` the frames shown so far.
	local flareBase = {}
	for i, flare in flares do
		flareBase[i] = { size = flare.Size, rotation = flare.Rotation }
	end
	local function animate(index: number, p: number, drawn: number, into: number?, total: number?)
		local frame = spec.frames[index]
		stepLayers(index, into or 0, p)
		if frame.boil and frame.outline then
			local step = BOIL[math.floor((total or 0) * 24) % #BOIL + 1]
			splitRed.Position = UDim2.fromOffset(
				centre.X + outlineShift * step[1],
				centre.Y + outlineShift * step[2]
			)
			splitCyan.Position = UDim2.fromOffset(
				centre.X - outlineShift * step[1],
				centre.Y - outlineShift * step[2]
			)
			outlineScale.Scale = step[3]
			cyanScale.Scale = step[3]
		end
		if frame.lines and frame.closing then
			local turn = LINE_TURNS[math.floor(drawn / 2) % #LINE_TURNS + 1]
			for i in lines do
				placeLine(i, turn, 1 - 0.45 * p)
			end
		elseif frame.lines then
			for i in lines do
				placeLine(i, 0, 1)
			end
		end
		if frame.slash and frame.thinning then
			slash.Size = UDim2.fromOffset(reach * 1.5, slashHeight * (1 - 0.82 * p))
		end
		if frame.shards then
			for _, shard in shards do
				local out = size.Y * (0.1 + 0.85 * p * shard.speed)
				shard.image.Position = UDim2.fromOffset(
					centre.X + math.cos(shard.angle) * out,
					centre.Y + math.sin(shard.angle) * out
				)
			end
		end
		if frame.flares then
			for i, flare in flares do
				local base = flareBase[i]
				local grow = if frame.spin then 1 + 0.15 * p else 1
				flare.Size = UDim2.fromOffset(base.size.X.Offset * grow, base.size.Y.Offset * grow)
				flare.Rotation = base.rotation + (if frame.spin then 25 * p else 0)
			end
		end
		if frame.zoomTo then
			local from = frame.zoom or 1
			scale.Scale = from + (frame.zoomTo - from) * p
		end
	end

	-- Each card is picked by the time since the start (kits-7f): a slow frame skips a card instead of stretching
	-- every one after it, so the run keeps its length at any frame rate.
	local ends: { number } = {}
	local total = 0
	for index, frame in spec.frames do
		total += frame.hold or 1 / 30
		ends[index] = total
	end
	show(1)
	animate(1, 0, 0)
	gui.Parent = player:WaitForChild("PlayerGui")
	local began = os.clock()
	local shown = 1
	local drawn = 0
	while true do
		RunService.RenderStepped:Wait()
		drawn += 1
		local elapsed = (os.clock() - began) / slow
		if elapsed >= total then
			break
		end
		local index = #spec.frames
		for i, finish in ends do
			if elapsed < finish then
				index = i
				break
			end
		end
		if index ~= shown then
			show(index)
			shown = index
		end
		local from = if index > 1 then ends[index - 1] else 0
		local hold = ends[index] - from
		animate(
			index,
			math.clamp((elapsed - from) / math.max(hold, 1e-3), 0, 1),
			drawn,
			elapsed - from,
			elapsed
		)
	end
	gui:Destroy()
end

return ImpactFrame
