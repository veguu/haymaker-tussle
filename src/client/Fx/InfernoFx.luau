--!strict
-- InfernoFx - the Inferno kit's effects, second version (Fx/KitFxCommon's thick layers, Fx/KitModels,
-- Fx/FxKit): the Blastoff (Q), the Meteor (R), and the kit's own look for a punch and a landing.
-- Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- The first version was thin glowing particles and the user turned it down (2026-11-15). This one
-- follows the explosions they sent then:
--   colour     red, orange and yellow as solid masses, layered, with oxblood smoke behind them and
--              white only for the first frames (Ako Shiba "Megumin Explosion V3", YouTube
--              NQfkrr8xEIM; Pew "Fire Moveset Showcase", wauPbM7qSWE: sheets of flame along the floor).
--   rings      a column of stacked rings over the blast, widest in the middle (Megumin), and rings
--              running out along the floor.
--   embers     big lens-shaped ones, a head across, thrown out and stopped (Megumin).
--   solid      rock: the meteor itself, a rim of rock punched up round the crater, and chunks thrown
--              out (Pew: every hit throws solid chunks; the user: "mix vfx with models").
--   accent     blue, only on the drifting motes (the hottest part of a flame).
--
-- BLASTOFF: an explosion under you as you leave the floor, and fire trailing from you in the air.
-- METEOR: a ring on the floor closes on the spot while the rock comes down burning, then the blast:
-- flame, a column of rings, oxblood smoke, a crater rim of rock, thrown chunks.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)
local KitModels = require(script.Parent.KitModels)

local InfernoFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local TONES: Common.Tones = {
	ink = Color3.fromRGB(78, 10, 6), -- oxblood
	deep = Color3.fromRGB(196, 36, 12),
	body = Color3.fromRGB(255, 112, 20),
	bright = Color3.fromRGB(255, 198, 66),
	white = Color3.fromRGB(255, 248, 222),
	accent = Color3.fromRGB(104, 176, 255),
	smoke = Color3.fromRGB(84, 56, 48),
}
local T = Common.thick(TONES)
local ROCK = Color3.fromRGB(74, 52, 46)
local ROCK_HOT = Color3.fromRGB(150, 62, 30)
local SCORCH = Color3.fromRGB(30, 14, 8)

-- Solid masses of flame: the flipbook tongues, big, in the fire's own tones rather than as glow.
local function flames(
	add: FxKit.Add,
	host: Instance,
	amount: number,
	delay: number,
	big: number,
	speed: NumberRange,
	spread: number
): ParticleEmitter
	local made = add(
		host,
		"Flames" .. delay,
		Tex.Wisp,
		amount,
		delay,
		curve(0, big * 0.6, big * 0.2, 0.3, big, big * 0.3, 1, big * 0.7, big * 0.3),
		{ speed = speed }
	)
	Common.flame(made, 0.3, 0.55)
	made.SpreadAngle = Vector2.new(spread, spread)
	made.Rotation = NumberRange.new(-25, 25)
	made.LightEmission = 0.35
	made.Brightness = 2
	made.Color = ramp(TONES.bright, TONES.body, TONES.deep, TONES.ink)
	made.Transparency = fade(0, 0, 0.6, 0.15, 1, 1)
	return made
end

-- A column of rings stacked over a blast, widest in the middle. `sizes` is each ring's Size, low to high.
local function ringColumn(
	add: FxKit.Add,
	floor: BasePart,
	name: string,
	step: number,
	sizes: { number }
)
	for index, size in sizes do
		local at = FxKit.attach(floor, Vector3.new(0, index * step, 0))
		local ring = add(
			at,
			name .. index,
			Tex.Circle,
			1,
			index,
			keys(0, size * 0.4, 0.3, size, 1, size * 1.2),
			{ flat = true }
		)
		Common.ring(ring, 0.34)
		ring.Brightness = 2.6
		ring.Color = if index % 2 == 1
			then ramp(TONES.white, TONES.bright, TONES.body)
			else ramp(TONES.bright, TONES.body, TONES.deep)
		local glow =
			add(at, name .. "Glow" .. index, Tex.Glow, 1, index, keys(0, size * 0.5, 1, size), {
				flat = true,
			})
		glow.Lifetime = NumberRange.new(0.3)
		glow.LightEmission = 0.4
		glow.Color = ramp(TONES.body, TONES.deep)
		glow.Transparency = fade(0, 0.45, 1, 1)
	end
end

local function scorch(add: FxKit.Add, at: Attachment, big: number, life: number)
	local made = add(at, "Scorch", Tex.Pinwheel, 1, 1, keys(0, big * 0.9, 1, big), {
		flat = true,
		onFloor = true,
	})
	made.Lifetime = NumberRange.new(life)
	made.Rotation = NumberRange.new(0, 360)
	made.LightEmission = 0
	made.Color = ColorSequence.new(SCORCH)
	made.Transparency = fade(0, 0.25, 0.7, 0.4, 1, 1)
end

-- Rock chunks thrown out and up from `from`.
local function chunks(from: Vector3, amount: number, speed: number, big: number)
	for index = 1, math.max(1, math.floor(amount * FxKit.QUALITY + 0.5)) do
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		KitModels.throw(
			if index % 2 == 0 then "Rock_ChunkA" else "Rock_ChunkB",
			big * (0.6 + math.random() * 0.9),
			from + out * (1 + math.random() * 2.5) + Vector3.yAxis * 1.5,
			out * speed * (0.35 + math.random() * 0.65)
				+ Vector3.yAxis * speed * (0.6 + math.random() * 0.7),
			160,
			0.8 + math.random() * 0.5,
			if index % 3 == 0 then ROCK_HOT else ROCK,
			Enum.Material.Slate
		)
	end
end

-- A rim of rock punched up round `centre`, leaning outward.
local function rim(centre: Vector3, count: number, radius: number, tall: number, hold: number)
	for index = 1, count do
		local angle = math.rad(index * (360 / count) + math.random(-10, 10))
		local spot = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local under = FxKit.floorUnder(spot + Vector3.yAxis * 4, 9)
		if under then
			KitModels.erupt(
				if index % 2 == 0 then "Rock_ChunkA" else "Rock_ChunkB",
				tall * (0.7 + math.random() * 0.6),
				KitModels.rooted(
					under - Vector3.yAxis * 0.4,
					under - centre,
					34,
					math.random(0, 359)
				),
				(index % 3) * 2 * FxKit.FRAME,
				hold,
				if index % 3 == 0 then ROCK_HOT else ROCK,
				Enum.Material.Slate,
				0
			)
		end
	end
end

-- A flame trail on a moving body: the Blastoff's own, the falling meteor's, a fighter set alight.
local function burn(part: BasePart, key: string, seconds: number, big: number)
	Common.stream(part, key, seconds, Vector3.zero, function(at)
		local fire = Common.emitter(at, "Fire", Tex.Wisp, 60)
		Common.flame(fire, 0.25, 0.4)
		fire.Size = NumberSequence.new(
			curve(0, big, big * 0.3, 0.4, big * 1.5, big * 0.4, 1, big * 0.5, big * 0.2)
		)
		fire.Speed = NumberRange.new(2, 7)
		fire.SpreadAngle = Vector2.new(180, 180)
		fire.Rotation = NumberRange.new(0, 360)
		fire.LightEmission = 0.35
		fire.Brightness = 2
		fire.Color = ramp(TONES.bright, TONES.body, TONES.deep, TONES.ink)
		local dark = Common.emitter(at, "Dark", Tex.Smoke, 24)
		Common.smoke(dark, TONES.ink, 0.5, 0.9)
		dark.Color = ramp(TONES.ink, TONES.smoke)
		dark.LightEmission = 0
		dark.ZOffset = -2
		dark.Size = NumberSequence.new(curve(0, big * 1.1, big * 0.3, 1, big * 2.4, big * 0.5))
		dark.Speed = NumberRange.new(1, 4)
		dark.Transparency = fade(0, 0.2, 0.5, 0.4, 1, 1)
		local core = Common.emitter(at, "Core", Tex.Glow, 50)
		core.Lifetime = NumberRange.new(0.12, 0.18)
		core.Size = NumberSequence.new(curve(0, big * 0.6, big * 0.1, 1, 0, 0))
		core.Brightness = 3
		core.ZOffset = 1
		core.Color = ramp(TONES.white, TONES.bright)
		local sparks = Common.emitter(at, "Embers", Tex.Leaf, 36)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Speed = NumberRange.new(6, 18)
		sparks.Drag = 3
		sparks.Lifetime = NumberRange.new(0.5, 0.9)
		sparks.Rotation = NumberRange.new(0, 360)
		sparks.Size = NumberSequence.new(curve(0, 0.5, 0.2, 1, 0.15, 0.08))
		sparks.Acceleration = Vector3.new(0, 8, 0)
		sparks.LightEmission = 0.5
		sparks.Brightness = 2.2
		sparks.Color = ramp(TONES.white, TONES.bright, TONES.body)
		return { fire, dark, core, sparks }
	end)
end

-- BLASTOFF: the explosion under the body ----------------------------------------------------------------
local blasts = FxKit.pool("HT_InfernoBlastFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_InfernoBlastFloor", Vector3.new(6, 0.2, 6), parent)
	local onFloor = FxKit.attach(floor, Vector3.new(0, 0.1, 0))
	local low = FxKit.attach(floor, Vector3.new(0, 2.5, 0))

	T.flash(add, low, 7, 0)
	T.stain(add, onFloor, 12, 1.4)
	scorch(add, onFloor, 7, 1.6)
	T.floorRing(add, onFloor, "Ring", 0, 3, 12, 1)
	T.floorRing(add, onFloor, "SecondRing", 3, 2, 9, 2)
	T.floorRing(add, onFloor, "ThirdRing", 7, 3, 14, 3)
	ringColumn(add, floor, "Column", 2.6, { 5, 6.5, 4.5 })
	local fire = flames(add, floor, 14, 0, 4.5, NumberRange.new(10, 30), 60)
	fire.EmissionDirection = Enum.NormalId.Top
	T.darkSmoke(add, low, 10, 1, 3.6)
	T.haze(add, low, 5, 3, 2.6)
	T.rays(add, floor, 3, 4)
	T.lens(add, low, 18, 1, 70)
	T.chips(add, low, 16, 1, 70, NumberRange.new(40, 80), 1)
	T.motes(add, low, 14, 2)

	return { floor = floor }
end)

-- METEOR: the ring that closes on the spot ----------------------------------------------------------------
local function buildMark(radius: number, seconds: number)
	return function(parent: Folder, add: FxKit.Add)
		local floor = FxKit.hiddenPart(
			"HT_InfernoMarkFloor",
			Vector3.new(radius * 1.6, 0.2, radius * 1.6),
			parent
		)
		local onFloor = FxKit.attach(floor, Vector3.new(0, 0.15, 0))

		-- The edge of the blast, there the whole time; a second ring closing on the middle; the floor
		-- darkening and then glowing as it comes.
		local edge = add(onFloor, "Edge", Tex.Circle, 1, 0, keys(0, radius * 0.96, 1, radius), {
			flat = true,
		})
		edge.Lifetime = NumberRange.new(seconds)
		edge.Rotation = NumberRange.new(0, 360)
		edge.Brightness = 2.6
		edge.LightEmission = 0.5
		edge.Color = ramp(TONES.bright, TONES.body, TONES.white)
		edge.Transparency = fade(0, 0.5, 0.15, 0.05, 0.9, 0, 1, 0.4)
		local closing = add(onFloor, "Closing", Tex.Circle, 1, 0, keys(0, radius, 1, 1.5), {
			flat = true,
		})
		closing.Lifetime = NumberRange.new(seconds)
		closing.Rotation = NumberRange.new(0, 360)
		closing.Brightness = 2.2
		closing.LightEmission = 0.5
		closing.Color = ramp(TONES.body, TONES.bright, TONES.white)
		closing.Transparency = fade(0, 0.3, 1, 0)
		local shade =
			add(onFloor, "Shade", Tex.Glow, 1, 0, keys(0, radius * 0.9, 1, radius * 1.05), {
				flat = true,
			})
		shade.Lifetime = NumberRange.new(seconds)
		shade.LightEmission = 0
		shade.Color = ramp(TONES.ink, TONES.deep)
		shade.Transparency = fade(0, 0.8, 0.5, 0.45, 1, 0.3)
		-- Embers rising off the floor inside it.
		for index, delay in { 0, 12, 24 } do
			local rising = add(
				floor,
				"Rising" .. index,
				Tex.Leaf,
				18,
				delay,
				curve(0, 0.5, 0.2, 1, 0.15, 0.1),
				{ speed = NumberRange.new(10, 24) }
			)
			rising.EmissionDirection = Enum.NormalId.Top
			rising.Orientation = Enum.ParticleOrientation.VelocityParallel
			rising.Lifetime = NumberRange.new(0.35, 0.55)
			rising.LightEmission = 0.5
			rising.Brightness = 2.2
			rising.Color = ramp(TONES.white, TONES.bright, TONES.body)
			rising.Transparency = fade(0, 0, 0.7, 0.2, 1, 1)
		end
		return { floor = floor }
	end
end

local markPools: { [string]: FxKit.Pool } = {}

-- METEOR: the blast ----------------------------------------------------------------------------------------
local impacts = FxKit.pool("HT_InfernoMeteorFx", 2, function(parent, add)
	local floor = FxKit.hiddenPart("HT_InfernoMeteorFloor", Vector3.new(14, 0.2, 14), parent)
	local onFloor = FxKit.attach(floor, Vector3.new(0, 0.1, 0))
	local low = FxKit.attach(floor, Vector3.new(0, 4, 0))
	local high = FxKit.attach(floor, Vector3.new(0, 12, 0))
	local face = FxKit.hiddenPart("HT_InfernoMeteorFace", Vector3.new(0.2, 0.2, 0.2), parent)

	-- 0 f. White first: the flash and the star.
	T.flash(add, low, 18, 0)
	local star = T.star(add, face, 15)

	-- 0 f. The floor: stain, scorch, three rings out to its edge.
	T.stain(add, onFloor, 24, 2.2)
	scorch(add, onFloor, 11, 2.4)
	T.floorRing(add, onFloor, "Ring", 0, 5, 26, 1)
	T.floorRing(add, onFloor, "SecondRing", 4, 4, 20, 2)
	T.floorRing(add, onFloor, "ThirdRing", 9, 6, 30, 3)

	-- 1 f. The column of rings over it, widest in the middle.
	ringColumn(add, floor, "Column", 3.4, { 8, 11, 12, 9, 6 })

	-- 0 f. Flame: a wall of it rolling outward along the floor, and a mass of it rising.
	local wall = flames(add, floor, 22, 0, 6, NumberRange.new(30, 60), 85)
	wall.EmissionDirection = Enum.NormalId.Top
	wall.Drag = 5
	local rising = flames(add, low, 16, 2, 8, NumberRange.new(14, 30), 35)
	rising.Acceleration = Vector3.new(0, 14, 0)

	-- 1 f. Oxblood smoke: a cap of it rising over the blast, more rolling out, then haze.
	T.darkSmoke(add, high, 12, 2, 6)
	T.darkSmoke(add, low, 14, 0, 5)
	T.haze(add, low, 8, 6, 4)

	-- 0 f. Rays.
	T.rays(add, floor, 5, 7)

	-- 1 f. Big lens embers, chips, and blue motes that outlast it all.
	T.lens(add, low, 34, 1, 75)
	T.chips(add, low, 30, 1, 70, NumberRange.new(60, 120), 1.6)
	T.motes(add, low, 28, 2)
	T.motes(add, high, 16, 20)

	return { floor = floor, face = face, star = star }
end)

-- THE HIT on whoever a blast throws, and the kit's own punch --------------------------------------------------
local function buildHit(long: number, dark: number, sparks: number)
	return function(parent: Folder, add: FxKit.Add)
		local face = FxKit.hiddenPart("HT_InfernoHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
		local centre = FxKit.attach(face)
		T.flash(add, centre, long * 0.6, 0)
		local star = T.star(add, face, long)
		for index, delay in { 2, 5 } do
			local ring = add(
				centre,
				"Ring" .. index,
				Tex.Circle,
				1,
				delay,
				keys(
					0,
					long * 0.2,
					0.35,
					long * (0.45 + index * 0.15),
					1,
					long * (0.6 + index * 0.15)
				)
			)
			Common.ring(ring, 0.28)
			ring.Brightness = 2.4
			ring.Color = if index == 1
				then ramp(TONES.white, TONES.bright)
				else ramp(TONES.bright, TONES.body, TONES.deep)
		end
		flames(add, centre, sparks, 0, long * 0.4, NumberRange.new(8, 22), 180)
		T.darkSmoke(add, centre, dark, 0, long * 0.28)
		T.lens(add, centre, sparks, 1, 180)
		T.motes(add, centre, math.ceil(sparks / 2), 2)
		return { face = face, star = star }
	end
end

local hits = FxKit.pool("HT_InfernoHitFx", 4, buildHit(9, 6, 14))
local punches = FxKit.pool("HT_InfernoPunchFx", 4, buildHit(4.5, 2, 6))

--- The Blastoff: the explosion under `root` as it leaves, and fire trailing from it in the air.
function InfernoFx.blastoff(root: BasePart, _direction: Vector3)
	local ground = FxKit.floorUnder(root.Position, 9)
	local feet = ground or root.Position - Vector3.yAxis * 2.8
	local rig = blasts.take()
	local floor = rig.parts.floor :: Part
	floor.CFrame = CFrame.new(feet + Vector3.yAxis * 0.1)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)
	if ground then
		rim(ground, 6, 4.5, 3.5, 0.7)
		chunks(ground, 9, 46, 1.3)
	end
	burn(root, "InfernoBlast", 0.6, 2.2)
end

--- The Meteor: the ring that closes on `centre` for `windup` + `fall` seconds, the rock coming
--- down through the last `fall` of them, and the blast when it lands. `radius` is the blast's.
function InfernoFx.meteor(centre: Vector3, windup: number, fall: number, radius: number)
	local slow = FxKit.slowness()
	local ground = FxKit.floorUnder(centre + Vector3.yAxis * 6, 20) or centre - Vector3.yAxis * 3
	local seconds = windup + fall
	local key = `{radius}:{seconds}`
	local marks = markPools[key]
	if not marks then
		marks = FxKit.pool("HT_InfernoMarkFx", 2, buildMark(radius, seconds))
		markPools[key] = marks
	end
	local mark = marks.take()
	local markFloor = mark.parts.floor :: Part
	markFloor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
	FxKit.fire(mark, 1)

	-- The rock, out of the sky at a slant.
	task.delay(windup * slow, function()
		local from = ground + Vector3.new(16, 62, -10)
		local rock = KitModels.throw(
			"Rock_Meteor",
			9,
			from,
			(ground + Vector3.yAxis * 3 - from) / math.max(fall, 0.05),
			0,
			fall,
			ROCK_HOT,
			Enum.Material.Slate,
			true
		)
		burn(rock, "InfernoMeteor", fall, 5)
	end)

	task.delay(seconds * slow, function()
		local rig = impacts.take()
		local floor = rig.parts.floor :: Part
		local face = rig.parts.face :: Part
		floor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
		face.CFrame = FxKit.screenAt(ground + Vector3.yAxis * 6)
		Common.placeAll(rig.parts.star, math.random() * 360)
		FxKit.fire(rig, 1)
		rim(ground, 9, radius * 0.5, 6, 1.3)
		rim(ground, 7, radius * 0.25, 4, 1.1)
		chunks(ground, 18, 78, 2)
	end)
end

--- A blast throwing `target`: fire bursts on them, and they burn for a moment as they go.
function InfernoFx.hit(target: BasePart, _away: Vector3)
	local rig = hits.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, 1)
	burn(target, "InfernoBurn", 0.9, 1.8)
end

--- The Inferno kit's own punch landing at `position`: a burst of fire. `strong` is a heavy hit.
function InfernoFx.punch(position: Vector3, strong: boolean)
	local rig = punches.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(position)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, if strong then 1.5 else 1)
	if strong then
		chunks(position - Vector3.yAxis, 3, 30, 0.8)
	end
end

--- The Inferno kit's own landing (a kick or a dive reaching the floor at `position`): a ring of
--- fire and a rim of rock.
function InfernoFx.landing(position: Vector3)
	local rig = blasts.take()
	local floor = rig.parts.floor :: Part
	floor.CFrame = CFrame.new(position + Vector3.yAxis * 0.1)
	FxKit.fire(rig, 0.8)
	rim(position, 6, 4, 3, 0.6)
	chunks(position, 7, 40, 1.1)
end

function InfernoFx.preload()
	blasts.preload()
	impacts.preload()
	hits.preload()
	punches.preload()
end

return InfernoFx
