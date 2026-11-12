--!strict
-- Foliage - the pure rules for map plants moving in the wind (Shared/PlantField draws them).
--
-- Every kit placement in a map's HT_Dressing folder is one Model named <Family>_<...>_<number>; its family
-- decides how it moves. Rocks, ruins and anything not listed never move.
--
-- * flower / plant / bush: the whole clump leans about its base (the bottom of its bounds), so the stems stay
--   planted; flowers are the softest, bushes the stiffest. They also bend away from a character walking through.
-- * tree: only the leaf crown leans, about a point low in the crown; the bark never moves. Trees are big and
--   seen from far, so they move over a longer range than the small plants.
-- * lily: pads and lotuses float: a slow bob and a slight turn on the water, no lean.
--
-- The wind itself is the grass's (Core/Environment wind direction, gust bands travelling down-wind, a shiver),
-- so grass, flowers and trees move together in the same gusts.

local Foliage = {}

export type Kind = "flower" | "plant" | "bush" | "tree" | "lily"

export type Tuning = {
	lean: number, -- radians: the steady lean with the wind
	gust: number, -- extra in a full gust
	flutter: number, -- the quick shiver
	side: number, -- a slow cross-wind wobble, so it isn't only back and forth
	bend: number, -- most a character can push it over (0 = never)
	range: number, -- studs from the camera: no movement past this (fades from 60% of it)
	rangeLow: number, -- the same on phones and low graphics
	bob: number?, -- studs (lilies)
	turn: number?, -- radians (lilies)
}

local R = math.rad

Foliage.Tuning = {
	flower = {
		lean = R(3),
		gust = R(6.5),
		flutter = R(3),
		side = R(2),
		bend = R(26),
		range = 110,
		rangeLow = 70,
	},
	plant = {
		lean = R(2),
		gust = R(6),
		flutter = R(2.5),
		side = R(1.5),
		bend = R(18),
		range = 110,
		rangeLow = 70,
	},
	bush = {
		lean = R(1),
		gust = R(3),
		flutter = R(1.2),
		side = R(0.8),
		bend = R(7),
		range = 130,
		rangeLow = 80,
	},
	tree = {
		lean = R(0.6),
		gust = R(2.2),
		flutter = R(0.5),
		side = R(0.5),
		bend = 0,
		range = 320,
		rangeLow = 200,
	},
	lily = {
		lean = 0,
		gust = 0,
		flutter = 0,
		side = 0,
		bend = 0,
		range = 110,
		rangeLow = 70,
		bob = 0.06,
		turn = R(3),
	},
} :: { [Kind]: Tuning }

local PREFIX: { { string | Kind } } = {
	{ "^Flowers_", "flower" },
	{ "^Plant_", "plant" },
	{ "^Bush_", "bush" },
	{ "^Tree_", "tree" },
	{ "^Lily_", "lily" },
}

--- How a placement named `name` moves, or nil if it never does (rocks, ruins, anything else).
function Foliage.kindOf(name: string): Kind?
	for _, row in PREFIX do
		if name:match(row[1] :: string) then
			return row[2] :: Kind
		end
	end
	return nil
end

--- Whether a part of a `kind` placement moves (a tree's bark stays put; everything else in a moving clump moves).
function Foliage.partMoves(kind: Kind, partName: string): boolean
	if kind == "tree" then
		return partName:match("_Leaf$") ~= nil
	end
	return true
end

--- 0..1: how much a plant `dist` studs from the camera moves (full inside 60% of `range`, none at `range`).
function Foliage.fade(dist: number, range: number): number
	local near = range * 0.6
	if dist <= near then
		return 1
	elseif dist >= range then
		return 0
	end
	return 1 - (dist - near) / (range - near)
end

--- 0..1: the gust at world (x, z) at time t, for wind (wx, wz) - the same bands the grass uses.
function Foliage.gust(
	x: number,
	z: number,
	t: number,
	wx: number,
	wz: number,
	gustLength: number,
	gustSeconds: number
): number
	local tau = 2 * math.pi
	local along = x * wx + z * wz
	local across = -x * wz + z * wx
	local band = 0.5 + 0.5 * math.sin(tau * (along / gustLength - t / gustSeconds))
	local lane = 0.65
		+ 0.35 * math.sin(tau * (across / (gustLength * 2.3) + t / (gustSeconds * 3.1)))
	return band * band * lane
end

--- The lean (lx, lz) as a horizontal vector in radians: down-wind lean plus the cross-wind wobble.
function Foliage.lean(
	tune: Tuning,
	gust: number,
	t: number,
	phase: number,
	flutterSeconds: number,
	wx: number,
	wz: number
): (number, number)
	local tau = 2 * math.pi
	local shiver = math.sin(tau * t / flutterSeconds + phase)
	local wobble = math.sin(tau * t / (flutterSeconds * 2.7) + phase * 1.9)
	local down = tune.lean + tune.gust * gust + tune.flutter * shiver
	local side = tune.side * wobble
	return wx * down - wz * side, wz * down + wx * side
end

--- Caps a lean vector at `max` radians.
function Foliage.cap(lx: number, lz: number, max: number): (number, number)
	local a = math.sqrt(lx * lx + lz * lz)
	if a > max and a > 0 then
		return lx / a * max, lz / a * max
	end
	return lx, lz
end

return Foliage
