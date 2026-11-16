--!strict
-- DragonFx - the Dragon kit's effects (Fx/KitFxCommon, Fx/FxKit): the Ascend (Q) and the Breath (R).
-- All particles. Decoration on this client only: nothing here can collide, block a ray or affect
-- gameplay.
--
-- The Breath is built the way Venomec's "Stylized Kamehameha" is (YouTube GZOYLWGYCys), in violet:
--   charge     it changes look instead of growing: a flash and a serrated ball, rings closing in front
--              of a fading disc, a sweeping spoked wheel, then a calm ring for the last frames
--              (f604-662).
--   launch     a one-frame flare and a muzzle spike two to three character heights long (f706), a dome
--              with ring bands and black barbs (f669-672), and a kick of the camera (f664-669).
--   beam       a fixed length, both ends larger than the middle (f976-981); bright lobes with dark
--              pinches between them flowing to the far end under a constant outline (f978-987);
--              four-point stars on its edge that stay two or three frames (f978-983); a far end that
--              flickers between a ball and a spiky star (f704-715) and throws dark specks (f704-709);
--              light on the floor along its line (f666, f945-985).
--   end        a one-frame flare (f186, f453, f737, f1010).
-- The Ascend takes its feathers from Nyght's "Light Moveset" (5NqNGoV3a30): about forty petals fly
-- one character height in a frame and stop (f4789-4791), a dome over the takeoff (f977), a four-point
-- star with a long vertical arm (f3886), soft dots that drift without gravity (f326, f998).
--
-- ASCEND: two wings of feathers beat down as you leave the floor, feathers scatter and hang, and thin
-- lines fall away under you as you rise.
-- BREATH: the charge in front of your face through the windup, the beam when it strikes (hit or
-- miss), and a violet burst on everyone it reaches.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)

local DragonFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local P = Common.Palettes.Dragon
local BLACK = ColorSequence.new(FxKit.BLACK)
local INK = Color3.fromRGB(26, 10, 60)
local PARK = CFrame.new(0, -1000, 0)
local BEAM_SPEED = 150 -- studs a second the beam's lobes travel
local BEAM_SECONDS = 0.3

local function dots(add: FxKit.Add, host: Instance, amount: number, delay: number)
	local made = add(
		host,
		"Dots",
		Tex.Glow,
		amount,
		delay,
		curve(0, 0.2, 0.08, 1, 0, 0),
		{ speed = NumberRange.new(2, 5) }
	)
	Common.embers(made, 0.8, 1.2)
	made.Color = ColorSequence.new(P.bright)
	return made
end

-- ASCEND: the takeoff ----------------------------------------------------------------------------------
-- A wing is four feathers fanned from the shoulder. Each: its angle on screen (0 is screen-right), how
-- far out its middle sits, its Size, and how fast it turns (the downbeat).
local WING_LEFT =
	{ { 122, 3, 3, 180 }, { 142, 3.3, 3.2, 180 }, { 162, 3.3, 3, 180 }, { 182, 3, 2.6, 180 } }
local WING_RIGHT =
	{ { 58, 3, 3, -180 }, { 38, 3.3, 3.2, -180 }, { 18, 3.3, 3, -180 }, { -2, 3, 2.6, -180 } }
local WING_SHAPE = { 0, 0.6, 0.15, 1, 1, 0.9 }

local takeoffs = FxKit.pool("HT_DragonAscendFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_DragonAscendFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)
	local low = FxKit.attach(floor, Vector3.new(0, 1.5, 0))
	-- Turned to the camera at the shoulders: the wings are laid out on it.
	local face = FxKit.hiddenPart("HT_DragonAscendFace", Vector3.new(0.2, 0.2, 0.2), parent)
	local centre = FxKit.attach(face)

	local function wing(name: string, specs: { { number } }, hot: boolean)
		return Common.pieces(add, face, name, Tex.Leaf, 0, 0, specs, WING_SHAPE, function(emitter)
			emitter.Lifetime = NumberRange.new(0.24)
			emitter.Squash = NumberSequence.new(-0.5)
			emitter.Transparency = fade(0, 0, 0.6, 0.15, 1, 1)
			if hot then
				emitter.Brightness = 3
				emitter.ZOffset = 1.2
				emitter.Color = ramp(P.white, P.bright)
			else
				emitter.LightEmission = 0.45
				emitter.Brightness = 1.6
				emitter.ZOffset = 0.6
				emitter.Color = ramp(P.bright, P.body, P.deep)
			end
		end)
	end
	local function cores(specs: { { number } }): { { number } }
		return {
			{ specs[2][1], specs[2][2] * 0.9, specs[2][3] * 0.7, specs[2][4] },
			{ specs[3][1], specs[3][2] * 0.9, specs[3][3] * 0.7, specs[3][4] },
		}
	end
	-- 0 f. The wings: violet feathers with white-hot ones over the middle two.
	local wings = {
		wing("LeftFeather", WING_LEFT, false),
		wing("RightFeather", WING_RIGHT, false),
		wing("LeftCore", cores(WING_LEFT), true),
		wing("RightCore", cores(WING_RIGHT), true),
	}

	-- 0 f. On the floor: a ring, a low dome, dust.
	local ring = add(
		onFloor,
		"Ring",
		Tex.Circle,
		1,
		0,
		keys(0, 2, 0.3, 6, 1, 7.5),
		{ flat = true, onFloor = true }
	)
	Common.ring(ring, 0.28)
	ring.Color = ramp(P.white, P.bright)
	local dome = add(low, "Dome", Tex.Dome, 1, 0, keys(0, 3, 0.2, 5.5, 1, 6), { onFloor = true })
	dome.Lifetime = NumberRange.new(0.2)
	dome.LightEmission = 0.7
	dome.Color = ramp(P.bright, P.body)
	dome.Transparency = fade(0, 0.4, 1, 1)
	local dust = add(
		onFloor,
		"Dust",
		Tex.Smoke,
		5,
		1,
		curve(0, 1.4, 0.3, 1, 3, 0.7),
		{ speed = NumberRange.new(4, 9), onFloor = true }
	)
	Common.smoke(dust, P.smoke, 0.4, 0.6)
	dust.SpreadAngle = Vector2.new(85, 85)

	-- 0 f. A tall thin ray and a four-point star.
	local ray = add(centre, "Ray", Tex.Leaf, 1, 0, keys(0, 2.8, 1, 3.4))
	Common.flash(ray, 0.2)
	ray.Rotation = NumberRange.new(90)
	ray.Squash = fade(0, -1.2, 1, -2.2)
	ray.Color = ramp(P.white, P.bright)
	local star = add(centre, "Star", Tex.Star, 1, 0, keys(0, 2.6, 0.4, 1.8, 1, 0))
	Common.twinkle(star, 0.14, 0.14)
	star.Color = ramp(P.white, P.bright)

	-- 1 f. Feathers that fly a character height and stop, then hang and sink.
	local feathers = add(
		centre,
		"Feathers",
		Tex.Leaf,
		26,
		1,
		curve(0, 0.5, 0.2, 1, 0.25, 0.1),
		{ speed = NumberRange.new(60, 110) }
	)
	Common.thrown(feathers, 180, 14, 0.5, 0.8)
	feathers.Rotation = NumberRange.new(0, 360)
	feathers.RotSpeed = NumberRange.new(-90, 90)
	feathers.Acceleration = Vector3.new(0, -6, 0)
	feathers.LightEmission = 0.7
	feathers.Brightness = 1.8
	feathers.Color = ramp(P.bright, P.body)

	-- 2 f. Soft dots that drift.
	dots(add, centre, 10, 2)

	return { floor = floor, face = face, wings = wings }
end)

-- BREATH: the charge ------------------------------------------------------------------------------------
local charges = FxKit.pool("HT_DragonChargeFx", 2, function(parent, add)
	local centre = FxKit.hiddenPart("HT_DragonCharge", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(centre)

	-- 0 f. Look one: a flash and a serrated ball (two four-point stars, one turned).
	local flash = add(at, "Flash", Tex.Glow, 1, 0, keys(0, 1.6, 1, 2))
	Common.flash(flash, 0.06)
	flash.Color = ramp(P.white, P.bright)
	for index, turned in { 0, 45 } do
		local teeth = add(at, "Teeth" .. index, Tex.Star, 1, 0, keys(0, 2.6, 1, 2))
		Common.twinkle(teeth, 0.08, 0.08)
		teeth.Rotation = NumberRange.new(turned)
		teeth.Color = ramp(P.white, P.bright)
	end

	-- 3 f. Look two: a disc that fades as three rings close on it.
	local disc = add(at, "Disc", Tex.Glow, 1, 3, keys(0, 2.4, 1, 1.2))
	disc.Lifetime = NumberRange.new(0.2)
	disc.LightEmission = 0.7
	disc.Color = ramp(P.bright, P.body)
	disc.Transparency = fade(0, 0.2, 1, 0.7)
	for index, delay in { 3, 7, 11 } do
		local closing = add(at, "Closing" .. index, Tex.Circle, 1, delay, keys(0, 3.2, 1, 0.6))
		Common.ring(closing, 0.15)
		closing.Color = ramp(P.bright, P.white)
		closing.Transparency = fade(0, 0.5, 0.6, 0.1, 1, 0.3)
	end

	-- 14 f. Look three: a spoked wheel sweeping round.
	local spokes = add(at, "Spokes", Tex.Star, 1, 14, keys(0, 3.2, 1, 2.2))
	Common.twinkle(spokes, 0.15, 0.15)
	spokes.RotSpeed = NumberRange.new(400)
	spokes.Color = ramp(P.white, P.bright)

	-- 20 f. The calm before it: one small ring and a white point.
	local calm = add(at, "Calm", Tex.Circle, 1, 20, keys(0, 1.5, 1, 1.4))
	Common.ring(calm, 0.12)
	calm.Brightness = 2.5
	local point = add(at, "Point", Tex.Glow, 1, 21, keys(0, 0.9, 1, 0.7))
	Common.flash(point, 0.1)

	return { centre = centre }
end)

-- BREATH: the beam --------------------------------------------------------------------------------------
local function buildBeam(length: number)
	return function(parent: Folder, add: FxKit.Add)
		-- At the mouth, its front face the way the beam goes.
		local muzzle = FxKit.hiddenPart("HT_DragonBeamMuzzle", Vector3.new(0.8, 0.8, 0.2), parent)
		local mouth = FxKit.attach(muzzle)
		local far = FxKit.attach(muzzle, Vector3.new(0, 0, -length))
		-- Its top face looks along the beam, so a flat layer on it stands square to the beam.
		local plate = FxKit.hiddenPart("HT_DragonBeamPlate", Vector3.new(0.2, 0.2, 0.2), parent)
		local onPlate = FxKit.attach(plate)
		-- The beam's whole length, for the stars on its edge; and the floor under it.
		local span = FxKit.hiddenPart("HT_DragonBeamSpan", Vector3.new(2.4, 2.4, length), parent)
		local under = FxKit.hiddenPart("HT_DragonBeamFloor", Vector3.new(1.6, 0.2, length), parent)

		-- 0 f. The launch: a flare across the beam, a spike along it, a four-point star.
		local across = add(mouth, "FlareAcross", Tex.Leaf, 1, 0, keys(0, 2, 1, 2.6))
		Common.flash(across, 0.05)
		across.Squash = NumberSequence.new(-1.4)
		across.Color = ramp(P.white, P.bright)
		local spike = add(mouth, "Spike", Tex.Leaf, 1, 0, keys(0, 2.6, 1, 3.2))
		Common.flash(spike, 0.1)
		spike.Squash = NumberSequence.new(-1.8)
		spike.Color = ramp(P.white, P.bright)
		local star = add(mouth, "Star", Tex.Star, 1, 0, keys(0, 3.4, 0.4, 2.4, 1, 0))
		Common.twinkle(star, 0.12, 0.12)
		star.Color = ramp(P.white, P.bright)

		-- 0 f. The dome at the mouth, two ring bands square to the beam, black barbs thrown back.
		local dome = add(mouth, "Dome", Tex.Dome, 1, 0, keys(0, 2, 0.3, 4, 1, 4.6))
		dome.Lifetime = NumberRange.new(0.18)
		dome.LightEmission = 0.7
		dome.Color = ramp(P.bright, P.body)
		dome.Transparency = fade(0, 0.3, 1, 1)
		local band =
			add(onPlate, "Band", Tex.Circle, 1, 0, keys(0, 1.4, 0.3, 3.6, 1, 4.4), { flat = true })
		Common.ring(band, 0.2)
		band.Color = ramp(P.white, P.bright)
		local second = add(
			onPlate,
			"SecondBand",
			Tex.Circle,
			1,
			3,
			keys(0, 1, 0.3, 2.6, 1, 3.2),
			{ flat = true }
		)
		Common.ring(second, 0.2)
		second.Color = ramp(P.bright, P.body)
		local barbs = add(
			muzzle,
			"Barbs",
			Tex.Needle,
			5,
			0,
			curve(0, 0.7, 0.2, 1, 0.3, 0.1),
			{ speed = NumberRange.new(30, 60) }
		)
		Common.streaks(barbs, -1.4, 0.08, 0.12)
		barbs.EmissionDirection = Enum.NormalId.Back
		barbs.SpreadAngle = Vector2.new(50, 50)
		barbs.LightEmission = 0
		barbs.Color = BLACK

		-- 19 f. The one-frame flare that ends it, at both ends.
		for index, host in { mouth, far } do
			local last = add(host, "EndFlare" .. index, Tex.Star, 1, 19, keys(0, 3, 1, 1.5))
			Common.twinkle(last, 0.06, 0.06)
			last.Color = ramp(P.white, P.bright)
		end

		-- THE BEAM ITSELF runs for BEAM_SECONDS (Common.run). Each lobe is thrown from the mouth and
		-- dies at the far end, so its size over its life is the beam's width along its length: wide,
		-- narrow, wide.
		local life = NumberRange.new(length / BEAM_SPEED)
		local function along(name: string, texture: string, rate: number): ParticleEmitter
			local made = Common.emitter(muzzle, name, texture, rate)
			made.Orientation = Enum.ParticleOrientation.VelocityParallel
			made.EmissionDirection = Enum.NormalId.Front
			made.Speed = NumberRange.new(BEAM_SPEED)
			made.Lifetime = life
			return made
		end
		local lobes = along("Lobes", Tex.Glow, 60)
		lobes.Squash = NumberSequence.new(-1.1)
		lobes.Size = NumberSequence.new(keys(0, 1.9, 0.5, 1.15, 1, 1.9))
		lobes.LightEmission = 0.7
		lobes.Color = ramp(P.bright, P.body)
		lobes.Transparency = NumberSequence.new(0.25)
		local hot = along("Core", Tex.Glow, 60)
		hot.Squash = NumberSequence.new(-1.1)
		hot.Size = NumberSequence.new(keys(0, 0.9, 0.5, 0.5, 1, 0.9))
		hot.Brightness = 3
		hot.ZOffset = 0.5
		hot.Color = ColorSequence.new(P.white)
		-- The dark pinches flowing along it.
		local pinches = along("Pinches", Tex.Leaf, 16)
		pinches.SpreadAngle = Vector2.new(2, 2)
		pinches.Squash = NumberSequence.new(-0.6)
		pinches.Size = NumberSequence.new(curve(0, 0.8, 0.2, 1, 0.8, 0.2))
		pinches.LightEmission = 0.1
		pinches.ZOffset = 0.8
		pinches.Color = ramp(P.deep, INK)
		pinches.Transparency = NumberSequence.new(0.2)
		-- Four-point stars on its edge, each for a few frames.
		local edge = Common.emitter(span, "EdgeStars", Tex.Star, 30)
		edge.Lifetime = NumberRange.new(0.05, 0.07)
		edge.Size = NumberSequence.new(curve(0, 1, 0.4, 1, 0.6, 0.3))
		edge.Rotation = NumberRange.new(0)
		edge.Brightness = 3
		edge.ZOffset = 1.5
		edge.Color = ramp(P.white, P.bright)
		-- The far end: a ball and a spiky star taking turns, and dark specks thrown on.
		local ball = Common.emitter(far, "FarBall", Tex.Glow, 30)
		ball.Lifetime = NumberRange.new(0.05)
		ball.Size = NumberSequence.new(curve(0, 2.4, 0.5, 1, 2.8, 0.5))
		ball.Brightness = 2.5
		ball.ZOffset = 1
		ball.Color = ramp(P.white, P.bright)
		local spiky = Common.emitter(far, "FarStar", Tex.Star, 14)
		spiky.Lifetime = NumberRange.new(0.05)
		spiky.Size = NumberSequence.new(curve(0, 3.2, 0.6, 1, 2.6, 0.6))
		spiky.Rotation = NumberRange.new(0, 90)
		spiky.Brightness = 3
		spiky.ZOffset = 1.2
		spiky.Color = ramp(P.white, P.bright)
		local specks = Common.emitter(far, "Specks", Tex.Leaf, 26)
		specks.Orientation = Enum.ParticleOrientation.VelocityParallel
		specks.EmissionDirection = Enum.NormalId.Front
		specks.SpreadAngle = Vector2.new(50, 50)
		specks.Speed = NumberRange.new(20, 45)
		specks.Lifetime = NumberRange.new(0.2, 0.35)
		specks.Size = NumberSequence.new(curve(0, 0.35, 0.12, 1, 0.15, 0.05))
		specks.LightEmission = 0
		specks.Color = ramp(P.deep, INK)
		-- Light on the floor along its line.
		local light = Common.emitter(under, "FloorLight", Tex.Glow, 24)
		light.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		light.EmissionDirection = Enum.NormalId.Top
		light.Speed = NumberRange.new(0.01)
		light.Lifetime = NumberRange.new(0.3)
		light.Size = NumberSequence.new(keys(0, 2.6, 1, 3.4))
		light.LightEmission = 0.45
		light.Color = ramp(P.body, P.deep)
		light.Transparency = fade(0, 0.6, 1, 1)

		return {
			muzzle = muzzle,
			plate = plate,
			span = span,
			under = under,
			across = across,
			spike = spike,
			running = { lobes, hot, pinches, edge, ball, spiky, specks, light },
		}
	end
end

local beamPools: { [number]: FxKit.Pool } = {}

local function beamPool(length: number): FxKit.Pool
	local pool = beamPools[length]
	if not pool then
		pool = FxKit.pool("HT_DragonBeamFx", 2, buildBeam(length))
		beamPools[length] = pool
	end
	return pool
end

-- BREATH: the burst on everyone it reaches ---------------------------------------------------------------
local STAR_SHAPE = { 0, 1, 0.35, 0.85, 1, 0.15 }

local hits = FxKit.pool("HT_DragonHitFx", 4, function(parent, add)
	local face = FxKit.hiddenPart("HT_DragonHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
	local centre = FxKit.attach(face)

	local core = add(centre, "Core", Tex.Glow, 1, 0, keys(0, 1.8, 0.3, 2.6, 1, 1.1))
	Common.flash(core, 0.1)
	core.Color = ramp(P.white, P.bright)
	local deep = Common.pieces(
		add,
		face,
		"DeepSpike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(6, 3, 6, -1, 53),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.18, 0.24)
			emitter.Squash = NumberSequence.new(-1)
			emitter.LightEmission = 0.4
			emitter.ZOffset = 0.6
			emitter.Color = ramp(P.body, P.deep)
			emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	)
	local bright = Common.pieces(
		add,
		face,
		"Spike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(10, 2.5, 7, -1.3, 17),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.14, 0.2)
			emitter.Squash = NumberSequence.new(-1.3)
			emitter.LightEmission = 0.5
			emitter.Brightness = 1.8
			emitter.ZOffset = 1.2
			emitter.Color = ramp(P.bright, P.body)
			emitter.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	)
	local barbs = Common.pieces(
		add,
		face,
		"Barb",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(4, 3, 5.5, -1.8, 29),
		STAR_SHAPE,
		function(emitter)
			emitter.Lifetime = NumberRange.new(0.12)
			emitter.Squash = NumberSequence.new(-1.8)
			emitter.LightEmission = 0
			emitter.ZOffset = 0.2
			emitter.Color = BLACK
			emitter.Transparency = fade(0, 0.05, 0.7, 0.15, 1, 1)
		end
	)

	-- 3 f and 6 f. Two ring bands. 2 f: lens sparks that fly briefly and stop; dots that drift. Smoke.
	for index, delay in { 3, 6 } do
		local band = add(
			centre,
			"Band" .. index,
			Tex.Circle,
			1,
			delay,
			keys(0, 1.2, 0.35, 3.2 + index * 0.6, 1, 4 + index * 0.7)
		)
		Common.ring(band, 0.24)
		band.Color = if index == 1 then ramp(P.white, P.bright) else ramp(P.bright, P.body)
	end
	local sparks = add(
		centre,
		"LensSparks",
		Tex.Leaf,
		12,
		2,
		curve(0, 0.55, 0.2, 1, 0.3, 0.1),
		{ speed = NumberRange.new(35, 65) }
	)
	Common.thrown(sparks, 180, 9, 0.12, 0.2)
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Squash = NumberSequence.new(-0.9)
	sparks.Brightness = 2.5
	sparks.Color = ramp(P.white, P.bright, P.body)
	dots(add, centre, 8, 2)
	local smoke = add(
		centre,
		"Smoke",
		Tex.Smoke,
		3,
		3,
		curve(0, 1.3, 0.3, 1, 2.8, 0.6),
		{ speed = NumberRange.new(2, 6) }
	)
	Common.smoke(smoke, P.smoke, 0.4, 0.65)
	smoke.SpreadAngle = Vector2.new(180, 180)

	return { face = face, deep = deep, bright = bright, barbs = barbs }
end)

--- The Ascend: wings beat down at `root` as it leaves, feathers scatter, and lines fall away under
--- it for `seconds`.
function DragonFx.ascend(root: BasePart, seconds: number)
	local ground = FxKit.floorUnder(root.Position, 8)
	local rig = takeoffs.take()
	local floor = rig.parts.floor :: Part
	local face = rig.parts.face :: Part
	if ground then
		floor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
	end
	face.CFrame = FxKit.screenAt(root.Position + Vector3.yAxis * 0.8)
	for _, feathers in rig.parts.wings do
		Common.place(feathers, 0, 1, 1)
	end
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)

	Common.stream(root, "DragonAscend", seconds, Vector3.new(0, -1.5, 0), function(at)
		local lines = Common.emitter(at, "Lines", Tex.Needle, 40)
		lines.Orientation = Enum.ParticleOrientation.VelocityParallel
		lines.EmissionDirection = Enum.NormalId.Bottom
		lines.SpreadAngle = Vector2.new(12, 12)
		lines.Speed = NumberRange.new(30, 60)
		lines.Lifetime = NumberRange.new(0.1, 0.14)
		lines.Squash = NumberSequence.new(-1.5)
		lines.Size = NumberSequence.new(curve(0, 0.8, 0.25, 1, 0.3, 0.1))
		lines.Brightness = 2
		lines.Color = ramp(P.white, P.bright)
		lines.Transparency = fade(0, 0.1, 1, 1)
		local feathers = Common.emitter(at, "Feathers", Tex.Leaf, 22)
		feathers.SpreadAngle = Vector2.new(180, 180)
		feathers.Speed = NumberRange.new(2, 6)
		feathers.Lifetime = NumberRange.new(0.5, 0.7)
		feathers.Rotation = NumberRange.new(0, 360)
		feathers.RotSpeed = NumberRange.new(-120, 120)
		feathers.Acceleration = Vector3.new(0, -12, 0)
		feathers.Size = NumberSequence.new(curve(0, 0.45, 0.15, 1, 0.2, 0.08))
		feathers.LightEmission = 0.7
		feathers.Brightness = 1.8
		feathers.Color = ramp(P.bright, P.body)
		feathers.Transparency = fade(0, 0, 0.7, 0.15, 1, 1)
		local motes = Common.emitter(at, "Dots", Tex.Glow, 16)
		Common.embers(motes, 0.6, 1)
		motes.Size = NumberSequence.new(curve(0, 0.2, 0.08, 1, 0, 0))
		motes.Speed = NumberRange.new(1, 4)
		motes.Color = ColorSequence.new(P.bright)
		return { lines, feathers, motes }
	end)
end

--- The Breath's windup: the charge at `position` (in front of the face).
function DragonFx.windup(position: Vector3)
	local rig = charges.take()
	local centre = rig.parts.centre :: Part
	centre.CFrame = CFrame.new(position)
	FxKit.fire(rig, 1)
end

--- The Breath striking, hit or miss: the beam from `position` along `direction`, `length` studs long.
function DragonFx.strike(position: Vector3, direction: Vector3, length: number)
	local way = FxKit.flat(direction)
	local rig = beamPool(length).take()
	local muzzle = rig.parts.muzzle :: Part
	local plate = rig.parts.plate :: Part
	local span = rig.parts.span :: Part
	local under = rig.parts.under :: Part
	muzzle.CFrame = CFrame.lookAt(position, position + way)
	plate.CFrame = CFrame.lookAt(position, position - way) * CFrame.Angles(-math.pi / 2, 0, 0)
	local middle = position + way * (length / 2)
	span.CFrame = CFrame.lookAt(middle, middle + way)
	local ground = FxKit.floorUnder(middle, 10)
	under.CFrame = if ground
		then CFrame.lookAt(ground + Vector3.yAxis * 0.15, ground + Vector3.yAxis * 0.15 + way)
		else PARK
	local angle = Common.screenAngle(way)
	local across = rig.parts.across :: ParticleEmitter
	local spike = rig.parts.spike :: ParticleEmitter
	across.Rotation = NumberRange.new(angle + 90)
	spike.Rotation = NumberRange.new(angle)
	FxKit.fire(rig, 1)
	Common.run(rig, rig.parts.running, 1, BEAM_SECONDS)
end

--- The Breath reaching `target`.
function DragonFx.hit(target: BasePart, _away: Vector3)
	local rig = hits.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	Common.place(rig.parts.deep, math.random() * 360, 1, 1)
	Common.place(rig.parts.bright, math.random() * 360, 1, 1)
	Common.place(rig.parts.barbs, math.random() * 360, 1, 1)
	FxKit.fire(rig, 1)
end

function DragonFx.preload(length: number)
	takeoffs.preload()
	charges.preload()
	beamPool(length).preload()
	hits.preload()
end

return DragonFx
