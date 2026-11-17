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
	hold: number?, -- seconds to hold it (default 1/30)
}

export type Spec = { frames: { Frame } }

local LINE_COUNT = 64
local RED = Color3.fromRGB(255, 40, 70)
local CYAN = Color3.fromRGB(40, 230, 255)
-- The direction each frame's shake pushes, in turn.
local SHAKES =
	{ Vector2.new(1, -0.6), Vector2.new(-0.8, 0.9), Vector2.new(0.5, 1), Vector2.new(-1, -0.4) }

-- Flat copies of these fighters in `viewport`, every part one colour.
local function silhouettes(models: { Model }, colour: Color3, viewport: ViewportFrame)
	viewport:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	for _, model in models do
		if model.Parent then
			local was = model.Archivable
			model.Archivable = true
			local copy = model:Clone()
			model.Archivable = was
			if copy then
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
					then
						item:Destroy()
					end
				end
				copy.Parent = world
			end
		end
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
--- once it is over (it yields for its length).
function ImpactFrame.play(spec: Spec, at: Vector3, models: { Model })
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	if not camera or not player then
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(at)
	local size = camera.ViewportSize
	local centre = if onScreen and screen.Z > 0
		then Vector2.new(screen.X, screen.Y)
		else Vector2.new(size.X / 2, size.Y / 2)
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

	-- The red and cyan copies never change colour: drawn once.
	silhouettes(models, RED, splitRed)
	silhouettes(models, CYAN, splitCyan)
	gui.Parent = player:WaitForChild("PlayerGui")

	local lastInk: Color3? = nil
	for index, frame in spec.frames do
		back.BackgroundColor3 = frame.bg
		local figures = frame.figures ~= false
		if figures and lastInk ~= frame.ink then
			silhouettes(models, frame.ink, viewport)
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
		local untilAt = os.clock() + (frame.hold or 1 / 30)
		repeat
			RunService.RenderStepped:Wait()
		until os.clock() >= untilAt
	end
	gui:Destroy()
end

return ImpactFrame
