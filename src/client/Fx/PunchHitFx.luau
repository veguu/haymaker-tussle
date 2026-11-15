--!strict
-- PunchHitFx - a landed punch, as a replica of the first hit in Venomec's "Mumen Rider Combo"
-- (YouTube 3R5WsLDp2f4, 2.28 s to 2.65 s, read frame by frame at 60 fps and again at 1080p). All
-- particles. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- THE HIT, frame by frame (1 f = 1/60 s), with what was MEASURED off the reference:
--   0 f   a white-hot core and a star of about forty spikes, no two alike. The star is at its full
--         size (longest spike about 10 studs) for ONE frame, two thirds of that at 1 f, a third at 2 f.
--   1 f   a band of long lines shot the way the hit sends them: a thick white middle, green in three
--         tones, black lines behind it reaching past its far end. A shock bubble with a bright rim:
--         3.2 studs across at 1 f, 5, 5.8, 6.3, 6.7 after: fast, then easing.
--   2 f   a ball of short spikes round the one hit, there to 5 f
--   4 f   needles fly off; a disc of dust races out along the floor (to 20 f)
--   5 f   deep green flame wisps over the one hit; smoke along the floor
--   6 f   thin white arcs, and dark ones outside them, turning the way of the hit (to 25 f)
--
-- TIMING (the user, 2026-11-14, on the build that copied the reference's frame counts exactly: "it looks
-- like its flickering instead of bursting. i also dont see any rotation, nor much size tweening ...
-- the particles became too dull, it should be more bright and shiny"). The reference's star lasts two
-- frames and its early layers five. Played in the game, particles that live two to four frames cannot
-- show growth or spin: they pop on and off. So the layers and their ORDER are the reference's, but each
-- lives long enough to be seen moving, and nothing is thrown again in quick pops.
--
-- vfx-9 (2026-11-14, after the frame-by-frame study in the vault, "VFX Ref V01", and the user's word
-- that timing, brightness and shape were all still off). The reference is a SEQUENCE of separate
-- pictures, and vfx-8 piled them on top of each other. Now:
--   * the white floor ring comes alone, one frame before anything else (LEAD)
--   * the star is at full size at once and only shrinks and thins (6 to 10 frames), so the band of
--     lines that follows is seen on its own
--   * the band is a wedge: tall at the fighters, tapering to one tip (three tiers of lines, the longest
--     in the middle), with about three dozen lines
--   * the sparks sit round the one hit, pointing outward as the camera sees them, and shrink in place
--   * a bigger white centre, a tighter glow; black is thin hatch lines inside the star and thin lines
--     by the band (no black blades, no black arcs); three glints, later; leftovers gone sooner; the
--     ring and the bubble no longer spin
--
-- HOW THE BURST IS MADE (the user, 2026-11-14: "speed, size, rotation, randomness, are all very useful
-- for making a burst, explosive like effect"). The star is NOT one emitter per spike any more. It is a
-- few emitters, each throwing many camera-facing blades from one point:
--   * the blade texture stands on the image's centre, so a particle's Rotation turns it about its own
--     base, and a particle growing or shrinking keeps its base on the contact
--   * Rotation is random over the whole circle, so the blades make a star; RotSpeed gives each a slow
--     spin
--   * Size is a curve over the particle's life (out fast, collapsing at once, a small remainder), with
--     an envelope, so every blade has its own length
--   * Squash has an envelope too, so every blade has its own thickness: needles and broad blades
--   * Lifetime is a range, so they don't all go at the same instant
-- Only the six longest spikes are aimed on purpose (LONG, below), from the hit's direction.
--
-- HOW IT'S BUILT. A few rigs made once and used in turn (eight invisible anchored parts each, with
-- their emitters). A hit moves the next rig to the spot and tells each emitter to throw a fixed number
-- of particles at its moment. Nothing is created per punch. Textures: design/vfx/draw_hit_replica.ps1.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local PunchHitFx = {}

local BLADE = "rbxassetid://105381132050037" -- hit_blade.png: one blade in its own colours, standing on the centre
local NEEDLE = "rbxassetid://86599252876072" -- hit_needle.png: one white spike, tip to the right
local DOME = "rbxassetid://111111021118111" -- hit_dome.png: the shock bubble
local FLOOR_RING = "rbxassetid://76783207419870" -- hit_floor.png: thin rings and radial dashes
local ARC = "rbxassetid://92074328735455" -- hit_arc.png: one thin arc
local CIRCLE = "rbxassetid://75527705961320" -- hit_circle.png: a circle outline, a thinner one inside
local GLOW = "rbxassetid://119052464621710" -- glow_soft.png: a soft round glow
local SMOKE = "rbxassetid://97818702295807" -- hit_smoke.png: flipbook, 4 x 4, a puff fraying into wisps
local WISP = "rbxassetid://140573434581662" -- hit_wisp.png: flipbook, 4 x 4, flame tongues rising and fraying
local DUST = "rbxassetid://122673105804911" -- hit_dust.png: soft streaks fanning out from an empty middle
local STAR = "rbxassetid://124927142938107" -- hit_star.png: a four-point glint

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SMOKE_GREY = Color3.fromRGB(236, 239, 243)
local GREEN = Color3.fromRGB(50, 255, 60) -- the reference's colour
local PARK = CFrame.new(0, -1000, 0)
local FRAME = 1 / 60
local RIGS = 4
local LEAD = 1 -- frames the floor ring comes before everything else
-- THE BAND's three tiers: the face its lines leave (width, height), how far ahead of the contact it
-- sits (half a line, so the lines start at the contact) and the Size of its lines. The middle tier is
-- small and long, the outer one tall and short: together a wedge that tapers to one tip.
local TIER_CORE = { face = Vector3.new(1.6, 1.2, 0.2), ahead = 10, size = 4.2 }
local TIER_MID = { face = Vector3.new(2, 3.6, 0.2), ahead = 6.5, size = 2.7 }
local TIER_OUTER = { face = Vector3.new(2.2, 6.5, 0.2), ahead = 3.5, size = 1.5 }
local HATCH_SIZE = 1.6 -- the square the hatch lines are scattered in
local FLOOR_REACH = 9 -- how far under the hit a floor is looked for
local QUALITY = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then 0.6
	else 1

-- THE LONG SPIKES, the only ones aimed by hand: the angle of each from the way the hit sends them
-- (degrees, anticlockwise as the camera sees it, 90 = up), its length in studs, and its Squash (the
-- higher, the thinner). Read off the reference's first frame: two lean back toward the attacker, up and
-- down; the rest fan forward round the band of lines.
local LONG = {
	{ 147, 11.5, 0.9 },
	{ 240, 10, 0.7 },
	{ 15, 10, 0.5 },
	{ 32, 9, 0.9 },
	{ 340, 7.5, 0.2 },
	{ 73, 5.5, 0.5 },
}
-- THE SPARKS: where each sits round the one hit as the camera sees it (degrees anticlockwise from
-- screen-right, before the hit's own random turn), how far out in studs, and how big against the rest.
local SPARKS = {
	{ 8, 2.5, 1 },
	{ 47, 1.8, 0.7 },
	{ 88, 2.7, 1.15 },
	{ 124, 2, 0.8 },
	{ 163, 2.4, 1 },
	{ 201, 1.7, 0.65 },
	{ 236, 2.6, 1.1 },
	{ 272, 1.9, 0.75 },
	{ 305, 2.5, 0.95 },
	{ 338, 2, 0.85 },
}
local SPARK_SIZE = 1.2 -- with Squash 0.6: a kite about 1.6 studs long and 0.4 thick
-- THE HATCH: two patches of thin black lines inside the star. Where each sits from the contact as the
-- camera sees it (x is along the way the hit goes across the screen, y is up), and the angle its lines
-- lie at (degrees anticlockwise from that way).
local HATCH = {
	{ Vector3.new(-0.3, 1.5, 0), 60 },
	{ Vector3.new(1.4, -1, 0), -30 },
}
local BLADE_SIZE = 1.2 -- the Size that draws a blade one stud long (measured in slow motion)
local HOLD_TIMES = 2 -- a heavy hit throws its star again this many times...
local HOLD_EVERY = 7 * FRAME -- ...this far apart: each burst is still out when the next comes

-- SLOW MOTION, for study only (PunchHitFx.studySlow). Every timer is stretched by this and every
-- emitter slowed by it, so the whole hit plays `slow` times slower and can be photographed frame by
-- frame against the reference.
local slow = 1

-- One layer: its emitter, how many it throws, when, and what changes with the hit's size and colour.
type Layer = {
	emitter: ParticleEmitter,
	amount: number,
	delay: number,
	tinted: boolean, -- takes the hit's colour
	size: { NumberSequenceKeypoint }, -- at scale 1
	speed: NumberRange, -- at scale 1
	onFloor: boolean,
	dark: number?, -- how far toward black its colour is taken (0 to 1): the deeper tones
	hot: number?, -- how far toward white it starts (0 to 1): the white-hot tones
	heavy: boolean?, -- only on a heavy hit
	again: number?, -- thrown this many more times after the first
	every: number?, -- seconds between those
	hold: boolean?, -- on a heavy hit, thrown again HOLD_TIMES times
}

-- A long spike: its emitter and its angle from the hit's direction (degrees).
type Aim = { emitter: ParticleEmitter, angle: number }
-- An arc whose angle is set for each hit: `tilt` degrees off upright toward the way of the hit, turning
-- on that way at `spin` degrees a second.
type Turn = { emitter: ParticleEmitter, tilt: number, spin: number }
-- A spark: its emitter, the attachment it sits on, and where that goes for each hit.
type Spark = { emitter: ParticleEmitter, at: Attachment, angle: number, radius: number }
-- A patch of hatch lines: its emitter, the part it is scattered in, and where that goes for each hit.
type Hatch = { emitter: ParticleEmitter, part: Part, offset: Vector3, angle: number }
-- One tier of the band: the part its lines leave, and its measures (TIER_...).
type Tier = { part: Part, face: Vector3, ahead: number }

type Rig = {
	center: Part,
	tiers: { Tier },
	floor: Part,
	face: Part, -- turned to the camera for each hit; the sparks sit on it
	layers: { Layer },
	aims: { Aim },
	turns: { Turn },
	sparks: { Spark },
	hatches: { Hatch },
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

-- A NumberSequence from pairs: time, value, time, value...
local function fade(...: number): NumberSequence
	local points = { ... }
	local made = {}
	for index = 1, #points, 2 do
		table.insert(made, NumberSequenceKeypoint.new(points[index], points[index + 1]))
	end
	return NumberSequence.new(made)
end

-- Keypoints from pairs: time, value... (every particle the same).
local function keys(...: number): { NumberSequenceKeypoint }
	return fade(...).Keypoints
end

-- Keypoints from triples: time, value, envelope... The envelope is how far above or below the value
-- one particle may be, so each has its own size: this is where the variety comes from.
local function curve(...: number): { NumberSequenceKeypoint }
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

local function buildRig(parent: Instance): Rig
	local center = hiddenPart("HT_PunchHit", Vector3.new(0.2, 0.2, 0.2), parent)
	-- The lines leave the whole of a part's front face, so they come as a band, not from a point.
	-- Three parts, one for each tier of the wedge.
	local lines = hiddenPart("HT_PunchHitLines", TIER_CORE.face, parent)
	local linesMid = hiddenPart("HT_PunchHitLinesMid", TIER_MID.face, parent)
	local linesOuter = hiddenPart("HT_PunchHitLinesOuter", TIER_OUTER.face, parent)
	local tiers: { Tier } = {
		{ part = lines, face = TIER_CORE.face, ahead = TIER_CORE.ahead },
		{ part = linesMid, face = TIER_MID.face, ahead = TIER_MID.ahead },
		{ part = linesOuter, face = TIER_OUTER.face, ahead = TIER_OUTER.ahead },
	}
	local floor = hiddenPart("HT_PunchHitFloor", Vector3.new(7, 0.2, 7), parent)
	-- Turned to the camera for each hit: its +X is the screen's right and its +Y the screen's up.
	local face = hiddenPart("HT_PunchHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
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
			-- Everything but the floor ring waits LEAD frames, so the ring is seen alone first.
			delay = (delayFrames + (if name == "FloorRing" then 0 else LEAD)) * FRAME,
			tinted = tinted,
			size = size,
			speed = speed,
			onFloor = host == floor or host == ground,
		})
		return made
	end
	-- Sets the tone of the layer just made: darker, and/or starting white-hot.
	local function tone(dark: number?, hot: number?)
		local last = layers[#layers]
		last.dark = dark
		last.hot = hot
	end
	local function heavyOnly(again: number?, everyFrames: number?)
		local last = layers[#layers]
		last.heavy = true
		last.again = again
		last.every = if everyFrames then everyFrames * FRAME else nil
	end
	local STILL = NumberRange.new(0)

	-- 0 f. The white-hot core: the reference's is about six studs wide. Full at once, a short swell,
	-- gone in six frames. Bright enough to bloom.
	local core = layer(at, "Core", GLOW, 1, 0, false, keys(0, 3, 0.3, 4.2, 1, 2), STILL)
	core.Lifetime = NumberRange.new(0.1)
	core.Brightness = 3
	core.ZOffset = 1.8
	core.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)

	-- 0 f. The glow round the core: tight to the star (the reference's floor is not tinted).
	local halo = layer(at, "Halo", GLOW, 1, 0, true, keys(0, 3, 0.4, 4.5, 1, 5), STILL)
	tone(0.2)
	halo.Lifetime = NumberRange.new(0.14)
	halo.Brightness = 1.4
	halo.LightEmission = 0.6 -- part glow, part its own green, so it stays green on a pale floor
	halo.ZOffset = 0.5
	halo.Transparency = fade(0, 0.5, 0.5, 0.7, 1, 1)

	-- THE STAR (see the top of this file). A blade's length on screen is its Size / BLADE_SIZE times
	-- 2^Squash; its thickness is divided by the same 2^Squash.

	-- 0 f. The hatch: two patches of thin black lines drawn over the star's white middle, as in the
	-- reference's first frame. Each patch is scattered through a small square that faces the camera;
	-- its lines lie at one angle, set for each hit (`hatches`), a little apart from each other.
	local hatches: { Hatch } = {}
	for index, spec in HATCH do
		local square = hiddenPart(
			"HT_PunchHitHatch" .. index,
			Vector3.new(HATCH_SIZE, HATCH_SIZE, 0.1),
			parent
		)
		local scribble = layer(
			square,
			"Hatch" .. index,
			NEEDLE,
			4,
			0,
			false,
			curve(0, 0.65, 0.25, 1, 0.5, 0.2),
			STILL
		)
		scribble.Shape = Enum.ParticleEmitterShape.Box
		scribble.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		scribble.Color = ColorSequence.new(BLACK)
		scribble.LightEmission = 0
		scribble.ZOffset = 2.2 -- in front of the white core
		scribble.Lifetime = NumberRange.new(0.08, 0.13)
		scribble.Squash = NumberSequence.new(-0.6) -- about 2 studs long, hair-thin
		scribble.Transparency = fade(0, 0.05, 0.7, 0.2, 1, 1)
		table.insert(
			hatches,
			{ emitter = scribble, part = square, offset = spec[1], angle = spec[2] }
		)
	end

	-- 0 f. The crowd of green blades. Each is at its full length at once (the reference's star is
	-- already shrinking on its second frame), then shortens and thins to a needle, turning a little,
	-- as it fades. Lengths from about 2 to 8 studs.
	local blades = layer(
		at,
		"StarBlades",
		BLADE,
		26,
		0,
		false,
		curve(0, 6, 3, 0.4, 3.6, 1.8, 1, 1.4, 0.7),
		STILL
	)
	layers[#layers].hold = true
	blades.LightEmission = 0.6
	blades.Brightness = 2
	blades.ZOffset = 1
	blades.Rotation = NumberRange.new(0, 360)
	blades.RotSpeed = NumberRange.new(-110, 110) -- up to 20 degrees of twist in its life
	blades.Lifetime = NumberRange.new(0.1, 0.16)
	blades.Squash = NumberSequence.new(curve(0, 0.1, 0.4, 0.4, 0.6, 0.5, 1, 1.2, 0.5)) -- broad, then thinning to a needle
	blades.Transparency = fade(0, 0, 0.55, 0.05, 1, 1)

	-- 0 f. The six long spikes, one emitter each: aimed for each hit (`aims`), not random.
	local aims: { Aim } = {}
	for index, spec in LONG do
		-- Its Size at full length, less what the Squash adds.
		local peak = BLADE_SIZE * spec[2] / 2 ^ spec[3]
		local spike = layer(
			at,
			"StarLong" .. index,
			BLADE,
			1,
			0,
			false,
			keys(0, peak, 0.35, peak * 0.7, 1, peak * 0.3),
			STILL
		)
		layers[#layers].hold = true
		spike.LightEmission = 0.65
		spike.Brightness = 2.2
		spike.ZOffset = 1.2
		spike.Lifetime = NumberRange.new(0.09, 0.14)
		spike.RotSpeed = NumberRange.new(-25, 25)
		spike.Squash = NumberSequence.new(spec[3] - 0.4, spec[3] + 0.5)
		spike.Transparency = fade(0, 0, 0.75, 0.1, 1, 1)
		table.insert(aims, { emitter = spike, angle = spec[1] })
	end

	-- 2 f. A second, smaller burst of blades on the one hit, spinning faster: one throw, not a flicker.
	local ball =
		layer(body, "StarBall", BLADE, 8, 2, false, curve(0, 0.6, 0.3, 0.3, 4.5, 2, 1, 2, 1), STILL)
	ball.LightEmission = 0.65
	ball.Brightness = 2
	ball.ZOffset = 1.1
	ball.Rotation = NumberRange.new(0, 360)
	ball.RotSpeed = NumberRange.new(-200, 200)
	ball.Lifetime = NumberRange.new(0.12, 0.2)
	ball.Squash = NumberSequence.new(curve(0, -0.2, 0.3, 1, 0.8, 0.4))
	ball.Transparency = fade(0, 0, 0.75, 0.1, 1, 1)

	-- 1 f. THE BAND of long lines shot the way of the hit. Each line has its own length (the size's
	-- envelope), its own speed and its own life. Brighter lines are drawn nearer (ZOffset).
	-- MEASURED in Play (vfx-9): a particle is drawn TWICE its Size across, so a line is as long as its
	-- Size times 4.8 (2 x 2^1.26). vfx-9's first try assumed 2.4 and the band came out 40 studs long.
	-- The same holds for every Size in this file: a ring of Size 3.3 is 6.6 studs across. It is nearly full length at once (the
	-- reference's band is four character heights long on its first frame) and drifts on a little, so
	-- the band stays rooted at the fighters. The three tiers together make the wedge (TIER_...).
	local function line(
		host: Part,
		name: string,
		amount: number,
		length: number,
		dark: number?,
		hot: number?,
		emission: number,
		brightness: number
	)
		local made = layer(
			host,
			name,
			NEEDLE,
			amount,
			1,
			true,
			curve(
				0,
				length * 0.8,
				length * 0.25,
				0.25,
				length,
				length * 0.3,
				1,
				length * 0.75,
				length * 0.25
			),
			NumberRange.new(15, 45)
		)
		tone(dark, hot)
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.EmissionDirection = Enum.NormalId.Front
		made.Lifetime = NumberRange.new(0.1, 0.16)
		made.Drag = 5
		made.Brightness = brightness * 1.4
		made.LightEmission = emission
		made.ZOffset = emission
		made.Squash = NumberSequence.new(-1.26)
		made.Transparency = fade(0, 0, 0.6, 0.05, 1, 1)
	end
	-- The thick white middle of the band: the longest lines, about 20 studs.
	local beam = layer(
		lines,
		"LinesCore",
		NEEDLE,
		3,
		1,
		false,
		curve(0, 4.7, 0.7, 1, 4.7, 0.7),
		NumberRange.new(15, 40)
	)
	beam.Orientation = Enum.ParticleOrientation.VelocityParallel
	beam.EmissionDirection = Enum.NormalId.Front
	beam.Lifetime = NumberRange.new(0.1, 0.15)
	beam.Drag = 5
	beam.Brightness = 3.5
	beam.Squash = NumberSequence.new(-0.95)
	beam.ZOffset = 1.2
	beam.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)
	-- Middle tier: long, mostly white-hot and bright green.
	line(lines, "LinesHot", 4, TIER_CORE.size, nil, 0.85, 0.85, 2)
	line(lines, "Lines", 4, TIER_CORE.size, 0.1, nil, 0.5, 1.3)
	-- Second tier: about 13 studs, all three tones.
	line(linesMid, "MidHot", 3, TIER_MID.size, nil, 0.85, 0.85, 2)
	line(linesMid, "MidLines", 6, TIER_MID.size, 0.1, nil, 0.5, 1.3)
	line(linesMid, "MidDeep", 4, TIER_MID.size, 0.5, nil, 0.2, 1)
	-- Outer tier: about 7 studs, over the whole height of the band, the deeper tones.
	line(linesOuter, "OuterLines", 6, TIER_OUTER.size, 0.1, nil, 0.5, 1.3)
	line(linesOuter, "OuterDeep", 5, TIER_OUTER.size, 0.5, nil, 0.2, 1)

	-- 1 f. Black lines above and below the green ones: faster and longer-lived, so they reach past
	-- the green's far end, fanned a little, and they outlast it by a few frames.
	local dark = layer(
		linesMid,
		"DarkLines",
		NEEDLE,
		14,
		1,
		false,
		curve(0, 2.6, 0.9, 1, 2.6, 0.9),
		NumberRange.new(60, 110)
	)
	dark.Orientation = Enum.ParticleOrientation.VelocityParallel
	dark.EmissionDirection = Enum.NormalId.Front
	dark.SpreadAngle = Vector2.new(5, 5)
	dark.Color = ColorSequence.new(BLACK)
	dark.LightEmission = 0
	dark.Squash = NumberSequence.new(-1.6)
	dark.Lifetime = NumberRange.new(0.14, 0.24)
	dark.Drag = 4
	dark.ZOffset = -0.5
	dark.Transparency = fade(0, 0.1, 0.7, 0.2, 1, 1)

	-- 1 f. THE SHOCKWAVE. The bubble: out fast, then easing (measured). It does not turn.
	local dome = layer(body, "Dome", DOME, 1, 1, false, keys(0, 3, 0.3, 5, 0.65, 6, 1, 6.4), STILL)
	dome.Lifetime = NumberRange.new(0.22)
	dome.Rotation = NumberRange.new(0, 360)
	dome.LightEmission = 0.7
	dome.Transparency = fade(0, 0.42, 0.5, 0.62, 1, 1)

	-- 1 f. Its bright rim: a second, brighter bubble racing outward ahead of the first (soft-edged: a
	-- drawn circle here looked like an interface ring, not a shockwave).
	local shock =
		layer(body, "ShockRing", DOME, 1, 1, false, keys(0, 2.6, 0.35, 5.4, 1, 6.8), STILL)
	shock.Lifetime = NumberRange.new(0.16)
	shock.Rotation = NumberRange.new(0, 360)
	shock.LightEmission = 0.8
	shock.Brightness = 1.6
	shock.Transparency = fade(0, 0.5, 0.5, 0.7, 1, 1)

	-- THE FIRST THING SEEN (it does not wait LEAD frames): the white ring on the floor, there one
	-- frame before the star. About six studs across at once, widening to nine as it fades. It does
	-- not turn.
	local ring = layer(
		ground,
		"FloorRing",
		FLOOR_RING,
		1,
		0,
		false,
		keys(0, 3.3, 0.5, 3.8, 1, 4.8),
		NumberRange.new(0.01)
	)
	ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ring.EmissionDirection = Enum.NormalId.Top
	ring.Lifetime = NumberRange.new(0.2)
	ring.Rotation = NumberRange.new(0, 360)
	ring.LightEmission = 0.8
	ring.Brightness = 1.6
	ring.Transparency = fade(0, 0, 0.5, 0.35, 1, 1)

	-- 4 f. THE SPARKS: ten small kites sitting round the one hit, each pointing outward as the camera
	-- sees it, shrinking where it is. One emitter each, on the part that is turned to the camera; where
	-- each sits and which way it points is set for each hit (`sparks`), not left to chance.
	local sparks: { Spark } = {}
	for index, spec in SPARKS do
		local seat = Instance.new("Attachment")
		seat.Parent = face
		local big = SPARK_SIZE * spec[3]
		local spark = layer(
			seat,
			"Spark" .. index,
			NEEDLE,
			1,
			4,
			true,
			keys(0, big, 0.35, big * 0.85, 1, big * 0.12),
			STILL
		)
		tone(nil, 0.6)
		spark.Lifetime = NumberRange.new(0.11, 0.17)
		spark.Squash = NumberSequence.new(0.6)
		spark.Brightness = 3
		spark.LightEmission = 0.6
		spark.ZOffset = 1.3
		spark.Transparency = fade(0, 0, 0.75, 0.1, 1, 1)
		table.insert(sparks, { emitter = spark, at = seat, angle = spec[1], radius = spec[2] })
	end

	-- 6 f. Glints: three four-point stars thrown outward, swelling and shrinking as they spin. In the
	-- reference they come late and are few.
	local glints = layer(
		at,
		"Glints",
		STAR,
		3,
		6,
		true,
		curve(0, 0.1, 0.05, 0.3, 1.5, 0.7, 1, 0, 0),
		NumberRange.new(8, 26)
	)
	tone(nil, 0.9)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Drag = 4
	glints.Lifetime = NumberRange.new(0.22, 0.5)
	glints.Rotation = NumberRange.new(0, 90)
	glints.RotSpeed = NumberRange.new(-260, 260)
	glints.Brightness = 3.5
	glints.ZOffset = 2
	glints.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)

	-- 4 f. The dust the hit blasts out along the floor: soft streaks fanning from an empty middle,
	-- twice as wide as the ring and there three times as long, drifting round a little.
	local dust = layer(
		ground,
		"FloorDust",
		DUST,
		1,
		4,
		false,
		keys(0, 4, 0.3, 6, 1, 7.5),
		NumberRange.new(0.01)
	)
	dust.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-60, 60)
	dust.Lifetime = NumberRange.new(0.3)
	dust.LightEmission = 0.5
	dust.Brightness = 1.3
	dust.Transparency = fade(0, 0.2, 0.4, 0.5, 1, 1)

	-- 2 f. A dark patch on the floor under it all, so the light has something to stand out from.
	local patch =
		layer(ground, "FloorShade", GLOW, 1, 2, false, keys(0, 4.5, 1, 6), NumberRange.new(0.01))
	patch.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	patch.EmissionDirection = Enum.NormalId.Top
	patch.Color = ColorSequence.new(BLACK)
	patch.LightEmission = 0
	patch.Lifetime = NumberRange.new(0.35)
	patch.Transparency = fade(0, 0.5, 0.5, 0.68, 1, 1)

	-- 5 f. Deep green flame wisps rising over the one hit: low glow, each its own size and speed.
	local haze = layer(
		above,
		"Haze",
		WISP,
		7,
		5,
		true,
		curve(0, 2, 0.7, 0.3, 3.4, 1, 1, 4, 1.2),
		NumberRange.new(3, 8)
	)
	tone(0.35)
	haze.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	haze.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	haze.EmissionDirection = Enum.NormalId.Top
	haze.SpreadAngle = Vector2.new(70, 70)
	haze.Lifetime = NumberRange.new(0.2, 0.32)
	haze.Rotation = NumberRange.new(-28, 28) -- flames stand upright, leaning a little each way
	haze.RotSpeed = NumberRange.new(-12, 12)
	haze.LightEmission = 0.55
	haze.Transparency = fade(0, 0.62, 0.5, 0.75, 1, 1)

	-- 6 f. Two thin white arcs over the one hit, leaning the way the hit sends them and turning on
	-- that way. Their angles are set for each hit (`turns`), not left to chance. They open quickly,
	-- then ease.
	local turns: { Turn } = {}
	local function arc(
		name: string,
		delayFrames: number,
		tilt: number,
		spin: number,
		from: number,
		to: number
	): ParticleEmitter
		local made = layer(
			body,
			name,
			ARC,
			1,
			delayFrames,
			false,
			keys(0, from, 0.35, from + (to - from) * 0.75, 1, to),
			STILL
		)
		made.Lifetime = NumberRange.new(0.22, 0.3)
		made.LightEmission = 0.7
		made.Brightness = 2
		made.Transparency = fade(0, 0.15, 0.6, 0.4, 1, 1)
		table.insert(turns, { emitter = made, tilt = tilt, spin = spin })
		return made
	end
	arc("ArcA", 6, 20, 110, 4.6, 6.6)
	arc("ArcB", 6, 55, 170, 5.4, 7.6)

	-- 5 f. Smoke along the floor, left behind after the light has gone: each puff swelling, drifting
	-- out and turning at its own rate. Gone about half a second after the hit, as in the reference.
	local smoke = layer(
		floor,
		"FloorSmoke",
		SMOKE,
		18,
		5,
		false,
		curve(0, 1.4, 0.5, 0.4, 2.6, 0.8, 1, 3.2, 0.9),
		NumberRange.new(0.5, 5)
	)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(80, 80)
	smoke.Color = ColorSequence.new(SMOKE_GREY)
	smoke.LightEmission = 0.3
	smoke.Lifetime = NumberRange.new(0.32, 0.5)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-50, 50)
	smoke.Drag = 3
	smoke.Transparency = fade(0, 0.12, 0.5, 0.4, 1, 1)

	-- THE HEAVY HIT (the reference's third hit, 3.53 s to 4.0 s): everything above, bigger, the star
	-- thrown again HOLD_TIMES times so it holds (the `hold` layers), and these.
	local holdLines = layer(
		lines,
		"HoldLines",
		NEEDLE,
		3,
		3,
		true,
		curve(0, 3.6, 1.2, 1, 3.6, 1.2),
		NumberRange.new(40, 80)
	)
	heavyOnly(11, 2)
	tone(0.2)
	holdLines.Orientation = Enum.ParticleOrientation.VelocityParallel
	holdLines.EmissionDirection = Enum.NormalId.Front
	holdLines.Lifetime = NumberRange.new(0.05, 0.08)
	holdLines.Brightness = 1.4
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
	local circle = layer(body, "Circle", CIRCLE, 1, 16, false, keys(0, 3.6, 1, 4.4), STILL)
	heavyOnly()
	circle.Lifetime = NumberRange.new(0.3)
	circle.LightEmission = 0.7
	circle.Brightness = 1
	circle.Transparency = fade(0, 0.3, 0.6, 0.5, 1, 1)

	-- 22 f. Two more arcs, taller than wide, as it dies away.
	local lateA = arc("LateArcA", 22, 10, 50, 4, 6)
	heavyOnly()
	lateA.Lifetime = NumberRange.new(0.35, 0.5)
	lateA.Squash = NumberSequence.new(0.5)
	local lateB = arc("LateArcB", 22, 70, 90, 4.4, 6.4)
	heavyOnly()
	lateB.Lifetime = NumberRange.new(0.35, 0.5)
	lateB.Squash = NumberSequence.new(0.5)

	return {
		center = center,
		tiers = tiers,
		floor = floor,
		face = face,
		layers = layers,
		aims = aims,
		turns = turns,
		sparks = sparks,
		hatches = hatches,
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

-- A layer's size curve at this hit's scale, keeping each point's envelope.
local function scaled(points: { NumberSequenceKeypoint }, scale: number): NumberSequence
	local out = table.create(#points)
	for index, point in points do
		out[index] =
			NumberSequenceKeypoint.new(point.Time, point.Value * scale, point.Envelope * scale)
	end
	return NumberSequence.new(out)
end

--- A landed punch at `position`, sending them along `direction`. `size` is how big it is against an
--- ordinary punch (1). `colour` tints the lines, haze and sparks; without it they're the reference's
--- green (the star's blades carry their own green in the texture and are not tinted). `heavy` adds the
--- heavy hit's layers: a quarter bigger, held for 0.4 s, with a column and a circle.
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
	local base = colour or GREEN
	local floorAt = floorUnder(position)

	rig.center.CFrame = CFrame.lookAt(position, position + way)
	-- Each tier of the band sits half a line ahead of the contact, so its lines start at the contact.
	for _, tier in rig.tiers do
		local from = position + way * tier.ahead * scale
		tier.part.CFrame = CFrame.lookAt(from, from + way)
		tier.part.Size = tier.face * scale
	end
	if floorAt then
		rig.floor.CFrame = CFrame.new(floorAt + way * 1.2 * scale)
		rig.floor.Size = Vector3.new(7 * scale, 0.2, 7 * scale)
	end

	-- Which way the hit goes across the screen: right (1) or left (-1). The long spikes and the arcs
	-- are laid out from it.
	local camera = workspace.CurrentCamera
	local right = if camera then camera.CFrame.RightVector else Vector3.xAxis
	local side = if way:Dot(right) >= 0 then 1 else -1
	for _, aim in rig.aims do
		-- A blade stands upright at Rotation 0, and a positive Rotation turns it anticlockwise. Its
		-- angle from the hit's direction is mirrored when the hit goes left, so up stays up.
		local onScreen = if side == 1 then aim.angle else 180 - aim.angle
		aim.emitter.Rotation = NumberRange.new(onScreen - 90)
	end
	for _, turn in rig.turns do
		turn.emitter.Rotation = NumberRange.new(-side * turn.tilt)
		turn.emitter.RotSpeed = NumberRange.new(-side * turn.spin)
	end

	-- A frame that faces the camera: its +X is the screen's right and its +Y the screen's up. The
	-- sparks and the hatch are laid out in it, so they are placed as the camera sees them.
	local eye = if camera then camera.CFrame.Position else position + Vector3.zAxis * 20
	local function screenAt(point: Vector3): CFrame
		local away = point - eye
		return if away.Magnitude > 0.1
			then CFrame.lookAt(point, point + away)
			else CFrame.new(point)
	end
	-- The sparks sit round the one hit, a little past the contact. The whole set is turned by a
	-- different amount each hit, so no two hits are the same; each spark points straight outward.
	rig.face.CFrame = screenAt(position + way * 1.4 * scale + Vector3.new(0, 0.3 * scale, 0))
	local turned = math.random() * 360
	for _, spark in rig.sparks do
		local angle = spark.angle + turned
		local radians = math.rad(angle)
		spark.at.Position = Vector3.new(math.cos(radians), math.sin(radians), 0)
			* spark.radius
			* scale
		spark.emitter.Rotation = NumberRange.new(angle - 8, angle + 8)
	end
	-- The hatch: each patch's square is put where it belongs on screen (mirrored when the hit goes
	-- left), and its lines lie at their angle, a few degrees apart.
	local screen = screenAt(position)
	for _, hatch in rig.hatches do
		local offset = Vector3.new(hatch.offset.X * side, hatch.offset.Y, 0) * scale
		hatch.part.CFrame = screen * CFrame.new(offset)
		hatch.part.Size = Vector3.new(HATCH_SIZE * scale, HATCH_SIZE * scale, 0.1)
		local angle = if side == 1 then hatch.angle else 180 - hatch.angle
		hatch.emitter.Rotation = NumberRange.new(angle - 12, angle + 12)
	end

	for _, layer in rig.layers do
		if (layer.onFloor and not floorAt) or (layer.heavy and not heavy) then
			continue
		end
		local emitter = layer.emitter
		if layer.tinted then
			local body = base:Lerp(BLACK, layer.dark or 0)
			emitter.Color = if layer.hot
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, body:Lerp(WHITE, layer.hot)),
					ColorSequenceKeypoint.new(0.45, body),
					ColorSequenceKeypoint.new(1, body),
				})
				else ColorSequence.new(body)
		end
		emitter.Size = scaled(layer.size, scale)
		emitter.Speed = NumberRange.new(layer.speed.Min * scale, layer.speed.Max * scale)
		emitter.TimeScale = 1 / slow
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
			task.delay(layer.delay * slow, fire)
		end
		for extra = 1, layer.again or 0 do
			task.delay((layer.delay + extra * (layer.every or FRAME)) * slow, fire)
		end
		if heavy and layer.hold then
			for extra = 1, HOLD_TIMES do
				task.delay((layer.delay + extra * HOLD_EVERY) * slow, fire)
			end
		end
	end
end

--- Builds every rig ahead of the first hit, so the textures are loaded by then.
function PunchHitFx.preload()
	for _ = 1, RIGS do
		takeRig()
	end
end

--- FOR STUDY ONLY: plays every hit after this `factor` times slower (1 puts it back), so it can be
--- photographed at the reference's frame numbers. Nothing in the game calls it.
function PunchHitFx.studySlow(factor: number)
	slow = math.max(factor, 1)
end

return PunchHitFx
