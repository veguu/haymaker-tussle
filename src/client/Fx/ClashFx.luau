--!strict
-- ClashFx - two small effects of a clash, BASIC and PLAIN, in the style (Fx/FxKit). All particles,
-- white only. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- vfx-12 (the user, 2026-11-14: basic effects, nothing green, "just make it plain ... this goes for
-- everything"): no colour and no black here either.
--
-- PULSE: one of the barrage's punches meeting in the middle. A small white-hot spot with six short
-- spikes round it, then a small thin ring opening from it. Small and quick: it is thrown many times
-- a second.
--
-- REPEL: a third fighter's punch bouncing off a clash. A cross flare for one frame (a long thin line
-- across and a shorter upright one, after xander22's "Projectiles", YouTube qbF1YPQFcEg, frames 377
-- and 1701), then a ring that widens and thins while an upright four-point star shrinks inside it
-- (after Hazaze's "Frigid Rush", YouTube 2fwT64lFtao, frames 164-179), white lines thrown back the
-- way the punch came from, and a few sparkles that sit and shrink.

local FxKit = require(script.Parent.FxKit)

local ClashFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve

-- The pulse's spikes: angle (degrees), how far out the middle sits (studs), Size. Each is 2.55 times
-- its Size long, and its middle sits half that out, so its tail starts at the spot.
local PULSE_SPIKES = {
	{ 20, 1.2, 0.94 },
	{ 80, 0.7, 0.55 },
	{ 140, 1.4, 1.1 },
	{ 200, 0.8, 0.63 },
	{ 260, 1.1, 0.86 },
	{ 320, 0.75, 0.59 },
}

local pulses = FxKit.pool("HT_ClashPulseFx", 6, function(parent, add)
	local center = FxKit.hiddenPart("HT_ClashPulse", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)

	-- 0 f. The white-hot spot.
	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 1.1, 0.3, 1.5, 1, 0.7))
	core.Lifetime = NumberRange.new(0.06)
	core.Brightness = 3
	core.ZOffset = 1
	core.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)

	-- 0 f. Six short spikes round it: full length at once, then shrinking away from the spot.
	local spikes =
		FxKit.placed(add, center, "Spike", PULSE_SPIKES, 0, -0.35, NumberRange.new(0.07, 0.12))

	-- 1 f. The small thin ring, opening from the middle. A plain circle.
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 1.2, 0.5, 2.6, 1, 3.2))
	ring.Lifetime = NumberRange.new(0.1)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.5
	ring.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)

	return { center = center, spikes = spikes }
end)

local repels = FxKit.pool("HT_ClashRepelFx", 3, function(parent, add)
	local center = FxKit.hiddenPart("HT_ClashRepel", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)
	-- The thrown-back lines leave the whole of this part's front face.
	local lines = FxKit.hiddenPart("HT_ClashRepelLines", Vector3.new(1.6, 2.2, 0.2), parent)

	-- 0 f. The cue: a cross flare, one long thin line across and a shorter upright one.
	local across = add(at, "FlareAcross", Tex.Needle, 1, 0, keys(0, 2.6, 1, 2.2))
	across.Lifetime = NumberRange.new(0.07)
	across.Rotation = NumberRange.new(0)
	across.Squash = NumberSequence.new(-1.5) -- about 15 studs long
	across.Brightness = 3
	across.ZOffset = 1.5
	across.Transparency = fade(0, 0, 0.5, 0.1, 1, 1)
	local upright = add(at, "FlareUp", Tex.Needle, 1, 0, keys(0, 1.6, 1, 1.3))
	upright.Lifetime = NumberRange.new(0.07)
	upright.Rotation = NumberRange.new(90)
	upright.Squash = NumberSequence.new(-1.5) -- about 9 studs tall
	upright.Brightness = 2.5
	upright.ZOffset = 1.5
	upright.Transparency = fade(0, 0.1, 0.5, 0.25, 1, 1)

	-- 1 f. The ring: widens and thins while it fades. Kept small enough not to dip under the floor.
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 2.2, 0.4, 3.6, 1, 4.6))
	ring.Lifetime = NumberRange.new(0.27)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 2
	ring.Transparency = fade(0, 0.05, 0.5, 0.4, 1, 1)

	-- 1 f. The four-point star inside it, upright, shrinking as the ring grows.
	local star = add(at, "Star", Tex.Star, 1, 1, keys(0, 3, 0.3, 2.2, 1, 0))
	star.Lifetime = NumberRange.new(0.2)
	star.Rotation = NumberRange.new(0)
	star.Brightness = 3
	star.ZOffset = 1
	star.Transparency = fade(0, 0, 0.8, 0.1, 1, 1)

	-- 1 f. White lines thrown back the way the punch came from (about 8 studs long).
	local back = add(
		lines,
		"Back",
		Tex.Needle,
		6,
		1,
		curve(0, 1.4, 0.4, 0.25, 1.7, 0.5, 1, 1.2, 0.4),
		{ speed = NumberRange.new(20, 50) }
	)
	back.Orientation = Enum.ParticleOrientation.VelocityParallel
	back.EmissionDirection = Enum.NormalId.Front
	back.Lifetime = NumberRange.new(0.1, 0.15)
	back.Drag = 5
	back.Brightness = 2.2
	back.Squash = NumberSequence.new(-1.26)
	back.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)

	-- 3 f. A few upright sparkles that sit where they are and shrink.
	local sparkles = add(
		at,
		"Sparkles",
		Tex.Star,
		4,
		3,
		curve(0, 0.5, 0.2, 0.2, 0.7, 0.25, 1, 0, 0),
		{ speed = NumberRange.new(6, 16) }
	)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Drag = 12
	sparkles.Lifetime = NumberRange.new(0.2, 0.32)
	sparkles.Rotation = NumberRange.new(0)
	sparkles.Brightness = 3
	sparkles.ZOffset = 1.2
	sparkles.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)

	return { center = center, lines = lines }
end)

--- Two of a clash's punches meeting at `position`.
function ClashFx.pulse(position: Vector3)
	local rig = pulses.take()
	local center = rig.parts.center :: Part
	-- The spot's part is turned to the camera, so its spikes are laid out as the camera sees them,
	-- turned differently each time.
	center.CFrame = FxKit.screenAt(position)
	FxKit.arrange(rig.parts.spikes, 1, math.random() * 360, 1)
	FxKit.fire(rig, 1)
end

--- A punch bouncing off a clash at `position`, thrown back along `back` (toward whoever threw it).
function ClashFx.repel(position: Vector3, back: Vector3)
	local rig = repels.take()
	local way = FxKit.flat(back)
	local center = rig.parts.center :: Part
	local lines = rig.parts.lines :: Part
	center.CFrame = CFrame.lookAt(position, position + way)
	-- The lines are about 8 studs long, so their source sits half a line along.
	local from = position + way * 4
	lines.CFrame = CFrame.lookAt(from, from + way)
	FxKit.fire(rig, 1)
end

--- Builds every rig ahead of the first use, so the textures are loaded by then.
function ClashFx.preload()
	pulses.preload()
	repels.preload()
end

return ClashFx
