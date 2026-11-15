--!strict
-- KickHitFx - a kick that lands: a BASIC, PLAIN hit, one size up from a punch (Fx/PunchHitFx), in
-- the style (Fx/FxKit). All particles, white only. Decoration on this client only: nothing here can
-- collide, block a ray or affect gameplay.
--
-- WHY IT IS BASIC AND PLAIN (the user, 2026-11-14): after asking for "a basic punching animation" in
-- place of the Mumen Rider replica, they asked for the kick to be basic too, and for nothing to be
-- green ("just make it plain ... this goes for everything"). vfx-10's kick was the reference's second
-- hit (a star, a 27-stud beam, a fan of black lines, a bubble, a green ball with fourteen sparks,
-- three hoops, smoke); it was never committed.
--
-- THE KICK, frame by frame (1 f = 1/60 s), about a body wide and gone in a fifth of a second:
--   0 f   a white-hot spot, and ten short white spikes round it, each its own length, full length at
--         once, then shrinking away from the spot; three longer ones lean the way the kick sends them
--   1 f   ONE short thick streak the way of the kick (what tells it from a punch), about 9 studs,
--         thinning as it goes; six thin white lines round it; a thin white ring opening from the spot
--   2 f   seven small sparks further out, pointing outward, shrinking where they are
--   3 f   a second, wider ring, and three glints
-- No colour, no black, no bubble, no ball, no hoops, no smoke. A body reaching the floor, or a kick
-- that hits nothing, gets the white floor burst (Fx/StepBurstFx), not this.

local FxKit = require(script.Parent.FxKit)

local KickHitFx = {}

local Tex = FxKit.Tex
local fade, keys, curve = FxKit.fade, FxKit.keys, FxKit.curve

local STREAK_SIZE = 3.4 -- the thick streak's Size at its longest: about 9 studs long
local STREAK_AHEAD = 4.5 -- half the streak: its source sits this far along, so it starts at the hit
local LINES_FACE = Vector3.new(1.4, 2.2, 0.2)
local SPIKE_SQUASH = -0.35 -- a spike is 2.55 times its Size long

-- Each piece: angle round the spot (degrees), how far out its middle sits (studs), Size. A spike's
-- middle sits half its length out, so its tail starts at the spot.
local SPIKES = {
	{ 6, 2.3, 1.8 },
	{ 41, 1.3, 1.02 },
	{ 78, 2.5, 1.96 },
	{ 113, 1.5, 1.18 },
	{ 150, 2.1, 1.65 },
	{ 187, 1.2, 0.94 },
	{ 222, 2.4, 1.88 },
	{ 259, 1.6, 1.25 },
	{ 296, 2, 1.57 },
	{ 331, 1.4, 1.1 },
}
-- The three leaning spikes: their angles are from the way the kick sends them.
local LEAN = {
	{ 28, 3, 2.35 },
	{ 332, 2.7, 2.12 },
	{ 80, 2, 1.57 },
}
local SPARKS = {
	{ 20, 3.6, 0.8 },
	{ 75, 4, 0.9 },
	{ 128, 3.5, 0.7 },
	{ 180, 3.9, 0.85 },
	{ 235, 3.6, 0.75 },
	{ 290, 4.1, 0.9 },
	{ 340, 3.4, 0.7 },
}

local pool = FxKit.pool("HT_KickHitFx", 4, function(parent, add)
	local center = FxKit.hiddenPart("HT_KickHit", Vector3.new(0.2, 0.2, 0.2), parent)
	local at = FxKit.attach(center)
	local streakPart = FxKit.hiddenPart("HT_KickStreak", Vector3.new(0.5, 0.5, 0.2), parent)
	local lines = FxKit.hiddenPart("HT_KickLines", LINES_FACE, parent)
	-- Turned to the camera for each kick: the spikes and sparks are laid out on it.
	local face = FxKit.hiddenPart("HT_KickFace", Vector3.new(0.2, 0.2, 0.2), parent)

	-- 0 f. The white-hot spot, and a faint soft glow round it.
	local core = add(at, "Core", Tex.Glow, 1, 0, keys(0, 2, 0.3, 2.8, 1, 1.3))
	core.Lifetime = NumberRange.new(0.09)
	core.Brightness = 3
	core.ZOffset = 1.5
	core.Transparency = fade(0, 0, 0.5, 0.15, 1, 1)
	local halo = add(at, "Halo", Tex.Glow, 1, 0, keys(0, 2.4, 0.4, 3.6, 1, 4.1), { tint = true })
	halo.Lifetime = NumberRange.new(0.12)
	halo.LightEmission = 0.6
	halo.ZOffset = 0.3
	halo.Transparency = fade(0, 0.7, 0.5, 0.82, 1, 1)

	-- 0 f. Ten short spikes and the three leaning ones: full length at once, then shrinking.
	local spikes =
		FxKit.placed(add, face, "Spike", SPIKES, 0, SPIKE_SQUASH, NumberRange.new(0.1, 0.15))
	local lean =
		FxKit.placed(add, face, "Lean", LEAN, 0, SPIKE_SQUASH, NumberRange.new(0.11, 0.15), true)

	-- 1 f. THE STREAK: one short thick line the way of the kick. A particle is drawn twice its Size
	-- across and Squash s makes it 2^-s times as long: about 6 studs at birth, 9 a quarter of the way
	-- through, then thinning. A bright middle in front, a slightly fatter soft one behind.
	local function streak(name: string, fatter: number): ParticleEmitter
		local big = STREAK_SIZE * fatter
		local made = add(
			streakPart,
			name,
			Tex.Needle,
			1,
			1,
			keys(0, big * 0.75, 0.25, big, 1, big * 0.55),
			{ speed = NumberRange.new(8, 16) }
		)
		made.Orientation = Enum.ParticleOrientation.VelocityParallel
		made.EmissionDirection = Enum.NormalId.Front
		made.Lifetime = NumberRange.new(0.11, 0.13)
		made.Squash = fade(0, -0.2, 0.25, -0.45, 1, -1.1)
		made.Transparency = fade(0, 0, 0.6, 0.08, 1, 1)
		return made
	end
	local bright = streak("Streak", 1)
	bright.Brightness = 3.2
	bright.ZOffset = 1.2
	local soft = streak("StreakSoft", 1.18)
	soft.LightEmission = 0.6
	soft.ZOffset = 0.4
	soft.Transparency = fade(0, 0.45, 0.6, 0.6, 1, 1)

	-- 1 f. Six thin white lines round the streak (about 6 studs long).
	local thin = add(
		lines,
		"Lines",
		Tex.Needle,
		6,
		1,
		curve(0, 1.1, 0.3, 0.25, 1.3, 0.35, 1, 1, 0.3),
		{ speed = NumberRange.new(12, 32) }
	)
	thin.Orientation = Enum.ParticleOrientation.VelocityParallel
	thin.EmissionDirection = Enum.NormalId.Front
	thin.Lifetime = NumberRange.new(0.09, 0.14)
	thin.Drag = 5
	thin.Brightness = 2.2
	thin.Squash = NumberSequence.new(-1.26)
	thin.ZOffset = 0.8
	thin.Transparency = fade(0, 0, 0.6, 0.1, 1, 1)

	-- 1 f. A thin white ring opening from the spot, and at 3 f a second, wider one. Plain circles.
	local ring = add(at, "Ring", Tex.Circle, 1, 1, keys(0, 1.5, 0.4, 2.8, 1, 3.4))
	ring.Lifetime = NumberRange.new(0.14)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Brightness = 1.8
	ring.Transparency = fade(0, 0.1, 0.5, 0.4, 1, 1)
	local second = add(at, "SecondRing", Tex.Circle, 1, 3, keys(0, 2.4, 0.4, 4.2, 1, 5))
	second.Lifetime = NumberRange.new(0.17)
	second.Rotation = NumberRange.new(0, 360)
	second.Brightness = 1.5
	second.Transparency = fade(0, 0.2, 0.5, 0.5, 1, 1)

	-- 2 f. Seven small sparks further out, pointing outward, shrinking where they are.
	local sparks = FxKit.placed(add, face, "Spark", SPARKS, 2, 0.6, NumberRange.new(0.11, 0.17))

	-- 3 f. Three upright glints thrown outward a little way.
	local glints = add(
		at,
		"Glints",
		Tex.Star,
		3,
		3,
		curve(0, 0.1, 0.05, 0.3, 0.9, 0.35, 1, 0, 0),
		{ speed = NumberRange.new(6, 18) }
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
		streakPart = streakPart,
		lines = lines,
		face = face,
		spikes = spikes,
		lean = lean,
		sparks = sparks,
	}
end)

--- A kick landing at `position`, sending them along `direction`. `size` is how big it is against an
--- ordinary kick (1). It is plain white unless a `colour` is passed for its tinted layers (nothing
--- passes one yet).
function KickHitFx.play(position: Vector3, direction: Vector3, size: number, colour: Color3?)
	local way = FxKit.flat(direction)
	local rig = pool.take()
	local parts = rig.parts
	local center = parts.center :: Part
	local streakPart = parts.streakPart :: Part
	local lines = parts.lines :: Part
	local face = parts.face :: Part
	local side = FxKit.sideOf(way)

	center.CFrame = CFrame.lookAt(position, position + way)
	local streakFrom = position + way * STREAK_AHEAD * size
	streakPart.CFrame = CFrame.lookAt(streakFrom, streakFrom + way)
	local linesFrom = position + way * 3 * size
	lines.CFrame = CFrame.lookAt(linesFrom, linesFrom + way)
	lines.Size = LINES_FACE * size
	-- The spikes and sparks are laid out as the camera sees them; the set is turned differently each
	-- kick, except the three leaning spikes, which follow the kick.
	face.CFrame = FxKit.screenAt(position)
	local turned = math.random() * 360
	FxKit.arrange(parts.spikes, size, turned, side)
	FxKit.arrange(parts.lean, size, 0, side)
	FxKit.arrange(parts.sparks, size, turned + 15, side)

	FxKit.fire(rig, size, colour)
end

--- Builds every rig ahead of the first kick, so the textures are loaded by then.
function KickHitFx.preload()
	pool.preload()
end

return KickHitFx
