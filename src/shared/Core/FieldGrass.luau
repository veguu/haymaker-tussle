--!strict
-- FieldGrass - the pure rules for a map's FIELD GRASS (owner, 2026-11-20: "that feel of you running through a grass
-- field, shouldn't be taller than the character, wind should also blow on it"): knee-to-thigh clumps on a grid over
-- the whole fighting surface, drawn only in a ring round the camera by Shared/FieldGrassField.
--   * clumpAt: where each clump stands, its shape, turn, size and tint: one per grid cell, worked out from the cell
--     alone, so a cell that leaves the ring and comes back gets the same clump, and every client agrees.
--   * windLean: how far the wind leans a clump at a point and moment, as tan(angle) along the wind: a steady lean,
--     gust bands rolling across the field (the map's wind, boosted for tall grass), and a small shiver.
--   * sinkAt: how far a clump sinks into the floor at the outer edge of the ring, so the ring's edge never pops.
--   * ease: the parting round a character, quick in and slow back, so a runner leaves a wake.
-- Specs: tests/FieldGrass.spec.luau.

local FieldGrass = {}

export type Config = {
	cell: number, -- studs between clump roots (one clump per cell, jittered inside it)
	radius: number, -- grass is drawn this far round the camera
	radiusTouch: number, -- and this far on phones
	fade: number, -- over the ring's last studs, clumps sink into the floor
	fadeTouch: number?, -- the same on phones (their ring is smaller)
	margin: number, -- studs kept clear inside the oval's edge
	variants: number, -- clump meshes: FieldGrass_A, _B, ... in ReplicatedStorage.HT_FieldGrass
	scale: { number }, -- size range { min, max }
	colours: { { number } }, -- tints, sRGB, picked per clump (the meshes are greyscale)
	gustBoost: number, -- how much harder a gust leans field grass than the map's wind numbers
	tierNear: number, -- studs from the camera: clumps inside move every frame
	tierMid: number, -- out to here every midEvery-th frame, beyond every farEvery-th
	midEvery: number,
	farEvery: number,
	tierNearTouch: number, -- the same on phones
	tierMidTouch: number,
	bendRadius: number, -- studs round a character's root that part the grass
	bendMax: number, -- degrees at a character's feet
	sink: number, -- studs a clump's root sits under the floor's top
	height: number, -- the tallest clump at scale 1 (studs), for the ring's sinking
}

export type Wind = {
	lean: number,
	strength: number,
	gustLength: number,
	gustSeconds: number,
	flutter: number,
	flutterSeconds: number,
}

export type Clump = {
	x: number,
	z: number,
	yaw: number,
	scale: number,
	variant: number,
	tint: number,
	phase: number,
}

local TAU = 2 * math.pi

--- A repeatable number in [0, 1) for a cell and a channel.
local function hash(ix: number, iz: number, channel: number): number
	local v = math.sin(ix * 127.1 + iz * 311.7 + channel * 74.7) * 43758.5453
	return v - math.floor(v)
end
FieldGrass.hash = hash

--- The clump of grid cell (ix, iz), positions from the arena's centre, or nil when the cell's root falls outside the
--- oval (semi-axes semiX, semiZ) less the config's margin.
function FieldGrass.clumpAt(
	cfg: Config,
	ix: number,
	iz: number,
	semiX: number,
	semiZ: number
): Clump?
	-- every other row shifted half a cell and a wide jitter, so no rows show (a fresh review saw rows, 2026-11-22)
	local x = (ix + (iz % 2) * 0.5 + 0.05 + 0.9 * hash(ix, iz, 1)) * cfg.cell
	local z = (iz + 0.05 + 0.9 * hash(ix, iz, 2)) * cfg.cell
	local a, b = semiX - cfg.margin, semiZ - cfg.margin
	if a <= 0 or b <= 0 or (x / a) ^ 2 + (z / b) ^ 2 >= 1 then
		return nil
	end
	return {
		x = x,
		z = z,
		yaw = hash(ix, iz, 3) * TAU,
		scale = cfg.scale[1] + (cfg.scale[2] - cfg.scale[1]) * hash(ix, iz, 4),
		variant = 1 + math.floor(hash(ix, iz, 5) * cfg.variants),
		tint = 1 + math.floor(hash(ix, iz, 6) * #cfg.colours),
		phase = hash(ix, iz, 7),
	}
end

--- How far the wind leans a clump at (x, z) at time t, as tan(angle) downwind (the map's wind is in studs of tip
--- push per stud of height). (wx, wz) is the wind's flat unit direction. Gust bands are `gustLength` apart and
--- take `gustSeconds` to pass a point; inside a band the push rises and falls smoothly.
function FieldGrass.windLean(
	wind: Wind,
	boost: number,
	wx: number,
	wz: number,
	x: number,
	z: number,
	t: number,
	phase: number
): number
	return FieldGrass.gustLean(wind, boost, (x * wx + z * wz) / wind.gustLength, t, phase)
end

--- windLean with the clump's place along the wind already worked out (`along`: its distance downwind in gust
--- lengths), so the per-frame cost is two sines. The game calls this one; windLean is the readable form.
function FieldGrass.gustLean(
	wind: Wind,
	boost: number,
	along: number,
	t: number,
	phase: number
): number
	local g = math.sin((along - t / wind.gustSeconds) * TAU)
	local band = if g > 0 then g * g else 0
	local flutter = wind.flutter * math.sin((t / wind.flutterSeconds + phase) * TAU)
	return wind.lean + wind.strength * boost * band + flutter
end

--- A cheap atan for leans (tan of the angle) from 0 to 1 (a full gust here is 0.8): within 0.005 radians of math.atan.
function FieldGrass.leanAngle(lean: number): number
	return lean / (1 + 0.28 * lean * lean)
end

--- How far (studs) a clump of size `scale` sinks at `dist` from the camera when the ring is `radius` wide: none
--- inside the ring, all the way under the floor at its edge.
function FieldGrass.sinkAt(cfg: Config, dist: number, radius: number, scale: number): number
	local start = radius - cfg.fade
	if dist <= start then
		return 0
	end
	local f = math.min(1, (dist - start) / cfg.fade)
	return f * f * cfg.height * scale
end

--- Eases `current` toward `target` over dt: quickly when pushed further over, slowly when easing back.
function FieldGrass.ease(
	current: number,
	target: number,
	dt: number,
	rateIn: number,
	rateOut: number
): number
	local rate = if math.abs(target) > math.abs(current) then rateIn else rateOut
	return target + (current - target) * math.exp(-rate * dt)
end

return FieldGrass
