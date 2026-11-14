--!strict
-- GustBurst - the glowing, layered effects of the Gustline style (design/VFX Style.md): a hit, a swing's
-- crescent, and a gust ring. Each is MANY see-through additive particle layers stacked, every one
-- changing size and turning over its short life, with one or two solid ink pieces among them for
-- contrast. That stacking is what makes them read as light. Decoration on this client only: nothing
-- here can collide, block a ray or affect gameplay.
--
-- HOW IT'S BUILT. Three small pools of rigs (hit, swing, ring), made on first use and used in turn. A
-- rig is one invisible anchored part with an attachment and a fixed set of emitters; an effect moves
-- the next rig to the spot, sets what varies (size, colour, turn) and tells each emitter to throw a
-- fixed number of particles. Nothing is created per effect once the pools are warm.
--
-- FLAT PARTICLES. A layer that has to lie in a plane (a crescent, a floor ring) uses
-- Orientation = VelocityPerpendicular with a tiny speed along the rig's up. Measured in Studio
-- (2026-11-13) for emission along +Y at Rotation 0: the crescent texture's head points along the
-- rig's -X and its curve bows toward +Z; a positive Rotation or RotSpeed turns it clockwise seen from
-- above, which is the way the head leads. So a rig laid out as fromMatrix(at, -head, head x bulge)
-- puts the head and the bow where they're asked for, and a crescent sweeps in by starting at a
-- negative Rotation with a positive RotSpeed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GustStyle = require(ReplicatedStorage.Shared.Config.GustStyle)
local GustFx = require(script.Parent.GustFx)

local GustBurst = {}

local IMAGES = GustStyle.Images
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)
local PARK = CFrame.new(0, -1000, 0)
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local QUALITY = if TOUCH then 0.55 else 1
local FLAT_SPEED = NumberRange.new(0.02)

local holder: Folder? = nil

local function folder(): Folder
	local parent = holder
	if not parent or parent.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "HT_GustBurst"
		made.Parent = workspace
		holder = made
		return made
	end
	return parent
end

local function rigPart(name: string): (Part, Attachment)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = PARK
	local at = Instance.new("Attachment")
	at.Parent = part
	return part, at
end

-- One layer. `glow` 1 is fully additive (light), 0 is drawn as it is (the solid ink pieces, smoke).
local function layer(parent: Instance, name: string, texture: string, glow: number): ParticleEmitter
	local made = Instance.new("ParticleEmitter")
	made.Name = name
	made.Texture = texture
	made.Rate = 0
	made.Enabled = false
	made.LightEmission = glow
	made.LightInfluence = 0
	made.EmissionDirection = Enum.NormalId.Top
	made.Parent = parent
	return made
end

-- A layer lying flat in the rig's plane.
local function flat(parent: Instance, name: string, texture: string, glow: number): ParticleEmitter
	local made = layer(parent, name, texture, glow)
	made.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	made.Speed = FLAT_SPEED
	return made
end

local function fade(from: number, holdUntil: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, from),
		NumberSequenceKeypoint.new(holdUntil, from + (1 - from) * 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function grow(from: number, to: number): NumberSequence
	-- Fast at first, settling: most of the change is in the first third.
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, from),
		NumberSequenceKeypoint.new(0.3, from + (to - from) * 0.7),
		NumberSequenceKeypoint.new(1, to),
	})
end

local function count(amount: number): number
	return math.max(1, math.floor(amount * QUALITY + 0.5))
end

local function shade(a: Color3, b: Color3): ColorSequence
	return ColorSequence.new(a, b)
end

-- THE HIT ---------------------------------------------------------------------------------------------
-- Fourteen layers. At the point of contact, thrown along the hit: a flare that starts huge and
-- collapses, a soft halo, long spikes, two shock rings standing across the hit, a ring facing the
-- camera, arcs spinning off, glowing motes that drift up, and a few solid ink speed lines. On the
-- floor under it: a burst ring and a glow ring racing out, a pool of light, a low ring of smoke, and
-- thin arcs that keep turning after the rest has gone.

type HitRig = {
	part: Part,
	floor: Attachment,
	flare: ParticleEmitter,
	core: ParticleEmitter,
	under: ParticleEmitter,
	halo: ParticleEmitter,
	spikes: ParticleEmitter,
	ringA: ParticleEmitter,
	ringB: ParticleEmitter,
	shock: ParticleEmitter,
	arcs: ParticleEmitter,
	motes: ParticleEmitter,
	lines: ParticleEmitter,
	floorBurst: ParticleEmitter,
	floorRing: ParticleEmitter,
	floorGlow: ParticleEmitter,
	smoke: ParticleEmitter,
	floorArcs: ParticleEmitter,
}

local HIT_RIGS = if TOUCH then 4 else 7
local hitRigs: { HitRig } = {}
local nextHit = 1

local function buildHit(): HitRig
	local part, at = rigPart("HT_GustHit")
	local floor = Instance.new("Attachment")
	floor.Name = "Floor"
	floor.Parent = part

	local flare = layer(at, "Flare", IMAGES.Flare, 1)
	flare.Speed = NumberRange.new(0)
	flare.Lifetime = NumberRange.new(0.14, 0.18)
	flare.Rotation = NumberRange.new(-25, 25)
	flare.RotSpeed = NumberRange.new(-90, 90)
	flare.Brightness = 1.5
	flare.ZOffset = 2
	flare.Transparency = fade(0, 0.5)

	-- The white-hot middle: small, so the colour around it isn't washed out.
	local core = layer(at, "Core", IMAGES.GlowSoft, 1)
	core.Speed = NumberRange.new(0)
	core.Lifetime = NumberRange.new(0.1, 0.13)
	core.Color = ColorSequence.new(WHITE)
	core.Brightness = 2
	core.ZOffset = 3
	core.Transparency = fade(0, 0.5)

	-- A soft dark pool behind everything, so the light has something to be brighter than on pale
	-- ground and against the sky. Not additive: it's the dark the glow reads against.
	local under = layer(at, "Under", IMAGES.GlowSoft, 0)
	under.Speed = NumberRange.new(0)
	under.Lifetime = NumberRange.new(0.2, 0.24)
	under.Color = ColorSequence.new(GustStyle.Ink)
	under.ZOffset = -2
	under.Transparency = fade(0.5, 0.4)

	local halo = layer(at, "Halo", IMAGES.GlowSoft, 1)
	halo.Speed = NumberRange.new(0)
	halo.Lifetime = NumberRange.new(0.2, 0.26)
	halo.Brightness = 1
	halo.ZOffset = 1
	halo.Transparency = fade(0.55, 0.3)

	local spikes = layer(at, "Spikes", SPARK_TEXTURE, 1)
	spikes.Orientation = Enum.ParticleOrientation.VelocityParallel
	spikes.Lifetime = NumberRange.new(0.1, 0.22)
	spikes.SpreadAngle = Vector2.new(75, 75)
	spikes.Drag = 7
	spikes.Squash = NumberSequence.new(-3.4)
	spikes.Brightness = 2
	spikes.Transparency = fade(0, 0.6)

	local ringA = flat(at, "RingA", IMAGES.RingGlow, 1)
	ringA.Lifetime = NumberRange.new(0.22, 0.28)
	ringA.Rotation = NumberRange.new(0, 360)
	ringA.RotSpeed = NumberRange.new(120, 200)
	ringA.Brightness = 2
	ringA.Transparency = fade(0.05, 0.4)

	local ringB = flat(at, "RingB", IMAGES.RingGlow, 1)
	ringB.Lifetime = NumberRange.new(0.34, 0.42)
	ringB.Rotation = NumberRange.new(0, 360)
	ringB.RotSpeed = NumberRange.new(-160, -90)
	ringB.Brightness = 1.5
	ringB.Transparency = fade(0.4, 0.3)

	local shock = layer(at, "Shock", IMAGES.RingGlow, 1)
	shock.Speed = NumberRange.new(0)
	shock.Lifetime = NumberRange.new(0.24, 0.3)
	shock.Rotation = NumberRange.new(0, 360)
	shock.RotSpeed = NumberRange.new(-60, 60)
	shock.Brightness = 1
	shock.Transparency = fade(0.55, 0.3)

	local arcs = layer(at, "Arcs", IMAGES.CrescentGlow, 1)
	arcs.Speed = NumberRange.new(0, 3)
	arcs.SpreadAngle = Vector2.new(180, 180)
	arcs.Lifetime = NumberRange.new(0.28, 0.5)
	arcs.Rotation = NumberRange.new(0, 360)
	arcs.RotSpeed = NumberRange.new(320, 620)
	arcs.Brightness = 1.5
	arcs.Transparency = fade(0.15, 0.4)

	local motes = layer(at, "Motes", IMAGES.MoteGlow, 1)
	motes.SpreadAngle = Vector2.new(75, 75)
	motes.Lifetime = NumberRange.new(0.45, 0.9)
	motes.Drag = 3
	motes.Acceleration = Vector3.new(0, 7, 0)
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-200, 200)
	motes.Brightness = 2
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.35, 0.35),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- The few solid pieces: ink speed lines along the hit, behind the light.
	local lines = layer(at, "Lines", IMAGES.Mote, 0)
	lines.Orientation = Enum.ParticleOrientation.VelocityParallel
	lines.SpreadAngle = Vector2.new(14, 14)
	lines.Lifetime = NumberRange.new(0.1, 0.16)
	lines.Squash = NumberSequence.new(-4.5)
	lines.Color = ColorSequence.new(GustStyle.Ink)
	lines.ZOffset = -1
	lines.Transparency = fade(0.1, 0.5)

	local floorBurst = flat(floor, "FloorBurst", IMAGES.RingBurst, 1)
	floorBurst.Lifetime = NumberRange.new(0.3, 0.36)
	floorBurst.Rotation = NumberRange.new(0, 360)
	floorBurst.RotSpeed = NumberRange.new(30, 60)
	floorBurst.Brightness = 1.5
	floorBurst.Transparency = fade(0.05, 0.35)

	local floorRing = flat(floor, "FloorRing", IMAGES.RingGlow, 1)
	floorRing.Lifetime = NumberRange.new(0.4, 0.46)
	floorRing.Rotation = NumberRange.new(0, 360)
	floorRing.RotSpeed = NumberRange.new(-120, -80)
	floorRing.Brightness = 1.5
	floorRing.Transparency = fade(0.2, 0.3)

	local floorGlow = flat(floor, "FloorGlow", IMAGES.GlowSoft, 1)
	floorGlow.Lifetime = NumberRange.new(0.28, 0.34)
	floorGlow.Brightness = 1
	floorGlow.Transparency = fade(0.7, 0.3)

	local smoke = layer(floor, "Smoke", SMOKE_TEXTURE, 0.3)
	smoke.SpreadAngle = Vector2.new(86, 86)
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Drag = 5
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-70, 70)
	smoke.Color = shade(GustStyle.BodyLight, GustStyle.Body)
	smoke.Transparency = fade(0.72, 0.2)

	local floorArcs = flat(floor, "FloorArcs", IMAGES.CrescentGlow, 1)
	floorArcs.Lifetime = NumberRange.new(0.6, 1)
	floorArcs.Rotation = NumberRange.new(0, 360)
	floorArcs.RotSpeed = NumberRange.new(180, 300)
	floorArcs.Brightness = 1.5
	floorArcs.Transparency = fade(0.4, 0.3)

	part.Parent = folder()
	return {
		part = part,
		floor = floor,
		flare = flare,
		core = core,
		under = under,
		halo = halo,
		spikes = spikes,
		ringA = ringA,
		ringB = ringB,
		shock = shock,
		arcs = arcs,
		motes = motes,
		lines = lines,
		floorBurst = floorBurst,
		floorRing = floorRing,
		floorGlow = floorGlow,
		smoke = smoke,
		floorArcs = floorArcs,
	}
end

local function takeHit(): HitRig
	folder()
	local rig = hitRigs[nextHit]
	if not rig or rig.part.Parent == nil then
		rig = buildHit()
		hitRigs[nextHit] = rig
	end
	nextHit = nextHit % HIT_RIGS + 1
	return rig
end

--- A hit at `position`, thrown along `direction`, `scale` times an ordinary punch's. `colour` is the
--- kit's accent on a heavy hit, or the pale wind colour on a light one. `heavy` throws more of
--- everything. `floor` is the floor under it, if it's close enough to mark.
function GustBurst.hit(
	position: Vector3,
	direction: Vector3,
	scale: number,
	colour: Color3,
	heavy: boolean,
	floor: Vector3?
)
	local rig = takeHit()
	local aim = if direction.Magnitude > 0.01 then direction.Unit else Vector3.zAxis
	-- The rig's up is the hit direction, so "Top" throws along the hit and flat layers stand across it.
	local side = aim:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	rig.part.CFrame = CFrame.fromMatrix(position, side.Unit, aim)
	local s = scale

	-- Glow adds up: stacked white layers turn the whole thing into a white blob and the colour is
	-- lost. So only the small core is white; everything else is the colour, or a lighter shade of it.
	local pale = colour:Lerp(WHITE, 0.45)
	rig.under.Size = grow(5 * s, 9 * s)
	rig.under:Emit(1)

	rig.core.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.6 * s),
		NumberSequenceKeypoint.new(1, 0.6 * s),
	})
	rig.core:Emit(1)

	rig.flare.Color = shade(pale, colour)
	rig.flare.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 7.5 * s),
		NumberSequenceKeypoint.new(0.3, 4.5 * s),
		NumberSequenceKeypoint.new(1, 1 * s),
	})
	rig.flare:Emit(if heavy then 2 else 1)

	rig.halo.Color = ColorSequence.new(colour)
	rig.halo.Size = grow(3 * s, 7.5 * s)
	rig.halo:Emit(1)

	rig.spikes.Color = shade(pale, colour)
	rig.spikes.Speed = NumberRange.new(60 * s, 135 * s)
	rig.spikes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3.2 * s),
		NumberSequenceKeypoint.new(1, 0.7 * s),
	})
	rig.spikes:Emit(count(if heavy then 24 else 15))

	rig.ringA.Color = ColorSequence.new(WHITE)
	rig.ringA.Size = grow(1.5 * s, 9 * s)
	rig.ringA:Emit(1)
	rig.ringB.Color = ColorSequence.new(colour)
	rig.ringB.Size = grow(1 * s, 13 * s)
	rig.ringB:Emit(1)

	rig.shock.Color = shade(WHITE, colour)
	rig.shock.Size = grow(2 * s, 12 * s)
	rig.shock:Emit(1)

	rig.arcs.Color = shade(WHITE, colour)
	rig.arcs.Size = grow(2.6 * s, 6 * s)
	rig.arcs:Emit(count(if heavy then 6 else 4))

	rig.motes.Color = shade(colour, WHITE)
	rig.motes.Speed = NumberRange.new(14 * s, 42 * s)
	rig.motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75 * s),
		NumberSequenceKeypoint.new(0.6, 0.5 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	rig.motes:Emit(count(if heavy then 18 else 11))

	rig.lines.Speed = NumberRange.new(90 * s, 150 * s)
	rig.lines.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2 * s),
		NumberSequenceKeypoint.new(1, 0.9 * s),
	})
	rig.lines:Emit(count(if heavy then 5 else 3))

	if floor then
		-- Lying on the floor, a little above it so it doesn't flicker into it.
		rig.floor.WorldCFrame = CFrame.new(floor + Vector3.yAxis * 0.15)
		rig.floorBurst.Color = shade(WHITE, colour)
		rig.floorBurst.Size = grow(3 * s, 14 * s)
		rig.floorBurst:Emit(1)
		rig.floorRing.Color = ColorSequence.new(colour)
		rig.floorRing.Size = grow(2 * s, 11 * s)
		rig.floorRing:Emit(1)
		rig.floorGlow.Color = ColorSequence.new(colour)
		rig.floorGlow.Size = grow(5 * s, 10 * s)
		rig.floorGlow:Emit(1)
		rig.smoke.Speed = NumberRange.new(14 * s, 27 * s)
		rig.smoke.Size = grow(1.6 * s, 4.6 * s)
		rig.smoke:Emit(count(if heavy then 10 else 6))
		rig.floorArcs.Color = shade(WHITE, colour)
		rig.floorArcs.Size = grow(5 * s, 9.5 * s)
		rig.floorArcs:Emit(if heavy then 4 else 2)
	end
end

-- THE SWING -------------------------------------------------------------------------------------------
-- Five layers that stay with the fighter: a pale hot core arc, a coloured body arc and a wide faint
-- trail arc (each sweeping in a little later and slower than the one before, so the swing smears), a
-- solid ink-edged arc under them, and glowing motes shed off the arc.
--
-- The arcs are GustFx plates, not particles. A flat particle's direction within its plane turned out
-- to depend on how the plane is tilted (measured 2026-11-13: the same rig drew its crescent the right
-- way round facing up and back to front facing down), so a particle crescent can't be aimed. A
-- plate's can. Plates aren't additive, so the glow is soft-edged see-through layers over each other.

type SwingRig = {
	part: Part,
	motes: ParticleEmitter,
}

local SWING_RIGS = if TOUCH then 4 else 8
local swingRigs: { SwingRig } = {}
local nextSwing = 1

local function buildSwing(): SwingRig
	local part, at = rigPart("HT_GustSwing")
	local motes = layer(at, "Motes", IMAGES.MoteGlow, 1)
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.Lifetime = NumberRange.new(0.3, 0.55)
	motes.Drag = 4
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-200, 200)
	motes.Brightness = 2
	motes.Transparency = fade(0, 0.5)
	part.Parent = folder()
	return { part = part, motes = motes }
end

export type Swing = {
	follow: BasePart, -- the fighter's root: the crescent stays with it
	at: Vector3, -- the arc's centre
	head: Vector3, -- where the leading (thick) end points when the swing strikes
	bulge: Vector3, -- which way the arc bows
	size: number, -- studs across
	seconds: number, -- how long the core lasts
	sweepDegrees: number, -- how far it turns as it comes in
	colour: Color3, -- the kit's accent, or the pale wind colour
	delay: number?, -- seconds before it starts
	double: boolean?, -- a second arc across from the first (the Cyclone)
	motes: number?, -- how many motes it sheds
}

--- A swing's gust crescent. See Swing.
function GustBurst.swing(options: Swing)
	local size, life, sweep = options.size, options.seconds, options.sweepDegrees
	local colour = options.colour
	local pale = colour:Lerp(WHITE, 0.6)
	local delay = options.delay or 0

	local function arc(
		head: Vector3,
		tint: Color3,
		scale: number,
		growTo: number,
		transparency: number,
		lifeShare: number,
		sweepShare: number,
		late: number
	)
		GustFx.show({
			shape = "glow",
			at = options.at,
			head = head,
			bulge = options.bulge,
			size = size * scale,
			grow = growTo,
			hold = life * 0.4 * lifeShare,
			fade = life * 0.6 * lifeShare,
			delay = delay + late,
			tint = tint,
			transparency = transparency,
			smooth = true,
			brightness = 1.5,
			sweepDegrees = sweep * sweepShare,
			sweepSeconds = life * 0.6,
			driftDegrees = 14,
			follow = options.follow,
		})
	end
	-- The solid piece first (the ink-edged arc), then the light over it.
	GustFx.show({
		shape = "crescent",
		at = options.at,
		head = options.head,
		bulge = options.bulge,
		size = size * 0.96,
		grow = 1.05,
		hold = life * 0.4,
		fade = life * 0.45,
		delay = delay,
		transparency = 0.35,
		sweepDegrees = sweep,
		sweepSeconds = life * 0.6,
		driftDegrees = 14,
		follow = options.follow,
	})
	if not TOUCH then
		arc(options.head, colour, 1.16, 1.4, 0.62, 1.6, 0.6, life * 0.1)
	end
	arc(options.head, colour, 1.06, 1.22, 0.3, 1.25, 0.8, life * 0.05)
	arc(options.head, pale, 1, 1.08, 0, 1, 1, 0)
	if options.double then
		arc(-options.head, colour, 1.04, 1.2, 0.3, 1.2, 0.8, life * 0.05)
		arc(-options.head, pale, 0.98, 1.08, 0.05, 1, 1, 0)
	end

	-- Motes thrown off along the way the arc bows, from where the fighter is when it starts.
	folder()
	local rig = swingRigs[nextSwing]
	if not rig or rig.part.Parent == nil then
		rig = buildSwing()
		swingRigs[nextSwing] = rig
	end
	nextSwing = nextSwing % SWING_RIGS + 1
	local follow = options.follow
	local offset = follow.CFrame:ToObjectSpace(CFrame.new(options.at))
	local bow = follow.CFrame:VectorToObjectSpace(options.bulge)
	task.delay(delay + life * 0.3, function()
		if follow.Parent == nil then
			return
		end
		local at = (follow.CFrame * offset).Position
		local way = follow.CFrame:VectorToWorldSpace(bow)
		local side = way:Cross(Vector3.yAxis)
		if side.Magnitude < 0.01 then
			side = Vector3.xAxis
		end
		-- The rig's up is the way the arc bows, so "Top" throws the motes that way.
		rig.part.CFrame = CFrame.fromMatrix(at + way * size * 0.3, side.Unit, way.Unit)
		rig.motes.Color = shade(colour, WHITE)
		rig.motes.Speed = NumberRange.new(size * 1.2, size * 3)
		rig.motes.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		rig.motes:Emit(count(options.motes or 5))
	end)
end

-- THE RING --------------------------------------------------------------------------------------------
-- Six layers standing across a direction (a dash or blink going through) or lying on the floor: a
-- bright thin ring, a coloured ring behind it turning the other way, a burst ring, a pool of light, a
-- ring facing the camera, and motes thrown back along the way it came.

type RingRig = {
	part: Part,
	ringA: ParticleEmitter,
	ringB: ParticleEmitter,
	burst: ParticleEmitter,
	glow: ParticleEmitter,
	shock: ParticleEmitter,
	motes: ParticleEmitter,
}

local RING_RIGS = if TOUCH then 4 else 8
local ringRigs: { RingRig } = {}
local nextRing = 1

local function buildRing(): RingRig
	local part, at = rigPart("HT_GustRing")
	local ringA = flat(at, "RingA", IMAGES.RingGlow, 1)
	ringA.Rotation = NumberRange.new(0, 360)
	ringA.RotSpeed = NumberRange.new(150, 240)
	ringA.Brightness = 2
	ringA.Transparency = fade(0.05, 0.45)
	local ringB = flat(at, "RingB", IMAGES.RingGlow, 1)
	ringB.Rotation = NumberRange.new(0, 360)
	ringB.RotSpeed = NumberRange.new(-200, -120)
	ringB.Brightness = 1.5
	ringB.Transparency = fade(0.3, 0.35)
	local burst = flat(at, "Burst", IMAGES.RingBurst, 1)
	burst.Rotation = NumberRange.new(0, 360)
	burst.RotSpeed = NumberRange.new(40, 90)
	burst.Brightness = 1.2
	burst.Transparency = fade(0.4, 0.3)
	local glow = flat(at, "Glow", IMAGES.GlowSoft, 1)
	glow.Brightness = 0.8
	glow.Transparency = fade(0.7, 0.3)
	local shock = layer(at, "Shock", IMAGES.RingGlow, 1)
	shock.Speed = NumberRange.new(0)
	shock.Rotation = NumberRange.new(0, 360)
	shock.Brightness = 1
	shock.Transparency = fade(0.6, 0.3)
	local motes = layer(at, "Motes", IMAGES.MoteGlow, 1)
	motes.EmissionDirection = Enum.NormalId.Bottom -- back the way it came
	motes.SpreadAngle = Vector2.new(40, 40)
	motes.Lifetime = NumberRange.new(0.3, 0.6)
	motes.Drag = 3
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-200, 200)
	motes.Brightness = 3
	motes.Transparency = fade(0, 0.5)
	part.Parent = folder()
	return {
		part = part,
		ringA = ringA,
		ringB = ringB,
		burst = burst,
		glow = glow,
		shock = shock,
		motes = motes,
	}
end

--- A gust ring at `position`, standing across `normal` (the way something went through it; straight
--- up for a ring on the floor). It opens from `size` studs to `size * spread` over `seconds`; a
--- `spread` under 1 closes it instead (something vanishing).
function GustBurst.ring(
	position: Vector3,
	normal: Vector3,
	size: number,
	spread: number,
	seconds: number,
	colour: Color3
)
	if normal.Magnitude < 0.01 then
		return
	end
	folder()
	local rig = ringRigs[nextRing]
	if not rig or rig.part.Parent == nil then
		rig = buildRing()
		ringRigs[nextRing] = rig
	end
	nextRing = nextRing % RING_RIGS + 1

	local up = normal.Unit
	local side = up:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	end
	rig.part.CFrame = CFrame.fromMatrix(position, side.Unit, up)
	local to = size * spread

	local function ring(
		emitter: ParticleEmitter,
		tint: ColorSequence,
		life: number,
		from: number,
		toSize: number
	)
		emitter.Color = tint
		emitter.Lifetime = NumberRange.new(seconds * life)
		emitter.Size = grow(from, toSize)
		emitter:Emit(1)
	end
	ring(rig.ringA, ColorSequence.new(WHITE), 1, size, to)
	ring(rig.ringB, ColorSequence.new(colour), 1.4, size * 0.6, to * 1.25)
	ring(rig.burst, shade(WHITE, colour), 1.1, size * 0.9, to * 1.5)
	ring(rig.glow, ColorSequence.new(colour), 0.9, size * 1.2, to * 1.1)
	ring(rig.shock, shade(WHITE, colour), 1, size * 0.8, to * 1.3)
	rig.motes.Color = shade(colour, WHITE)
	rig.motes.Speed = NumberRange.new(size * 2, size * 6)
	rig.motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	rig.motes:Emit(count(9))
end

return GustBurst
