--!strict
-- FrostFx - the Frost kit's effects, second version (Fx/KitFxCommon, Fx/KitModels, Fx/FxKit): the
-- Frostbite (Q), the freeze it leaves, the Glacier (R), and the kit's own look for a punch and a
-- landing. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- The first version was thin glowing particles, and the user turned it down (2026-11-15): "way too
-- thin", "too bright so its hard to see", "the ice should be made out of a solid model", "very complex
-- and detailed with multiple colors and shades", "REALLY big". This one is built on the references they
-- sent then, and on the vault's rule that every frame needs a dark shade, the colour, a thin white
-- core and one accent ("VFX Readability and Value - Lessons from Blind Reviews"):
--   solid ice   real crystals of very different sizes leaning outward, white-hot for their first
--               frames, standing, then white again and sinking (DonutLee1 "ICE ERUPTION", YouTube
--               nOloysSOoGY). Ice chips thrown as debris (Pew "Ice Moveset Showcase", HOeAQEvFDNA:
--               every hit throws solid chunks).
--   dark        navy smoke behind the ice and a navy stain on the floor, so the bright parts have
--               something to stand against (Pew: a dark ball round the white core; TharoVFX "Roblox
--               VFX Ice", W0Xi9x_WHFI: a dark cloud round the body).
--   colour      solid blues, not glow: the crystals and the big shapes are opaque or nearly so.
--   white       kept to the first flash and thin rays.
--   accent      pale violet, only on the drifting motes.
--   size        the Glacier's ice stands three character heights tall and fills its whole reach.
--
-- FROSTBITE: a burst of ice where you set off, a thick blue wake with small crystals coming up
-- behind you, and everyone you pass shut in a block of ice that breaks when it is hit.
-- GLACIER: cold gathering on the raised hand and motes rising over its reach, then the stomp: about
-- twenty crystals burst from the floor ahead in three waves, with navy smoke, rings, rays and
-- thrown chips, stand for a second, and sink.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)
local KitModels = require(script.Parent.KitModels)

local FrostFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local P = Common.Palettes.Frost
local INK = Color3.fromRGB(14, 30, 92) -- the dark shade: saturated navy, never grey
local ACCENT = Color3.fromRGB(196, 172, 255) -- pale violet
local TWINKLE = curve(0, 0, 0, 0.3, 0.6, 0.25, 1, 0, 0)
-- What the solid ice is made of: four pale glass blues, dark to pale, and a white-blue that glows.
-- ice-1 (2026-11-22): the tones of the owner's reference (Niagara-Ice, YouTube dIWMbXMnwqc: its ice
-- measures (125,162,198) to (213,239,251) from the 5th to the 75th percentile), and a little more
-- see-through. The meshes carry only pale facet tones (never below 0.64, 0.79, 0.88), so the white-hot
-- flash is white: darker vertex colours turn Neon navy.
local ICE = {
	Color3.fromRGB(182, 224, 244),
	Color3.fromRGB(205, 236, 250),
	Color3.fromRGB(225, 244, 253),
	Color3.fromRGB(245, 252, 255),
}
local ICE_SEE = 0 -- solid: the reference ice is not see-through (the owner, ice-8)
local GLOW = Color3.fromRGB(170, 236, 255)

-- THE LAYERS, each made the same way wherever it is used.

-- Navy smoke: the dark behind the bright.
local function darkSmoke(add: FxKit.Add, host: Instance, amount: number, delay: number, big: number)
	local made = add(
		host,
		"DarkSmoke" .. delay,
		Tex.Smoke,
		amount,
		delay,
		curve(0, big, big * 0.3, 1, big * 2, big * 0.5),
		{ speed = NumberRange.new(big * 1.2, big * 3) }
	)
	Common.smoke(made, INK, 0.7, 1.1)
	made.Color = ramp(INK, P.deep)
	made.LightEmission = 0
	made.ZOffset = -2
	made.SpreadAngle = Vector2.new(180, 180)
	made.Transparency = fade(0, 0.15, 0.5, 0.35, 1, 1)
	return made
end

local function mist(add: FxKit.Add, host: Instance, amount: number, delay: number, big: number)
	local made = add(
		host,
		"Mist" .. delay,
		Tex.Smoke,
		amount,
		delay,
		curve(0, big, big * 0.3, 1, big * 2.1, big * 0.5),
		{ speed = NumberRange.new(big, big * 2.5) }
	)
	Common.smoke(made, P.smoke, 0.6, 1)
	made.LightEmission = 0.15
	made.SpreadAngle = Vector2.new(180, 180)
	return made
end

local function snow(add: FxKit.Add, host: Instance, amount: number, delay: number, big: number)
	local made = add(host, "Snow" .. delay, Tex.Star, amount, delay, {
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, big, big * 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	Common.twinkle(made, 0.4, 0.8)
	made.Color = ramp(P.white, P.bright)
	return made
end

-- Chips thrown up that fly briefly and fall: solid-coloured, not glowing.
local function chips(
	add: FxKit.Add,
	host: Instance,
	amount: number,
	delay: number,
	spread: number,
	speed: NumberRange,
	big: number
)
	local made = add(
		host,
		"Chips" .. delay,
		Tex.Leaf,
		amount,
		delay,
		curve(0, big, big * 0.4, 1, big * 0.5, big * 0.2),
		{ speed = speed }
	)
	Common.thrown(made, spread, 3, 0.5, 0.9)
	made.Orientation = Enum.ParticleOrientation.VelocityParallel
	made.Squash = NumberSequence.new(-0.3)
	made.Acceleration = Vector3.new(0, -60, 0)
	made.LightEmission = 0.3
	made.Brightness = 1.6
	made.Color = ramp(P.white, P.bright, P.body)
	return made
end

-- Violet motes that drift up: the accent.
local function motes(add: FxKit.Add, host: Instance, amount: number, delay: number)
	local made = add(
		host,
		"Motes" .. delay,
		Tex.Glow,
		amount,
		delay,
		curve(0, 0.45, 0.2, 0.7, 0.35, 0.15, 1, 0, 0),
		{ speed = NumberRange.new(3, 9) }
	)
	Common.embers(made, 0.9, 1.5)
	made.Acceleration = Vector3.new(0, 5, 0)
	made.Color = ramp(P.white, ACCENT)
	return made
end

-- A ring on the floor: white first, then blue as it widens.
local function floorRing(
	add: FxKit.Add,
	at: Attachment,
	name: string,
	delay: number,
	from: number,
	to: number,
	colour: ColorSequence
)
	local made = add(
		at,
		name,
		Tex.Circle,
		1,
		delay,
		keys(0, from, 0.3, to * 0.85, 1, to),
		{ flat = true, onFloor = true }
	)
	Common.ring(made, 0.36)
	made.Brightness = 2.4
	made.Color = colour
	return made
end

-- The navy stain a burst leaves on the floor, with frost over it.
local function stain(add: FxKit.Add, at: Attachment, big: number, life: number)
	local made = add(at, "Stain", Tex.Glow, 1, 0, keys(0, big * 0.7, 0.2, big, 1, big * 1.1), {
		flat = true,
		onFloor = true,
	})
	made.Lifetime = NumberRange.new(life)
	made.LightEmission = 0
	made.Color = ramp(INK, P.deep)
	made.Transparency = fade(0, 0.2, 0.7, 0.35, 1, 1)
	local frost =
		add(at, "Frost", Tex.Glow, 1, 1, keys(0, big * 0.45, 0.2, big * 0.7, 1, big * 0.8), {
			flat = true,
			onFloor = true,
		})
	frost.Lifetime = NumberRange.new(life * 0.8)
	frost.LightEmission = 0.4
	frost.Color = ramp(P.bright, P.body)
	frost.Transparency = fade(0, 0.35, 0.6, 0.55, 1, 1)
end

-- Thin white rays standing up out of a burst.
local function rays(add: FxKit.Add, host: BasePart, count: number, big: number)
	for index = 1, count do
		local at = FxKit.attach(host, Vector3.new((index - (count + 1) / 2) * big * 0.9, 0, 0))
		local ray = add(at, "Ray" .. index, Tex.Leaf, 1, index - 1, keys(0, big, 1, big * 1.25))
		Common.flash(ray, 0.2)
		ray.Rotation = NumberRange.new(84 + index * 4)
		ray.Squash = fade(0, -1.2, 1, -2.4)
		ray.Color = ramp(P.white, P.bright)
	end
end

-- SOLID ICE: one crystal, leaning away from `centre`. Tone 1 (dark) to 4 (pale); 0 is a glowing one.
-- `yaw` turns it about its own length (degrees); left out, it is turned at random. With `index` (its
-- number in its cluster) it leaves by breaking into chunks that fly away from `centre`; without, it sinks.
local function crystal(
	name: string,
	height: number,
	position: Vector3,
	centre: Vector3,
	lean: number,
	delay: number,
	hold: number,
	tone: number,
	yaw: number?,
	index: number?
)
	local base = KitModels.rooted(position, position - centre, lean, yaw or math.random(0, 359))
	local breaks: KitModels.Break? = if index
		then { index = index, middle = centre, chunk = "Ice_Shard" }
		else nil
	if tone == 0 then
		KitModels.erupt(name, height, base, delay, hold, GLOW, Enum.Material.Neon, 0.2, breaks)
	else
		KitModels.erupt(
			name,
			height,
			base,
			delay,
			hold,
			ICE[tone],
			Enum.Material.SmoothPlastic,
			ICE_SEE,
			breaks
		)
	end
end

-- Chips of solid ice thrown out and up from `from`.
local function debris(from: Vector3, amount: number, speed: number, big: number)
	for _ = 1, math.max(1, math.floor(amount * FxKit.QUALITY + 0.5)) do
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local velocity = out * speed * (0.35 + math.random() * 0.65)
			+ Vector3.yAxis * speed * (0.7 + math.random() * 0.6)
		KitModels.throw(
			"Ice_Shard",
			big * (0.6 + math.random() * 0.8),
			from + out * (1 + math.random() * 2) + Vector3.yAxis * 1.5,
			velocity,
			150,
			0.7 + math.random() * 0.5,
			ICE[math.random(2, 4)]
		)
	end
end

-- FROSTBITE: setting off -----------------------------------------------------------------------------
local starts = FxKit.pool("HT_FrostBiteFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_FrostBiteFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)
	local low = FxKit.attach(floor, Vector3.new(0, 2, 0))
	-- Its front face looks back along the dash.
	local back = FxKit.hiddenPart("HT_FrostBiteBack", Vector3.new(3, 3, 0.2), parent)
	local area = FxKit.hiddenPart("HT_FrostBiteArea", Vector3.new(9, 4, 9), parent)

	local flash = add(low, "Flash", Tex.Glow, 1, 0, keys(0, 3, 0.3, 4.4, 1, 1.6))
	Common.flash(flash, 0.09)
	flash.Color = ramp(P.white, P.bright)
	stain(add, onFloor, 7, 1)
	floorRing(add, onFloor, "Ring", 0, 2, 8, ramp(P.white, P.bright))
	floorRing(add, onFloor, "SecondRing", 4, 1.5, 6, ramp(P.bright, P.body))
	darkSmoke(add, low, 6, 0, 2.2)
	mist(add, low, 4, 1, 1.6)

	-- Thick streaks thrown back: blue, with white ones among them.
	local streaks = add(
		back,
		"Streaks",
		Tex.Needle,
		10,
		0,
		curve(0, 2.2, 0.6, 1, 0.9, 0.3),
		{ speed = NumberRange.new(60, 110) }
	)
	Common.streaks(streaks, -1.2, 0.14, 0.22)
	streaks.SpreadAngle = Vector2.new(14, 14)
	streaks.LightEmission = 0.3
	streaks.Color = ramp(P.bright, P.body, P.deep)
	local hot = add(
		back,
		"HotStreaks",
		Tex.Needle,
		5,
		0,
		curve(0, 1.4, 0.4, 1, 0.5, 0.2),
		{ speed = NumberRange.new(80, 130) }
	)
	Common.streaks(hot, -1.6, 0.1, 0.16)
	hot.SpreadAngle = Vector2.new(8, 8)
	hot.Color = ColorSequence.new(P.white)
	local thrown = chips(add, back, 12, 1, 35, NumberRange.new(30, 60), 0.9)
	thrown.EmissionDirection = Enum.NormalId.Front
	snow(add, area, 10, 2, 0.7)
	motes(add, low, 8, 2)

	return { floor = floor, back = back, area = area }
end)

-- THE FREEZE: round the block of ice ------------------------------------------------------------------
local freezes = FxKit.pool("HT_FrostFreezeFx", 4, function(parent, add)
	local centre = FxKit.hiddenPart("HT_FrostFreeze", Vector3.new(4, 6, 4), parent)
	local at = FxKit.attach(centre)
	local floor = FxKit.hiddenPart("HT_FrostFreezeFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)

	local flash = add(at, "Flash", Tex.Glow, 1, 0, keys(0, 4, 0.3, 5.5, 1, 2))
	Common.flash(flash, 0.09)
	flash.Color = ramp(P.white, P.bright)
	stain(add, onFloor, 6, 1.2)
	floorRing(add, onFloor, "Ring", 0, 1.5, 7, ramp(P.white, P.bright))
	darkSmoke(add, at, 5, 0, 2)
	mist(add, at, 5, 1, 1.8)
	rays(add, centre, 3, 3)
	chips(add, at, 14, 1, 180, NumberRange.new(25, 55), 0.8)
	snow(add, centre, 12, 2, 0.7)
	motes(add, at, 8, 2)

	return { centre = centre, floor = floor }
end)

-- THE SHATTER: ice breaking ----------------------------------------------------------------------------
local STAR_SHAPE = { 0, 1, 0.35, 0.85, 1, 0.15 }

-- A star in three tones: navy spikes, blue ones over them, a few thin white ones on top.
local function star(add: FxKit.Add, face: Part, long: number)
	local deep = Common.pieces(
		add,
		face,
		"DeepSpike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(9, long * 0.5, long, -0.7, 31),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.22, 0.3)
			emitter.Squash = NumberSequence.new(-0.7)
			emitter.LightEmission = 0
			emitter.ZOffset = 0.4
			emitter.Color = ramp(P.deep, INK)
			emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	)
	local body = Common.pieces(
		add,
		face,
		"Spike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(13, long * 0.4, long * 1.15, -1, 7),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.18, 0.26)
			emitter.Squash = NumberSequence.new(-1)
			emitter.LightEmission = 0.3
			emitter.Brightness = 1.8
			emitter.ZOffset = 1
			emitter.Color = ramp(P.bright, P.body)
			emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	)
	local hot = Common.pieces(
		add,
		face,
		"HotSpike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(6, long * 0.5, long * 1.3, -1.7, 19),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.12, 0.18)
			emitter.Squash = NumberSequence.new(-1.7)
			emitter.Brightness = 3
			emitter.ZOffset = 1.6
			emitter.Color = ColorSequence.new(P.white)
			emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	)
	return { deep, body, hot }
end

local function placeStar(sets: { { Common.Piece } })
	for _, set in sets do
		Common.place(set, math.random() * 360, 1, 1)
	end
end

local shatters = FxKit.pool("HT_FrostShatterFx", 4, function(parent, add)
	local face = FxKit.hiddenPart("HT_FrostShatterFace", Vector3.new(0.2, 0.2, 0.2), parent)
	local centre = FxKit.attach(face)
	local area = FxKit.hiddenPart("HT_FrostShatterArea", Vector3.new(8, 7, 8), parent)

	local flash = add(centre, "Flash", Tex.Glow, 1, 0, keys(0, 4, 0.3, 6, 1, 2.2))
	Common.flash(flash, 0.1)
	flash.Color = ramp(P.white, P.bright)
	local sets = star(add, face, 9)
	for index, delay in { 2, 5 } do
		local ring = add(
			centre,
			"Ring" .. index,
			Tex.Circle,
			1,
			delay,
			keys(0, 2, 0.35, 5 + index * 1.5, 1, 6.5 + index * 1.5)
		)
		Common.ring(ring, 0.3)
		ring.Brightness = 2.4
		ring.Color = if index == 1 then ramp(P.white, P.bright) else ramp(P.bright, P.body)
	end
	darkSmoke(add, centre, 6, 0, 2.4)
	mist(add, centre, 5, 2, 2)
	chips(add, centre, 18, 1, 180, NumberRange.new(35, 75), 1)
	snow(add, area, 14, 2, 0.8)
	motes(add, centre, 10, 2)

	return { face = face, area = area, sets = sets }
end)

-- GLACIER: what marks its reach through the windup --------------------------------------------------------
local marks = FxKit.pool("HT_FrostMarkFx", 2, function(parent, add)
	local area = FxKit.hiddenPart("HT_FrostMarkArea", Vector3.new(22, 0.2, 14), parent)
	local centre = FxKit.attach(area, Vector3.new(0, 0.2, 0))
	local raised = FxKit.attach(area, Vector3.new(0, 2.5, 0))
	for index, delay in { 0, 8, 16 } do
		local rising = add(
			area,
			"Rising" .. index,
			Tex.Glow,
			22,
			delay,
			curve(0, 0.5, 0.2, 1, 0, 0),
			{ speed = NumberRange.new(8, 18) }
		)
		rising.EmissionDirection = Enum.NormalId.Top
		rising.Lifetime = NumberRange.new(0.3, 0.45)
		rising.Brightness = 2.5
		rising.Color = ramp(P.white, P.bright)
		rising.Transparency = fade(0, 0, 0.7, 0.2, 1, 1)
	end
	snow(add, area, 10, 6, 0.7)
	-- A navy shade spreading over the floor where the ice will come up.
	local shade = add(centre, "Shade", Tex.Glow, 1, 0, keys(0, 6, 1, 13), { flat = true })
	shade.Lifetime = NumberRange.new(0.42)
	shade.LightEmission = 0
	shade.Color = ColorSequence.new(INK)
	shade.Transparency = fade(0, 0.7, 0.8, 0.35, 1, 0.6)
	local glint = add(raised, "Glint", Tex.Star, 1, 21, keys(0, 5, 0.5, 3, 1, 0))
	Common.twinkle(glint, 0.1, 0.1)
	glint.Color = ramp(P.white, P.bright)
	return { area = area }
end)

-- GLACIER: the particles round the solid ice ---------------------------------------------------------------
local bursts = FxKit.pool("HT_FrostGlacierFx", 2, function(parent, add)
	-- Lies on the floor at the middle of the cluster, its front the way the thrower faces.
	local ground = FxKit.hiddenPart("HT_FrostGlacierGround", Vector3.new(12, 0.2, 9), parent)
	local onFloor = FxKit.attach(ground, Vector3.new(0, 0.1, 0))
	local low = FxKit.attach(ground, Vector3.new(0, 4, 0))
	local high = FxKit.attach(ground, Vector3.new(0, 9, 0))
	local area = FxKit.hiddenPart("HT_FrostGlacierArea", Vector3.new(24, 12, 16), parent)

	-- 0 f. The white flash the ice arrives in, and the floor: a navy stain, frost, ONE shockwave ring
	-- (three until ice-9; the owner: "only one shockwave when the ice erupts instead of a bunch of rings").
	local flash = add(low, "Flash", Tex.Glow, 1, 0, keys(0, 9, 0.3, 13, 1, 5))
	Common.flash(flash, 0.1)
	flash.Color = ramp(P.white, P.bright)
	stain(add, onFloor, 17, 1.8)
	floorRing(add, onFloor, "Ring", 0, 4, 20, ramp(P.white, P.bright))

	-- 0 f. Navy smoke behind the ice and pale mist over it.
	darkSmoke(add, low, 12, 0, 4.5)
	darkSmoke(add, high, 8, 4, 4)
	mist(add, low, 8, 2, 3.5)

	-- 0 f. Rays.
	rays(add, ground, 5, 5)

	-- 1 f. Chips thrown high; snow over the whole reach, three times; violet motes rising.
	chips(add, low, 34, 1, 55, NumberRange.new(55, 105), 1.5)
	snow(add, area, 22, 3, 0.8)
	snow(add, area, 18, 20, 0.8)
	snow(add, area, 16, 40, 0.7)
	motes(add, low, 22, 2)

	-- 93 f (1.55 s: the rise, then GLACIER_HOLD). The ice breaking: a second flash, mist and falling chips.
	local last = add(low, "LastFlash", Tex.Glow, 1, 93, keys(0, 8, 1, 4))
	Common.flash(last, 0.1)
	last.Color = ramp(P.white, P.bright)
	-- After the reference's break (ice-12): mist that lingers, a burst of small bright sparks that
	-- slow and die, snow, and a pale frost patch that stays on the floor for two seconds.
	mist(add, low, 10, 95, 4)
	mist(add, low, 8, 110, 4.5)
	local sparks = add(low, "BreakSparks", Tex.Glow, 70, 93, curve(0, 0.5, 0.25, 1, 0, 0), {
		speed = NumberRange.new(18, 50),
	})
	Common.embers(sparks, 0.5, 1.1)
	sparks.Color = ramp(P.white, P.bright)
	snow(add, area, 24, 96, 0.8)
	local patch = add(onFloor, "BreakFrost", Tex.Glow, 1, 93, keys(0, 12, 0.15, 17, 1, 18), {
		flat = true,
		onFloor = true,
	})
	patch.Lifetime = NumberRange.new(2.2)
	patch.LightEmission = 0.5
	patch.Color = ramp(P.white, P.bright)
	patch.Transparency = fade(0, 0.3, 0.6, 0.5, 1, 1)

	return { ground = ground, area = area }
end)

-- The Glacier's crystals, in the thrower's own frame: right, ahead, height, lean in degrees, wave
-- (each wave arrives two frames after the one before), which piece, its tone (1 dark to 4 pale;
-- 0 a glowing one), and its turn about its own length in degrees.
-- ice-1 (2026-11-22): ONE FLOWER, after the owner's reference: every crystal stands within 3 studs of
-- one centre and leans away from it, tall broad blades inside (wave 1), long low ones outside (wave
-- 2). Made and checked in Blender (design/kits/ice-study: ice_layout.py is this table, fit_yaws.py
-- chose each turn). The limits it keeps are the old layout's: no ice further ahead than 18.3 studs,
-- wider than 16.4 to a side, behind the thrower, or nearer the camera than 13.2; and no blade lying
-- flatter than 70 degrees or only just poking out of the floor. Each turn is set, not random: a
-- leaning piece turned the wrong way puts a side blade flat on the floor.
local GLACIER: { { any } } = {
	{ 0, 8, 10, 0, 0, "Ice_Clump", 3, 30 },
	{ -0.21, 8.77, 14, 8, 0, "Ice_SpikeTall", 0, 345 },
	{ 0.51, 8.61, 12, 12, 0, "Ice_SpikeTall", 0, 165 },
	{ -0.75, 9.3, 19, 20, 1, "Ice_SpikeThick", 4, 180 },
	{ 0.75, 9.3, 18, 22, 1, "Ice_SpikeThick", 2, 165 },
	{ -1.48, 8.26, 16.5, 34, 1, "Ice_SpikeThick", 2, 195 },
	{ 1.49, 8.13, 16, 36, 1, "Ice_SpikeThick", 3, 150 },
	{ 0, 9.5, 16, 10, 1, "Ice_SpikeThick", 1, 165 },
	{ 0, 6.5, 8, 20, 1, "Ice_SpikeTall", 3, 165 },
	{ -0.96, 6.85, 11, 30, 1, "Ice_SpikeTall", 4, 0 },
	{ 0.96, 6.85, 11, 32, 1, "Ice_SpikeTall", 1, 150 },
	{ -2.05, 9.43, 15, 40, 2, "Ice_SpikeThick", 3, 315 },
	{ 2.05, 9.43, 15, 40, 2, "Ice_SpikeThick", 4, 165 },
	{ -2.35, 7.14, 13, 42, 2, "Ice_SpikeThick", 1, 15 },
	{ 2.35, 7.14, 13, 42, 2, "Ice_SpikeThick", 2, 150 },
	{ -2.9, 8.78, 14, 66, 2, "Ice_SpikeTall", 3, 30 },
	{ 2.85, 8.93, 13.5, 64, 2, "Ice_SpikeTall", 4, 75 },
	{ -1.27, 10.72, 10, 56, 2, "Ice_SpikeTall", 2, 345 },
	{ 1.12, 10.78, 9.5, 56, 2, "Ice_SpikeTall", 3, 165 },
	{ -2.95, 7.48, 12, 70, 2, "Ice_SpikeTall", 1, 240 },
	{ 2.97, 7.58, 12, 70, 2, "Ice_SpikeTall", 1, 45 },
	{ -1.41, 6.59, 9, 40, 2, "Ice_SpikeTall", 4, 15 },
	{ 1.49, 6.66, 9, 40, 2, "Ice_SpikeTall", 2, 135 },
}
local GLACIER_HOLD = 1.4 -- seconds the flower stands before it breaks (0.9 until ice-4: the owner wanted longer)
local GLACIER_CENTRE = 8 -- how far ahead of the thrower the middle of the cluster is

-- THE KIT'S OWN PUNCH: a small ice burst where a punch lands -------------------------------------------------
local punches = FxKit.pool("HT_FrostPunchFx", 4, function(parent, add)
	local face = FxKit.hiddenPart("HT_FrostPunchFace", Vector3.new(2, 2, 0.2), parent)
	local centre = FxKit.attach(face)
	local flash = add(centre, "Flash", Tex.Glow, 1, 0, keys(0, 1.6, 0.3, 2.4, 1, 0.9))
	Common.flash(flash, 0.07)
	flash.Color = ramp(P.white, P.bright)
	local sets = star(add, face, 4.5)
	local ring = add(centre, "Ring", Tex.Circle, 1, 2, keys(0, 1, 0.35, 3, 1, 3.8))
	Common.ring(ring, 0.2)
	ring.Brightness = 2.2
	ring.Color = ramp(P.white, P.bright, P.body)
	darkSmoke(add, centre, 2, 0, 1.1)
	chips(add, centre, 7, 1, 180, NumberRange.new(20, 45), 0.6)
	snow(add, face, 4, 2, 0.6)
	return { face = face, sets = sets }
end)

--- The Frostbite: the burst where `root` sets off along `direction`, then for `seconds` a thick
--- wake behind it, with small crystals coming up out of the floor it has crossed.
function FrostFx.frostbite(root: BasePart, direction: Vector3, seconds: number)
	local way = FxKit.flat(direction)
	local ground = FxKit.floorUnder(root.Position, 8)
	local feet = ground or root.Position - Vector3.yAxis * 2.8
	local rig = starts.take()
	local floor = rig.parts.floor :: Part
	local back = rig.parts.back :: Part
	local area = rig.parts.area :: Part
	floor.CFrame = CFrame.new(feet + Vector3.yAxis * 0.1)
	back.CFrame = CFrame.lookAt(root.Position - way, root.Position - way * 2)
	area.CFrame = CFrame.new(feet + Vector3.yAxis * 2)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)
	if ground then
		for index = 1, 4 do
			local angle = math.rad(index * 90 + 45)
			local spot = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.6
			crystal("Ice_SpikeTall", 3.5 + index * 0.5, spot, ground, 28, 0, 0.45, 1 + index % 4)
		end
		debris(ground, 6, 26, 0.9)
	end

	-- Small crystals come up behind the body as it goes.
	local slow = FxKit.slowness()
	local steps = math.max(2, math.floor(seconds / 0.06))
	for index = 1, steps do
		task.delay(index * 0.06 * slow, function()
			if not root.Parent then
				return
			end
			local under = FxKit.floorUnder(root.Position, 8)
			if under then
				local side = if index % 2 == 0 then 1 else -1
				local across = Vector3.new(-way.Z, 0, way.X) * side * (1.2 + math.random() * 1.4)
				crystal(
					if index % 3 == 0 then "Ice_SpikeThick" else "Ice_SpikeTall",
					3 + math.random() * 3,
					under - way * 2 + across,
					under - way * 2,
					24,
					0,
					0.5,
					1 + index % 4
				)
			end
		end)
	end

	Common.stream(root, "FrostWake", seconds, Vector3.zero, function(at)
		-- The body of the wake: solid blue, thick.
		local wake = Common.emitter(at, "Wake", Tex.Glow, 70)
		wake.Lifetime = NumberRange.new(0.3, 0.4)
		wake.Size = NumberSequence.new(curve(0, 3.2, 0.6, 0.5, 2.2, 0.5, 1, 0, 0))
		wake.LightEmission = 0.3
		wake.Color = ramp(P.bright, P.body, P.deep)
		wake.Transparency = fade(0, 0.25, 0.7, 0.4, 1, 1)
		-- Navy smoke under it.
		local dark = Common.emitter(at, "Dark", Tex.Smoke, 26)
		Common.smoke(dark, INK, 0.5, 0.8)
		dark.Color = ramp(INK, P.deep)
		dark.LightEmission = 0
		dark.ZOffset = -2
		dark.Size = NumberSequence.new(curve(0, 2.6, 0.6, 1, 4.6, 1))
		dark.Speed = NumberRange.new(1, 4)
		dark.Transparency = fade(0, 0.2, 0.5, 0.4, 1, 1)
		-- A thin white core down its middle.
		local core = Common.emitter(at, "Core", Tex.Glow, 70)
		core.Lifetime = NumberRange.new(0.14, 0.2)
		core.Size = NumberSequence.new(curve(0, 1.2, 0.2, 1, 0, 0))
		core.Brightness = 3
		core.ZOffset = 1
		core.Color = ColorSequence.new(P.white)
		local lines = Common.emitter(at, "Lines", Tex.Needle, 46)
		lines.Orientation = Enum.ParticleOrientation.VelocityParallel
		lines.EmissionDirection = Enum.NormalId.Back
		lines.SpreadAngle = Vector2.new(14, 14)
		lines.Speed = NumberRange.new(40, 70)
		lines.Lifetime = NumberRange.new(0.12, 0.18)
		lines.Squash = NumberSequence.new(-1.3)
		lines.Size = NumberSequence.new(curve(0, 1.6, 0.5, 1, 0.6, 0.2))
		lines.LightEmission = 0.4
		lines.Brightness = 2
		lines.Color = ramp(P.white, P.bright, P.body)
		local thrown = Common.emitter(at, "Chips", Tex.Leaf, 40)
		thrown.Orientation = Enum.ParticleOrientation.VelocityParallel
		thrown.EmissionDirection = Enum.NormalId.Back
		thrown.SpreadAngle = Vector2.new(50, 50)
		thrown.Speed = NumberRange.new(14, 34)
		thrown.Lifetime = NumberRange.new(0.3, 0.5)
		thrown.Size = NumberSequence.new(curve(0, 0.8, 0.3, 1, 0.3, 0.1))
		thrown.Acceleration = Vector3.new(0, -40, 0)
		thrown.LightEmission = 0.3
		thrown.Brightness = 1.6
		thrown.Color = ramp(P.white, P.bright, P.body)
		local stars = Common.emitter(at, "Snow", Tex.Star, 30)
		Common.twinkle(stars, 0.4, 0.7)
		stars.Size = NumberSequence.new(TWINKLE)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Speed = NumberRange.new(0, 4)
		stars.Color = ramp(P.white, P.bright)
		return { wake, dark, core, lines, thrown, stars }
	end)
end

-- The block each frozen fighter is standing in.
local blocks: { [Model]: BasePart } = setmetatable({}, { __mode = "k" }) :: any

--- `character` has been frozen for `seconds`: a block of solid ice round them, and the burst it
--- arrives in.
function FrostFx.freeze(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local ground = FxKit.floorUnder(root.Position, 12)
	local feet = ground or root.Position - Vector3.yAxis * 3
	local rig = freezes.take()
	local centre = rig.parts.centre :: Part
	local floor = rig.parts.floor :: Part
	centre.CFrame = CFrame.new(root.Position)
	floor.CFrame = CFrame.new(feet + Vector3.yAxis * 0.1)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)

	local old = blocks[character]
	if old then
		old:Destroy()
	end
	local block, size = KitModels.piece("Ice_Block", 8)
	block.Material = Enum.Material.SmoothPlastic
	block.Color = ICE[3]
	block.Transparency = 0.4
	block.Size = size
	block.CFrame = CFrame.new(feet)
		* CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
		* CFrame.new(0, size.Y / 2, 0)
	blocks[character] = block
	-- Small crystals round its foot, for as long as it stands.
	for index = 1, 5 do
		local angle = math.rad(index * 72 + math.random(0, 30))
		local spot = feet + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.8
		crystal(
			"Ice_SpikeTall",
			2.5 + math.random() * 2.5,
			spot,
			feet,
			30,
			0,
			math.max(seconds - 0.2, 0.2),
			1 + index % 4,
			nil,
			index
		)
	end
	-- If the thaw is never heard (they left, or were moved), the block still goes.
	task.delay((seconds + 0.5) * FxKit.slowness(), function()
		if blocks[character] == block then
			blocks[character] = nil
			block:Destroy()
		end
	end)
end

--- `character`'s ice is gone: broken by a hit (`broken`), or run out.
function FrostFx.thaw(character: Model, broken: boolean)
	local block = blocks[character]
	blocks[character] = nil
	local at = if block then block.Position else nil
	if block then
		block:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local centre = at or (if root and root:IsA("BasePart") then root.Position else nil)
	if not centre then
		return
	end
	local rig = shatters.take()
	local face = rig.parts.face :: Part
	local area = rig.parts.area :: Part
	face.CFrame = FxKit.screenAt(centre)
	area.CFrame = CFrame.new(centre)
	placeStar(rig.parts.sets)
	FxKit.fire(rig, if broken then 1 else 0.6)
	debris(centre - Vector3.yAxis * 2, if broken then 14 else 6, if broken then 46 else 22, 1.3)
end

--- The Glacier's windup: motes rising over its reach (ahead of `root`, along `direction`) and cold
--- gathering on the hand (`arm`) for `seconds`.
function FrostFx.windup(root: BasePart, arm: BasePart?, direction: Vector3, seconds: number)
	local way = FxKit.flat(direction)
	local ground = FxKit.floorUnder(root.Position, 8)
	if ground then
		local rig = marks.take()
		local area = rig.parts.area :: Part
		local middle = ground + way * GLACIER_CENTRE + Vector3.yAxis * 0.15
		area.CFrame = CFrame.lookAt(middle, middle + way)
		FxKit.fire(rig, 1)
	end
	if arm then
		Common.stream(arm, "FrostHand", seconds, Vector3.new(0, -arm.Size.Y / 2, 0), function(at)
			local ball = Common.emitter(at, "Ball", Tex.Glow, 40)
			ball.LockedToPart = true
			ball.Lifetime = NumberRange.new(0.1)
			ball.Size = NumberSequence.new(keys(0, 1.6, 1, 2.4))
			ball.Brightness = 3
			ball.ZOffset = 1
			ball.Color = ramp(P.bright, P.white)
			ball.Transparency = fade(0, 0.2, 1, 1)
			local dark = Common.emitter(at, "Dark", Tex.Smoke, 16)
			Common.smoke(dark, INK, 0.3, 0.5)
			dark.LightEmission = 0
			dark.ZOffset = -1
			dark.Size = NumberSequence.new(curve(0, 1.6, 0.4, 1, 3, 0.6))
			dark.Speed = NumberRange.new(1, 3)
			local stars = Common.emitter(at, "Snow", Tex.Star, 22)
			Common.twinkle(stars, 0.2, 0.35)
			stars.Size = NumberSequence.new(TWINKLE)
			stars.SpreadAngle = Vector2.new(180, 180)
			stars.Speed = NumberRange.new(2, 7)
			stars.Color = ramp(P.white, P.bright)
			return { ball, dark, stars }
		end)
	end
end

--- The Glacier striking, hit or miss: solid ice bursts from the floor ahead of `root` along
--- `direction`, with everything round it.
function FrostFx.strike(root: BasePart, direction: Vector3)
	local way = FxKit.flat(direction)
	local right = Vector3.new(-way.Z, 0, way.X)
	local ground = FxKit.floorUnder(root.Position, 8)
	local feet = ground or root.Position - Vector3.yAxis * 2.8
	local middle = feet + way * GLACIER_CENTRE
	local rig = bursts.take()
	local base = rig.parts.ground :: Part
	local area = rig.parts.area :: Part
	base.CFrame = CFrame.lookAt(middle + Vector3.yAxis * 0.1, middle + Vector3.yAxis * 0.1 + way)
	area.CFrame = CFrame.lookAt(middle + Vector3.yAxis * 6, middle + Vector3.yAxis * 6 + way)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)

	for index, spec in GLACIER do
		local spot = feet + right * spec[1] + way * spec[2]
		-- Each crystal stands on the floor that is really under it, or isn't made (off an edge).
		local under = FxKit.floorUnder(spot + Vector3.yAxis * 4, 9)
		if under then
			crystal(
				spec[6],
				spec[3],
				under,
				middle,
				spec[4],
				spec[5] * 2 * FxKit.FRAME,
				GLACIER_HOLD,
				spec[7],
				spec[8],
				index
			)
		end
	end
	debris(middle, 14, 62, 1.6)
	-- And again as the ice sinks.
	task.delay((GLACIER_HOLD + 0.15) * FxKit.slowness(), function()
		debris(middle, 8, 30, 1.2)
	end)
end

--- The Glacier throwing `target`: ice breaks round them, and they leave snow behind as they go.
function FrostFx.hit(target: BasePart, _away: Vector3)
	local rig = shatters.take()
	local face = rig.parts.face :: Part
	local area = rig.parts.area :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	area.CFrame = CFrame.new(target.Position)
	placeStar(rig.parts.sets)
	FxKit.fire(rig, 0.8)
	Common.stream(target, "FrostChill", 1, Vector3.zero, function(at)
		local stars = Common.emitter(at, "Snow", Tex.Star, 26)
		Common.twinkle(stars, 0.4, 0.7)
		stars.Size = NumberSequence.new(TWINKLE)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Speed = NumberRange.new(0, 4)
		stars.Color = ramp(P.white, P.bright)
		local wake = Common.emitter(at, "Wake", Tex.Glow, 30)
		wake.Lifetime = NumberRange.new(0.3, 0.45)
		wake.Size = NumberSequence.new(curve(0, 2.4, 0.5, 1, 0, 0))
		wake.LightEmission = 0.3
		wake.Color = ramp(P.bright, P.body, P.deep)
		wake.Transparency = fade(0, 0.3, 1, 1)
		return { stars, wake }
	end)
end

--- The Frost kit's own punch landing at `position`: a small burst of ice. `strong` is a heavy hit.
function FrostFx.punch(position: Vector3, strong: boolean)
	local rig = punches.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(position)
	placeStar(rig.parts.sets)
	FxKit.fire(rig, if strong then 1.5 else 1)
	debris(position - Vector3.yAxis, if strong then 5 else 2, 24, 0.7)
end

--- The Frost kit's own landing (a kick or a dive reaching the floor at `position`): a ring of
--- crystals round the spot.
function FrostFx.landing(position: Vector3)
	for index = 1, 7 do
		local angle = math.rad(index * 51 + math.random(0, 20))
		local spot = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (3 + index % 3)
		crystal(
			if index % 3 == 0 then "Ice_SpikeThick" else "Ice_SpikeTall",
			4 + math.random() * 4,
			spot,
			position,
			32,
			(index % 3) * 2 * FxKit.FRAME,
			0.55,
			1 + index % 4
		)
	end
	debris(position, 8, 40, 1.1)
	local rig = shatters.take()
	local face = rig.parts.face :: Part
	local area = rig.parts.area :: Part
	face.CFrame = FxKit.screenAt(position + Vector3.yAxis * 2)
	area.CFrame = CFrame.new(position + Vector3.yAxis * 3)
	placeStar(rig.parts.sets)
	FxKit.fire(rig, 0.9)
end

function FrostFx.preload()
	task.spawn(KitModels.preload)
	starts.preload()
	freezes.preload()
	shatters.preload()
	marks.preload()
	bursts.preload()
	punches.preload()
end

return FrostFx
