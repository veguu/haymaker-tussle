--!strict
-- Environment - the rules of a map's environment as plain maths, with no Roblox instances. EnvironmentKit
-- turns them into Lighting values and parts; MapService uses the rotation; tests/Environment.spec proves
-- the presets keep the views clear.
--
-- Everything is relative to the arena's centre on its surface (+Y up, the lobby on +Z).
-- Everything that moves is a pure function of time, so every player sees the same sky, and loading a map
-- twice gives the same result: clouds sway back and forth along the wind on a fixed path, and each
-- drifting leaf replays a seeded fall.

local Environment = {}

export type Box = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number }
export type Corridor = { from: Box, to: Box, tMax: number, name: string }
export type Mass = { x: number, y: number, z: number, r: number, wisp: boolean }

local TAU = 2 * math.pi

-- How far the checks reach. The fighting space is the arena plus a margin, from under its rim to well above
-- an uppercut; clouds also keep to the sky band from the gameplay camera and stay well beyond the islands.
Environment.Limits = {
	fightHalfX = 165,
	fightHalfZ = 150,
	fightBottom = -140,
	fightTop = 110,
	viewHalfX = 145, -- the arena as seen from the lobby: oval, rim and underside
	viewHalfZ = 125,
	viewBottom = -130,
	viewTop = 60,
	viewReach = 3, -- the lobby's view runs on past the arena to this many times the lobby-to-arena distance
	landmarkReach = 2, -- and the gameplay camera's view of a landmark runs on past it to here
	cloudMinDistance = 380, -- every part of every cloud is at least this far out, horizontally
	cloudMinElevation = 3, -- degrees: every cloud sits above the horizon seen from the arena
	moteMinDistance = 170, -- drifting leaves stay this far out horizontally
}

local function isArray(t: any): boolean
	return type(t) == "table" and (t[1] ~= nil or next(t) == nil)
end

--- `over` laid on `base`: nested tables merge key by key; arrays (lists, colours) are replaced whole.
function Environment.merge(base: any, over: any): any
	if type(base) ~= "table" or type(over) ~= "table" or isArray(over) then
		if
			over == nil or (type(over) == "table" and next(over) == nil and type(base) == "table")
		then
			return base
		end
		return over
	end
	local out = table.clone(base)
	for k, v in over do
		local b = out[k]
		if type(b) == "table" and type(v) == "table" and not isArray(v) and not isArray(b) then
			out[k] = Environment.merge(b, v)
		else
			out[k] = v
		end
	end
	return out
end

--- The full preset for a map id: its environment over the shared default. An unknown id (or one with no
--- environment) gets the default, so a new map always has a sunny sky.
function Environment.resolve(envs: any, id: string?): any
	local entry = id and envs.Maps[id]
	return Environment.merge(envs.Default, entry and entry.environment or {})
end

--- The map after `current` in the rotation (the first if `current` isn't in it).
function Environment.nextMap(rotation: { string }, current: string?): string
	for i, id in rotation do
		if id == current then
			return rotation[i % #rotation + 1]
		end
	end
	return rotation[1]
end

--- The wind as a flat unit vector.
function Environment.wind(wind: { number }?): (number, number)
	local x, z = 1, 0
	if wind then
		x, z = wind[1], wind[2]
	end
	local len = math.sqrt(x * x + z * z)
	if len < 1e-6 then
		return 1, 0
	end
	return x / len, z / len
end

--- Where a cloud's centre is at time `t`: swaying along the wind, with a slow rise and fall.
function Environment.cloudCentre(
	cloud: any,
	wx: number,
	wz: number,
	t: number
): (number, number, number)
	local period = math.max(cloud.period or 160, 1)
	local s = math.sin(TAU * (t / period + (cloud.phase or 0)))
	local sway = (cloud.sway or 0) * s
	local rise = 0.012
		* cloud.length
		* math.sin(TAU * (t / (period * 0.63) + (cloud.phase or 0) * 2))
	return cloud.x + wx * sway, cloud.y + rise, cloud.z + wz * sway
end

-- A small deterministic hash in [0, 1), so masses and leaves need no engine Random.
function Environment.hash(a: number, b: number, c: number?): number
	local h = math.sin(a * 12.9898 + b * 78.233 + (c or 0) * 37.719) * 43758.5453
	return h - math.floor(h)
end

-- Cloud shapes, as (along, up, radius) shares of the cloud's length: a big middle and smaller sides
-- ("compact"), or a big head, a run of smaller masses and a thin tail ("stretched").
local SHAPES = {
	compact = {
		{ 0, 0, 0.22 },
		{ -0.28, 0.03, 0.15 },
		{ 0.3, -0.02, 0.16 },
		{ -0.12, 0.08, 0.17 },
		{ 0.14, 0.1, 0.14 },
	},
	stretched = {
		{ 0.18, 0, 0.16 },
		{ 0.32, 0.04, 0.12 },
		{ 0.02, 0.06, 0.13 },
		{ -0.12, 0, 0.1 },
		{ 0.42, -0.02, 0.08 },
		{ -0.22, -0.01, 0.07 },
		{ -0.29, -0.02, 0.062 },
		{ -0.36, -0.03, 0.053 },
	},
}

--- A cloud's masses relative to its centre, turned to its heading. The flat underside is at y = 0 - each
--- mass's centre sits 0.55 r above it - so the pale-blue base drawn there covers every mass's lower cap.
--- `index` varies the jitter per cloud, the same every time.
function Environment.cloudMasses(cloud: any, index: number): { Mass }
	local shape = SHAPES[cloud.kind] or SHAPES.compact
	local h = math.rad(cloud.heading or 0)
	local ch, sh = math.cos(h), math.sin(h)
	local L = cloud.length
	local out: { Mass } = {}
	for k, m in shape do
		local jx = (Environment.hash(index, k, 1) - 0.5) * 0.1
		local jr = 0.92 + Environment.hash(index, k, 2) * 0.16
		local side = (Environment.hash(index, k, 3) - 0.5) * 0.1 * L
		local along = m[1] * L * (1 + jx)
		local r = m[3] * L * jr
		table.insert(out, {
			x = along * ch - side * sh,
			z = along * sh + side * ch,
			y = r * 0.55 + m[2] * L,
			r = r,
			wisp = false,
		})
	end
	if cloud.kind == "stretched" then -- the thin flat wisps at the end of the tail
		for k = 0, 2 do
			local along = (-0.44 - 0.05 * k) * L
			table.insert(
				out,
				{ x = along * ch, z = along * sh, y = 0, r = L * (0.04 - 0.007 * k), wisp = true }
			)
		end
	end
	return out
end

--- How much a cloud at horizontal distance `d` gives up its contrast (0 near, up to `fadeMost` far).
function Environment.cloudFade(clouds: any, d: number): number
	local a, b = clouds.fadeStart or 350, clouds.fadeEnd or 1100
	local k = math.clamp((d - a) / math.max(b - a, 1), 0, 1)
	return k * (clouds.fadeMost or 0.6)
end

--- One drifting leaf or petal at time `t`: position, spin (radians) and how visible it is (0 to 1). Each
--- one replays a seeded fall from a random point of its spot, carried along the wind, fluttering.
function Environment.mote(
	spot: any,
	spotIndex: number,
	i: number,
	t: number,
	wx: number,
	wz: number
)
	local life = 9 + Environment.hash(spotIndex, i, 9) * 4
	local offset = Environment.hash(spotIndex, i, 10) * life
	local age = (t + offset) % life
	local cycle = math.floor((t + offset) / life)
	local u = age / life
	local a = Environment.hash(spotIndex * 31 + i, cycle, 11) * TAU
	local rr = math.sqrt(Environment.hash(spotIndex * 31 + i, cycle, 12)) * spot.radius
	local drift = age * 1.6
	local flutter = math.sin(age * 2.1 + i) * 1.2
	local x = spot.x + math.cos(a) * rr + wx * drift - wz * flutter
	local z = spot.z + math.sin(a) * rr + wz * drift + wx * flutter
	local y = spot.y - u * (spot.fall or 20) + math.sin(age * 3.3 + i) * 0.4
	local alpha = math.min(1, u / 0.15, (1 - u) / 0.2)
	return x, y, z, age * (1.5 + Environment.hash(spotIndex, i, 13)), math.max(alpha, 0)
end

--- The lobby's view of the arena: from where people stand on the lobby (the viewing edge back to the spawn
--- patch, floor to above eye height) to the arena (oval, rim and underside, and the air an uppercut
--- reaches), carried on past the arena so nothing sits behind it either.
function Environment.lobbyCorridor(lobby: any, arena: any): Corridor
	local L = Environment.Limits
	local half = lobby.Width / 2
	local cx = lobby.CenterX - arena.CenterX
	local floor = lobby.FloorY - arena.CenterY
	local viewZ0 = lobby.ViewEdgeZ - arena.CenterZ
	local viewZ1 = lobby.SpawnZ + lobby.SpawnSpread - arena.CenterZ
	return {
		name = "lobby view",
		from = {
			x0 = cx - half,
			x1 = cx + half,
			y0 = floor,
			y1 = floor + lobby.EyeHeight + 3,
			z0 = viewZ0,
			z1 = viewZ1,
		},
		to = {
			x0 = -L.viewHalfX,
			x1 = L.viewHalfX,
			y0 = L.viewBottom,
			y1 = L.viewTop,
			z0 = -L.viewHalfZ,
			z1 = L.viewHalfZ,
		},
		tMax = L.viewReach,
	}
end

--- The gameplay camera's view of a landmark: from the arena (the fighting surface, camera height) to it.
function Environment.landmarkCorridor(mark: any): Corridor
	return {
		name = mark.name or "landmark",
		from = { x0 = -115, x1 = 115, y0 = 0, y1 = 25, z0 = -95, z1 = 95 },
		to = {
			x0 = mark.x - mark.radius,
			x1 = mark.x + mark.radius,
			y0 = mark.y - mark.radius,
			y1 = mark.y + mark.radius,
			z0 = mark.z - mark.radius,
			z1 = mark.z + mark.radius,
		},
		tMax = Environment.Limits.landmarkReach,
	}
end

-- Is there a t in [lo, hi] with a + b t <= p (sign 1) ... narrowed to the t where one bound holds.
local function narrow(lo: number, hi: number, a: number, b: number, p: number): (number, number)
	-- a + b t <= p
	if math.abs(b) < 1e-9 then
		if a <= p then
			return lo, hi
		end
		return 1, 0
	elseif b > 0 then
		return lo, math.min(hi, (p - a) / b)
	end
	return math.max(lo, (p - a) / b), hi
end

--- Does a sphere (centre p, radius r) touch the corridor? The corridor is every point on a line from a
--- point of `from` to a point of `to` (and on past it, to `tMax`): for each t the points form a box between
--- the two, so the sphere touches it if some t puts its centre inside that box grown by r on every axis.
function Environment.inCorridor(c: Corridor, px: number, py: number, pz: number, r: number): boolean
	local lo, hi = 0, c.tMax
	local axes = {
		{ c.from.x0, c.from.x1, c.to.x0, c.to.x1, px },
		{ c.from.y0, c.from.y1, c.to.y0, c.to.y1, py },
		{ c.from.z0, c.from.z1, c.to.z0, c.to.z1, pz },
	}
	for _, ax in axes do
		local f0, f1, t0, t1, p = ax[1] - r, ax[2] + r, ax[3] - r, ax[4] + r, ax[5]
		-- lower bound: f0 + (t0 - f0) t <= p
		lo, hi = narrow(lo, hi, f0, t0 - f0, p)
		-- upper bound: p <= f1 + (t1 - f1) t, i.e. -f1 - (t1 - f1) t <= -p
		lo, hi = narrow(lo, hi, -f1, -(t1 - f1), -p)
		if lo > hi then
			return false
		end
	end
	return lo <= hi
end

function Environment.inFightSpace(px: number, py: number, pz: number, r: number): boolean
	local L = Environment.Limits
	return math.abs(px) < L.fightHalfX + r
		and math.abs(pz) < L.fightHalfZ + r
		and py > L.fightBottom - r
		and py < L.fightTop + r
end

local SWAY_SAMPLES = 16

--- Everything wrong with a preset's clouds and leaves, as readable lines (empty when it's clean). Checks
--- every mass of every cloud over its whole sway, and every leaf over its whole fall.
function Environment.problems(preset: any, lobby: any, arena: any): { string }
	local L = Environment.Limits
	local out: { string } = {}
	local corridors = { Environment.lobbyCorridor(lobby, arena) }
	for _, mark in preset.landmarks or {} do
		table.insert(corridors, Environment.landmarkCorridor(mark))
	end
	local wx, wz = Environment.wind(preset.clouds.wind)
	local minElev = math.tan(math.rad(L.cloudMinElevation))
	for index, cloud in preset.clouds.list do
		local masses = Environment.cloudMasses(cloud, index)
		local seen: { [string]: boolean } = {}
		for s = 0, SWAY_SAMPLES - 1 do
			local period = math.max(cloud.period or 160, 1)
			local cx, cy, cz = Environment.cloudCentre(cloud, wx, wz, period * s / SWAY_SAMPLES)
			for _, m in masses do
				local px, py, pz = cx + m.x, cy + m.y, cz + m.z
				local d = math.sqrt(px * px + pz * pz)
				local function note(what: string)
					if not seen[what] then
						seen[what] = true
						table.insert(out, `cloud {index}: {what}`)
					end
				end
				if d - m.r < L.cloudMinDistance then
					note(`closer than {L.cloudMinDistance} studs`)
				end
				if (py - m.r) < d * minElev then
					note("below the sky band (sits behind fighters or the platform edge)")
				end
				if Environment.inFightSpace(px, py, pz, m.r) then
					note("in the fighting space")
				end
				for _, c in corridors do
					if Environment.inCorridor(c, px, py, pz, m.r) then
						note(`in the {c.name} view`)
					end
				end
			end
		end
	end
	for si, spot in (preset.motes and preset.motes.list) or {} do
		local lobbyView = corridors[1]
		local bad: string? = nil
		for i = 1, spot.count do
			for step = 0, 23 do
				local x, y, z = Environment.mote(spot, si, i, step * 0.55, wx, wz)
				if math.sqrt(x * x + z * z) < L.moteMinDistance then
					bad = "drifts into the fighting space"
				elseif Environment.inCorridor(lobbyView, x, y, z, 0.5) then
					bad = "drifts into the lobby view"
				end
			end
		end
		if bad then
			table.insert(out, `mote spot {si}: {bad}`)
		end
	end
	return out
end

--- One step of the screen fade toward `target` (1 = covered, 0 = clear), taking `seconds` for a full fade.
function Environment.fadeStep(alpha: number, target: number, dt: number, seconds: number): number
	if seconds <= 0 then
		return target
	end
	local step = dt / seconds
	if alpha < target then
		return math.min(target, alpha + step)
	end
	return math.max(target, alpha - step)
end

return Environment
