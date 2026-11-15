--!strict
-- AirFx - small effects of moving air, BASIC and PLAIN, in the style (Fx/FxKit): the gust behind a
-- punch thrown in the air, the two ends of a blink, and the smoke a launched body leaves behind it.
-- All particles, white and grey only. Decoration on this client only: nothing here can collide, block
-- a ray or affect gameplay.
--
-- These replace effects made of solid sphere parts (the user, 2026-11-13: no solid 3D clouds; 2026-11-14:
-- basic, plain, no rings with lines coming out of them).
--
-- GUST (after the wind ring in Scrippage's "Weapon Switcher", YouTube UOoYfyJhQN8, frames 97-126: a
-- thin hollow ring that opens fast, slows, and fades as it widens): a thin ring standing square to the
-- punch, a second smaller one two frames later, five thin lines trailing back, three small puffs.
--
-- BLINK (after the same video's weapon-swap flash, frames 164-168: a four-point star for four or five
-- frames): where they leave, an upright line that grows tall and hair-thin while a ring closes on it;
-- where they arrive, a white spot, an upright four-point star, a ring opening, three lines crossing
-- the gap, and a couple of small puffs.
--
-- TRAIL: soft grey puffs left along the path of a body that has been launched, for a moment.

local FxKit = require(script.Parent.FxKit)

local AirFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve

-- A plain smoke puff layer: plays the flipbook once, swelling a little and fading.
local function puffs(emitter: ParticleEmitter)
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	emitter.Color = ColorSequence.new(FxKit.SMOKE_GREY)
	emitter.LightEmission = 0.3
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Drag = 3
	emitter.Transparency = fade(0, 0.3, 0.6, 0.5, 1, 1)
end

-- A line layer shot from a part's front face, lying along its flight.
local function shot(emitter: ParticleEmitter)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Drag = 5
	emitter.Brightness = 2
	emitter.Squash = NumberSequence.new(-1.26)
	emitter.Transparency = fade(0, 0.05, 0.6, 0.15, 1, 1)
end

local gusts = FxKit.pool("HT_AirGustFx", 4, function(parent, add)
	-- Its top face looks back along the punch, so a flat layer on it stands square to the punch.
	local plate = FxKit.hiddenPart("HT_AirGust", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(plate)
	local lines = FxKit.hiddenPart("HT_AirGustLines", Vector3.new(1.8, 2.4, 0.2), parent)

	-- 0 f. The ring: opens fast, slows, fades as it widens. 2 f: a second, smaller one.
	local ring = add(at, "Ring", Tex.Circle, 1, 0, keys(0, 0.8, 0.35, 2.2, 1, 3), { flat = true })
	ring.Lifetime = NumberRange.new(0.2)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.8
	ring.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)
	local second =
		add(at, "SecondRing", Tex.Circle, 1, 2, keys(0, 0.5, 0.35, 1.4, 1, 1.9), { flat = true })
	second.Lifetime = NumberRange.new(0.18)
	second.Rotation = NumberRange.new(0, 360)
	second.Brightness = 1.5
	second.Transparency = fade(0, 0.2, 0.5, 0.5, 1, 1)

	-- 1 f. Five thin lines trailing back (about 4 studs long).
	local trail = add(
		lines,
		"Lines",
		Tex.Needle,
		5,
		1,
		curve(0, 0.75, 0.25, 0.25, 0.9, 0.3, 1, 0.7, 0.2),
		{ speed = NumberRange.new(14, 30) }
	)
	shot(trail)
	trail.Lifetime = NumberRange.new(0.1, 0.16)

	-- 1 f. Three small puffs drifting back.
	local smoke = add(
		lines,
		"Puffs",
		Tex.Smoke,
		3,
		1,
		curve(0, 0.6, 0.2, 0.4, 1, 0.3, 1, 1.3, 0.4),
		{ speed = NumberRange.new(3, 7) }
	)
	puffs(smoke)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Lifetime = NumberRange.new(0.25, 0.35)

	return { plate = plate, lines = lines }
end)

local leaves = FxKit.pool("HT_AirBlinkOutFx", 3, function(parent, add)
	local center = FxKit.hiddenPart("HT_AirBlinkOut", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)

	-- 0 f. An upright line that grows tall and hair-thin: the body closing to nothing.
	local line = add(at, "Line", Tex.Needle, 1, 0, keys(0, 1.6, 1, 2.2))
	line.Lifetime = NumberRange.new(0.12)
	line.Rotation = NumberRange.new(90)
	line.Squash = fade(0, -0.6, 1, -1.8) -- about 5 studs tall at first, 15 and hair-thin at the end
	line.Brightness = 3
	line.ZOffset = 1
	line.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)

	-- 0 f. A ring closing on it.
	local ring = add(at, "Ring", Tex.Circle, 1, 0, keys(0, 2.6, 0.6, 1, 1, 0.3))
	ring.Lifetime = NumberRange.new(0.1)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.8
	ring.Transparency = fade(0, 0.3, 0.5, 0.1, 1, 0.6)

	return { center = center }
end)

local arrivals = FxKit.pool("HT_AirBlinkInFx", 3, function(parent, add)
	local center = FxKit.hiddenPart("HT_AirBlinkIn", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)
	local lines = FxKit.hiddenPart("HT_AirBlinkLines", Vector3.new(1.2, 2.6, 0.2), parent)

	-- 0 f. A white spot and an upright four-point star, gone in seven frames.
	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 1.4, 0.3, 2, 1, 0.8))
	core.Lifetime = NumberRange.new(0.07)
	core.Brightness = 3
	core.ZOffset = 1
	core.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)
	local star = add(at, "Star", Tex.Star, 1, 0, keys(0, 2.6, 0.3, 2, 1, 0))
	star.Lifetime = NumberRange.new(0.12)
	star.Rotation = NumberRange.new(0)
	star.Brightness = 3
	star.ZOffset = 1.2
	star.Transparency = fade(0, 0, 0.8, 0.1, 1, 1)

	-- 1 f. A ring opening from the spot.
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 0.8, 0.4, 2.2, 1, 2.8))
	ring.Lifetime = NumberRange.new(0.14)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.8
	ring.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)

	-- 0 f. Three lines crossing the gap into the spot (about 7 studs long). Only when the way they
	-- came is known.
	local across = add(
		lines,
		"Across",
		Tex.Needle,
		3,
		0,
		curve(0, 1.2, 0.3, 0.25, 1.4, 0.4, 1, 1.1, 0.3),
		{ speed = NumberRange.new(10, 25), flag = "across" }
	)
	shot(across)
	across.Lifetime = NumberRange.new(0.1, 0.14)

	-- 2 f. Two small puffs where they arrive.
	local smoke = add(
		at,
		"Puffs",
		Tex.Smoke,
		2,
		2,
		curve(0, 0.6, 0.2, 0.4, 1.1, 0.3, 1, 1.4, 0.4),
		{ speed = NumberRange.new(1, 4) }
	)
	puffs(smoke)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Lifetime = NumberRange.new(0.25, 0.35)

	return { center = center, lines = lines }
end)

--- The gust behind a punch thrown in the air at `position`, the punch going along `direction`.
function AirFx.gust(position: Vector3, direction: Vector3)
	if direction.Magnitude < 0.01 then
		return
	end
	local back = -direction.Unit
	local rig = gusts.take()
	local plate = rig.parts.plate :: Part
	local lines = rig.parts.lines :: Part
	local behind = position + back * 1.2
	-- The plate's +Y is turned to look back along the punch.
	plate.CFrame = CFrame.lookAt(behind, behind + back) * CFrame.Angles(-math.pi / 2, 0, 0)
	-- The lines are about 4 studs long, so their source sits half a line along.
	local from = behind + back * 2
	lines.CFrame = CFrame.lookAt(from, from + back)
	FxKit.fire(rig, 1)
end

--- Where a blink leaves from: the body closes to an upright line.
function AirFx.blinkOut(position: Vector3)
	local rig = leaves.take()
	local center = rig.parts.center :: Part
	center.CFrame = CFrame.new(position)
	FxKit.fire(rig, 1)
end

--- Where a blink arrives. `came` is the way from where they left to here (its length is the gap);
--- with it, lines cross the last of the gap into the spot.
function AirFx.blinkIn(position: Vector3, came: Vector3?)
	local rig = arrivals.take()
	local center = rig.parts.center :: Part
	local lines = rig.parts.lines :: Part
	center.CFrame = CFrame.new(position)
	local across = came ~= nil and came.Magnitude > 1
	if came and across then
		local along = came.Unit
		-- The lines are about 7 studs long and end at the spot.
		local from = position - along * 3.5
		lines.CFrame = CFrame.lookAt(from, from + along)
	end
	FxKit.fire(rig, 1, nil, { across = across })
end

-- TRAIL. One emitter on each part that has been launched, made the first time and reused: switched on
-- for the moment the body is flying, so it leaves puffs along its path.
type Trailing = { emitter: ParticleEmitter, token: number }
local trails: { [BasePart]: Trailing } = setmetatable({}, { __mode = "k" }) :: any

--- Smoke puffs left behind `part` (a launched body's root) for `seconds`.
function AirFx.trail(part: BasePart, seconds: number)
	local trailing = trails[part]
	if not trailing or trailing.emitter.Parent ~= part then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "HT_AirTrail"
		emitter.Texture = Tex.Smoke
		emitter.Enabled = false
		emitter.Rate = 22
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7, 0.2),
			NumberSequenceKeypoint.new(0.4, 1.2, 0.3),
			NumberSequenceKeypoint.new(1, 1.6, 0.4),
		})
		emitter.Speed = NumberRange.new(0.5, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Lifetime = NumberRange.new(0.3, 0.45)
		puffs(emitter)
		emitter.Parent = part
		trailing = { emitter = emitter, token = 0 }
		trails[part] = trailing
	end
	trailing.token += 1
	local token = trailing.token
	local shown = trailing
	shown.emitter.Enabled = true
	task.delay(seconds, function()
		if shown.token == token then
			shown.emitter.Enabled = false
		end
	end)
end

-- BUMP: two fighters knocking into each other. A small white spot, one thin ring and four small
-- puffs. Nobody is hurt, so it is smaller and softer than a hit.
local bumps = FxKit.pool("HT_AirBumpFx", 4, function(parent, add)
	local center = FxKit.hiddenPart("HT_AirBump", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)

	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 1, 0.3, 1.5, 1, 0.7))
	core.Lifetime = NumberRange.new(0.07)
	core.Brightness = 2.5
	core.ZOffset = 1
	core.Transparency = fade(0, 0.1, 0.5, 0.25, 1, 1)

	local ring = add(at, "Ring", Tex.Circle, 1, 0, keys(0, 0.9, 0.4, 2, 1, 2.6))
	ring.Lifetime = NumberRange.new(0.14)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.6
	ring.Transparency = fade(0, 0.15, 0.5, 0.45, 1, 1)

	local smoke = add(
		at,
		"Puffs",
		Tex.Smoke,
		4,
		1,
		curve(0, 0.7, 0.2, 0.4, 1.3, 0.4, 1, 1.7, 0.5),
		{ speed = NumberRange.new(2, 6) }
	)
	puffs(smoke)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Lifetime = NumberRange.new(0.28, 0.4)

	return { center = center }
end)

-- DRIFT: one puff of smoke kicked up by feet sliding sideways out of a dash. It leaves the way the
-- part's front faces, rising a little as it swells.
local drifts = FxKit.pool("HT_AirDriftFx", 8, function(parent, add)
	local center = FxKit.hiddenPart("HT_AirDrift", Vector3.new(0.6, 0.4, 0.2), parent)
	local smoke = add(
		center,
		"Puff",
		Tex.Smoke,
		1,
		0,
		curve(0, 0.8, 0.2, 0.4, 1.6, 0.4, 1, 2.2, 0.5),
		{ speed = NumberRange.new(3, 5) }
	)
	puffs(smoke)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Acceleration = Vector3.new(0, 6, 0)
	smoke.Lifetime = NumberRange.new(0.4, 0.55)
	return { center = center }
end)

--- Two fighters bumping at `position`. `scale` is how hard (1 = an ordinary knock).
function AirFx.bump(position: Vector3, scale: number)
	local rig = bumps.take()
	local center = rig.parts.center :: Part
	center.CFrame = CFrame.new(position)
	FxKit.fire(rig, scale)
end

--- One puff of drift smoke at `position`, leaving along `drift`.
function AirFx.puff(position: Vector3, drift: Vector3)
	local rig = drifts.take()
	local center = rig.parts.center :: Part
	local way = FxKit.flat(drift)
	center.CFrame = CFrame.lookAt(position, position + way)
	FxKit.fire(rig, 1)
end

-- RIBBON. A plain wide streak behind a part for a moment (the body an uppercut has thrown). One
-- Trail per part, made the first time and reused.
local ribbons: { [BasePart]: Trail } = setmetatable({}, { __mode = "k" }) :: any
local ribbonTokens: { [Trail]: number } = setmetatable({}, { __mode = "k" }) :: any

--- A streak behind `part` for `seconds`, `width` studs thick, each bit of it lasting `life` seconds.
function AirFx.ribbon(part: BasePart, seconds: number, width: number, life: number)
	local drop = part.Size.Y / 2 - 0.15
	local trail = ribbons[part]
	if not trail or trail.Parent ~= part then
		local top = Instance.new("Attachment")
		top.Name = "HT_AirRibbonA"
		top.Parent = part
		local bottom = Instance.new("Attachment")
		bottom.Name = "HT_AirRibbonB"
		bottom.Parent = part
		local made = Instance.new("Trail")
		made.Name = "HT_AirRibbon"
		made.Attachment0 = top
		made.Attachment1 = bottom
		made.FaceCamera = true
		made.MinLength = 0.05
		made.Color = ColorSequence.new(FxKit.WHITE, FxKit.SMOKE_GREY)
		made.Transparency = fade(0, 0.25, 1, 1)
		made.WidthScale = NumberSequence.new(1, 0.2)
		made.LightEmission = 1
		made.LightInfluence = 0
		made.Enabled = false
		made.Parent = part
		ribbons[part] = made
		trail = made
	end
	local shown = trail :: Trail
	-- Its width can change from use to use.
	if shown.Attachment0 and shown.Attachment1 then
		shown.Attachment0.Position = Vector3.new(0, -drop, width / 2)
		shown.Attachment1.Position = Vector3.new(0, -drop, -width / 2)
	end
	shown.Lifetime = life
	shown:Clear()
	shown.Enabled = true
	local token = (ribbonTokens[shown] or 0) + 1
	ribbonTokens[shown] = token
	task.delay(seconds, function()
		if ribbonTokens[shown] == token then
			shown.Enabled = false
		end
	end)
end

--- Builds every rig ahead of the first use, so the textures are loaded by then.
function AirFx.preload()
	gusts.preload()
	leaves.preload()
	arrivals.preload()
	bumps.preload()
	drifts.preload()
end

return AirFx
