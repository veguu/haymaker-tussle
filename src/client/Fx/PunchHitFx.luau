--!strict
-- PunchHitFx - a landed punch: a BASIC, PLAIN hit spark, in the style (Fx/FxKit). All particles,
-- white only. Decoration on this client only: nothing here can collide, block a ray or affect gameplay.
--
-- WHY IT IS BASIC AND PLAIN (the user, 2026-11-14, on vfx-10): "i dont really want the mumen rider
-- vfx, i just want a basic punching animation", then "dont make the stuff green just make it plain
-- ... this goes for everything". Until then this file was a layer-by-layer replica of the first hit
-- in Venomec's "Mumen Rider Combo" (a green star of forty spikes, a 22-stud band of lines, a shock
-- bubble, a floor ring, smoke, arcs): far too much for a punch thrown every half second. That replica
-- is in Git (commit 070c547, vfx-9) if it is wanted for a bigger move.
--
-- THE PUNCH, frame by frame (1 f = 1/60 s), about the size of a head and gone in a sixth of a second:
--   0 f   a small white-hot spot, and eight short white spikes round it, each its own length, full
--         length at once, then shrinking away from the spot; two longer ones lean the way the hit
--         sends them
--   1 f   a thin white ring opening from the spot, and five short white lines shot the way of the hit
--   2 f   four small sparks further out, pointing outward, shrinking where they are
-- A strong hit is the same thing half as big again, with a second ring and three glints.
-- No colour, no black, no floor ring, no bubble, no smoke.

local FxKit = require(script.Parent.FxKit)

local PunchHitFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve

local STRONG_SCALE = 1.5
local LINE_AHEAD = 2.6 -- half a line: the lines' source sits this far along, so they start at the hit
local SPIKE_SQUASH = -0.35 -- a spike is 2.55 times its Size long

-- Each piece: angle round the spot (degrees), how far out its middle sits (studs), Size. A spike's
-- middle sits half its length out, so its tail starts at the spot.
local SPIKES = {
	{ 10, 1.8, 1.41 },
	{ 52, 1, 0.78 },
	{ 97, 2, 1.57 },
	{ 140, 1.2, 0.94 },
	{ 186, 1.6, 1.25 },
	{ 228, 0.9, 0.71 },
	{ 275, 1.9, 1.49 },
	{ 318, 1.3, 1.02 },
}
-- The two leaning spikes: their angles are from the way the hit sends them, not turned at random.
local LEAN = {
	{ 22, 2.4, 1.88 },
	{ 338, 2.1, 1.65 },
}
local SPARKS = {
	{ 40, 2.8, 0.6 },
	{ 130, 3.1, 0.7 },
	{ 215, 2.7, 0.55 },
	{ 300, 3, 0.65 },
}

local pool = FxKit.pool("HT_PunchHitFx", 6, function(parent, add)
	local center = FxKit.hiddenPart("HT_PunchHit", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)
	-- The lines leave the whole of this part's front face, so they come as a small band.
	local lines = FxKit.hiddenPart("HT_PunchHitLines", Vector3.new(1, 1.4, 0.2), parent)
	-- Turned to the camera for each hit: the spikes and sparks are laid out on it.
	local face = FxKit.hiddenPart("HT_PunchHitFace", Vector3.new(0.2, 0.2, 0.2), parent)

	-- 0 f. The white-hot spot, and a faint soft glow round it.
	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 1.5, 0.3, 2.1, 1, 1))
	core.Lifetime = NumberRange.new(0.08)
	core.Brightness = 3
	core.ZOffset = 1.5
	core.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)
	local halo = add(at, "Halo", Tex.Glow, 1, 0, keys(0, 1.8, 0.4, 2.8, 1, 3.2), { tint = true })
	halo.Lifetime = NumberRange.new(0.11)
	halo.LightEmission = 0.6
	halo.ZOffset = 0.3
	halo.Transparency = fade(0, 0.7, 0.5, 0.82, 1, 1)

	-- 0 f. Eight short spikes and the two leaning ones: full length at once, then shrinking.
	local spikes =
		FxKit.placed(add, face, "Spike", SPIKES, 0, SPIKE_SQUASH, NumberRange.new(0.09, 0.14))
	local lean =
		FxKit.placed(add, face, "Lean", LEAN, 0, SPIKE_SQUASH, NumberRange.new(0.1, 0.14), true)

	-- 1 f. A thin white ring opening from the spot: a plain circle.
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 1.1, 0.4, 2.1, 1, 2.6))
	ring.Lifetime = NumberRange.new(0.13)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.8
	ring.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)

	-- 1 f. Five short white lines shot the way of the hit (about 5 studs long), drifting on a little.
	local streaks = add(
		lines,
		"Lines",
		Tex.Needle,
		5,
		1,
		curve(0, 0.9, 0.3, 0.25, 1.1, 0.3, 1, 0.8, 0.25),
		{ speed = NumberRange.new(12, 30) }
	)
	streaks.Orientation = Enum.ParticleOrientation.VelocityParallel
	streaks.EmissionDirection = Enum.NormalId.Front
	streaks.Lifetime = NumberRange.new(0.08, 0.13)
	streaks.Drag = 5
	streaks.Brightness = 2.2
	streaks.Squash = NumberSequence.new(-1.26)
	streaks.ZOffset = 0.8
	streaks.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)

	-- 2 f. Four small sparks further out, pointing outward, shrinking where they are.
	local sparks = FxKit.placed(add, face, "Spark", SPARKS, 2, 0.6, NumberRange.new(0.1, 0.15))

	-- A STRONG HIT ONLY. 3 f: a second, wider ring. 4 f: three upright glints thrown outward.
	local second =
		add(at, "SecondRing", Tex.Circle, 1, 3, keys(0, 1.8, 0.4, 3.2, 1, 3.9), { flag = "strong" })
	second.Lifetime = NumberRange.new(0.16)
	second.Rotation = NumberRange.new(0, 360)
	second.Brightness = 1.6
	second.Transparency = fade(0, 0.2, 0.5, 0.5, 1, 1)
	local glints = add(
		at,
		"Glints",
		Tex.Star,
		3,
		4,
		curve(0, 0.1, 0.05, 0.3, 0.8, 0.3, 1, 0, 0),
		{ flag = "strong", speed = NumberRange.new(6, 16) }
	)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Drag = 6
	glints.Lifetime = NumberRange.new(0.18, 0.3)
	glints.Rotation = NumberRange.new(0)
	glints.Brightness = 3
	glints.ZOffset = 1.6
	glints.Transparency = fade(0, 0, 0.7, 0.1, 1, 1)

	return {
		center = center,
		lines = lines,
		face = face,
		spikes = spikes,
		lean = lean,
		sparks = sparks,
	}
end)

--- A landed punch at `position`, sending them along `direction`. `size` is how big it is against an
--- ordinary punch (1). It is plain white unless a `colour` is passed for its tinted layers (nothing
--- passes one yet). `heavy` is a strong hit: half as big again, with a second ring and three glints.
function PunchHitFx.play(
	position: Vector3,
	direction: Vector3,
	size: number,
	colour: Color3?,
	heavy: boolean?
)
	local scale = if heavy then size * STRONG_SCALE else size
	local way = FxKit.flat(direction)
	local rig = pool.take()
	local parts = rig.parts
	local center = parts.center :: Part
	local lines = parts.lines :: Part
	local face = parts.face :: Part
	local side = FxKit.sideOf(way)

	center.CFrame = CFrame.lookAt(position, position + way)
	local from = position + way * LINE_AHEAD * scale
	lines.CFrame = CFrame.lookAt(from, from + way)
	lines.Size = Vector3.new(1, 1.4, 0.2) * scale
	-- The spikes and sparks are laid out as the camera sees them; the set is turned differently each
	-- hit, except the two leaning spikes, which follow the hit.
	face.CFrame = FxKit.screenAt(position)
	local turned = math.random() * 360
	FxKit.arrange(parts.spikes, scale, turned, side)
	FxKit.arrange(parts.lean, scale, 0, side)
	FxKit.arrange(parts.sparks, scale, turned + 20, side)

	FxKit.fire(rig, scale, colour, { strong = heavy == true })
end

--- Builds every rig ahead of the first hit, so the textures are loaded by then.
function PunchHitFx.preload()
	pool.preload()
end

--- FOR STUDY ONLY: plays every kit effect after this `factor` times slower (1 puts it back).
function PunchHitFx.studySlow(factor: number)
	FxKit.studySlow(factor)
end

return PunchHitFx
