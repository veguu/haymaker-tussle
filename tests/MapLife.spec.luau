--!strict
local MapLife = require("../src/shared/Core/MapLife")
local Envs: any = require("../src/shared/Config/MapEnvironments")

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

local FLEE = { reach = 8, close = 2.5, speed = 18 }

return {
	["a butterfly wanders a few studs round its home, never far"] = function()
		for i = 1, 14 do
			for k = 0, 400 do
				local x, y, z = MapLife.butterfly(i, k * 0.173)
				assert(
					math.abs(x) <= 3.9 + 1e-9 and math.abs(z) <= 3.5 + 1e-9,
					`butterfly {i} strayed: {x}, {z}`
				)
				assert(math.abs(y) <= 0.5 + 1e-9, `butterfly {i} rose or sank too far: {y}`)
				local rx, ry, rz = MapLife.butterfly(i, k * 0.173, 1.8)
				assert(
					near(rx, x * 1.8, 1e-9) and near(ry, y * 1.8, 1e-9) and near(rz, z * 1.8, 1e-9),
					"roam scales it"
				)
			end
		end
	end,

	["more butterflies: a companion beside each, the rest alone in the gaps, inside the arena, the same every time"] = function()
		local homes = {}
		for i = 1, 14 do
			local a = i * 2.4
			table.insert(homes, { (40 + i * 8) * math.cos(a), (40 + i * 8) * math.sin(a) })
		end
		local spread = { pair = { 3, 6 }, ring = { 35, 160 }, apart = 14, lift = 1.2 }
		local extra = MapLife.extraHomes(homes, 40, spread)
		assert(#extra == 26, `26 extras for 40, got {#extra}`)
		for i, e in extra do
			assert(math.sqrt(e.x * e.x + e.z * e.z) <= 172, `extra {i} off the floor: {e.x}, {e.z}`)
			assert(e.y >= 0 and e.y <= 1.2, `extra {i} height {e.y}`)
			assert(e.src >= 1 and e.src <= 14, `extra {i} copies home {e.src}`)
			if i <= 14 then
				local d = math.sqrt((e.x - homes[i][1]) ^ 2 + (e.z - homes[i][2]) ^ 2)
				assert(d >= 3 - 1e-9 and d <= 6 + 1e-9, `companion {i} is {d} from its partner`)
				assert(e.src ~= i, "a companion is another colour")
			else
				for j, h in homes do
					local d = math.sqrt((e.x - h[1]) ^ 2 + (e.z - h[2]) ^ 2)
					assert(d >= 14 - 1e-9, `lone extra {i} is {d} from home {j}`)
				end
			end
		end
		local again = MapLife.extraHomes(homes, 40, spread)
		assert(again[20].x == extra[20].x and again[20].z == extra[20].z, "the same every time")
		assert(#MapLife.extraHomes(homes, 10, spread) == 0, "no extras when the model holds enough")
		assert(#MapLife.problems({
			butterflies = {
				calm = 4,
				fast = 12,
				reach = 8,
				close = 2.5,
				speed = 18,
				dart = 4,
				rise = 2,
				count = 200,
			},
		}) > 0, "a swarm is refused")
		local b = Envs.Maps.meadow.life.butterflies
		assert(
			b.count >= 16 and b.count <= 30 and b.phone <= 8,
			"Map 1: noticeable, not overdone (life-6); few on a phone"
		)
	end,

	["a butterfly glides: no jumps, no overshoot, never past its top speed, steady for any frame time"] = function()
		for _, dt in { 1 / 240, 1 / 60, 1 / 20, 0.1 } do
			local px, py, pz, vx, vy, vz = 0, 0, 0, 0, 0, 0
			local last = math.huge
			for _ = 1, math.ceil(10 / dt) do -- 22 studs at 5 a second, slowing near the end
				local nx, ny, nz, nvx, nvy, nvz =
					MapLife.glide(px, py, pz, vx, vy, vz, 20, 2, -10, dt, 1.2, 5)
				local step = math.sqrt((nx - px) ^ 2 + (ny - py) ^ 2 + (nz - pz) ^ 2)
				assert(step <= 5 * dt + 1e-9, `a jump of {step} in {dt} s`)
				local d = math.sqrt((20 - nx) ^ 2 + (2 - ny) ^ 2 + (-10 - nz) ^ 2)
				assert(d <= last + 1e-9, "it never turns back past its stop")
				last = d
				px, py, pz, vx, vy, vz = nx, ny, nz, nvx, nvy, nvz
			end
			assert(last < 0.5, `arrived within 10 s at dt {dt}: {last} off`)
		end
	end,

	["a dodge is a smooth swerve, yet well aside by the time a dash arrives"] = function()
		-- the owner: "they should smoothly move out the way. not instantly teleport"; and "you'll NEVER be able to hit
		-- the butterfly". A 60-stud dash is seen reach + speed * lead = 8 + 15 studs out: about 0.38 s before it arrives.
		local b = Envs.Maps.meadow.life.butterflies
		local dt = 1 / 60
		local px, pz, vx, vz = 0, 0, 0, 0
		local first
		local tx = b.dart
		for k = 1, math.floor((b.reach + 60 * b.lead) / 60 / dt) do
			local nx, _, nz, nvx, _, nvz =
				MapLife.glide(px, 0, pz, vx, 0, vz, tx, 0, 0, dt, b.flee.quick, b.flee.speed)
			if k == 1 then
				first = nx - px
			end
			px, pz, vx, vz = nx, nz, nvx, nvz
		end
		assert(first < 0.1, `the first frame moves {first} studs: a jump, not a swerve`)
		assert(px >= 2.5, `only {px} studs aside when the dash arrives`)
	end,

	["each butterfly's stops spread round its home, a new place each time, the same every run"] = function()
		local seen = {}
		for n = 1, 30 do
			local x, y, z = MapLife.stop(3, n, 28, 2.5)
			assert(
				math.sqrt(x * x + z * z) <= 28 + 1e-9 and y >= 0 and y <= 2.5,
				`stop {n} out of range`
			)
			local a, _, c = MapLife.stop(3, n, 28, 2.5)
			assert(a == x and c == z, "the same every run")
			seen[math.floor(x / 10) .. ":" .. math.floor(z / 10)] = true
			local l = MapLife.linger(3, n, 0.6, 2.5)
			assert(l >= 0.6 and l <= 2.5, "lingers 0.6 to 2.5 s")
		end
		local cells = 0
		for _ in seen do
			cells += 1
		end
		assert(cells >= 10, `it roams: {cells} different 10-stud cells in 30 stops`)
	end,

	["a dash straight at a butterfly makes it dart aside, on its own side of the line"] = function()
		-- fighter at the origin dashing along +x at 60; the butterfly 5 studs ahead, a little to +z
		local hit, sx, sz = MapLife.threat(FLEE, 5, 0.5, 0, 0, 60, 0)
		assert(hit, "a dash at it within reach must make it flee")
		assert(
			near(sx, 0, 1e-9) and near(sz, 1, 1e-9),
			`it darts sideways to its own side (+z), got {sx}, {sz}`
		)
		local hit2, _, sz2 = MapLife.threat(FLEE, 5, -0.5, 0, 0, 60, 0)
		assert(hit2 and sz2 < 0, "on the other side of the line it darts the other way")
	end,

	["a dash is seen `lead` seconds sooner, so a fast one is never missed between checks"] = function()
		local f = { reach = 8, close = 2.5, speed = 18, lead = 0.15 }
		assert(
			MapLife.threat(f, 15, 0, 0, 0, 60, 0),
			"60 studs a second, 15 away: within 8 + 60 x 0.15"
		)
		assert(not (MapLife.threat(f, 15, 0, 0, 0, 10, 0)), "a walk from 15 away is nothing")
		local long =
			{ calm = 4, fast = 12, reach = 8, close = 2, speed = 18, dart = 4, rise = 2, lead = 2 }
		assert(#MapLife.problems({ butterflies = long }) > 0, "a long lead is refused")
	end,

	["a fighter far off, walking past or going away never bothers it"] = function()
		assert(not (MapLife.threat(FLEE, 20, 0, 0, 0, 60, 0)), "out of reach")
		assert(not (MapLife.threat(FLEE, 5, 0, 0, 0, 10, 0)), "walking at it slowly")
		assert(not (MapLife.threat(FLEE, 5, 0, 0, 0, -60, 0)), "dashing away from it")
		assert(not (MapLife.threat(FLEE, 0, 6, 0, 0, 60, 0)), "dashing past, well to the side")
	end,

	["anyone standing right by it makes it move away from them"] = function()
		local hit, sx, sz = MapLife.threat(FLEE, 1, 0, 0, 0, 0, 0)
		assert(
			hit and near(sx, 1) and near(sz, 0),
			"straight away from a fighter standing within close"
		)
	end,

	["the dart is out fast, held, and home again; wings beat faster only while it flees"] = function()
		assert(MapLife.dart(-1) == 0 and MapLife.dart(0) == 0, "nothing before it starts")
		assert(
			MapLife.dart(0.25) > 0.99 and MapLife.dart(1.4) > 0.99,
			"fully out by a quarter second, held"
		)
		assert(near(MapLife.dart(3.9), 0, 1e-9), "home again by 3.9 s")
		assert(MapLife.beats(nil, 4, 12) == 4, "calm: 4 a second")
		assert(near(MapLife.beats(0.5, 4, 12), 12, 1e-6), "fleeing: 12 a second")
		assert(MapLife.beats(2.3, 4, 12) == 4, "calm again after it")
		for k = 0, 100 do
			local w = MapLife.wing(k * 0.1)
			assert(
				w >= -0.2 - 1e-9 and w <= 1.3 + 1e-9,
				"a wing lifts 1.3 at most and dips 0.2 below flat"
			)
		end
	end,

	["a bee buzzes within a few studs, low over the flowers"] = function()
		for i = 1, 8 do
			for k = 0, 300 do
				local x, y, z = MapLife.bee(i, k * 0.211)
				assert(
					math.abs(x) <= 2.7 + 1e-9
						and math.abs(z) <= 2.2 + 1e-9
						and math.abs(y) <= 0.4 + 1e-9,
					"bee strayed"
				)
			end
		end
	end,

	["animals graze head down about half the time and shuffle back where they were"] = function()
		for i = 1, 14 do
			local down, n = 0, 0
			for k = 0, 2000 do
				local g = MapLife.graze(i, k * 0.05)
				assert(g <= 0.06 and g >= -1.36, `head tilt out of range: {g}`)
				if g < -0.6 then
					down += 1
				end
				n += 1
				local s = MapLife.shuffle(i, k * 0.05)
				assert(s >= -1e-9 and s <= 2 + 1e-9, `a shuffle of {s} studs`)
			end
			assert(down / n > 0.3 and down / n < 0.6, `grazing share {down / n}`)
		end
	end,

	["a flock laps its loop every period, and its velocity is its motion"] = function()
		local fl = Envs.Maps.meadow.life.flocks[1]
		local x0, y0, z0 = MapLife.orbit(fl, 2, 3)
		local x1, y1, z1 = MapLife.orbit(fl, 2, 3 + fl.period)
		assert(
			near(x0, x1, 1e-6) and near(y0, y1, 1e-6) and near(z0, z1, 1e-6),
			"a lap later, the same place"
		)
		local ax, ay, az, vx, vy, vz = MapLife.orbit(fl, 2, 5)
		local bx, by, bz = MapLife.orbit(fl, 2, 5 + 1e-4)
		assert(
			near((bx - ax) / 1e-4, vx, 0.05) and near((by - ay) / 1e-4, vy, 0.05),
			"velocity matches the path"
		)
		assert(near((bz - az) / 1e-4, vz, 0.05), "velocity matches the path (z)")
	end,

	["a balloon starts where it was built and drifts slowly round its loop"] = function()
		local dx, _, dz = MapLife.balloon(1, 0, 120, 2.5)
		assert(near(dx, 0, 1e-9) and near(dz, 0, 1e-9), "no jump at the start")
		local ax, _, az = MapLife.balloon(1, 10, 120, 2.5)
		local bx, _, bz = MapLife.balloon(1, 11, 120, 2.5)
		local speed = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		assert(speed <= 2.5 + 1e-6, `balloons drift at most 2.5 studs a second, got {speed}`)
	end,

	["the cloud shadows slide with the wind at the set speed, each offset within a tile"] = function()
		local u0, v0 = MapLife.slide(0, 5.5, 1, 0, 360)
		local u1, v1 = MapLife.slide(10, 5.5, 1, 0, 360)
		assert(near(u1 - u0, 55, 1e-9) and near(v1 - v0, 0, 1e-9), "55 studs in 10 s along +x")
		for k = 0, 50 do
			local u, v = MapLife.slide(k * 37, 5.5, 0.958, 0.287, 360)
			assert(u >= 0 and u < 360 and v >= 0 and v < 360, "within one tile")
		end
	end,

	["a dandelion bursts when run through, and grows back"] = function()
		assert(MapLife.bursts(0, 0, 0.5, 0.5, 20, 1.2, 2), "running through it")
		assert(not MapLife.bursts(0, 0, 0.5, 0.5, 1, 1.2, 2), "standing by it")
		assert(not MapLife.bursts(0, 0, 3, 0, 20, 1.2, 2), "running past, out of reach")
		assert(MapLife.puff(nil, 25, 2) == 1, "whole until burst")
		assert(
			MapLife.puff(0, 25, 2) == 0 and MapLife.puff(20, 25, 2) == 0,
			"gone, then still gone"
		)
		assert(MapLife.puff(27, 25, 2) == 1, "back after regrow + grow")
	end,

	["phones keep exactly the asked number, spread over the list"] = function()
		for _, case in { { 14, 6 }, { 8, 3 }, { 5, 5 }, { 6, 0 }, { 6, 9 } } do
			local n, keep = case[1], case[2]
			local got = 0
			for i = 1, n do
				if MapLife.kept(i, n, keep) then
					got += 1
				end
			end
			assert(got == math.min(n, keep), `kept {got} of {n}, wanted {keep}`)
		end
	end,

	["every map's life entry is sane, Map 1 has no cloud shadows, and a dark shade is refused"] = function()
		for id, entry in Envs.Maps do
			if entry.life then
				local problems = MapLife.problems(entry.life)
				assert(#problems == 0, `{id}: {table.concat(problems, "; ")}`)
			end
		end
		-- the owner, 2026-11-26: the cloud shadows made the map look "not fully rendered"; they are gone
		assert(Envs.Maps.meadow.life.shadows == nil, "Map 1 has no cloud shadows")
		assert(
			#MapLife.problems({ shadows = { tile = 360, speed = 5.5, transparency = 0.6 } }) == 0,
			"light ones pass"
		)
		assert(
			#MapLife.problems({ shadows = { tile = 360, speed = 5.5, transparency = 0.2 } }) > 0,
			"a dark shade is refused"
		)
	end,
}
