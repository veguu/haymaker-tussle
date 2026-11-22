--!strict
-- FxKit - what every effect in Fx/ shares, so they look like one set: the textures, the tones, the
-- measures and the machinery (pooled rigs of emitters fired in sequence). Decoration on this client
-- only: nothing here can collide, block a ray or affect gameplay.
--
-- THE STYLE (from the frame-by-frame study of twelve reference videos, in the vault under
-- "63 VFX Creation/Reference Study", and the punch hit the user approved as vfx-9):
--   1. A SEQUENCE, not a pile. A one-frame cue first, then the main shape at full size at once, then
--      the layer that shows direction, then sparks, then thin rings and smoke. A layer never grows in
--      and is never thrown again in quick pops.
--   2. PLAIN. Everything is white and grey (the user, 2026-11-14: "dont make the stuff green just
--      make it plain ... this goes for everything"). A layer marked 	int takes a colour only if
--      one is passed in, which nothing does yet. Thin black lines are the only dark, and not on
--      swing trails.
--   3. POINTED SHAPES, PLACED ON PURPOSE. No scatter in a ball: pieces are laid out as the camera sees
--      them, and anything with a direction gets its angle from the move.
--   4. REAL SIZES. H is one character height in studs. A particle is drawn TWICE its Size across
--      (measured in Play), so a ring 2 H wide has Size H.
--   5. SHORT LEFTOVERS. The bright part is over in about a sixth of a second; smoke and rings are
--      gone in about half a second. Smoke is a flipbook.
--
-- HOW AN EFFECT IS BUILT ON IT. `FxKit.pool(name, count, build)` makes `count` rigs, used in turn.
-- `build` gets a folder and an `add` function: each `add` makes one ParticleEmitter (a layer) with how
-- many it throws and how many frames after the start. `FxKit.fire(rig, scale, colour, flags)` throws
-- every layer at its moment. Nothing is created per use.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local FxKit = {}

-- Textures (drawn by design/vfx/draw_hit_replica.ps1). NOT TO BE USED: FloorRing, Crown and Dust. Each is a
-- circle with lines coming out of it, and the user read them as "a drawing of the sun" (2026-11-14).
-- Rings are plain thin circles (Circle).
FxKit.Tex = {
	Blade = "rbxassetid://105381132050037", -- NOT TO BE USED: its green is drawn into it, so it can't be plain
	Needle = "rbxassetid://86599252876072", -- one white spike, tip to the right
	Dome = "rbxassetid://111111021118111", -- the shock bubble
	FloorRing = "rbxassetid://76783207419870", -- thin rings and radial dashes (a ticked ring)
	Crown = "rbxassetid://73916576983471", -- thin rings and tufts pointing outward (a toothed burst)
	Arc = "rbxassetid://92074328735455", -- one thin arc
	Circle = "rbxassetid://75527705961320", -- a circle outline, a thinner one inside
	Glow = "rbxassetid://119052464621710", -- a soft round glow
	Smoke = "rbxassetid://97818702295807", -- flipbook, 4 x 4, a puff fraying into wisps
	-- flipbook, 4 x 4, flat white (design/vfx/smoke/smoke_swirl.py): a wisp curls up into a swirl, splits into
	-- beans and shrinks to dots. Stands upright: its foot is 37.8 % of the image below the image's middle.
	SwirlPuff = "rbxassetid://72521547682766",
	Wisp = "rbxassetid://140573434581662", -- flipbook, 4 x 4, flame tongues rising and fraying
	Dust = "rbxassetid://122673105804911", -- soft streaks fanning out from an empty middle
	Star = "rbxassetid://124927142938107", -- a four-point glint
	Ribbon = "rbxassetid://136226108329170", -- a bright tip edge, thinning streaks (for Trails)
	-- The ability kits' shapes (design/vfx/draw_kit_shapes.ps1, 2026-11-15). All plain white, to be tinted.
	Claw = "rbxassetid://90850328041429", -- a thick crescent pointed at both ends, bulge at the top
	Shard = "rbxassetid://91703865151068", -- an ice crystal standing on the image's centre, pointing up
	Leaf = "rbxassetid://107713021393708", -- a lens pointed at both ends, lying along X, tip to the right
	Pinwheel = "rbxassetid://125971836125924", -- a ring broken into five crescents
	-- the haymaker's impact-frame flipbooks (kits-8e, design/vfx/draw_impact_flipbooks.ps1): 2 x 2 frames of 512 px each
	ImpactLinesA = "", -- rough manga speed lines closing in, frames 1-4
	ImpactLinesB = "", -- and frames 5-8
	ImpactBurst = "", -- a tonal, grainy burst opening out, 4 frames
}

FxKit.WHITE = Color3.new(1, 1, 1)
FxKit.BLACK = Color3.new(0, 0, 0)
FxKit.SMOKE_GREY = Color3.fromRGB(236, 239, 243)
FxKit.PLAIN = Color3.new(1, 1, 1) -- what a tinted layer is when no colour is passed in
FxKit.FRAME = 1 / 60
FxKit.H = 5 -- one character height, in studs
FxKit.BLADE_SIZE = 1.2 -- the Size that draws a blade one stud long
FxKit.QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

local PARK = CFrame.new(0, -1000, 0)
local STILL = NumberRange.new(0)
local FLAT = NumberRange.new(0.01) -- a flat particle needs a direction to lie square to

-- FOR STUDY ONLY: every kit effect plays this many times slower (FxKit.studySlow).
local slow = 1

export type Layer = {
	emitter: ParticleEmitter,
	amount: number,
	delay: number, -- seconds after the start
	size: { NumberSequenceKeypoint }, -- at scale 1
	speed: NumberRange, -- at scale 1
	tinted: boolean, -- takes the effect's colour
	dark: number?, -- how far toward black its colour is taken (0 to 1)
	hot: number?, -- how far toward white it starts (0 to 1)
	flag: string?, -- thrown only when this flag is set for the use
	onFloor: boolean, -- thrown only when there is a floor under the effect
}

export type Options = {
	tint: boolean?,
	dark: number?,
	hot: number?,
	flag: string?,
	onFloor: boolean?,
	speed: NumberRange?,
	flat: boolean?, -- lies flat on its host's top face (a floor layer)
}

export type Add = (
	host: Instance,
	name: string,
	texture: string,
	amount: number,
	delayFrames: number,
	size: { NumberSequenceKeypoint },
	options: Options?
) -> ParticleEmitter

export type Rig = {
	layers: { Layer },
	used: number, -- counts up each use, so a late layer of an old use is dropped
	parts: { [string]: any }, -- whatever `build` returned: parts, attachments, lists
}

export type Pool = {
	take: () -> Rig,
	preload: () -> (),
	folder: () -> Folder?,
}

--- A NumberSequence from pairs: time, value, time, value...
function FxKit.fade(...: number): NumberSequence
	local points = { ... }
	local made = {}
	for index = 1, #points, 2 do
		table.insert(made, NumberSequenceKeypoint.new(points[index], points[index + 1]))
	end
	return NumberSequence.new(made)
end

--- Keypoints from pairs: time, value... (every particle the same).
function FxKit.keys(...: number): { NumberSequenceKeypoint }
	return FxKit.fade(...).Keypoints
end

--- Keypoints from triples: time, value, envelope... The envelope is how far above or below the value
--- one particle may be, so each has its own size.
function FxKit.curve(...: number): { NumberSequenceKeypoint }
	local points = { ... }
	local made = {}
	for index = 1, #points, 3 do
		table.insert(
			made,
			NumberSequenceKeypoint.new(points[index], points[index + 1], points[index + 2])
		)
	end
	return made
end

--- An invisible anchored part that nothing can touch, parked far below until it is used.
function FxKit.hiddenPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = PARK
	part.Parent = parent
	return part
end

--- An attachment on `part` at `position` (in the part's own space).
function FxKit.attach(part: BasePart, position: Vector3?): Attachment
	local made = Instance.new("Attachment")
	if position then
		made.Position = position
	end
	made.Parent = part
	return made
end

--- A pool of `count` rigs named `name`, each made by `build` the first time it is needed.
function FxKit.pool(
	name: string,
	count: number,
	build: (parent: Folder, add: Add) -> { [string]: any }
): Pool
	local rigs: { Rig } = {}
	local nextRig = 1
	local holder: Folder? = nil

	local function make(parent: Folder): Rig
		local layers: { Layer } = {}
		local function add(
			host: Instance,
			layerName: string,
			texture: string,
			amount: number,
			delayFrames: number,
			size: { NumberSequenceKeypoint },
			options: Options?
		): ParticleEmitter
			local made = Instance.new("ParticleEmitter")
			made.Name = layerName
			made.Texture = texture
			made.Rate = 0
			made.Enabled = false
			made.LightEmission = 1
			made.LightInfluence = 0
			made.Color = ColorSequence.new(FxKit.WHITE)
			local flat = options and options.flat
			if flat then
				made.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
				made.EmissionDirection = Enum.NormalId.Top
			end
			made.Parent = host
			table.insert(layers, {
				emitter = made,
				amount = amount,
				delay = delayFrames * FxKit.FRAME,
				size = size,
				speed = (options and options.speed) or (if flat then FLAT else STILL),
				tinted = (options and options.tint) or false,
				dark = options and options.dark,
				hot = options and options.hot,
				flag = options and options.flag,
				onFloor = (options and options.onFloor) or false,
			})
			return made
		end
		local parts = build(parent, add)
		return { layers = layers, used = 0, parts = parts }
	end

	local function take(): Rig
		local parent = holder
		if not parent or parent.Parent == nil then
			local made = Instance.new("Folder")
			made.Name = name
			made.Parent = workspace
			holder = made
			parent = made
			rigs = {}
			nextRig = 1
		end
		local rig = rigs[nextRig]
		if not rig then
			rig = make(parent :: Folder)
			rigs[nextRig] = rig
		end
		nextRig = nextRig % count + 1
		return rig
	end

	return {
		take = take,
		preload = function()
			for _ = 1, count do
				take()
			end
		end,
		folder = function()
			return holder
		end,
	}
end

--- Throws every layer of `rig` at its moment. `scale` multiplies every size and speed, `colour`
--- tints the tinted layers (the hit colour if nil), `flags` switches flagged layers on, and layers
--- marked onFloor are skipped when `hasFloor` is false.
function FxKit.fire(
	rig: Rig,
	scale: number,
	colour: Color3?,
	flags: { [string]: boolean }?,
	hasFloor: boolean?
)
	rig.used += 1
	local use = rig.used
	local base = colour or FxKit.PLAIN
	for _, layer in rig.layers do
		if layer.onFloor and hasFloor == false then
			continue
		end
		if layer.flag and not (flags and flags[layer.flag]) then
			continue
		end
		local emitter = layer.emitter
		if layer.tinted then
			local body = base:Lerp(FxKit.BLACK, layer.dark or 0)
			emitter.Color = if layer.hot
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, body:Lerp(FxKit.WHITE, layer.hot)),
					ColorSequenceKeypoint.new(0.45, body),
					ColorSequenceKeypoint.new(1, body),
				})
				else ColorSequence.new(body)
		end
		local points = table.create(#layer.size)
		for index, point in layer.size do
			points[index] =
				NumberSequenceKeypoint.new(point.Time, point.Value * scale, point.Envelope * scale)
		end
		emitter.Size = NumberSequence.new(points)
		emitter.Speed = NumberRange.new(layer.speed.Min * scale, layer.speed.Max * scale)
		emitter.TimeScale = 1 / slow
		local amount = if layer.amount <= 3
			then layer.amount
			else math.max(1, math.floor(layer.amount * FxKit.QUALITY + 0.5))
		if layer.delay <= 0 then
			emitter:Emit(amount)
		else
			task.delay(layer.delay * slow, function()
				-- Dropped if the rig has been given to a newer use meanwhile.
				if rig.used == use and emitter.Parent then
					emitter:Emit(amount)
				end
			end)
		end
	end
end

--- The floor under `position` within `reach` studs, looking past every fighter and `ignore`.
function FxKit.floorUnder(position: Vector3, reach: number, ignore: { Instance }?): Vector3?
	local skip: { Instance } = CollectionService:GetTagged("HT_Combatant")
	for _, folderName in
		{ "HT_PunchHitFx", "HT_StepBurstFx", "HT_KickHitFx", "HT_ClashFx", "HT_Fx" }
	do
		local found = workspace:FindFirstChild(folderName)
		if found then
			table.insert(skip, found)
		end
	end
	if ignore then
		for _, item in ignore do
			table.insert(skip, item)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	params.IgnoreWater = true
	local hit = workspace:Raycast(position, Vector3.new(0, -reach, 0), params)
	return hit and hit.Position
end

--- A frame at `point` that faces the camera: its +X is the screen's right and its +Y the screen's up.
--- Pieces laid out in it are placed as the camera sees them.
function FxKit.screenAt(point: Vector3): CFrame
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else point + Vector3.zAxis * 20
	local away = point - eye
	return if away.Magnitude > 0.1 then CFrame.lookAt(point, point + away) else CFrame.new(point)
end

--- Which way `way` goes across the screen: right (1) or left (-1).
function FxKit.sideOf(way: Vector3): number
	local camera = workspace.CurrentCamera
	local right = if camera then camera.CFrame.RightVector else Vector3.xAxis
	return if way:Dot(right) >= 0 then 1 else -1
end

--- `direction` flattened to the floor and made a unit vector (+Z if it has no flat part).
function FxKit.flat(direction: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
end

export type Placed = {
	emitter: ParticleEmitter,
	at: Attachment,
	angle: number,
	radius: number,
	aimed: boolean,
}

--- PLACED PIECES: spikes and sparks laid out round a point as the camera sees them, one emitter each
--- on an attachment of `face` (a part turned to the camera for each use, see FxKit.screenAt). Each
--- piece is the plain white needle, pointing straight outward. `specs` is a list of { angle in
--- degrees, how far out its middle sits in studs, Size }. A needle is 2 x Size x 2^-squash long, so
--- a spike whose tail should start at the point sits half its length out. With `aimed`, the angles are
--- measured from the way the move goes and are not turned at random.
function FxKit.placed(
	add: Add,
	face: Part,
	name: string,
	specs: { { number } },
	delayFrames: number,
	squash: number,
	life: NumberRange,
	aimed: boolean?
): { Placed }
	local list: { Placed } = {}
	for index, spec in specs do
		local seat = FxKit.attach(face)
		local big = spec[3]
		local made = add(
			seat,
			name .. index,
			FxKit.Tex.Needle,
			1,
			delayFrames,
			FxKit.keys(0, big, 0.35, big * 0.85, 1, big * 0.15),
			{ tint = true }
		)
		made.Lifetime = life
		made.Squash = NumberSequence.new(squash)
		made.Brightness = 3
		made.ZOffset = 1.2
		made.Transparency = FxKit.fade(0, 0, 0.7, 0.1, 1, 1)
		table.insert(list, {
			emitter = made,
			at = seat,
			angle = spec[1],
			radius = spec[2],
			aimed = aimed == true,
		})
	end
	return list
end

--- Puts placed pieces where they belong for one use: `scale` multiplies how far out they sit,
--- `turned` (degrees) turns the pieces that are not aimed, and `side` (1 or -1, FxKit.sideOf) mirrors
--- the aimed ones when the move goes left across the screen.
function FxKit.arrange(list: { Placed }, scale: number, turned: number, side: number)
	for _, piece in list do
		local angle = if piece.aimed
			then (if side == 1 then piece.angle else 180 - piece.angle)
			else piece.angle + turned
		local radians = math.rad(angle)
		piece.at.Position = Vector3.new(math.cos(radians), math.sin(radians), 0)
			* piece.radius
			* scale
		piece.emitter.Rotation = NumberRange.new(angle - 6, angle + 6)
	end
end

--- FOR STUDY ONLY: every kit effect plays `factor` times slower after this (1 puts it back).
function FxKit.studySlow(factor: number)
	slow = math.max(factor, 1)
end

--- The study slow-down in force (1 in play).
function FxKit.slowness(): number
	return slow
end

return FxKit
