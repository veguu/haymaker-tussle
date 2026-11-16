--!strict
-- BruiserFx - the Bruiser kit's effects (Fx/KitFxCommon, Fx/FxKit): the Charge (Q) and the Slam (R).
-- All particles. Decoration on this client only: nothing here can collide, block a ray or affect
-- gameplay.
--
-- The Slam is the big ground hit of two references, in gold:
--   stack      bottom to top: floor glow and ring edge, core, spikes, one vertical ray, shards and
--              dots, a haze of dust (Scrippage "Weapon Switcher", YouTube UOoYfyJhQN8, f288-328).
--   dome       a translucent dome over the impact, ten character heights wide in the reference, that
--              overshoots and settles (Nyght "Light Moveset", 5NqNGoV3a30, f977, f2366-2387).
--   spikes     needles that arrive standing on the floor and do not move (Nyght f330-335), the far
--              ring a moment after the near one.
--   debris     dark angular rocks that rise for ten frames and fall for sixty (Smile_Dev "VFX Pack 3"
--              f2738-2799, f190-191).
--   charge     rings closing on the fist, then a glint in the last frames (Smile_Dev f3107-3114).
--
-- CHARGE: dust and gold streaks where you set off, and a gold shield in front of you for as long as
-- it runs (it shrugs off one punch).
-- SLAM: rings closing on the raised fist, then the ground burst all round you when it lands (hit or
-- miss), and a gold burst on everyone it throws.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)

local BruiserFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local ramp = Common.ramp
local P = Common.Palettes.Bruiser
local ROCK = Color3.fromRGB(98, 86, 72)
local ROCK_DARK = Color3.fromRGB(52, 46, 40)

local function dust(add: FxKit.Add, host: Instance, amount: number, delay: number, big: number)
	local made = add(
		host,
		"Dust",
		Tex.Smoke,
		amount,
		delay,
		curve(0, big, big * 0.3, 1, big * 2.2, big * 0.5),
		{ speed = NumberRange.new(big * 4, big * 9) }
	)
	Common.smoke(made, P.smoke, 0.5, 0.8)
	made.SpreadAngle = Vector2.new(85, 85)
	return made
end

local function lensSparks(
	add: FxKit.Add,
	host: Instance,
	amount: number,
	delay: number,
	spread: number
)
	local made = add(
		host,
		"LensSparks",
		Tex.Leaf,
		amount,
		delay,
		curve(0, 0.6, 0.25, 1, 0.3, 0.1),
		{ speed = NumberRange.new(35, 70) }
	)
	Common.thrown(made, spread, 8, 0.12, 0.2)
	made.Orientation = Enum.ParticleOrientation.VelocityParallel
	made.Squash = NumberSequence.new(-0.9)
	made.Brightness = 2.5
	made.Color = ramp(P.white, P.bright, P.body)
	return made
end

-- CHARGE: setting off ----------------------------------------------------------------------------------
local starts = FxKit.pool("HT_BruiserChargeFx", 3, function(parent, add)
	local floor = FxKit.hiddenPart("HT_BruiserChargeFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)
	-- Its front face looks back along the charge.
	local back = FxKit.hiddenPart("HT_BruiserChargeBack", Vector3.new(2.2, 2.6, 0.2), parent)
	local centre = FxKit.attach(back)

	local ring = add(
		onFloor,
		"Ring",
		Tex.Circle,
		1,
		0,
		keys(0, 1.6, 0.3, 5, 1, 6),
		{ flat = true, onFloor = true }
	)
	Common.ring(ring, 0.25)
	ring.Color = ramp(P.white, P.bright)
	dust(add, onFloor, 6, 0, 1.3).EmissionDirection = Enum.NormalId.Top

	local flare = add(centre, "Flare", Tex.Leaf, 1, 0, keys(0, 2.4, 1, 3))
	Common.flash(flare, 0.07)
	flare.Squash = NumberSequence.new(-1.5)
	flare.Rotation = NumberRange.new(0)
	flare.Color = ramp(P.white, P.bright)
	local core = add(centre, "Core", Tex.Glow, 1, 0, keys(0, 1.6, 0.3, 2.4, 1, 1))
	Common.flash(core, 0.1)
	core.Color = ramp(P.white, P.bright, P.body)

	local streaks = add(
		back,
		"Streaks",
		Tex.Needle,
		8,
		0,
		curve(0, 1.3, 0.4, 1, 0.5, 0.2),
		{ speed = NumberRange.new(50, 95) }
	)
	Common.streaks(streaks, -1.5, 0.1, 0.17)
	streaks.SpreadAngle = Vector2.new(10, 10)
	streaks.Color = ramp(P.white, P.bright, P.body)
	local sparks = lensSparks(add, back, 10, 1, 35)
	sparks.EmissionDirection = Enum.NormalId.Front

	return { floor = floor, back = back }
end)

-- SLAM: the rings closing on the fist --------------------------------------------------------------------
local gathers = FxKit.pool("HT_BruiserGatherFx", 2, function(parent, add)
	local centre = FxKit.hiddenPart("HT_BruiserGather", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(centre)
	for index, delay in { 0, 6, 12 } do
		local closing = add(at, "Closing" .. index, Tex.Circle, 1, delay, keys(0, 3.6, 1, 0.5))
		Common.ring(closing, 0.16)
		closing.Color = ramp(P.bright, P.white)
		closing.Transparency = fade(0, 0.5, 0.6, 0.1, 1, 0.3)
	end
	local glow = add(at, "Glow", Tex.Glow, 1, 0, keys(0, 0.6, 0.8, 2, 1, 0.8))
	glow.Lifetime = NumberRange.new(0.34)
	glow.Brightness = 2.5
	glow.ZOffset = 1
	glow.Color = ramp(P.body, P.bright, P.white)
	glow.Transparency = fade(0, 0.3, 0.8, 0, 1, 0.6)
	local glint = add(at, "Glint", Tex.Star, 1, 18, keys(0, 3, 0.5, 2, 1, 0))
	Common.twinkle(glint, 0.1, 0.1)
	glint.Color = ramp(P.white, P.bright)
	return { centre = centre }
end)

-- SLAM: the ground burst ----------------------------------------------------------------------------------
-- The standing spikes: two rings of eight round the thrower. Each ring: how far out, the spike's Size
-- (it is about 4 x Size long, its lower half under the floor), and how many frames after the first
-- it arrives.
local SPIKE_RINGS = { { 6, 2.4, 0 }, { 10.5, 1.8, 3 } }

local bursts = FxKit.pool("HT_BruiserSlamFx", 2, function(parent, add)
	local floor = FxKit.hiddenPart("HT_BruiserSlamFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)
	local low = FxKit.attach(floor, Vector3.new(0, 2, 0))

	-- 0 f. The floor: a white flash, then three rings out to its reach, the last one grey.
	local flash = add(onFloor, "FloorFlash", Tex.Glow, 1, 0, keys(0, 6, 1, 9), { flat = true })
	flash.Lifetime = NumberRange.new(0.14)
	flash.Brightness = 2
	flash.Color = ramp(P.white, P.bright)
	flash.Transparency = fade(0, 0.2, 1, 1)
	local glow = add(onFloor, "FloorGlow", Tex.Glow, 1, 0, keys(0, 8, 1, 12), { flat = true })
	glow.Lifetime = NumberRange.new(0.6)
	glow.LightEmission = 0.7
	glow.Color = ramp(P.body, P.deep)
	glow.Transparency = fade(0, 0.5, 1, 1)
	local rings = {
		{ 0, 3, 10, 13, ramp(P.white, P.bright) },
		{ 3, 2, 8, 11, ramp(P.bright, P.body) },
		{ 6, 3, 11, 14, ColorSequence.new(FxKit.SMOKE_GREY) },
	}
	for index, spec in rings do
		local ring = add(
			onFloor,
			"Ring" .. index,
			Tex.Circle,
			1,
			spec[1] :: number,
			keys(0, spec[2] :: number, 0.25, spec[3] :: number, 1, spec[4] :: number),
			{ flat = true }
		)
		Common.ring(ring, 0.3)
		ring.Color = spec[5] :: ColorSequence
		if index == 3 then
			ring.LightEmission = 0.3
		end
	end

	-- 0 f. The core, a tall ray, and the dome: out past its size, then settling.
	local core = add(low, "Core", Tex.Glow, 1, 0, keys(0, 3, 0.3, 4.4, 1, 1.6))
	Common.flash(core, 0.1)
	core.Color = ramp(P.white, P.bright)
	local ray = add(low, "Ray", Tex.Leaf, 1, 0, keys(0, 3.4, 1, 4))
	Common.flash(ray, 0.18)
	ray.Rotation = NumberRange.new(90)
	ray.Squash = fade(0, -1.2, 1, -2.2)
	ray.Color = ramp(P.white, P.bright)
	local dome = add(low, "Dome", Tex.Dome, 1, 0, keys(0, 5, 0.2, 10, 0.35, 9.2, 1, 10.5))
	dome.Lifetime = NumberRange.new(0.32)
	dome.LightEmission = 0.7
	dome.Color = ramp(P.white, P.bright, P.body)
	dome.Transparency = fade(0, 0.25, 0.6, 0.5, 1, 1)

	-- The spikes: standing on the floor in two rings, the far one three frames after the near one.
	for ringIndex, spec in SPIKE_RINGS do
		for index = 1, 8 do
			local angle = math.rad(index * 45 + ringIndex * 22.5)
			local seat = FxKit.attach(
				floor,
				Vector3.new(math.cos(angle) * spec[1], 0.1, math.sin(angle) * spec[1])
			)
			local size = spec[2] * (0.75 + 0.5 * ((index * 7 + ringIndex * 3) % 5) / 4)
			local spike = add(
				seat,
				"Spike" .. ringIndex .. "_" .. index,
				Tex.Needle,
				1,
				spec[3],
				keys(0, size * 0.4, 0.12, size * 1.15, 0.3, size, 1, size * 0.5)
			)
			spike.Lifetime = NumberRange.new(0.26, 0.34)
			spike.Rotation = NumberRange.new(84, 96)
			spike.Squash = NumberSequence.new(-1)
			spike.LightEmission = 0.7
			spike.Brightness = 1.8
			spike.ZOffset = 0.8
			spike.Color = ramp(P.bright, P.body)
			spike.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)
		end
	end

	-- 1 f. Rocks thrown up that fall back, dust rolling out, lens sparks, drifting dots.
	local rocks = add(
		onFloor,
		"Rocks",
		Tex.Shard,
		12,
		1,
		curve(0, 0.9, 0.3, 1, 0.7, 0.25),
		{ speed = NumberRange.new(35, 62) }
	)
	Common.thrown(rocks, 55, 0.4, 0.6, 0.9)
	rocks.Rotation = NumberRange.new(0, 360)
	rocks.RotSpeed = NumberRange.new(-200, 200)
	rocks.Acceleration = Vector3.new(0, -95, 0)
	rocks.LightEmission = 0
	rocks.Color = ramp(ROCK, ROCK_DARK)
	dust(add, onFloor, 10, 1, 2)
	lensSparks(add, low, 18, 2, 80)
	local dots = add(
		low,
		"Dots",
		Tex.Glow,
		14,
		2,
		curve(0, 0.22, 0.08, 1, 0, 0),
		{ speed = NumberRange.new(4, 12) }
	)
	Common.embers(dots, 0.8, 1.2)
	dots.Color = ramp(P.bright, P.body)

	return { floor = floor }
end)

-- SLAM: the burst on everyone it throws ---------------------------------------------------------------------
local STAR_SHAPE = { 0, 1, 0.35, 0.85, 1, 0.15 }

local hits = FxKit.pool("HT_BruiserHitFx", 4, function(parent, add)
	local face = FxKit.hiddenPart("HT_BruiserHitFace", Vector3.new(0.2, 0.2, 0.2), parent)
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
		Common.starSpecs(6, 3, 6.5, -1, 61),
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
		Common.starSpecs(12, 2.5, 8, -1.3, 37),
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
	local ring = add(centre, "Ring", Tex.Circle, 1, 3, keys(0, 1.4, 0.35, 4, 1, 5))
	Common.ring(ring, 0.25)
	ring.Color = ramp(P.bright, P.body)
	lensSparks(add, centre, 14, 2, 180)
	local smoke = dust(add, centre, 4, 3, 1.3)
	smoke.SpreadAngle = Vector2.new(180, 180)
	return { face = face, deep = deep, bright = bright }
end)

--- The Charge: dust and streaks where `root` sets off along `direction`, and a gold shield in front
--- of it for `seconds`.
function BruiserFx.charge(root: BasePart, direction: Vector3, seconds: number)
	local way = FxKit.flat(direction)
	local ground = FxKit.floorUnder(root.Position, 8)
	local rig = starts.take()
	local floor = rig.parts.floor :: Part
	local back = rig.parts.back :: Part
	if ground then
		floor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
	end
	local behind = root.Position - way
	back.CFrame = CFrame.lookAt(behind, behind - way)
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)

	Common.stream(root, "BruiserCharge", seconds, Vector3.new(0, 0, -1.6), function(at)
		-- The shield: a dome held in front of the body.
		local shield = Common.emitter(at, "Shield", Tex.Dome, 24)
		shield.LockedToPart = true
		shield.Lifetime = NumberRange.new(0.12)
		shield.Size = NumberSequence.new(keys(0, 2.4, 1, 2.9))
		shield.LightEmission = 0.8
		shield.Color = ramp(P.white, P.bright, P.body)
		shield.Transparency = fade(0, 0.45, 1, 1)
		local lines = Common.emitter(at, "Lines", Tex.Needle, 36)
		lines.Orientation = Enum.ParticleOrientation.VelocityParallel
		lines.EmissionDirection = Enum.NormalId.Back
		lines.SpreadAngle = Vector2.new(14, 14)
		lines.Speed = NumberRange.new(35, 60)
		lines.Lifetime = NumberRange.new(0.1, 0.15)
		lines.Squash = NumberSequence.new(-1.5)
		lines.Size = NumberSequence.new(curve(0, 0.9, 0.3, 1, 0.3, 0.1))
		lines.Brightness = 2
		lines.Color = ramp(P.white, P.bright, P.body)
		lines.Transparency = fade(0, 0.1, 1, 1)
		local sparks = Common.emitter(at, "Sparks", Tex.Leaf, 18)
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.EmissionDirection = Enum.NormalId.Back
		sparks.SpreadAngle = Vector2.new(40, 40)
		sparks.Speed = NumberRange.new(12, 28)
		sparks.Drag = 6
		sparks.Lifetime = NumberRange.new(0.15, 0.25)
		sparks.Squash = NumberSequence.new(-0.9)
		sparks.Size = NumberSequence.new(curve(0, 0.45, 0.15, 1, 0.2, 0.08))
		sparks.Brightness = 2.5
		sparks.Color = ramp(P.white, P.bright, P.body)
		local puffs = Common.emitter(at, "Dust", Tex.Smoke, 14)
		Common.smoke(puffs, P.smoke, 0.35, 0.55)
		puffs.Size = NumberSequence.new(curve(0, 1.2, 0.3, 1, 2.4, 0.5))
		puffs.Speed = NumberRange.new(1, 4)
		return { shield, lines, sparks, puffs }
	end)
end

--- The Slam's windup: rings closing on the raised fist at `position`.
function BruiserFx.windup(position: Vector3)
	local rig = gathers.take()
	local centre = rig.parts.centre :: Part
	centre.CFrame = CFrame.new(position)
	FxKit.fire(rig, 1)
end

--- The Slam landing, hit or miss: the ground burst all round `root`. Returns the floor point under
--- it, if there is one.
function BruiserFx.strike(root: BasePart): Vector3?
	local ground = FxKit.floorUnder(root.Position, 10)
	local feet = ground or root.Position - Vector3.yAxis * 2.8
	local rig = bursts.take()
	local floor = rig.parts.floor :: Part
	floor.CFrame = CFrame.new(feet + Vector3.yAxis * 0.1)
	FxKit.fire(rig, 1)
	return ground
end

--- The Slam throwing `target`.
function BruiserFx.hit(target: BasePart, _away: Vector3)
	local rig = hits.take()
	local face = rig.parts.face :: Part
	face.CFrame = FxKit.screenAt(target.Position)
	Common.place(rig.parts.deep, math.random() * 360, 1, 1)
	Common.place(rig.parts.bright, math.random() * 360, 1, 1)
	FxKit.fire(rig, 1)
end

function BruiserFx.preload()
	starts.preload()
	gathers.preload()
	bursts.preload()
	hits.preload()
end

return BruiserFx
