--!strict
-- SkillFx - the heavier effects of the two original attack skills, the Base kit's Uppercut and the
-- Tempest kit's Cyclone (Fx/KitFxCommon, Fx/FxKit). The user, 2026-11-15: the R moves should be
-- strong, "bigger hitboxes and stronger effects". These two stay in the game's plain white and grey
-- (FxKit's style); what changes is their size and how many layers they get. All particles. Decoration
-- on this client only.
--
-- UPPERCUT, on whoever it lands on (on top of the ordinary hit): a column. One tall thin ray and a
-- four-point star (Nyght "Light Moveset" f3886: a long vertical arm), streaks thrown straight up
-- (Venomec "Mumen Rider" f140-143: a streak bundle from a hit), a dome (Nyght f977), and two rings on
-- the floor under them, the second grey (xander22 f468-519).
-- CYCLONE, round the thrower as it strikes: a ring broken into crescents spinning out to its reach
-- (xander22 f474; Scrippage "Weapon Switcher" f889-905: the bright part goes half way round in ten
-- frames), two thin wind rings (Scrippage f97-126), lines thrown out level, and dust.

local Common = require(script.Parent.KitFxCommon)
local FxKit = require(script.Parent.FxKit)

local SkillFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve
local GREY = ColorSequence.new(FxKit.SMOKE_GREY)

local columns = FxKit.pool("HT_UppercutColumnFx", 3, function(parent, add)
	local centre = FxKit.hiddenPart("HT_UppercutColumn", Vector3.new(1.6, 0.2, 1.6), parent)
	local at = FxKit.attach(centre)
	local floor = FxKit.hiddenPart("HT_UppercutColumnFloor", Vector3.new(0.2, 0.2, 0.2), parent)
	local onFloor = FxKit.attach(floor)

	-- 0 f. The ray, the star and a white ball.
	local ray = add(at, "Ray", Tex.Leaf, 1, 0, keys(0, 3.6, 1, 4.4))
	Common.flash(ray, 0.2)
	ray.Rotation = NumberRange.new(90)
	ray.Squash = fade(0, -1.2, 1, -2.4)
	local star = add(at, "Star", Tex.Star, 1, 0, keys(0, 3.6, 0.4, 2.6, 1, 0))
	Common.twinkle(star, 0.12, 0.12)
	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 2, 0.3, 2.8, 1, 1.2))
	Common.flash(core, 0.09)

	-- 0 f. Streaks thrown straight up, and a dome.
	local streaks = add(
		centre,
		"Streaks",
		Tex.Needle,
		9,
		0,
		curve(0, 1.5, 0.4, 1, 0.6, 0.2),
		{ speed = NumberRange.new(80, 135) }
	)
	Common.streaks(streaks, -1.6, 0.1, 0.17)
	streaks.EmissionDirection = Enum.NormalId.Top
	streaks.SpreadAngle = Vector2.new(9, 9)
	local dome = add(at, "Dome", Tex.Dome, 1, 0, keys(0, 2.4, 0.25, 4.6, 1, 5.2))
	dome.Lifetime = NumberRange.new(0.2)
	dome.Transparency = fade(0, 0.4, 1, 1)

	-- 1 f and 5 f. Two rings on the floor under them, the second grey; dust.
	local ring = add(
		onFloor,
		"Ring",
		Tex.Circle,
		1,
		1,
		keys(0, 1.6, 0.3, 5, 1, 6.2),
		{ flat = true, onFloor = true }
	)
	Common.ring(ring, 0.26)
	local air = add(
		onFloor,
		"AirRing",
		Tex.Circle,
		1,
		5,
		keys(0, 2, 0.4, 6, 1, 7.4),
		{ flat = true, onFloor = true }
	)
	Common.ring(air, 0.3)
	air.Color = GREY
	air.LightEmission = 0.3
	local dust = add(
		onFloor,
		"Dust",
		Tex.Smoke,
		5,
		1,
		curve(0, 1.3, 0.3, 1, 3, 0.7),
		{ speed = NumberRange.new(4, 10), onFloor = true }
	)
	Common.smoke(dust, FxKit.SMOKE_GREY, 0.4, 0.65)
	dust.SpreadAngle = Vector2.new(85, 85)

	return { centre = centre, floor = floor }
end)

local function buildWhirl(reach: number)
	return function(parent: Folder, add: FxKit.Add)
		-- Lies level at the chest: flat layers on it ring the body.
		local level = FxKit.hiddenPart("HT_CycloneWhirl", Vector3.new(0.2, 0.2, 0.2), parent)
		local onLevel = FxKit.attach(level)
		local floor = FxKit.hiddenPart("HT_CycloneWhirlFloor", Vector3.new(0.2, 0.2, 0.2), parent)
		local onFloor = FxKit.attach(floor)

		-- 0 f. The ring of crescents, spinning as it opens to the reach; a smaller one inside it.
		for index, share in { 1, 0.62 } do
			local wheel = add(
				onLevel,
				"Wheel" .. index,
				Tex.Pinwheel,
				1,
				(index - 1) * 2,
				keys(0, reach * 0.45 * share, 0.25, reach * share, 1, reach * 1.14 * share),
				{ flat = true }
			)
			wheel.Lifetime = NumberRange.new(0.26)
			wheel.Rotation = NumberRange.new(0, 360)
			wheel.RotSpeed = NumberRange.new(780)
			wheel.Brightness = 2
			wheel.Transparency = fade(0, 0, 0.6, 0.25, 1, 1)
		end
		-- 2 f and 6 f. Two thin wind rings, the second grey.
		local ring = add(
			onLevel,
			"Ring",
			Tex.Circle,
			1,
			2,
			keys(0, reach * 0.4, 0.3, reach * 1.05, 1, reach * 1.25),
			{ flat = true }
		)
		Common.ring(ring, 0.24)
		local air = add(
			onFloor,
			"AirRing",
			Tex.Circle,
			1,
			6,
			keys(0, reach * 0.4, 0.4, reach, 1, reach * 1.2),
			{ flat = true, onFloor = true }
		)
		Common.ring(air, 0.3)
		air.Color = GREY
		air.LightEmission = 0.3

		-- 1 f. Lines thrown out level all round; dust at the feet.
		local lines = add(
			onLevel,
			"Lines",
			Tex.Needle,
			14,
			1,
			curve(0, 1.1, 0.3, 1, 0.5, 0.2),
			{ speed = NumberRange.new(55, 95) }
		)
		Common.streaks(lines, -1.4, 0.1, 0.16)
		lines.SpreadAngle = Vector2.new(180, 6)
		local dust = add(
			onFloor,
			"Dust",
			Tex.Smoke,
			6,
			1,
			curve(0, 1.3, 0.3, 1, 3, 0.7),
			{ speed = NumberRange.new(5, 12), onFloor = true }
		)
		Common.smoke(dust, FxKit.SMOKE_GREY, 0.4, 0.65)
		dust.SpreadAngle = Vector2.new(85, 85)

		return { level = level, floor = floor }
	end
end

local whirlPools: { [number]: FxKit.Pool } = {}

local function whirlPool(reach: number): FxKit.Pool
	local pool = whirlPools[reach]
	if not pool then
		pool = FxKit.pool("HT_CycloneWhirlFx", 2, buildWhirl(reach))
		whirlPools[reach] = pool
	end
	return pool
end

--- The Uppercut landing on `target`: the column, on top of the ordinary hit.
function SkillFx.uppercutHit(target: BasePart)
	local rig = columns.take()
	local centre = rig.parts.centre :: Part
	local floor = rig.parts.floor :: Part
	centre.CFrame = CFrame.new(target.Position)
	local ground = FxKit.floorUnder(target.Position, 10)
	if ground then
		floor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
	end
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)
end

--- The Cyclone striking, hit or miss: the whirl round `root`, out to `reach` studs.
function SkillFx.cycloneStrike(root: BasePart, reach: number)
	local rig = whirlPool(reach).take()
	local level = rig.parts.level :: Part
	local floor = rig.parts.floor :: Part
	level.CFrame = CFrame.new(root.Position + Vector3.yAxis * 0.4)
	local ground = FxKit.floorUnder(root.Position, 8)
	if ground then
		floor.CFrame = CFrame.new(ground + Vector3.yAxis * 0.1)
	end
	FxKit.fire(rig, 1, nil, nil, ground ~= nil)
end

function SkillFx.preload(reach: number)
	columns.preload()
	whirlPool(reach).preload()
end

return SkillFx
