--!strict
-- Pond - a map's shallow pond as plain maths, no Roblox instances (user, 2026-11-11: one pond in the middle of
-- Gnomon's battlefield; walking in it slows you, moderately and adjustably).
--
-- THE SHAPE is shared with the Blender build (design/maps/gnomon_dress.py POND, the same formula): an irregular
-- oval. For a point (x, z) from the arena's centre, rho = its oval radius (semiX, semiZ) divided by a gentle
-- wobble round the shoreline. The basin is `depth` deep where rho <= inner, rising smoothly to the ground at
-- rho = 1. The water's surface is `water` studs below the ground, so the water covers wherever the bed is deeper
-- than that: that is the pond area that slows you.
--
-- Roblox axes: x along the arena's long axis, z toward the lobby. Blender's y is -z, so the wobble's angle is
-- taken in Blender's (x, -z) to match the build.

local Pond = {}

export type Shape = {
	x: number,
	z: number,
	semiX: number,
	semiZ: number,
	wobble: { { number } }, -- { cycles, amount, phase } round the shoreline
	depth: number,
	inner: number,
	water: number,
}

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

--- The oval radius of a point (1 = the shoreline's rim), from the arena's centre in Roblox x, z.
function Pond.rho(pond: Shape, x: number, z: number): number
	local u, v = (x - pond.x) / pond.semiX, -(z - pond.z) / pond.semiZ
	local theta = math.atan2(v, u)
	local wob = 1
	for _, w in pond.wobble do
		wob += w[2] * math.sin(w[1] * theta + w[3])
	end
	return math.sqrt(u * u + v * v) / wob
end

--- How far below the arena's floor the pond's bed is here (0 outside the basin).
function Pond.bedDepth(pond: Shape, x: number, z: number): number
	return pond.depth * smoothstep(1, pond.inner, Pond.rho(pond, x, z))
end

--- Is this spot under the water (the bed deeper than the water's surface)?
function Pond.inWater(pond: Shape, x: number, z: number): boolean
	return Pond.bedDepth(pond, x, z) > pond.water
end

--- The share of normal speed a body here keeps: `multiplier` while it's in the water and on (or just above) the
--- bed, 1 otherwise. `rootAbove` is the body's root height above the arena's floor; anything higher than
--- `maxRootAbove` is in the air over the pond, not wading.
function Pond.speedShare(
	pond: Shape?,
	multiplier: number,
	maxRootAbove: number,
	x: number,
	z: number,
	rootAbove: number
): number
	if not pond or rootAbove > maxRootAbove then
		return 1
	end
	return if Pond.inWater(pond, x, z) then multiplier else 1
end

return Pond
