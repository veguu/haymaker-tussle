--!nocheck
-- Fits a REAL camera (Roblox: square pixels, the lens centred on the frame) to the plunge drawing's own construction
-- (Plunge.cs TP: three vanishing points with weights, a general projective map). kits-8h: the camera first derived from
-- the vanishing points was 190-450 px off the drawing for the same torso points, so live frames never matched it.
-- Samples the torso, the dent, the fist and the arms as drawn (torso units = studs; x right, y up, z back), projects
-- them with TP, and solves for the eye, the view and the focal length by least squares (Nelder-Mead).
--   lune run lune/drawn_fit        prints the fit, the error per part, and the numbers for tests/support/DrawnView
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local VL0, VR0, VD0, T00 = { -2400, -500 }, { 2050, -500 }, { 620, 3600 }, { 950, 160 }
local WX, WZ, WD = 0.26 / (2 * 0.74), 0.27 / 0.73, 0.25 / (2 * 0.75)
local function TP(v)
	local dx, dz, dd = v.X + 1, v.Z + 0.5, 1 - v.Y
	local den = 1 + dx * WX + dd * WD + dz * WZ
	return (T00[1] + dx * WX * VL0[1] + dd * WD * VD0[1] + dz * WZ * VR0[1]) / den,
		(T00[2] + dx * WX * VL0[2] + dd * WD * VD0[2] + dz * WZ * VR0[2]) / den
end

-- the drawn parts, as Plunge.cs builds them (mid-sequence: arms sweep ~22/20, lift ~-30/-34; head dropped ~11)
-- the contact and the fist's half size as drawn (Plunge.cs HX, HY, FH: kits-8h the chest's centre and an R6 arm)
local HX, HY = 0, 0
local samples: { { part: string, p: any } } = {}
local function add(part, p)
	local x, y = TP(p)
	if x > -300 and x < 1580 and y > -300 and y < 1020 then
		table.insert(samples, { part = part, p = p, x = x, y = y })
	end
end
for _, sx in { -1, -0.5, 0, 0.5, 1 } do
	for _, sy in { -1, -0.5, 0, 0.5, 1 } do
		add("torso front", Vector3.new(sx, sy, -0.5))
	end
	add("torso top", Vector3.new(sx, 1, 0))
	add("torso top", Vector3.new(sx, 1, 0.5))
end
for _, sy in { -1, 0, 1 } do
	add("torso left side", Vector3.new(-1, sy, 0))
	add("torso left side", Vector3.new(-1, sy, 0.5))
end
for k = 0, 11 do
	local a = k / 12 * math.pi * 2
	add("dent", Vector3.new(HX + 0.5 * math.cos(a), HY + 0.5 * math.sin(a), -0.5))
end
for _, z in { -0.6, -1.0, -1.4, -1.9 } do
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		add("fist/forearm", Vector3.new(HX + 0.5 * c[1], HY + 0.5 * c[2], z))
	end
end
local function arm(side, sweep, lift)
	local s, l = math.rad(sweep), math.rad(lift)
	local dir =
		Vector3.new(side * math.sin(s) * math.cos(l), math.sin(l), -math.cos(s) * math.cos(l))
	for _, along in { -0.5, 0.5, 1.5 } do
		add(side > 0 and "right arm" or "left arm", Vector3.new(side * 1.5, 0.5, 0) + dir * along)
	end
end
arm(1, 24, -30)
arm(-1, 20, -34)

local function cameraOf(q)
	local eye = Vector3.new(q[1], q[2], q[3])
	local yaw, pitch, roll, focal = q[4], q[5], q[6], q[7]
	local f = Vector3.new(
		math.sin(yaw) * math.cos(pitch),
		-math.sin(pitch),
		math.cos(yaw) * math.cos(pitch)
	)
	local r0 = f:Cross(Vector3.new(0, 1, 0)).Unit
	local d0 = f:Cross(r0)
	local r = r0 * math.cos(roll) + d0 * math.sin(roll)
	local d = d0 * math.cos(roll) - r0 * math.sin(roll)
	return eye, r, d, f, focal
end
local function project(q, p)
	local eye, r, d, f, focal = cameraOf(q)
	local v = p - eye
	local z = v:Dot(f)
	if z < 0.1 then
		return nil
	end
	return 640 + focal * v:Dot(r) / z, 360 + focal * v:Dot(d) / z
end
-- what the owner checks most: the fist and forearm, the hit on the chest, then the chest; the arms and the rest after
local WEIGHT = { dent = 3, ["fist/forearm"] = 3, ["torso front"] = 2 }
local function cost(q)
	local sum, total = 0, 0
	for _, s in samples do
		local x, y = project(q, s.p)
		if not x then
			return 1e12
		end
		local w = WEIGHT[s.part] or 1
		sum += w * ((x - s.x) ^ 2 + (y - s.y) ^ 2)
		total += w
	end
	return sum / total
end

-- Nelder-Mead
local function nelder(start, steps, iters)
	local n = #start
	local simplex = { { x = table.clone(start), c = cost(start) } }
	for i = 1, n do
		local p = table.clone(start)
		p[i] += steps[i]
		table.insert(simplex, { x = p, c = cost(p) })
	end
	for _ = 1, iters do
		table.sort(simplex, function(a, b)
			return a.c < b.c
		end)
		local centroid = table.create(n, 0)
		for i = 1, n do
			for j = 1, n do
				centroid[j] += simplex[i].x[j] / n
			end
		end
		local worst = simplex[n + 1]
		local function along(t)
			local p = {}
			for j = 1, n do
				p[j] = centroid[j] + t * (worst.x[j] - centroid[j])
			end
			return p
		end
		local xr = along(-1)
		local cr = cost(xr)
		if cr < simplex[1].c then
			local xe = along(-2)
			local ce = cost(xe)
			simplex[n + 1] = if ce < cr then { x = xe, c = ce } else { x = xr, c = cr }
		elseif cr < simplex[n].c then
			simplex[n + 1] = { x = xr, c = cr }
		else
			local xc = along(0.5)
			local cc = cost(xc)
			if cc < worst.c then
				simplex[n + 1] = { x = xc, c = cc }
			else
				for i = 2, n + 1 do
					for j = 1, n do
						simplex[i].x[j] = simplex[1].x[j]
							+ 0.5 * (simplex[i].x[j] - simplex[1].x[j])
					end
					simplex[i].c = cost(simplex[i].x)
				end
			end
		end
	end
	table.sort(simplex, function(a, b)
		return a.c < b.c
	end)
	return simplex[1].x, simplex[1].c
end

-- start: the old estimate (eye, a view down at the torso, a 23 deg lens)
local best, bestCost
for _, startYaw in { 0.4, 0.7, 1.0 } do
	for _, startPitch in { 0.3, 0.55, 0.8 } do
		local q, c = nelder(
			{ -2.1, 2.0, -2.2, startYaw, startPitch, 0, 1600 },
			{ 0.6, 0.6, 0.6, 0.2, 0.2, 0.2, 300 },
			4000
		)
		q, c = nelder(q, { 0.2, 0.2, 0.2, 0.05, 0.05, 0.05, 100 }, 4000)
		if not bestCost or c < bestCost then
			best, bestCost = q, c
		end
	end
end
local eye, r, d, f, focal = cameraOf(best)
print(string.format("fit: rms %.1f px over %d samples", math.sqrt(bestCost), #samples))
print(string.format("EYE = Vector3.new(%.3f, %.3f, %.3f)", eye.X, eye.Y, eye.Z))
print(string.format("RIGHT = Vector3.new(%.3f, %.3f, %.3f)", r.X, r.Y, r.Z))
print(string.format("DOWN = Vector3.new(%.3f, %.3f, %.3f)", d.X, d.Y, d.Z))
print(string.format("FORWARD = Vector3.new(%.3f, %.3f, %.3f)", f.X, f.Y, f.Z))
print(
	string.format(
		"FOCAL = %.0f  (vertical FOV %.1f deg on the 720 px frame)",
		focal,
		2 * math.deg(math.atan(360 / focal))
	)
)
local byPart = {}
for _, s in samples do
	local x, y = project(best, s.p)
	local e = math.sqrt((x - s.x) ^ 2 + (y - s.y) ^ 2)
	local b = byPart[s.part] or { n = 0, sum = 0, worst = 0 }
	b.n += 1
	b.sum += e
	b.worst = math.max(b.worst, e)
	byPart[s.part] = b
end
for part, b in byPart do
	print(
		string.format(
			"  %-16s mean %5.1f px, worst %5.1f px (%d points)",
			part,
			b.sum / b.n,
			b.worst,
			b.n
		)
	)
end
