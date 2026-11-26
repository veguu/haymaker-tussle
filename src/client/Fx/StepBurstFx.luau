--!strict
-- StepBurstFx - the burst on the floor under a hard step, a dash off the ground, a jump or a landing,
-- after the floor rings in Venomec's "Mumen Rider Combo" (YouTube 3R5WsLDp2f4; the launch at frames
-- 196-211, the landing at 258-292, the second launch at 327-343). All particles, white and grey only:
-- in the style (Fx/FxKit) a colourless shape on the floor means movement, never a hit.
--
-- THE BURST, frame by frame (1 f = 1/60 s), with the reference's measures (H = one character height):
--   0 f   a toothed white burst flat on the floor: 0.85 H wide, then 1.7, 2.5, 2.6, 2.7: very fast for
--         two frames, then a hard stop, fading from the third. With it a soft flash, 1.4 to 2.1 H.
--   1 f   a thin bright circle inside it, 0.7 to 1.2 H
--   3 f   a ticked ring that keeps spreading at a steady 0.2 H a frame while it fades (to 14 f)
--   6 f   three thin crescents lying inside the ring, the slowest thing here (to about 25 f)
--   5 f   a ring of smoke puffs, gone by half a second
-- Three speeds: the flash (2 frames), the ring (11) and the crescents (20).
--
-- vfx-11 (the user, 2026-11-14: the toothed burst and the ticked ring looked like "a drawing of the
-- sun"): both are plain thin circles now, and the extra inner circle is gone. What is left is two
-- rings at two speeds, three crescents and the smoke.
--
-- vfx-10: rebuilt on FxKit. The old one was drawn twice the reference's size (a particle is drawn
-- twice its Size across), turned its arcs at 420 degrees a second, and kept its smoke 0.75 s.

local FxKit = require(script.Parent.FxKit)

local StepBurstFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve

local WIDTH = 9 -- of the part the smoke rises from, at scale 1
local LIFT = 0.6 -- the part sits this far above the floor, so the smoke isn't half buried
local FLOOR_REACH = 7 -- how far under the point a floor is looked for

local pool = FxKit.pool("HT_StepBurstFx", 6, function(parent, add)
	local floor = FxKit.hiddenPart("HT_StepBurst", Vector3.new(WIDTH, 0.2, WIDTH), parent)
	local ground = FxKit.attach(floor, Vector3.new(0, 0.15 - LIFT, 0))

	-- 0 f. The toothed burst: out very fast, then a hard stop.
	local burst = add(
		ground,
		"Burst",
		Tex.Circle,
		1,
		0,
		keys(0, 2.1, 0.14, 4.25, 0.29, 6.25, 0.43, 6.5, 1, 6.9),
		{ flat = true }
	)
	burst.Lifetime = NumberRange.new(0.117)
	burst.Rotation = NumberRange.new(0, 360)
	burst.LightEmission = 0.8
	burst.Brightness = 1.6
	burst.Transparency = fade(0, 0, 0.4, 0.1, 1, 1)

	-- 0 f. The soft flash under the feet.
	local flash = add(ground, "Flash", Tex.Glow, 1, 0, keys(0, 3.5, 1, 5.2), { flat = true })
	flash.Lifetime = NumberRange.new(0.06)
	flash.LightEmission = 0.8
	flash.Brightness = 1.5
	flash.Transparency = fade(0, 0.25, 1, 1)

	-- 3 f. The ticked ring: a ripple that keeps spreading at a steady rate while it fades.
	local ring =
		add(ground, "Ring", Tex.Circle, 1, 3, keys(0, 3.4, 0.5, 6.2, 1, 8.5), { flat = true })
	ring.Lifetime = NumberRange.new(0.18)
	ring.Rotation = NumberRange.new(0, 360)
	ring.LightEmission = 0.8
	ring.Brightness = 1.6
	ring.Transparency = fade(0, 0.05, 0.5, 0.35, 1, 1)

	-- 6 f. Three thin crescents lying inside the ring, a third of a turn apart, widening slowly. They
	-- turn together, slowly, so they stay evenly spaced.
	for index = 1, 3 do
		local arc = add(
			ground,
			"Crescent" .. index,
			Tex.Arc,
			1,
			6,
			keys(0, 5.2, 0.4, 6.8, 1, 8),
			{ flat = true }
		)
		arc.Rotation = NumberRange.new((index - 1) * 120)
		arc.RotSpeed = NumberRange.new(50)
		arc.Lifetime = NumberRange.new(0.34)
		arc.Brightness = 2
		arc.Transparency = fade(0, 0.1, 0.5, 0.35, 1, 1)
	end

	-- 5 f. Smoke round it: a few puffs that play the flipbook once and fade nearly where they are.
	local smoke = add(
		floor,
		"Smoke",
		Tex.Smoke,
		8,
		5,
		curve(0, 1.3, 0.4, 0.5, 2, 0.6, 1, 2.4, 0.7),
		{ speed = NumberRange.new(0.4, 1.6) }
	)
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.Shape = Enum.ParticleEmitterShape.Disc
	smoke.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(80, 80)
	smoke.Color = ColorSequence.new(FxKit.SMOKE_GREY)
	smoke.LightEmission = 0.3
	smoke.Lifetime = NumberRange.new(0.35, 0.5)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Drag = 2
	smoke.Transparency = fade(0, 0.2, 0.6, 0.45, 1, 1)

	-- A HEAVY LANDING ONLY (a body slammed into the floor): the same burst, plus
	-- thin white lines thrown up off the floor at once, and more smoke rising from 4 f. This replaces
	-- the old ground blast (a flash, spikes, a pillar of light, embers and fire in gold and orange).
	local upLines = add(
		floor,
		"UpLines",
		Tex.Needle,
		7,
		0,
		curve(0, 0.9, 0.3, 0.25, 1.1, 0.35, 1, 0.8, 0.25),
		{ speed = NumberRange.new(25, 55), flag = "heavy" }
	)
	upLines.Orientation = Enum.ParticleOrientation.VelocityParallel
	upLines.EmissionDirection = Enum.NormalId.Top
	upLines.SpreadAngle = Vector2.new(28, 28)
	upLines.Lifetime = NumberRange.new(0.1, 0.17)
	upLines.Drag = 5
	upLines.Brightness = 2.2
	upLines.Squash = NumberSequence.new(-1.26) -- about 5 studs long
	upLines.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)
	local rising = add(
		floor,
		"RisingSmoke",
		Tex.Smoke,
		7,
		4,
		curve(0, 1.4, 0.4, 0.4, 2.4, 0.7, 1, 3, 0.8),
		{ speed = NumberRange.new(3, 8), flag = "heavy" }
	)
	rising.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	rising.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	rising.EmissionDirection = Enum.NormalId.Top
	rising.SpreadAngle = Vector2.new(35, 35)
	rising.Color = ColorSequence.new(FxKit.SMOKE_GREY)
	rising.LightEmission = 0.3
	rising.Lifetime = NumberRange.new(0.4, 0.55)
	rising.Rotation = NumberRange.new(0, 360)
	rising.RotSpeed = NumberRange.new(-30, 30)
	rising.Drag = 2
	rising.Transparency = fade(0, 0.25, 0.6, 0.5, 1, 1)

	return { floor = floor }
end)

--- A burst on the floor under `position` (nothing if there's no floor within reach). `scale` is its
--- size against the reference's (1 = 2.7 character heights wide at its widest). heavy is a body
--- slammed into the floor: lines thrown up and more smoke.
function StepBurstFx.play(position: Vector3, scale: number, heavy: boolean?)
	local at = FxKit.floorUnder(position, FLOOR_REACH)
	if not at then
		return
	end
	local rig = pool.take()
	local floor = rig.parts.floor :: Part
	floor.CFrame = CFrame.new(at + Vector3.new(0, LIFT, 0))
	floor.Size = Vector3.new(WIDTH * scale, 0.2, WIDTH * scale)
	FxKit.fire(rig, scale, nil, { heavy = heavy == true })
end

--- Builds every rig ahead of the first burst, so the textures are loaded by then.
function StepBurstFx.preload()
	pool.preload()
end

return StepBurstFx
