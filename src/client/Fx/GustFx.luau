--!strict
-- GustFx - the flat shapes of the Gustline style (design/VFX Style.md): the gust crescent, the gust
-- ring and the floor scuff. Each is a thin invisible plate with the shape's image on both faces, moved,
-- turned, grown and faded here. Decoration on this client only: nothing here can collide, block a ray
-- or affect gameplay.
--
-- HOW IT'S BUILT. A pool of plates, made on first use and reused: a plate is one Part with a SurfaceGui
-- on its top and bottom face, each holding a base image and an accent image over it. Showing a shape
-- sets the images and colours on the next free plate; one Heartbeat connection runs every live plate
-- and disconnects when none is showing. Nothing is created per effect once the pool is warm.
--
-- A PLATE'S FRAME. The image lies flat in the plate. `head` is the way the shape's leading end points
-- (a crescent's thick end; a ring's thick side) and `bulge` the way a crescent's curve bows out. The
-- plate turns about its own normal: a crescent sweeps in tail first (`sweepDegrees` over
-- `sweepSeconds`) and drifts on a little as it goes (`driftDegrees`), so it never sits still.
--
-- FADING. Hard shapes hold, then break up in steps (the style's habit); `smooth` fades evenly, for
-- scuffs and soft things.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GustStyle = require(ReplicatedStorage.Shared.Config.GustStyle)

local GustFx = {}

-- "glow" is the crescent as light: a soft-edged white arc, tinted and laid over itself in several
-- see-through layers by GustBurst.swing.
export type Shape = "crescent" | "ring" | "scuff" | "glow"

export type Options = {
	shape: Shape,
	at: Vector3, -- the plate's centre
	head: Vector3, -- where the leading end points (need not be exact: it's squared up against bulge)
	bulge: Vector3, -- which way the curve bows; with head, this sets the plate's plane
	size: number, -- studs across when it appears
	grow: number?, -- how many times that size by the end (default 1.15)
	hold: number, -- seconds fully shown
	fade: number, -- seconds to go after that
	delay: number?, -- seconds before it appears
	accent: Color3?, -- a kit's accent: shows the accent layer in this colour
	tint: Color3?, -- colour of the base image (white leaves it as drawn; scuffs default to Ink)
	transparency: number?, -- how see-through it starts (default 0)
	smooth: boolean?, -- fade evenly; otherwise in steps
	brightness: number?, -- how strongly it shines (1 is as drawn; glow layers use more)
	sweepDegrees: number?, -- starts turned back this far and sweeps in
	sweepSeconds: number?,
	driftDegrees: number?, -- turns on this far over its whole life
	follow: BasePart?, -- keeps its place relative to this part (a swing stays with its fighter)
}

type Face = { gui: SurfaceGui, base: ImageLabel, accent: ImageLabel }

type Plate = {
	part: Part,
	faces: { Face },
	live: boolean,
	startAt: number,
	options: Options,
	frame: CFrame, -- where it sits: in the world, or relative to `follow`
	shown: number, -- the transparency last written, so the images are only touched when it changes
}

local PARK = CFrame.new(0, -1000, 0)
local THICKNESS = 0.05
local PIXELS = 256
-- A swing is four or five plates at once (GustBurst.swing), and a full round has many fighters
-- swinging, so the pool is sized for that.
local POOL = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 28
	else 72
-- A hard shape breaks up in these steps of its fade rather than fading evenly.
local STEPS = { 0.4, 0.7, 1 }

local IMAGES: { [Shape]: { base: string, accent: string? } } = {
	crescent = { base = GustStyle.Images.CrescentBase, accent = GustStyle.Images.CrescentAccent },
	ring = { base = GustStyle.Images.RingBase, accent = GustStyle.Images.RingAccent },
	scuff = { base = GustStyle.Images.Scuff },
	glow = { base = GustStyle.Images.CrescentGlow },
}

local holder: Folder? = nil
local plates: { Plate } = {}
local nextPlate = 1
local running: RBXScriptConnection? = nil
local preloaded = false

local function buildFace(part: Part, face: Enum.NormalId): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HT_Gust"
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(PIXELS, PIXELS)
	gui.ResetOnSpawn = false
	local base = Instance.new("ImageLabel")
	base.Name = "Base"
	base.BackgroundTransparency = 1
	base.Size = UDim2.fromScale(1, 1)
	base.Parent = gui
	local accent = Instance.new("ImageLabel")
	accent.Name = "Accent"
	accent.BackgroundTransparency = 1
	accent.Size = UDim2.fromScale(1, 1)
	accent.ZIndex = 2
	accent.Visible = false
	accent.Parent = gui
	gui.Parent = part
	return { gui = gui, base = base, accent = accent }
end

local function buildPlate(parent: Instance): Plate
	local part = Instance.new("Part")
	part.Name = "HT_GustPlate"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, THICKNESS, 1)
	part.CFrame = PARK
	local faces = { buildFace(part, Enum.NormalId.Top), buildFace(part, Enum.NormalId.Bottom) }
	part.Parent = parent
	return {
		part = part,
		faces = faces,
		live = false,
		startAt = 0,
		options = nil :: any,
		frame = PARK,
		shown = -1,
	}
end

local function takePlate(): Plate
	local parent = holder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_GustFx"
		made.Parent = workspace
		holder = made
		parent = made
		plates = {}
		nextPlate = 1
	end
	-- The next one in turn. If every plate is busy, the oldest is taken over.
	local plate = plates[nextPlate]
	if not plate then
		plate = buildPlate(parent :: Folder)
		plates[nextPlate] = plate
	end
	nextPlate = nextPlate % POOL + 1
	return plate
end

local function setTransparency(plate: Plate, value: number)
	if plate.shown == value then
		return
	end
	plate.shown = value
	for _, face in plate.faces do
		face.base.ImageTransparency = value
		face.accent.ImageTransparency = value
	end
end

local function easeOut(share: number): number
	local left = 1 - math.clamp(share, 0, 1)
	return 1 - left * left
end

-- One frame of one plate. Returns false when it has finished.
local function step(plate: Plate, now: number): boolean
	local options = plate.options
	local age = now - plate.startAt
	if age < 0 then
		return true -- still waiting out its delay, parked
	end
	local life = options.hold + options.fade
	if age >= life or (options.follow and options.follow.Parent == nil) then
		return false
	end
	local share = age / life

	local start = options.transparency or 0
	if age <= options.hold then
		setTransparency(plate, start)
	else
		local gone = (age - options.hold) / math.max(options.fade, 0.001)
		if not options.smooth then
			for _, edge in STEPS do
				if gone <= edge then
					gone = edge - (STEPS[1] - 0.05)
					break
				end
			end
		end
		setTransparency(plate, start + (1 - start) * math.clamp(gone, 0, 0.97))
	end

	local size = options.size * (1 + ((options.grow or 1.15) - 1) * easeOut(share))
	plate.part.Size = Vector3.new(size, THICKNESS, size)

	local swept = 1
	if options.sweepDegrees and (options.sweepSeconds or 0) > 0 then
		swept = easeOut(age / (options.sweepSeconds :: number))
	end
	local turn = -(options.sweepDegrees or 0) * (1 - swept) + (options.driftDegrees or 0) * share
	local frame = if options.follow then options.follow.CFrame * plate.frame else plate.frame
	plate.part.CFrame = frame * CFrame.Angles(0, math.rad(turn), 0)
	return true
end

local function run()
	if running then
		return
	end
	running = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local any = false
		for _, plate in plates do
			if plate.live then
				if step(plate, now) then
					any = true
				else
					plate.live = false
					plate.part.CFrame = PARK
				end
			end
		end
		if not any and running then
			running:Disconnect()
			running = nil
		end
	end)
end

--- Loads the style's textures ahead of the first fight, so the first shape isn't blank.
function GustFx.preload()
	if preloaded then
		return
	end
	preloaded = true
	local list = {}
	for _, image in GustStyle.Images :: any do
		table.insert(list, image)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

--- Shows one flat shape. See Options.
function GustFx.show(options: Options)
	local head, bulge = options.head, options.bulge
	if head.Magnitude < 0.01 or bulge.Magnitude < 0.01 then
		return
	end
	bulge = bulge.Unit
	-- Square the head up against the bulge, so the two only have to be roughly right.
	head = head - bulge * head:Dot(bulge)
	if head.Magnitude < 0.01 then
		return
	end
	head = head.Unit
	-- The image's right is the plate's front and its down is the plate's right (measured in Studio,
	-- 2026-11-13), so: front = head, right = bulge.
	local world = CFrame.fromMatrix(options.at, bulge, bulge:Cross(head))

	local plate = takePlate()
	local images = IMAGES[options.shape]
	local tint = options.tint
		or (if options.shape == "scuff" then GustStyle.Ink else GustStyle.Core)
	for _, face in plate.faces do
		face.gui.Brightness = options.brightness or 1
		face.base.Image = images.base
		face.base.ImageColor3 = tint
		local accent = options.accent and images.accent
		face.accent.Visible = accent ~= nil
		if accent and options.accent then
			face.accent.Image = accent
			face.accent.ImageColor3 = options.accent
		end
	end
	plate.options = options
	plate.frame = if options.follow then options.follow.CFrame:ToObjectSpace(world) else world
	plate.startAt = os.clock() + (options.delay or 0)
	plate.shown = -1
	plate.part.Size = Vector3.new(options.size, THICKNESS, options.size)
	plate.part.CFrame = PARK
	plate.live = true
	run()
end

--- A gust ring lying on the floor at `at`, thick side toward `from` (where the force came from).
function GustFx.floorRing(
	at: Vector3,
	from: Vector3,
	size: number,
	grow: number,
	seconds: number,
	accent: Color3?
)
	local flat = Vector3.new(from.X, 0, from.Z)
	local head = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
	GustFx.show({
		shape = "ring",
		at = at + Vector3.yAxis * 0.12,
		head = head,
		bulge = Vector3.new(-head.Z, 0, head.X),
		size = size,
		grow = grow,
		hold = seconds * 0.45,
		fade = seconds * 0.55,
		accent = accent,
		driftDegrees = 40,
	})
end

--- A gust ring standing upright at `at`, facing along `travel`: what a dash or a blink leaves.
function GustFx.airRing(
	at: Vector3,
	travel: Vector3,
	size: number,
	grow: number,
	seconds: number,
	accent: Color3?
)
	if travel.Magnitude < 0.01 then
		return
	end
	local forward = travel.Unit
	local side = forward:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	side = side.Unit
	GustFx.show({
		shape = "ring",
		at = at,
		head = side:Cross(forward), -- up: the thick side on top
		bulge = side,
		size = size,
		grow = grow,
		hold = seconds * 0.4,
		fade = seconds * 0.6,
		accent = accent,
		driftDegrees = 60,
	})
end

--- An ink scuff left on the floor at `at`: broken arcs and cracks that stay a moment after the rest.
function GustFx.scuff(at: Vector3, size: number, seconds: number, turn: number?)
	local angle = turn or (os.clock() * 7 % (math.pi * 2))
	local head = Vector3.new(math.cos(angle), 0, math.sin(angle))
	GustFx.show({
		shape = "scuff",
		at = at + Vector3.yAxis * 0.08,
		head = head,
		bulge = Vector3.new(-head.Z, 0, head.X),
		size = size,
		grow = 1.04,
		hold = seconds * 0.5,
		fade = seconds * 0.5,
		transparency = 0.25,
		smooth = true,
	})
end

return GustFx
