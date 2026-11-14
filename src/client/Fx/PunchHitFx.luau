--!strict
-- PunchHitFx - a landed punch, as a replica of the first hit in Venomec's "Mumen Rider Combo"
-- (YouTube 3R5WsLDp2f4, 2.28 s to 2.65 s, read frame by frame at 60 fps). All particles. Decoration on
-- this client only: nothing here can collide, block a ray or affect gameplay.
--
-- THE HIT, frame by frame (1 f = 1/60 s):
--   0 f   a white-hot core with a star of sharp spikes all round it; a white ring on the floor
--   1 f   a band of long thin lines shot the way the hit sends them, black lines among them; a soft
--         white bubble swelling round the one hit
--   4 f   the lines thin out and go; small needles fly off
--   6 f   coloured haze over the one hit, thin white arcs turning round them, smoke along the floor
--   20 f  only smoke and the arcs are left, fading
--
-- HOW IT'S BUILT. A few rigs made once and used in turn (three invisible anchored parts each, with
-- their emitters). A hit moves the next rig to the spot and tells each emitter to throw a fixed number
-- of particles at its moment. Nothing is created per punch. Textures: design/vfx/draw_hit_replica.ps1.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local PunchHitFx = {}

local NEEDLE = "rbxassetid://104578885010671" -- hit_needle.png: one spike, tip to the right
local DOME = "rbxassetid://111111021118111" -- hit_dome.png: the shock bubble
local FLOOR_RING = "rbxassetid://76783207419870" -- hit_floor.png: thin rings and radial dashes
local ARC = "rbxassetid://92074328735455" -- hit_arc.png: one thin arc
local CIRCLE = "rbxassetid://75527705961320" -- hit_circle.png: a circle outline, a thinner one inside
local GLOW = "rbxassetid://119052464621710" -- glow_soft.png: a soft round glow
local SMOKE = "rbxassetid://97818702295807" -- hit_smoke.png: flipbook, 4 x 4, a puff fraying into wisps

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SMOKE_GREY = Color3.fromRGB(236, 239, 243)
local GREEN = Color3.fromRGB(50, 255, 60) -- the reference's colour
local PARK = CFrame.new(0, -1000, 0)
local FRAME = 1 / 60
local RIGS = 6
local BURST_SIZE = Vector3.new(2.4, 2.4, 2.4)
local LINES_SIZE = Vector3.new(2.2, 3, 0.2)
local FLOOR_REACH = 9 -- how far under the hit a floor is looked for
local QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

-- One layer: its emitter, how many it throws, when, and what changes with the hit's size and colour.
type Layer = {
	emitter: ParticleEmitter,
	amount: number,
	delay: number,
	tinted: boolean, -- takes the hit's colour
	size: { NumberSequenceKeypoint }, -- at scale 1
	speed: NumberRange, -- at scale 1
	onFloor: boolean,
	heavy: boolean?, -- only on a heavy hit
	again: number?, -- thrown this many more times after the first
	every: number?, -- seconds between those
}

type Rig = {
	burst: Part,
	center: Part,
	lines: Part,
	floor: Part,
	layers: { Layer },
	used: number, -- counts up each time the rig is used, so a late layer of an old hit is dropped
}

local rigs: { Rig } = {}
local nextRig = 1
local holder: Folder? = nil

local function hiddenPart(name: string, size: Vector3, parent: Instance): Part
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

local function fade(...: number): NumberSequence
	local points = { ... }
	local keys = {}
	for index = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[index], points[index + 1]))
	end
	return NumberSequence.new(keys)
end

local function keys(...: number): { NumberSequenceKeypoint }
	return fade(...).Keypoints
end

local function buildRig(parent: Instance): Rig
	local center = hiddenPart("HT_PunchHit", Vector3.new(0.2, 0.2, 0.2), parent)
	-- The lines leave the whole of this part's front face, so they come as a band, not from a point.
	local lines = hiddenPart("HT_PunchHitLines", LINES_SIZE, parent)
	local floor = hiddenPart("HT_PunchHitFloor", Vector3.new(7, 0.2, 7), parent)
	-- The spikes leave the surface of this ball, straight outward, so their bases meet at the contact.
	local burst = hiddenPart("HT_PunchHitBurst", BURST_SIZE, parent)
	local at = Instance.new("Attachment")
	at.Parent = center
	-- On the one hit, a little past the point of contact.
	local body = Instance.new("Attachment")
	body.Position = Vector3.new(0, 0.3, -1.4)
	body.Parent = center
	-- Over the head of the one hit.
	local above = Instance.new("Attachment")
	above.Position = Vector3.new(0, 1.6, -1.4)
	above.Parent = center
	local ground = Instance.new("Attachment")
	ground.Position = Vector3.new(0, 0.15, 0)
	ground.Parent = floor

	local layers: { Layer } = {}
	local function layer(
		host: Instance,
		name: string,
		texture: string,
		amount: number,
		delayFrames: number,
		tinted: boolean,
		size: { NumberSequenceKeypoint },
		speed: NumberRange
	): ParticleEmitter
		local made = Instance.new("ParticleEmitter")
		made.Name = name
		made.Texture = texture
		made.Rate = 0
		made.Enabled = false
		made.LightEmission = 1
		made.LightInfluence = 0
		made.Color = ColorSequence.new(WHITE)
		made.Parent = host
		table.insert(layers, {
			emitter = made,
			amount = amount,
			delay = delayFrames * FRAME,
			tinted = tinted,
			size = size,
			speed = speed,
			onFloor = host == floor or host == ground,
		})
		return made
	end

	-- 0 f. The white-hot core: there for three frames.
	local core = layer(at, "Core", GLOW, 1, 0, false, keys(0, 2.8, 1, 1.2), NumberRange.new(0))
	core.Lifetime = NumberRange.new(0.09)
	core.Brightness = 3
	core.ZOffset = 1.5
	core.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)

	-- 0 f. The colour round the core.
	local halo = layer(at, "Halo", GLOW, 1, 0, true, keys(0, 5, 1, 4), NumberRange.new(0))
	halo.Lifetime = NumberRange.new(0.1)
	halo.Brightness = 1
	halo.LightEmission = 0.5
	halo.ZOffset = 0.5
	halo.Transparency = fade(0, 0.55, 0.5, 0.75, 1, 1)

	-- 0 f. The star: sharp spikes all round, long at first, shrinking as they fly out.
	local spikes = layer(
		burst,
		"Spikes",
		NEEDLE,
		18,
		0,
		true,
		keys(0, 9, 0.5, 5, 1, 1.5),
		NumberRange.new(8, 26)
	)
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Shape = Enum.ParticleEmitterShape.Sphere
	spikes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	spikes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	spikes.Lifetime = NumberRange.new(0.09, 0.13)
	spikes.Brightness = 1.3
	spikes.LightEmission = 0.55
	spikes.Squash = NumberSequence.new(0.4)
	spikes.ZOffset = 1
	spikes.Transparency = fade(0, 0, 0.75, 0.1, 1, 1)

	-- 0 f. A few spikes far longer than the rest.
	local longSpikes =
		layer(burst, "LongSpikes", NEEDLE, 4, 0, true, keys(0, 6.5, 1, 3), NumberRange.new(10, 20))
	longSpikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	longSpikes.Shape = Enum.ParticleEmitterShape.Sphere
	longSpikes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	longSpikes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	longSpikes.Lifetime = NumberRange.new(0.05, 0.07)
	longSpikes.Brightness = 1.5
	longSpikes.LightEmission = 0.55
	longSpikes.Squash = NumberSequence.new(-0.5)
	longSpikes.ZOffset = 1
	longSpikes.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)

	-- 1 f. The band of long lines shot the way of the hit, thinning as they go.
	local band =
		layer(lines, "Lines", NEEDLE, 14, 1, true, keys(0, 5.4, 1, 5.4), NumberRange.new(70, 120))
	band.Orientation = Enum.ParticleOrientation.VelocityParallel
	band.EmissionDirection = Enum.NormalId.Front
	band.Lifetime = NumberRange.new(0.06, 0.1)
	band.Brightness = 1.6
	band.LightEmission = 0.6
	band.Squash = NumberSequence.new(-1.26)
	band.Transparency = fade(0, 0, 0.6, 0.05, 1, 1)

	-- 1 f. Black lines among them, which outlast them by a few frames.
	local dark = layer(
		lines,
		"DarkLines",
		NEEDLE,
		7,
		1,
		false,
		keys(0, 3.3, 1, 3.3),
		NumberRange.new(40, 70)
	)
	dark.Orientation = Enum.ParticleOrientation.VelocityParallel
	dark.EmissionDirection = Enum.NormalId.Front
	dark.Color = ColorSequence.new(BLACK)
	dark.LightEmission = 0
	dark.Squash = NumberSequence.new(-1.6)
	dark.Lifetime = NumberRange.new(0.1, 0.15)
	dark.Transparency = fade(0, 0.1, 0.7, 0.2, 1, 1)

	-- 1 f. The shock bubble round the one hit.
	local dome =
		layer(body, "Dome", DOME, 1, 1, false, keys(0, 5, 0.4, 8, 1, 9.5), NumberRange.new(0))
	dome.Lifetime = NumberRange.new(0.13)
	dome.Rotation = NumberRange.new(0, 360)
	dome.LightEmission = 0.7
	dome.Transparency = fade(0, 0.5, 0.5, 0.7, 1, 1)

	-- 0 f. The ring racing out along the floor.
	local ring = layer(
		ground,
		"FloorRing",
		FLOOR_RING,
		1,
		0,
		false,
		keys(0, 3, 0.3, 6.5, 1, 8),
		NumberRange.new(0.01)
	)
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Lifetime = NumberRange.new(0.2)
	ring.Rotation = NumberRange.new(0, 360)
	ring.LightEmission = 0.8
	ring.Brightness = 1
	ring.Transparency = fade(0, 0, 0.5, 0.35, 1, 1)

	-- 4 f. Small needles flying off.
	local sparks =
		layer(burst, "Sparks", NEEDLE, 9, 4, true, keys(0, 0.9, 1, 0.3), NumberRange.new(35, 70))
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.Lifetime = NumberRange.new(0.1, 0.2)
	sparks.Squash = NumberSequence.new(-0.8)
	sparks.Drag = 5
	sparks.Brightness = 2
	sparks.LightEmission = 0.6
	sparks.Transparency = fade(0, 0, 0.8, 0.1, 1, 1)

	-- 5 f. Coloured haze over the one hit.
	local haze =
		layer(above, "Haze", SMOKE, 5, 5, true, keys(0, 3.2, 1, 5.5), NumberRange.new(1.5, 5))
	haze.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	haze.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	haze.EmissionDirection = Enum.NormalId.Top
	haze.SpreadAngle = Vector2.new(70, 70)
	haze.Lifetime = NumberRange.new(0.12, 0.18)
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-50, 50)
	haze.LightEmission = 0.5
	haze.Transparency = fade(0, 0.55, 0.5, 0.7, 1, 1)

	-- 6 f. Thin white arcs turning round the one hit.
	local arcs = layer(body, "Arcs", ARC, 2, 6, false, keys(0, 4.6, 1, 6.2), NumberRange.new(0))
	arcs.Lifetime = NumberRange.new(0.34, 0.44)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.RotSpeed = NumberRange.new(-140, 140)
	arcs.LightEmission = 0.7
	arcs.Brightness = 2
	arcs.Transparency = fade(0, 0.15, 0.6, 0.4, 1, 1)

	-- 5 f. Smoke along the floor, left behind after the light has gone.
	local smoke = layer(
		floor,
		"FloorSmoke",
		SMOKE,
		16,
		5,
		false,
		keys(0, 3, 1, 5.5),
		NumberRange.new(0.5, 2.5)
	)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(80, 80)
	smoke.Color = ColorSequence.new(SMOKE_GREY)
	smoke.LightEmission = 0.3
	smoke.Lifetime = NumberRange.new(0.5, 0.8)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Drag = 2
	smoke.Transparency = fade(0, 0.2, 0.5, 0.45, 1, 1)

	-- THE HEAVY HIT (the reference's third hit, 3.53 s to 4.0 s): everything above, bigger, and these.
	-- The star and the lines are thrown again every two frames for 0.4 s, so the hit holds.
	local function heavyOnly(again: number?, everyFrames: number?)
		local last = layers[#layers]
		last.heavy = true
		last.again = again
		last.every = if everyFrames then everyFrames * FRAME else nil
	end

	local hold =
		layer(burst, "Hold", NEEDLE, 5, 3, true, keys(0, 7.5, 1, 3), NumberRange.new(6, 18))
	heavyOnly(11, 2)
	hold.Orientation = Enum.ParticleOrientation.VelocityParallel
	hold.Shape = Enum.ParticleEmitterShape.Sphere
	hold.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	hold.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	hold.Lifetime = NumberRange.new(0.07, 0.1)
	hold.Brightness = 1.3
	hold.LightEmission = 0.55
	hold.Squash = NumberSequence.new(-0.2)
	hold.ZOffset = 1
	hold.Transparency = fade(0, 0, 0.7, 0.15, 1, 1)

	local holdLines =
		layer(lines, "HoldLines", NEEDLE, 3, 3, true, keys(0, 3.6, 1, 3.6), NumberRange.new(40, 70))
	heavyOnly(11, 2)
	holdLines.Orientation = Enum.ParticleOrientation.VelocityParallel
	holdLines.EmissionDirection = Enum.NormalId.Front
	holdLines.Lifetime = NumberRange.new(0.05, 0.08)
	holdLines.Brightness = 1.6
	holdLines.LightEmission = 0.6
	holdLines.Squash = NumberSequence.new(-1.1)
	holdLines.Transparency = fade(0, 0, 0.6, 0.05, 1, 1)

	-- 1 f. A tall soft white column rising over the one hit.
	local column =
		layer(above, "Column", GLOW, 2, 1, false, keys(0, 3.5, 1, 5), NumberRange.new(1, 3))
	heavyOnly()
	column.EmissionDirection = Enum.NormalId.Top
	column.Lifetime = NumberRange.new(0.4, 0.5)
	column.LightEmission = 0.4
	column.Squash = NumberSequence.new(1)
	column.Transparency = fade(0, 0.8, 0.6, 0.88, 1, 1)

	-- 16 f. A white circle left where the star was.
	local circle =
		layer(body, "Circle", CIRCLE, 1, 16, false, keys(0, 3.6, 1, 4.4), NumberRange.new(0))
	heavyOnly()
	circle.Lifetime = NumberRange.new(0.3)
	circle.LightEmission = 0.7
	circle.Brightness = 1
	circle.Transparency = fade(0, 0.3, 0.6, 0.5, 1, 1)

	-- 22 f. More thin arcs, taller, turning round them as it dies away.
	local lateArcs =
		layer(body, "LateArcs", ARC, 2, 22, false, keys(0, 4, 1, 6), NumberRange.new(0))
	heavyOnly()
	lateArcs.Lifetime = NumberRange.new(0.35, 0.5)
	lateArcs.Rotation = NumberRange.new(0, 360)
	lateArcs.RotSpeed = NumberRange.new(-160, 160)
	lateArcs.LightEmission = 0.7
	lateArcs.Brightness = 2
	lateArcs.Squash = NumberSequence.new(0.5) -- taller than wide
	lateArcs.Transparency = fade(0, 0.15, 0.6, 0.4, 1, 1)

	return {
		burst = burst,
		center = center,
		lines = lines,
		floor = floor,
		layers = layers,
		used = 0,
	}
end

local function takeRig(): Rig
	local parent = holder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_PunchHitFx"
		made.Parent = workspace
		holder = made
		parent = made
		rigs = {}
		nextRig = 1
	end
	local rig = rigs[nextRig]
	if not rig then
		rig = buildRig(parent :: Folder)
		rigs[nextRig] = rig
	end
	nextRig = nextRig % RIGS + 1
	return rig
end

-- The floor under a point, ignoring fighters and this module's own parts.
local function floorUnder(position: Vector3): Vector3?
	local ignore: { Instance } = CollectionService:GetTagged("HT_Combatant")
	if holder then
		table.insert(ignore, holder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local hit = workspace:Raycast(position, Vector3.new(0, -FLOOR_REACH, 0), params)
	return hit and hit.Position
end

local function scaled(points: { NumberSequenceKeypoint }, scale: number): NumberSequence
	local out = table.create(#points)
	for index, point in points do
		out[index] = NumberSequenceKeypoint.new(point.Time, point.Value * scale)
	end
	return NumberSequence.new(out)
end

--- A landed punch at `position`, sending them along `direction`. `scale` is its size against an
--- ordinary punch (1). `colour` tints the coloured layers; without it they're the reference's green.
--- `heavy` adds the heavy hit's layers: a quarter bigger, held for 0.4 s, with a column and a circle.
function PunchHitFx.play(
	position: Vector3,
	direction: Vector3,
	size: number,
	colour: Color3?,
	heavy: boolean?
)
	local scale = if heavy then size * 1.25 else size
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local way = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local rig = takeRig()
	rig.used += 1
	local use = rig.used
	local tint = ColorSequence.new(colour or GREEN)
	local floorAt = floorUnder(position)

	rig.center.CFrame = CFrame.lookAt(position, position + way)
	-- The lines are as long as they are fast, so their source sits half a line ahead of the contact.
	rig.burst.CFrame = CFrame.new(position)
	rig.burst.Size = BURST_SIZE * scale
	rig.lines.CFrame = CFrame.lookAt(position + way * 8 * scale, position + way * 9 * scale)
	rig.lines.Size = LINES_SIZE * scale
	if floorAt then
		rig.floor.CFrame = CFrame.new(floorAt + way * 1.2 * scale)
		rig.floor.Size = Vector3.new(7 * scale, 0.2, 7 * scale)
	end

	for _, layer in rig.layers do
		if (layer.onFloor and not floorAt) or (layer.heavy and not heavy) then
			continue
		end
		local emitter = layer.emitter
		if layer.tinted then
			emitter.Color = tint
		end
		emitter.Size = scaled(layer.size, scale)
		emitter.Speed = NumberRange.new(layer.speed.Min * scale, layer.speed.Max * scale)
		local amount = if layer.amount <= 2
			then layer.amount
			else math.max(1, math.floor(layer.amount * QUALITY + 0.5))
		local function fire()
			-- Dropped if the rig has been moved to a newer hit meanwhile.
			if rig.used == use and emitter.Parent then
				emitter:Emit(amount)
			end
		end
		if layer.delay <= 0 then
			fire()
		else
			task.delay(layer.delay, fire)
		end
		for extra = 1, layer.again or 0 do
			task.delay(layer.delay + extra * (layer.every or FRAME), fire)
		end
	end
end

--- Builds every rig ahead of the first hit, so the textures are loaded by then.
function PunchHitFx.preload()
	for _ = 1, RIGS do
		takeRig()
	end
end

return PunchHitFx
