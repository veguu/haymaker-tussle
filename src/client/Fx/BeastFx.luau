--!strict
-- BeastFx - the Beast kit's effects, second version (Fx/KitFxCommon's thick layers, Fx/KitModels,
-- Fx/FxKit): the Pounce (Q) and its slam, the Frenzy (R), and the kit's own look for a punch and a
-- landing. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- The first version was thin glowing crescents and the user turned it down (2026-11-15). This one
-- follows the claw references they sent then:
--   claws      several thick crescents fanned one behind the next, pink-white in the middle and
--              red at the edge (MilkCup-VFX "Claw Slash VFX", YouTube IuAK5xNAGjY), here with solid
--              curved blades sweeping through them (the user: "mix vfx with models").
--   dark       black-red smoke and specks rising off every hit, and dark slivers between the claws.
--   after      thin red scars left where the claws passed, for half a second (MilkCup-VFX).
--   sparks     thin red lines and big lens sparks thrown the way the claws went.
--   accent     amber, only on the drifting motes and the glint of the eyes.
--
-- POUNCE: a glint and claw marks where you spring from, a thick red wake in the air, and where you
-- come down a ring of fangs bursting out of the floor round a red blast.
-- FRENZY: four swipes as you run, each three solid claws sweeping across the front, the last one
-- bigger; three slashes and scars on whoever it throws.
-- 2026-11-15: the solid two-tone crescents (thick arcs, the claw fan, the dark slivers) are gone; the
-- user found them out of place on top of the rest.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)
local KitModels = require(script.Parent.KitModels)

local BeastFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local TONES: Common.Tones = {
	ink = Color3.fromRGB(44, 2, 10), -- black-red
	deep = Color3.fromRGB(142, 8, 24),
	body = Color3.fromRGB(234, 28, 36),
	bright = Color3.fromRGB(255, 100, 80),
	white = Color3.fromRGB(255, 236, 228),
	accent = Color3.fromRGB(255, 192, 62),
	smoke = Color3.fromRGB(62, 42, 46),
}
local T = Common.thick(TONES)
local BLACK = ColorSequence.new(FxKit.BLACK)
local CLAW_RED = Color3.fromRGB(255, 58, 52)
local BONE = Color3.fromRGB(236, 224, 212)
local ROCK = Color3.fromRGB(70, 58, 56)

-- Thin lines thrown the way the claws went.
local function lines(add: FxKit.Add, host: Instance, amount: number, delay: number): ParticleEmitter
	local made = add(
		host,
		"Lines" .. delay,
		Tex.Needle,
		amount,
		delay,
		curve(0, 1.4, 0.5, 1, 0.5, 0.2),
		{ speed = NumberRange.new(70, 130) }
	)
	Common.streaks(made, -1.4, 0.08, 0.14)
	made.LightEmission = 0.4
	made.Color = ramp(TONES.white, TONES.bright, TONES.body)
	return made
end

-- Three parallel cuts, the outer two `gap` studs either side of the middle one, with the scars
-- they leave. Returns the sets to place.
local function cuts(add: FxKit.Add, face: Part, size: number, gap: number)
	local function three(by: number): { { number } }
		return {
			{ 90, gap, size * by, 0, -90 },
			{ 0, 0, size * by, 0, 0 },
			{ -90, gap, size * by, 0, 90 },
		}
	end
	local function set(
		name: string,
		by: number,
		delay: number,
		life: number,
		setup: (emitter: ParticleEmitter) -> ()
	)
		return Common.pieces(
			add,
			face,
			name,
			Tex.Leaf,
			0,
			delay,
			three(by),
			{ 0, 1, 1, 1.1 },
			function(emitter)
				emitter.Lifetime = NumberRange.new(life)
				emitter.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)
				setup(emitter)
			end,
			1
		)
	end
	return {
		set("CutDeep", 1.15, 0, 0.22, function(emitter)
			emitter.LightEmission = 0
			emitter.ZOffset = 0.6
			emitter.Squash = fade(0, -0.9, 1, -1.8)
			emitter.Color = ramp(TONES.deep, TONES.ink)
		end),
		set("Cut", 1, 0, 0.2, function(emitter)
			emitter.LightEmission = 0.3
			emitter.Brightness = 1.8
			emitter.ZOffset = 1
			emitter.Squash = fade(0, -1.2, 1, -2.2)
			emitter.Color = ramp(TONES.bright, TONES.body, TONES.deep)
		end),
		set("CutCore", 0.8, 0, 0.14, function(emitter)
			emitter.Brightness = 3
			emitter.ZOffset = 1.6
			emitter.Squash = fade(0, -1.9, 1, -2.8)
			emitter.Color = ramp(TONES.white, TONES.bright)
		end),
		-- The scars: hair-thin red lines that stay half a second.
		set("Scar", 1, 5, 0.5, function(emitter)
			emitter.LightEmission = 0.5
			emitter.Brightness = 2
			emitter.ZOffset = 0.8
			emitter.Squash = NumberSequence.new(-3)
			emitter.Color = ramp(TONES.bright, TONES.body, TONES.deep)
			emitter.Transparency = fade(0, 0.1, 0.7, 0.3, 1, 1)
		end),
	}
end

-- Dark specks that rise off a hit.
local function specks(
	add: FxKit.Add,
	host: Instance,
	amount: number,
	delay: number
): ParticleEmitter
	local made = add(
		host,
		"Specks" .. delay,
		Tex.Leaf,
		amount,
		delay,
		curve(0, 0.5, 0.2, 1, 0.25, 0.1),
		{ speed = NumberRange.new(6, 16) }
	)
	Common.thrown(made, 180, 4, 0.5, 0.8)
	made.Rotation = NumberRange.new(0, 360)
	made.RotSpeed = NumberRange.new(-80, 80)
	made.Acceleration = Vector3.new(0, 10, 0)
	made.LightEmission = 0
	made.Color = ramp(TONES.deep, TONES.ink)
	return made
end

local glints = FxKit.pool("HT_BeastGlintFx", 3, function(parent, add)
	local centre = FxKit.hiddenPart("HT_BeastGlint", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(centre)
	local star = add(at, "Glint", Tex.Star, 1, 0, keys(0, 2.6, 0.4, 1.8, 1, 0))
	Common.twinkle(star, 0.14, 0.14)
	star.Color = ramp(TONES.white, TONES.accent)
	local spot = add(at, "Spot", Tex.Glow, 1, 0, keys(0, 1.2, 1, 0.4))
	Common.flash(spot, 0.1)
	spot.Color = ramp(TONES.white, TONES.bright)
	return { centre = centre }
end)

-- POUNCE: the spring -------------------------------------------------------------------------------------
local springs = FxKit.pool("HT_BeastPounceFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_BeastPounceFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor, Vector3.new(0, 0.1, 0))
	local low = FxKit.attach(floor, Vector3.new(0, 2, 0))
	-- Its front face looks back along the leap.
	local back = FxKit.hiddenPart("HT_BeastPounceBack", Vector3.new(3, 3, 0.2), parent)

	T.flash(add, low, 4, 0)
	T.stain(add, onFloor, 8, 1)
	T.floorRing(add, onFloor, "Ring", 0, 2, 9, 1)
	T.floorRing(add, onFloor, "SecondRing", 4, 1.5, 7, 3)
	T.darkSmoke(add, low, 6, 0, 2.2)
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
	streaks.Color = ramp(TONES.bright, TONES.body, TONES.deep)
	local ink = add(
		back,
		"Ink",
		Tex.Needle,
		5,
		0,
		curve(0, 1.6, 0.4, 1, 0.7, 0.2),
		{ speed = NumberRange.new(50, 95) }
	)
	Common.streaks(ink, -1.5, 0.12, 0.18)
	ink.SpreadAngle = Vector2.new(18, 18)
	ink.LightEmission = 0
	ink.ZOffset = -0.5
	ink.Color = BLACK
	local sparks = T.lens(add, back, 10, 1, 35)
	sparks.EmissionDirection = Enum.NormalId.Front
	T.motes(add, low, 8, 2)

	return { floor = floor, back = back }
end)

-- POUNCE: the slam where it comes down ---------------------------------------------------------------------
local slams = FxKit.pool("HT_BeastSlamFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_BeastSlamFloor", Vector3.new(6, 0.2, 6), parent)
	local onFloor = FxKit.attach(floor, Vector3.new(0, 0.1, 0))
	local low = FxKit.attach(floor, Vector3.new(0, 3, 0))
	local face = FxKit.hiddenPart("HT_BeastSlamFace", Vector3.new(0.2, 0.2, 0.2), parent)

	T.flash(add, low, 9, 0)
	local star = T.star(add, face, 11)
	T.stain(add, onFloor, 15, 1.6)
	T.floorRing(add, onFloor, "Ring", 0, 3, 17, 1)
	T.floorRing(add, onFloor, "SecondRing", 4, 2.5, 13, 2)
	T.floorRing(add, onFloor, "ThirdRing", 8, 4, 20, 3)
	T.darkSmoke(add, low, 12, 0, 3.6)
	T.haze(add, low, 5, 3, 2.6)
	T.rays(add, floor, 3, 4.5)
	T.lens(add, low, 24, 1, 75)
	T.chips(add, low, 20, 1, 70, NumberRange.new(45, 90), 1.1)
	specks(add, low, 14, 2)
	T.motes(add, low, 14, 2)

	return { floor = floor, face = face, star = star }
end)

-- FRENZY: one swipe ----------------------------------------------------------------------------------------
local swipes = FxKit.pool("HT_BeastFrenzyFx", 5, function(parent, add)
	-- Its front face looks the way the swipe is thrown.
	local front = FxKit.hiddenPart("HT_BeastFrenzyFront", Vector3.new(7, 2, 0.2), parent)
	local centre = FxKit.attach(front)

	T.flash(add, centre, 4, 0)
	T.darkSmoke(add, centre, 4, 1, 2)
	local sparks = T.lens(add, front, 16, 3, 20)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.SpreadAngle = Vector2.new(70, 20)
	local thin = lines(add, front, 12, 3)
	thin.SpreadAngle = Vector2.new(60, 14)
	specks(add, centre, 8, 2)
	-- The last swipe only: a star and a ring where the claws meet.
	local ring = add(centre, "Ring", Tex.Circle, 1, 2, keys(0, 2, 0.35, 7, 1, 9), { flag = "last" })
	Common.ring(ring, 0.28)
	ring.Brightness = 2.4
	ring.Color = ramp(TONES.white, TONES.bright, TONES.body)
	local motes = T.motes(add, centre, 12, 2)
	motes.Name = "LastMotes"

	return { front = front }
end)

-- THE HIT: three slashes and their scars across whoever is thrown; the kit's own punch is a small one.
local function buildHit(size: number, gap: number, long: number, sparks: number)
	return function(parent: Folder, add: FxKit.Add)
		local face = FxKit.hiddenPart("HT_BeastHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
		local centre = FxKit.attach(face)
		T.flash(add, centre, long * 0.5, 0)
		local slashes = cuts(add, face, size, gap)
		local star = T.star(add, face, long)
		local ring = add(
			centre,
			"Ring",
			Tex.Circle,
			1,
			3,
			keys(0, long * 0.2, 0.35, long * 0.6, 1, long * 0.75)
		)
		Common.ring(ring, 0.24)
		ring.Brightness = 2.4
		ring.Color = ramp(TONES.bright, TONES.body)
		T.darkSmoke(add, centre, math.ceil(sparks / 4), 0, long * 0.3)
		T.lens(add, centre, sparks, 3, 180)
		specks(add, centre, math.ceil(sparks / 2), 2)
		T.motes(add, centre, math.ceil(sparks / 3), 2)
		return { face = face, slashes = slashes, star = star }
	end
end

local hits = FxKit.pool("HT_BeastHitFx", 4, buildHit(2.2, 1.5, 8, 20))
local punches = FxKit.pool("HT_BeastPunchFx", 4, buildHit(1.2, 0.9, 4.5, 7))

-- A ring of fangs bursting out of the floor round `centre`, curving in over it.
local function fangs(centre: Vector3, count: number, radius: number, tall: number, hold: number)
	for index = 1, count do
		local angle = math.rad(index * (360 / count) + math.random(-8, 8))
		local spot = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local under = FxKit.floorUnder(spot + Vector3.yAxis * 4, 9)
		if under then
			-- Turned so the fang's curve points at the middle, and leaning a little outward.
			local base = CFrame.lookAt(under, Vector3.new(centre.X, under.Y, centre.Z))
				* CFrame.Angles(0, math.pi / 2, 0)
				* CFrame.Angles(0, 0, math.rad(14))
			KitModels.erupt(
				"Claw_Fang",
				tall * (0.8 + math.random() * 0.4),
				base,
				(index % 3) * FxKit.FRAME,
				hold,
				if index % 2 == 0 then BONE else CLAW_RED,
				if index % 2 == 0 then Enum.Material.SmoothPlastic else Enum.Material.Neon,
				0
			)
		end
	end
end

local function rocks(from: Vector3, amount: number, speed: number, big: number)
	for index = 1, math.max(1, math.floor(amount * FxKit.QUALITY + 0.5)) do
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		KitModels.throw(
			if index % 2 == 0 then "Rock_ChunkA" else "Rock_ChunkB",
			big * (0.6 + math.random() * 0.8),
			from + out * (1 + math.random() * 2) + Vector3.yAxis * 1.2,
			out * speed * (0.35 + math.random() * 0.65)
				+ Vector3.yAxis * speed * (0.6 + math.random() * 0.6),
			160,
			0.7 + math.random() * 0.5,
			ROCK,
			Enum.Material.Slate
		)
	end
end

--- A glint at `position`: the cue on the hand before a Frenzy, and the eyes before a Pounce.
function BeastFx.glint(position: Vector3)
	local rig = glints.take()
	local centre = rig.parts.centre :: Part
	centre.CFrame = CFrame.new(position)
	FxKit.fire(rig, 1)
end

--- The Pounce: the spring where `root` leaves along `direction`, and a thick red wake behind it
--- for `seconds`.
function BeastFx.pounce(root: BasePart, direction: Vector3, seconds: number)
	local way = FxKit.flat(direction)
	local ground = FxKit.floorUnder(root.Position, 8)
	local feet = ground or root.Position - Vector3.yAxis * 2.8
	local rig = springs.take()
	local floor = rig.parts.floor :: Part
	local back = rig.parts.back :: Part
	floor.CFrame = CFrame.new(feet + Vector3.yAxis * 0.1)
	back.CFrame = CFrame.lookAt(root.Position - way, root.Position - way * 2)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)
	BeastFx.glint(root.Position + Vector3.yAxis * 1.6 + way * 0.4)

	Common.stream(root, "BeastWake", seconds, Vector3.zero, function(at)
		local wake = Common.emitter(at, "Wake", Tex.Glow, 70)
		wake.Lifetime = NumberRange.new(0.28, 0.38)
		wake.Size = NumberSequence.new(curve(0, 3, 0.6, 0.5, 2, 0.5, 1, 0, 0))
		wake.LightEmission = 0.3
		wake.Color = ramp(TONES.bright, TONES.body, TONES.deep)
		wake.Transparency = fade(0, 0.25, 0.7, 0.4, 1, 1)
		local dark = Common.emitter(at, "Dark", Tex.Smoke, 26)
		Common.smoke(dark, TONES.ink, 0.5, 0.8)
		dark.Color = ramp(TONES.ink, TONES.deep)
		dark.LightEmission = 0
		dark.ZOffset = -2
		dark.Size = NumberSequence.new(curve(0, 2.6, 0.6, 1, 4.6, 1))
		dark.Speed = NumberRange.new(1, 4)
		dark.Transparency = fade(0, 0.2, 0.5, 0.4, 1, 1)
		local thin = Common.emitter(at, "Lines", Tex.Needle, 46)
		thin.Orientation = Enum.ParticleOrientation.VelocityParallel
		thin.EmissionDirection = Enum.NormalId.Back
		thin.SpreadAngle = Vector2.new(14, 14)
		thin.Speed = NumberRange.new(40, 70)
		thin.Lifetime = NumberRange.new(0.12, 0.18)
		thin.Squash = NumberSequence.new(-1.3)
		thin.Size = NumberSequence.new(curve(0, 1.6, 0.5, 1, 0.6, 0.2))
		thin.LightEmission = 0.4
		thin.Brightness = 2
		thin.Color = ramp(TONES.white, TONES.bright, TONES.body)
		local sparks = Common.emitter(at, "Sparks", Tex.Leaf, 30)
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.EmissionDirection = Enum.NormalId.Back
		sparks.SpreadAngle = Vector2.new(45, 45)
		sparks.Speed = NumberRange.new(14, 34)
		sparks.Drag = 5
		sparks.Lifetime = NumberRange.new(0.25, 0.4)
		sparks.Size = NumberSequence.new(curve(0, 0.8, 0.3, 1, 0.3, 0.1))
		sparks.LightEmission = 0.4
		sparks.Brightness = 2
		sparks.Color = ramp(TONES.white, TONES.bright, TONES.body)
		return { wake, dark, thin, sparks }
	end)
end

--- The Pounce coming down at `position` on the floor: the slam, and a ring of fangs round it.
function BeastFx.slam(position: Vector3)
	local rig = slams.take()
	local floor = rig.parts.floor :: Part
	local face = rig.parts.face :: Part
	floor.CFrame = CFrame.new(position + Vector3.yAxis * 0.1)
	face.CFrame = FxKit.screenAt(position + Vector3.yAxis * 4)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, 1)
	fangs(position, 7, 6, 8, 0.7)
	rocks(position, 10, 52, 1.3)
end

--- One swipe of the Frenzy in front of `root`, facing `direction`. `index` is which swipe it is
--- (they alternate sides) and `last` the big one that throws.
function BeastFx.swipe(root: BasePart, direction: Vector3, index: number, last: boolean)
	local way = FxKit.flat(direction)
	local right = Vector3.new(-way.Z, 0, way.X)
	local side = if index % 2 == 0 then -1 else 1
	local chest = root.Position + Vector3.yAxis * 0.4
	local rig = swipes.take()
	local front = rig.parts.front :: Part
	local ahead = chest + way * 5
	front.CFrame = CFrame.lookAt(ahead, ahead + way)
	FxKit.fire(rig, if last then 1.3 else 1, nil, { last = last })

	-- Three solid claws sweep across the front, one above the next.
	local reach = if last then 7 else 5.5
	for row = -1, 1 do
		local height = Vector3.yAxis * (row * 1.5)
		local from = chest + way * 4 + right * (side * reach) + height
		local to = chest + way * 5.5 - right * (side * reach) + height
		-- The blade lies level, pointing along the sweep; its curve leads into it.
		local turn = CFrame.Angles(0, 0, side * math.pi / 2)
		KitModels.sweep(
			"Claw_Blade",
			if last then 13 else 10,
			CFrame.lookAt(from, from + way) * turn,
			CFrame.lookAt(to, to + way) * turn,
			0.13,
			if row == 0 then BONE else CLAW_RED,
			Enum.Material.Neon
		)
	end
end

--- The Frenzy (or the Pounce's slam) throwing `target` along `away`: three slashes across them.
function BeastFx.hit(target: BasePart, away: Vector3)
	local rig = hits.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	Common.placeAll(rig.parts.slashes, Common.screenAngle(FxKit.flat(away)) + 55)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, 1)
end

--- The Beast kit's own punch landing at `position`, thrown along `away`: three short cuts.
function BeastFx.punch(position: Vector3, away: Vector3, strong: boolean)
	local rig = punches.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(position)
	Common.placeAll(rig.parts.slashes, Common.screenAngle(FxKit.flat(away)) + 55)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, if strong then 1.5 else 1)
end

--- The Beast kit's own landing (a kick or a dive reaching the floor at `position`): a small slam.
function BeastFx.landing(position: Vector3)
	local rig = slams.take()
	local floor = rig.parts.floor :: Part
	local face = rig.parts.face :: Part
	floor.CFrame = CFrame.new(position + Vector3.yAxis * 0.1)
	face.CFrame = FxKit.screenAt(position + Vector3.yAxis * 3)
	Common.placeAll(rig.parts.star, math.random() * 360)
	FxKit.fire(rig, 0.7)
	fangs(position, 5, 4.2, 5.5, 0.55)
	rocks(position, 6, 38, 1)
end

function BeastFx.preload()
	glints.preload()
	springs.preload()
	slams.preload()
	swipes.preload()
	hits.preload()
	punches.preload()
end

return BeastFx
