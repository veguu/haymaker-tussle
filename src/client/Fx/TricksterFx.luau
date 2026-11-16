--!strict
-- TricksterFx - the Trickster kit's effects (Fx/KitFxCommon, Fx/FxKit): the Flip (Q) and the
-- Backfist (R). All particles. Decoration on this client only: nothing here can collide, block a ray
-- or affect gameplay.
--
-- Sleight of hand, in pink:
--   vanish     a four-point star for four or five frames, as a weapon swap is hidden (Scrippage
--              "Weapon Switcher", YouTube UOoYfyJhQN8, f164-168, f241-244), under a puff of smoke and
--              petals that hide the body (Divergent Vfx "Acheron Ultimate" f163-186).
--   petals     fly a character height in a frame and stop, then hang (Nyght "Light Moveset"
--              f4789-4791); sparkles come after, and stay where they appear (Scrippage f891-940).
--   slash ring a ring round the body whose bright part goes half way round in ten frames
--              (Scrippage f889-905), broken into crescents (xander22 f474), with one thick crescent
--              sweeping over it (Nyght f2896-2899: three-quarters of a turn in four frames).
--   star hit   a four-point star with a long vertical arm (Scrippage f996; Nyght f3886).
--
-- FLIP: a star and a puff where you were, petals left hanging, sparkles along your arc, and a small
-- ring where you land.
-- BACKFIST: a glint on the fist, a spinning ring of crescents all round you as it strikes (hit or
-- miss), and a star burst on everyone it throws.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)

local TricksterFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local P = Common.Palettes.Trickster
local TWINKLE = curve(0, 0, 0, 0.3, 0.7, 0.3, 1, 0, 0)

local function sparkles(add: FxKit.Add, host: Instance, amount: number, delay: number)
	local made = add(host, "Sparkles" .. delay, Tex.Star, amount, delay, TWINKLE)
	Common.twinkle(made, 0.3, 0.55)
	made.Color = ramp(P.white, P.bright)
	return made
end

local function petals(add: FxKit.Add, host: Instance, amount: number, delay: number)
	local made = add(
		host,
		"Petals",
		Tex.Leaf,
		amount,
		delay,
		curve(0, 0.5, 0.2, 1, 0.25, 0.1),
		{ speed = NumberRange.new(55, 100) }
	)
	Common.thrown(made, 180, 14, 0.5, 0.8)
	made.Rotation = NumberRange.new(0, 360)
	made.RotSpeed = NumberRange.new(-120, 120)
	made.Acceleration = Vector3.new(0, -7, 0)
	made.LightEmission = 0.7
	made.Brightness = 1.8
	made.Color = ramp(P.white, P.bright, P.body)
	return made
end

-- The big four-point star with a long vertical arm, for a few frames.
local function bigStar(add: FxKit.Add, at: Attachment, big: number, delay: number)
	local star = add(at, "Star" .. delay, Tex.Star, 1, delay, keys(0, big, 0.4, big * 0.7, 1, 0))
	Common.twinkle(star, 0.1, 0.1)
	star.Color = ramp(P.white, P.bright)
	local arm = add(at, "Arm" .. delay, Tex.Leaf, 1, delay, keys(0, big * 0.6, 1, big * 0.75))
	Common.flash(arm, 0.1)
	arm.Rotation = NumberRange.new(90)
	arm.Squash = fade(0, -1.4, 1, -2.2)
	arm.Color = ramp(P.white, P.bright)
end

local glints = FxKit.pool("HT_TricksterGlintFx", 3, function(parent, add)
	local centre = FxKit.hiddenPart("HT_TricksterGlint", Vector3.new(0.2, 0.2, 0.2), parent)
	bigStar(add, FxKit.attach(centre), 2, 0)
	return { centre = centre }
end)

-- FLIP: where you were -----------------------------------------------------------------------------------
local vanishes = FxKit.pool("HT_TricksterFlipFx", 3, function(parent, add)
	local centre = FxKit.hiddenPart("HT_TricksterFlip", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(centre)
	local area = FxKit.hiddenPart("HT_TricksterFlipArea", Vector3.new(6, 5, 6), parent)

	-- 0 f. The star and a white spot.
	bigStar(add, at, 3.4, 0)
	local spot = add(at, "Spot", Tex.Glow, 1, 0, keys(0, 1.6, 0.3, 2.4, 1, 1))
	Common.flash(spot, 0.08)
	spot.Color = ramp(P.white, P.bright)

	-- 0 f. The puff that hides the body, and a ring out of it.
	local puff = add(
		at,
		"Puff",
		Tex.Smoke,
		8,
		0,
		curve(0, 1.8, 0.5, 1, 4, 1),
		{ speed = NumberRange.new(3, 9) }
	)
	Common.smoke(puff, P.smoke, 0.45, 0.7)
	puff.SpreadAngle = Vector2.new(180, 180)
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 1, 0.35, 3.4, 1, 4.2))
	Common.ring(ring, 0.22)
	ring.Color = ramp(P.bright, P.body)

	-- 1 f. Petals that fly a character height and stop; 4 f: sparkles that stay.
	petals(add, at, 18, 1)
	sparkles(add, area, 7, 4)

	return { centre = centre, area = area }
end)

-- FLIP: the landing ---------------------------------------------------------------------------------------
local landings = FxKit.pool("HT_TricksterLandFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_TricksterLandFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)
	local area = FxKit.hiddenPart("HT_TricksterLandArea", Vector3.new(5, 2, 5), parent)
	local ring =
		add(onFloor, "Ring", Tex.Circle, 1, 0, keys(0, 1, 0.3, 3.4, 1, 4.2), { flat = true })
	Common.ring(ring, 0.22)
	ring.Color = ramp(P.white, P.bright)
	sparkles(add, area, 6, 1)
	return { floor = floor, area = area }
end)

-- BACKFIST: the ring of crescents all round ---------------------------------------------------------------
local spins = FxKit.pool("HT_TricksterBackfistFx", 2, function(parent, add)
	-- Lies level at the chest: flat layers on it ring the body.
	local level = FxKit.hiddenPart("HT_TricksterBackfistLevel", Vector3.new(0.2, 0.2, 0.2), parent)
	local onLevel = FxKit.attach(level)
	local area = FxKit.hiddenPart("HT_TricksterBackfistArea", Vector3.new(15, 3, 15), parent)

	-- 0 f. The ring of crescents, spinning fast as it opens out to the reach: pink, with a white-hot
	-- one inside it.
	local wheel =
		add(onLevel, "Wheel", Tex.Pinwheel, 1, 0, keys(0, 4, 0.25, 8.6, 1, 9.8), { flat = true })
	wheel.Lifetime = NumberRange.new(0.24)
	wheel.Rotation = NumberRange.new(0, 360)
	wheel.RotSpeed = NumberRange.new(900)
	wheel.LightEmission = 0.7
	wheel.Brightness = 1.8
	wheel.Color = ramp(P.bright, P.body, P.deep)
	wheel.Transparency = fade(0, 0, 0.6, 0.2, 1, 1)
	local hot = add(
		onLevel,
		"WheelCore",
		Tex.Pinwheel,
		1,
		0,
		keys(0, 3.4, 0.25, 7.4, 1, 8.4),
		{ flat = true }
	)
	hot.Lifetime = NumberRange.new(0.18)
	hot.Rotation = NumberRange.new(0, 360)
	hot.RotSpeed = NumberRange.new(900)
	hot.LightEmission = 0.8
	hot.Brightness = 1.8
	hot.Color = ramp(P.white, P.bright)
	hot.Transparency = fade(0, 0, 0.6, 0.15, 1, 1)
	-- 2 f. A thin ring past it.
	local edge =
		add(onLevel, "Edge", Tex.Circle, 1, 2, keys(0, 4, 0.3, 9, 1, 10.5), { flat = true })
	Common.ring(edge, 0.22)
	edge.Color = ramp(P.white, P.bright)

	-- 3 f. Sparkles left all round; lens sparks thrown out level.
	sparkles(add, area, 10, 3)
	local sparks = add(
		onLevel,
		"LensSparks",
		Tex.Leaf,
		16,
		2,
		curve(0, 0.6, 0.25, 1, 0.3, 0.1),
		{ speed = NumberRange.new(45, 80) }
	)
	Common.thrown(sparks, 180, 9, 0.12, 0.2)
	sparks.SpreadAngle = Vector2.new(180, 8)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Squash = NumberSequence.new(-0.9)
	sparks.Brightness = 2.5
	sparks.Color = ramp(P.white, P.bright, P.body)

	return { level = level, area = area }
end)

-- BACKFIST: the star burst on everyone it throws ------------------------------------------------------------
local STAR_SHAPE = { 0, 1, 0.35, 0.85, 1, 0.15 }

local hits = FxKit.pool("HT_TricksterHitFx", 4, function(parent, add)
	local face = FxKit.hiddenPart("HT_TricksterHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
	local centre = FxKit.attach(face)
	local area = FxKit.hiddenPart("HT_TricksterHitArea", Vector3.new(5, 5, 5), parent)

	bigStar(add, centre, 4.2, 0)
	local core = add(centre, "Core", Tex.Glow, 1, 0, keys(0, 1.6, 0.3, 2.4, 1, 1))
	Common.flash(core, 0.09)
	core.Color = ramp(P.white, P.bright)
	local deep = Common.pieces(
		add,
		face,
		"DeepSpike",
		Tex.Needle,
		0,
		0,
		Common.starSpecs(6, 2.5, 5.5, -1, 71),
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
		Common.starSpecs(10, 2, 6.5, -1.3, 43),
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
	local ring = add(centre, "Ring", Tex.Circle, 1, 3, keys(0, 1.2, 0.35, 3.6, 1, 4.4))
	Common.ring(ring, 0.24)
	ring.Color = ramp(P.bright, P.body)
	petals(add, centre, 10, 1)
	sparkles(add, area, 8, 3)
	local puff = add(
		centre,
		"Puff",
		Tex.Smoke,
		3,
		3,
		curve(0, 1.2, 0.3, 1, 2.6, 0.6),
		{ speed = NumberRange.new(2, 6) }
	)
	Common.smoke(puff, P.smoke, 0.4, 0.6)
	puff.SpreadAngle = Vector2.new(180, 180)
	return { face = face, area = area, deep = deep, bright = bright }
end)

--- A glint at `position`: the cue on the fist before a Backfist.
function TricksterFx.glint(position: Vector3)
	local rig = glints.take()
	local centre = rig.parts.centre :: Part
	centre.CFrame = CFrame.new(position)
	FxKit.fire(rig, 1)
end

--- The Flip: the star, puff and petals where `root` was, and sparkles along its arc for `seconds`.
function TricksterFx.flip(root: BasePart, seconds: number)
	local rig = vanishes.take()
	local centre = rig.parts.centre :: Part
	local area = rig.parts.area :: Part
	centre.CFrame = CFrame.new(root.Position)
	area.CFrame = CFrame.new(root.Position)
	FxKit.fire(rig, 1)

	Common.stream(root, "TricksterFlip", seconds, Vector3.zero, function(at)
		local stars = Common.emitter(at, "Sparkles", Tex.Star, 22)
		Common.twinkle(stars, 0.35, 0.6)
		stars.Size = NumberSequence.new(TWINKLE)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Speed = NumberRange.new(0, 3)
		stars.Color = ramp(P.white, P.bright)
		local lines = Common.emitter(at, "Lines", Tex.Needle, 30)
		lines.Orientation = Enum.ParticleOrientation.VelocityParallel
		lines.EmissionDirection = Enum.NormalId.Back
		lines.SpreadAngle = Vector2.new(12, 12)
		lines.Speed = NumberRange.new(25, 45)
		lines.Lifetime = NumberRange.new(0.1, 0.14)
		lines.Squash = NumberSequence.new(-1.5)
		lines.Size = NumberSequence.new(curve(0, 0.8, 0.25, 1, 0.3, 0.1))
		lines.Brightness = 2
		lines.Color = ramp(P.white, P.bright, P.body)
		lines.Transparency = fade(0, 0.1, 1, 1)
		local leaves = Common.emitter(at, "Petals", Tex.Leaf, 16)
		leaves.SpreadAngle = Vector2.new(180, 180)
		leaves.Speed = NumberRange.new(2, 6)
		leaves.Lifetime = NumberRange.new(0.5, 0.7)
		leaves.Rotation = NumberRange.new(0, 360)
		leaves.RotSpeed = NumberRange.new(-120, 120)
		leaves.Acceleration = Vector3.new(0, -10, 0)
		leaves.Size = NumberSequence.new(curve(0, 0.45, 0.15, 1, 0.2, 0.08))
		leaves.LightEmission = 0.7
		leaves.Brightness = 1.8
		leaves.Color = ramp(P.bright, P.body)
		leaves.Transparency = fade(0, 0, 0.7, 0.15, 1, 1)
		return { stars, lines, leaves }
	end)
end

--- The Flip coming down at `position` on the floor.
function TricksterFx.land(position: Vector3)
	local rig = landings.take()
	local floor = rig.parts.floor :: Part
	local area = rig.parts.area :: Part
	floor.CFrame = CFrame.new(position + Vector3.yAxis * 0.1)
	area.CFrame = CFrame.new(position + Vector3.yAxis * 1.2)
	FxKit.fire(rig, 1)
end

--- The Backfist striking, hit or miss: the ring of crescents all round `root`, which faces `direction`.
function TricksterFx.strike(root: BasePart, direction: Vector3)
	local way = FxKit.flat(direction)
	local rig = spins.take()
	local level = rig.parts.level :: Part
	local area = rig.parts.area :: Part
	local chest = root.Position + Vector3.yAxis * 0.4
	level.CFrame = CFrame.lookAt(chest, chest + way)
	area.CFrame = CFrame.new(chest)
	FxKit.fire(rig, 1)
end

--- The Backfist throwing `target`.
function TricksterFx.hit(target: BasePart, _away: Vector3)
	local rig = hits.take()
	local face = rig.parts.face :: Part
	local area = rig.parts.area :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	area.CFrame = CFrame.new(target.Position)
	Common.place(rig.parts.deep, math.random() * 360, 1, 1)
	Common.place(rig.parts.bright, math.random() * 360, 1, 1)
	FxKit.fire(rig, 1)
end

function TricksterFx.preload()
	glints.preload()
	vanishes.preload()
	landings.preload()
	spins.preload()
	hits.preload()
end

return TricksterFx
