--!strict
-- MapLife - the pure rules for a map's small life (owner 2026-11-26, Map 1 "full of life": butterflies and bees over
-- the flowers, birds, hot-air balloons, grazing sheep and cows, vines under the rim, dandelions that burst when run
-- through, cloud shadows, splashes when wading). Shared/MapLife moves the parts with these; the map's `life` entry in
-- Config/MapEnvironments holds the tunables. Every motion is the approved Blender preview's
-- (design/maps/suite/meadow_life.py), as functions of a clock instead of keyframes, each creature on its own rhythm
-- from its index (MapLife.rand), so nothing ever loops visibly.
-- Roblox axes, arena-local: x, y up, z toward the lobby. A Blender y offset in the preview is a -z offset here.
-- Specs: tests/MapLife.spec.luau.

local MapLife = {}

local TAU = 2 * math.pi

--- Smoothstep of x clamped to 0..1.
function MapLife.ease(x: number): number
	local k = math.clamp(x, 0, 1)
	return k * k * (3 - 2 * k)
end
local ease = MapLife.ease

--- A steady pseudo-random number 0 to 1 for creature `i`, key `k` (the same every run, every client).
function MapLife.rand(i: number, k: number): number
	local x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - math.floor(x)
end
local rand = MapLife.rand

--- Which of `n` creatures to keep when only `keep` are wanted (phones): spread evenly over the list (1-based `i`).
function MapLife.kept(i: number, n: number, keep: number): boolean
	if keep >= n then
		return true
	elseif keep <= 0 then
		return false
	end
	return math.floor(i * keep / n) > math.floor((i - 1) * keep / n)
end

-- ===== butterflies ===================================================================================================

--- A butterfly's wander about its home at clock `t` (studs): a lazy figure-of-eight, rising and dipping.
--- `roam` (default 1) scales the whole loop: Map 1 uses 1.8 since 2026-11-26 (life-5: the owner wanted them "at least
--- noticeable"), so they cross the view about 7 studs each way and bob about a stud.
function MapLife.butterfly(i: number, t: number, roam: number?): (number, number, number)
	local s = roam or 1
	local a = t * (0.25 + 0.2 * rand(i, 4)) * math.pi + rand(i, 1) * TAU
	local rx, ry = 1.5 + 2 * rand(i, 2), 1.5 + 2 * rand(i, 3)
	return s * (rx * math.sin(a) + 0.4 * math.sin(a * 3.1)),
		s * (0.35 * math.sin(a * 2.3) + 0.15 * math.sin(a * 5.7)),
		-(s * ry * math.sin(a * 0.7 + 1.3))
end

-- ===== butterflies that roam (life-6) ==================================================================================
-- Owner 2026-11-26: "they should smoothly move out the way. not instantly teleport. they also like fly around, not just
-- fly in cricles in one spot". So a butterfly FLIES: from stop to stop across the field round its home, lingering a
-- moment at each, every move a smooth glide (below), and a dodge is the same glide, only quicker, to a point off the
-- fighter's line. `butterfly(i, t, small)` is now only the flutter laid on top.

--- Stop `n` of butterfly `i`: an offset (x, up, z) from its home, up to `range` studs out and `lift` up; the same every
--- time, a new place for each n.
function MapLife.stop(i: number, n: number, range: number, lift: number): (number, number, number)
	local k = i * 31 + n
	local a = rand(k, 51) * TAU
	local r = range * math.sqrt(0.1 + 0.9 * rand(k, 52))
	return r * math.cos(a), lift * rand(k, 53), r * math.sin(a)
end

--- How long butterfly `i` lingers at stop `n`, `least` to `most` seconds.
function MapLife.linger(i: number, n: number, least: number, most: number): number
	return least + (most - least) * rand(i * 31 + n, 54)
end

--- One frame of a smooth flight from (px, py, pz) moving (vx, vy, vz) toward (tx, ty, tz): a critically damped spring
--- (it never overshoots, never jumps, and holds for any frame time), `quick` its rate (1/s: about 4.7 / quick seconds
--- to arrive), and never faster than `cap` studs a second. Returns the new position and velocity.
function MapLife.glide(
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	tx: number,
	ty: number,
	tz: number,
	dt: number,
	quick: number,
	cap: number
): (number, number, number, number, number, number)
	local e = math.exp(-quick * dt)
	local function axis(p: number, v: number, t: number): (number, number)
		local x = p - t
		local c = v + quick * x
		return t + (x + c * dt) * e, (v - quick * c * dt) * e
	end
	local nx, nvx = axis(px, vx, tx)
	local ny, nvy = axis(py, vy, ty)
	local nz, nvz = axis(pz, vz, tz)
	local dx, dy, dz = nx - px, ny - py, nz - pz
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	local most = cap * dt
	if d > most and d > 0 then
		local k = most / d
		dx, dy, dz = dx * k, dy * k, dz * k
		return px + dx, py + dy, pz + dz, dx / dt, dy / dt, dz / dt
	end
	return nx, ny, nz, nvx, nvy, nvz
end

export type Spread = {
	pair: { number }?, -- studs {least, most}: a companion this far from its partner (a pair over the same flowers)
	ring: { number }?, -- studs {least, most} from the arena's centre: where lone extras may go
	apart: number?, -- studs: a lone extra keeps at least this far from every other home
	lift: number?, -- studs: an extra flies up to this much higher than the one it was copied from
}

--- Homes for MORE butterflies than the map's model holds (owner 2026-11-26: "there isn't much butterflies, i want
--- them to be subtle yes, but at least noticeable"): `homes` are the model's ({x, z} from the arena's centre); the
--- first extras are companions, one beside each home in turn (`pair` studs off); the rest go alone into the gaps
--- (`ring`, `apart`). Returns `want - #homes` entries {x, z, y = extra height, src = the home index to copy, a
--- different colour from its partner}; the same every time (no randomness kept between calls).
function MapLife.extraHomes(
	homes: { { any } },
	want: number,
	spread: Spread?
): { { x: number, z: number, y: number, src: number } }
	local sp: Spread = spread or {}
	local pair = sp.pair or { 3, 6 }
	local ring = sp.ring or { 35, 160 }
	local apart = sp.apart or 14
	local lift = sp.lift or 0
	local n = #homes
	local out = {}
	if n == 0 or want <= n then
		return out
	end
	local all = {}
	for _, h in homes do
		table.insert(all, { h[1] :: number, h[2] :: number })
	end
	local extra = want - n
	for i = 1, math.min(extra, n) do
		local h = all[i]
		local a = rand(i, 41) * TAU
		local r = pair[1] + (pair[2] - pair[1]) * rand(i, 42)
		local x, z = h[1] + r * math.cos(a), h[2] + r * math.sin(a)
		table.insert(out, { x = x, z = z, y = lift * rand(i, 45), src = i % n + 1 })
	end
	local placed = {}
	for _, e in out do
		table.insert(placed, { e.x, e.z })
	end
	local k = 0
	while #out < extra and k < 4000 do
		k += 1
		local r =
			math.sqrt(ring[1] * ring[1] + (ring[2] * ring[2] - ring[1] * ring[1]) * rand(k, 43))
		local a = rand(k, 44) * TAU
		local x, z = r * math.cos(a), r * math.sin(a)
		local ok = true
		for _, list in { all, placed } do
			for _, h in list do
				if (h[1] - x) ^ 2 + (h[2] - z) ^ 2 < apart * apart then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
		end
		if ok then
			table.insert(out, { x = x, z = z, y = lift * rand(k, 45), src = k % n + 1 })
			table.insert(placed, { x, z })
		end
	end
	return out
end

export type Flee = {
	reach: number, -- studs: a fighter farther than this never bothers it
	close: number, -- studs: closer than this it flees whatever the fighter does
	speed: number, -- studs a second: a fighter coming AT it this fast (a dash, a charge) makes it flee
	lead: number?, -- seconds: a fighter coming at it is seen this much sooner (a dash crosses `reach` in ~0.13 s)
}

--- Whether a fighter at (px, pz) moving (vx, vz) makes a butterfly at (bx, bz) flee, and the way it darts (a unit
--- x, z): sideways off the fighter's line, on its own side of it (the preview's dash: 4 studs aside, 2 up); straight
--- away when the fighter is just standing close. It can NEVER be hit (no collision, no query): this only keeps it
--- out of the fight (owner: "you'll NEVER be able to hit the butterfly, if u dash towards a butterfly they'll move
--- out the way").
function MapLife.threat(
	f: Flee,
	bx: number,
	bz: number,
	px: number,
	pz: number,
	vx: number,
	vz: number
): (boolean, number, number)
	local dx, dz = bx - px, bz - pz
	local d = math.sqrt(dx * dx + dz * dz)
	local v = math.sqrt(vx * vx + vz * vz)
	local closing = if d > 1e-6 then (vx * dx + vz * dz) / d else v
	if d > f.reach + math.max(closing, 0) * (f.lead or 0) then
		return false, 0, 0
	end
	if closing >= f.speed and v > 1e-6 then
		-- off the line it comes along, toward the butterfly's side of it
		local sx, sz = -vz / v, vx / v
		if sx * dx + sz * dz < 0 then
			sx, sz = -sx, -sz
		end
		return true, sx, sz
	end
	if d < f.close then
		if d < 1e-6 then
			return true, 1, 0
		end
		return true, dx / d, dz / d
	end
	return false, 0, 0
end

--- How far into its dart a butterfly is (0 to 1) `s` seconds after it began: out in 0.22 s, held, then drifting back
--- home from 1.4 s over 2.5 s.
function MapLife.dart(s: number): number
	if s < 0 then
		return 0
	end
	return ease(s / 0.22) * (1 - ease((s - 1.4) / 2.5))
end

--- Wing beats a second `s` seconds after a dart began (nil: calm): `calm`, up to `fast` while it flees.
function MapLife.beats(s: number?, calm: number, fast: number): number
	if s == nil or s < -0.05 or s > 2.2 then
		return calm
	end
	local x = s + 0.05
	return calm + (fast - calm) * ease(x / 0.15) * (1 - ease((x - 1.4) / 0.8))
end

--- A wing's lift (radians, up from flat) at flap phase `phase` (radians).
function MapLife.wing(phase: number): number
	return 0.55 + 0.75 * math.sin(phase)
end

-- ===== bees ==========================================================================================================

--- A bee's buzz about its home at clock `t`: wide slow loops with a fast jitter.
function MapLife.bee(i: number, t: number): (number, number, number)
	local a = t + rand(i, 5) * 10
	return 2.2 * math.sin(a * 0.9) + 0.5 * math.sin(a * 7.3),
		0.3 * math.sin(a * 1.7) + 0.1 * math.sin(a * 9.0),
		-(1.8 * math.sin(a * 0.6 + 1) + 0.4 * math.sin(a * 6.1))
end

-- ===== animals =======================================================================================================

--- An animal's head tilt at clock `t` (radians about its side axis; below 0 = down to the grass): down for about
--- half of its own 5 to 8 s rhythm, chewing a little while down.
function MapLife.graze(i: number, t: number): number
	local period = 5 + 3 * rand(i, 6)
	local k = (t / period + rand(i, 7)) % 1
	local down = ease(k / 0.12) * (1 - ease((k - 0.55) / 0.12))
	return -1.3 * down - 0.05 * math.sin(t * 6) * down
end

--- An animal's shuffle at clock `t` (studs along its facing): a step or two forward now and then, and back later, so
--- it never wanders off its island.
function MapLife.shuffle(i: number, t: number): number
	local period = 24 + 12 * rand(i, 8)
	local k = (t / period + rand(i, 9)) % 1
	return (1 + rand(i, 10)) * (ease((k - 0.2) / 0.06) - ease((k - 0.7) / 0.06))
end

-- ===== birds =========================================================================================================

export type Flock = {
	centre: { number }, -- arena-local x, y, z
	radii: { number }, -- along x, along z
	dir: number, -- 1 or -1: which way round
	period: number, -- seconds a lap
	kind: string, -- a template kind: "Gull" or "Swallow"
	count: number,
	spread: number, -- studs: how far each bird keeps off the flock's line
	flap: number, -- wing beats a second
	amp: number, -- radians: wing beat size
}

--- Bird `b` of a flock at clock `t`: its position (arena-local x, y, z) and its velocity (x, y, z, studs a second).
function MapLife.orbit(
	fl: Flock,
	b: number,
	t: number
): (number, number, number, number, number, number)
	local w = fl.dir * TAU / fl.period
	local a = w * t - b * 0.035 * fl.dir * TAU
	local ox = (rand(b, 21 + fl.period) - 0.5) * 2 * fl.spread
	local oy = (rand(b, 22 + fl.period) - 0.5) * fl.spread
	local oz = (rand(b, 23 + fl.period) - 0.5) * 2 * fl.spread
	local c, r = fl.centre, fl.radii
	return c[1] + r[1] * math.cos(a) + ox,
		c[2] + 6 * math.sin(a * 3) + oy,
		c[3] - r[2] * math.sin(a) + oz,
		-r[1] * math.sin(a) * w,
		18 * math.cos(a * 3) * w,
		-r[2] * math.cos(a) * w
end

--- A bird's wing lift (radians) at clock `t`: beating, easing off now and then into a glide.
function MapLife.birdWing(fl: Flock, b: number, t: number): number
	return 0.15
		+ fl.amp
			* math.sin(t * fl.flap * TAU + rand(b, 24) * TAU)
			* (0.5 + 0.5 * math.cos(t * 0.9 + rand(b, 25) * 6))
end

-- ===== balloons ======================================================================================================

--- A hot-air balloon's drift from its start at clock `t`: round a long slow loop (`loop` studs across, at `speed`
--- studs a second), bobbing 2 studs every 7 s; and its sway (radians about x, about z, and its turn).
function MapLife.balloon(
	i: number,
	t: number,
	loop: number,
	speed: number
): (number, number, number, number, number, number)
	local r = loop / 2
	local ph = rand(i, 11) * TAU
	local a = t * speed / r + ph
	return r * (math.cos(a) - math.cos(ph)),
		2 * math.sin(t / 7 * TAU + ph),
		0.5 * r * (math.sin(a) - math.sin(ph)),
		0.02 * math.sin(t / 6 * TAU + ph),
		0.02 * math.cos(t / 5 * TAU + ph),
		0.08 * math.sin(t / 20 * TAU)
end

-- ===== vines and roots ===============================================================================================

--- A vine's (or root's) swing about its top at clock `t`: out and back across the rim, and a slight twist (radians).
function MapLife.sway(i: number, t: number, amount: number): (number, number)
	local per, ph = 4 + 2 * rand(i, 12), rand(i, 13) * TAU
	return amount * math.sin(t / per * TAU + ph), 0.3 * amount * math.sin(t / per * 2.7 + ph)
end

-- ===== cloud shadows =================================================================================================

--- How far the cloud shadows' image has slid at clock `t`: along the wind (wx, wz: a unit x, z) at `speed` studs a
--- second, as a Texture's OffsetStudsU and OffsetStudsV change, each within one tile. On a Top-face Texture of an
--- unturned part the image's u runs along -x and v along -z, and a growing offset slides the image back along them
--- (measured 2026-11-22, studio_map.py), so the image moves along +x by +U and along +z by +V.
function MapLife.slide(
	t: number,
	speed: number,
	wx: number,
	wz: number,
	tile: number
): (number, number)
	local d = t * speed
	return (d * wx) % tile, (d * wz) % tile
end

-- ===== the floor's moments ===========================================================================================

--- Seconds between splashes for a fighter wading: often while it moves, slower while it stands.
function MapLife.splashGap(moving: boolean, onMove: number, standing: number): number
	return if moving then onMove else standing
end

--- A dandelion puff's size (0 to 1) `since` seconds after it burst (nil: never): gone at once, back after `regrow`
--- seconds, growing over `grow` seconds.
function MapLife.puff(since: number?, regrow: number, grow: number): number
	if since == nil then
		return 1
	end
	return ease((since - regrow) / math.max(grow, 1e-3))
end

--- Whether a fighter at (px, pz) moving at `speed` studs a second bursts a puff at (x, z): running through it.
function MapLife.bursts(
	x: number,
	z: number,
	px: number,
	pz: number,
	speed: number,
	reach: number,
	least: number
): boolean
	local dx, dz = x - px, z - pz
	return speed >= least and dx * dx + dz * dz <= reach * reach
end

-- ===== the config ====================================================================================================

local function positive(v: any): boolean
	return type(v) == "number" and v > 0 and v == v
end

--- What is wrong with a map's `life` entry (empty when nothing). Gentle scenery only: capped counts and speeds.
function MapLife.problems(c: any): { string }
	local out = {}
	if type(c) ~= "table" then
		return { "life is not a table" }
	end
	local b = c.butterflies
	if b then
		if not (positive(b.calm) and positive(b.fast) and b.fast >= b.calm and b.fast <= 20) then
			table.insert(
				out,
				"butterflies: calm and fast wing beats must be above 0, fast at least calm, at most 20"
			)
		end
		if
			not (
				positive(b.reach)
				and positive(b.close)
				and positive(b.speed)
				and b.close < b.reach
			)
		then
			table.insert(
				out,
				"butterflies: reach, close and speed must be above 0, close under reach"
			)
		end
		if b.lead ~= nil and not (type(b.lead) == "number" and b.lead >= 0 and b.lead <= 0.5) then
			table.insert(out, "butterflies: lead 0 to 0.5 s")
		end
		if
			not (
				positive(b.dart)
				and b.dart <= 8
				and type(b.rise) == "number"
				and b.rise >= 0
				and b.rise <= 4
			)
		then
			table.insert(out, "butterflies: dart 0 to 8 studs, rise 0 to 4")
		end
		if
			b.count ~= nil and not (type(b.count) == "number" and b.count >= 0 and b.count <= 80)
		then
			table.insert(out, "butterflies: count 0 to 80 (each is 3 moving parts on every client)")
		end
		if
			b.flutter ~= nil
			and not (type(b.flutter) == "number" and b.flutter >= 0 and b.flutter <= 1)
		then
			table.insert(out, "butterflies: flutter 0 to 1 (the little loop laid on the flight)")
		end
		local w = b.wander
		if
			w ~= nil
			and not (
				type(w) == "table"
				and positive(w.range)
				and w.range <= 60
				and type(w.lift) == "number"
				and w.lift >= 0
				and w.lift <= 5
				and positive(w.speed)
				and w.speed <= 10
				and positive(w.quick)
				and type(w.linger) == "table"
				and type(w.linger[1]) == "number"
				and type(w.linger[2]) == "number"
				and w.linger[1] >= 0
				and w.linger[2] >= w.linger[1]
			)
		then
			table.insert(
				out,
				"butterflies: wander {range 0-60, lift 0-5, speed 0-10, quick > 0, linger {least, most}}"
			)
		end
		local f = b.flee
		if
			f ~= nil
			and not (
				type(f) == "table"
				and positive(f.quick)
				and positive(f.speed)
				and f.speed <= 30
			)
		then
			table.insert(out, "butterflies: flee {quick > 0, speed 0-30}")
		end
		if
			b.scale ~= nil and not (type(b.scale) == "number" and b.scale >= 0.5 and b.scale <= 2)
		then
			table.insert(
				out,
				"butterflies: scale 0.5 to 2 (floor life stays small: the stud flowers' scale)"
			)
		end
	end
	for _, fl in c.flocks or {} do
		if
			not (
				type(fl.centre) == "table"
				and #fl.centre == 3
				and type(fl.radii) == "table"
				and #fl.radii == 2
				and (fl.dir == 1 or fl.dir == -1)
				and positive(fl.period)
				and fl.period >= 8
				and positive(fl.count)
				and fl.count <= 12
				and (fl.kind == "Gull" or fl.kind == "Swallow")
			)
		then
			table.insert(
				out,
				"a flock needs centre {x, y, z}, radii {x, z}, dir 1 or -1, period 8+ s, 1 to 12 birds, kind Gull or Swallow"
			)
		end
	end
	local s = c.shadows
	if s then
		if
			not (positive(s.tile) and type(s.speed) == "number" and s.speed >= 0 and s.speed <= 20)
		then
			table.insert(out, "shadows: tile above 0, speed 0 to 20 studs a second")
		end
		if
			not (type(s.transparency) == "number" and s.transparency >= 0.5 and s.transparency <= 1)
		then
			table.insert(out, "shadows: transparency 0.5 to 1 (they must stay light)")
		end
	end
	local d = c.dandelions
	if
		d
		and not (
			positive(d.reach)
			and positive(d.regrow)
			and positive(d.grow)
			and type(d.least) == "number"
		)
	then
		table.insert(out, "dandelions: reach, regrow and grow above 0, least a number")
	end
	local bl = c.balloons
	if bl and not (positive(bl.loop) and positive(bl.speed) and bl.speed <= 6) then
		table.insert(out, "balloons: loop above 0, speed above 0 and at most 6")
	end
	return out
end

return MapLife
