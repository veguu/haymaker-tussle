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
}

export type Spec = { frames: { Frame } }

local LINE_COUNT = 64
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
}

function ImpactFrame.prepare(models: { Model }): Prepared
	local worlds: { [string]: WorldModel } = {}
	local colours = { main = Color3.new(0, 0, 0), red = RED, cyan = CYAN }
	for key in colours do
		local world = Instance.new("WorldModel")
		world.Name = key
		worlds[key] = world
	end
	local prepared: Prepared = { worlds = worlds, pairs = {}, inked = {} }
	for _, model in models do
		if model.Parent then
			local live = model:GetDescendants()
			local lists: { [string]: { Instance } } = {}
			for key, colour in colours do
				local was = model.Archivable
				model.Archivable = true
				local copy = model:Clone()
				model.Archivable = was
				if copy then
					-- a clone keeps the descendants' order, so index i here is index i in the live body
					lists[key] = copy:GetDescendants()
					flatten(copy, colour)
					copy.Parent = worlds[key]
				end
			end
			for index, item in live do
				if item:IsA("BasePart") then
					local copies: { BasePart } = {}
					for key, list in lists do
						local twin = list[index]
						if twin and twin.Parent and twin:IsA("BasePart") then
							table.insert(copies, twin)
							if key == "main" then
								table.insert(prepared.inked, twin)
							end
						end
					end
					table.insert(prepared.pairs, { live = item, copies = copies })
				end
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
		local mid = inner + length / 2
		local line = image(stage, Tex.Leaf, 3)
		line.Size = UDim2.fromOffset(
			length,
			if index % 3 == 0 then 64 elseif index % 3 == 1 then 42 else 28
		)
		line.Position =
			UDim2.fromOffset(centre.X + math.cos(angle) * mid, centre.Y + math.sin(angle) * mid)
		line.Rotation = math.deg(angle)
		table.insert(lines, line)
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
	local splitRed = viewportFor(stage, camera, 5)
	splitRed.Position = UDim2.fromOffset(-size.Y * 0.018, size.Y * 0.006)
	local splitCyan = viewportFor(stage, camera, 5)
	splitCyan.Position = UDim2.fromOffset(size.Y * 0.018, -size.Y * 0.006)
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

	-- The copies, posed as the bodies are at the hit; the red and cyan ones never change colour.
	local ready = prepared or ImpactFrame.prepare(models)
	pose(ready)
	ready.worlds.main.Parent = viewport
	ready.worlds.red.Parent = splitRed
	ready.worlds.cyan.Parent = splitCyan
	splitRed.Ambient, splitRed.LightColor = RED, RED
	splitCyan.Ambient, splitCyan.LightColor = CYAN, CYAN

	local lastInk: Color3? = nil
	local function show(index: number)
		local frame = spec.frames[index]
		back.BackgroundColor3 = frame.bg
		local figures = frame.figures ~= false
		if figures and lastInk ~= frame.ink then
			ink(ready, frame.ink, viewport)
			lastInk = frame.ink
		end
		viewport.Visible = figures
		splitRed.Visible = figures and frame.split == true
		splitCyan.Visible = figures and frame.split == true
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
		ring.Visible = frame.ring ~= nil
		if frame.ring then
			ring.Size = UDim2.fromOffset(size.Y * frame.ring, size.Y * frame.ring)
			ringStroke.Color = frame.ink
		end
		for _, flare in flares do
			flare.Visible = frame.flares == true
			flare.ImageColor3 = frame.ink
		end
		glow.Visible = frame.burst == true
		core.Visible = frame.burst == true
		scale.Scale = frame.zoom or 1
		local push = SHAKES[(index - 1) % #SHAKES + 1] * (frame.shake or 0)
		stage.Position = UDim2.fromOffset(centre.X + push.X, centre.Y + push.Y)
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
	gui.Parent = player:WaitForChild("PlayerGui")
	local began = os.clock()
	local shown = 1
	while true do
		RunService.RenderStepped:Wait()
		local elapsed = os.clock() - began
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
	end
	gui:Destroy()
end

return ImpactFrame
