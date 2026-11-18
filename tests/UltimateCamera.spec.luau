--!strict
-- Haymaker Rush v2: can you see what's going on? (the user, 2026-11-16: "the camera work isnt really good as you
-- cant see whats going on"; design/haymaker-rush-v2-brief.md section 7). The timeline's camera is projected
-- every 1/30 s, from several places the attacker can start, at phone, desktop and tablet shapes.
-- ULT_REPORT=1 prints the worst numbers per shot (lune run lune/test, or this file alone).
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Ultimates = require("../src/shared/Core/Ultimates")

local Vector3 = roblox.Vector3

local ROOT_TO_HEAD = 1.5 -- a character's head centre over its root (R15)
local ROOT_TO_FEET = 2.9 -- its feet under its root
local MARGIN = 0.08 -- the safe frame: 8 % of the screen on every side
local FLOOR_BELOW_FEET = 0.4 -- in the juggle the floor under their feet shows too (the user, kits-7c)
local MIN_TARGET_HEIGHT = 0.15 -- the target fills at least this share of the screen height in a wide shot
local HANG_TARGET_HEIGHT = 0.08 -- except the worm's-eye hang, small against the sky on purpose
local MAX_HIDDEN = 0.2 -- the attacker may hide the target's head this long at most
local ASPECTS = { phone = 19.5 / 9, desktop = 16 / 9, tablet = 4 / 3 }
-- where the attacker can be when it starts (the string's last punch knocked the target a few studs away)
local STARTS = {
	Vector3.new(0, 0, 6),
	Vector3.new(3, 0, 9),
	Vector3.new(-3, 0, 7),
	Vector3.new(0, 0, 12),
}

-- The close inserts (kits-7e: the lock-in and the wind-up, one fighter on purpose) and the impact frames are allowed
-- to crop; every other shot keeps both fighters whole.
-- kits-8a: so is a push INTO an insert once it is moving (the owner's "zoom in onto the fist and the targets torso":
-- the zoom crops on its way in).
local function isWide(line: any, t: number): boolean
	local haymaker = 0
	for _, cue in line.cues do
		if cue.name == "haymaker" then
			haymaker = cue.t
		end
	end
	local current = Ultimates.currentShot(line, t)
	local nextShot
	for _, shot in line.shots do
		if shot.t > t then
			nextShot = shot
			break
		end
	end
	local pushingIn = nextShot ~= nil and nextShot.insert and not nextShot.cut and t > current.t
	return not current.insert and not pushingIn and not (t >= haymaker and t < haymaker + 0.3)
end

-- A point's place on screen: -1..1 across and up, and its depth (+ in front).
local function project(
	point: any,
	cam: any,
	look: any,
	fov: number,
	roll: number,
	aspect: number
): (number, number, number)
	local forward = (look - cam).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(forward)
	local rel = point - cam
	local depth = rel:Dot(forward)
	local half = math.tan(math.rad(fov) / 2)
	local x = rel:Dot(right) / (math.max(depth, 1e-3) * half * aspect)
	local y = rel:Dot(up) / (math.max(depth, 1e-3) * half)
	local r = math.rad(roll)
	return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r), depth
end

local function inside(x: number, y: number, depth: number): boolean
	local edge = 1 - 2 * MARGIN
	return depth > 0 and math.abs(x) <= edge and math.abs(y) <= edge
end

-- distance from a point to a fighter's body (a vertical segment from feet to head)
local function toBody(point: any, root: any): number
	local y = math.clamp(point.Y, root.Y - ROOT_TO_FEET, root.Y + ROOT_TO_HEAD + 0.5)
	return (point - Vector3.new(root.X, y, root.Z)).Magnitude
end

type Problem = { t: number, what: string }

local function check(): ({ Problem }, { [string]: string })
	local line = Ultimates.TIMELINES.Base
	local problems: { Problem } = {}
	local report: { [string]: string } = {}
	for _, start in STARTS do
		for aspectName, aspect in ASPECTS do
			local hiddenFor = 0
			local t = 0
			while t < line.cinematic do
				local attackerAt, targetAt = Ultimates.pose(line, t, start)
				local cam, look, fov, roll = Ultimates.shot(line, t, attackerAt, targetAt, start)
				-- with the hits' punch-ins applied (they narrow the view)
				fov -= (Ultimates.kick(line, t))
				local tag = string.format("start %s, %s", tostring(start), aspectName)
				-- never inside a body
				for who, root in { attacker = attackerAt, target = targetAt } do
					if toBody(cam, root) < 1.5 then
						table.insert(problems, { t = t, what = `camera inside the {who} ({tag})` })
					end
				end
				if isWide(line, t) then
					local worst = 0
					for who, root in { attacker = attackerAt, target = targetAt } do
						for part, point in
							{ root = root, head = root + Vector3.new(0, ROOT_TO_HEAD, 0) }
						do
							local x, y, depth = project(point, cam, look, fov, roll, aspect)
							worst = math.max(worst, math.abs(x), math.abs(y))
							if not inside(x, y, depth) then
								table.insert(problems, {
									t = t,
									what = string.format(
										"%s %s off screen (%.2f, %.2f) (%s)",
										who,
										part,
										x,
										y,
										tag
									),
								})
							end
						end
					end
					-- the side view from the first hook through the flurry (1.14-3.45): both whole, feet and the
					-- floor under them in frame
					if t >= 1.14 and t < 3.72 then
						for who, root in { attacker = attackerAt, target = targetAt } do
							local floorY = math.min(root.Y, 0) - ROOT_TO_FEET - FLOOR_BELOW_FEET
							local x, y, depth = project(
								Vector3.new(root.X, floorY, root.Z),
								cam,
								look,
								fov,
								roll,
								aspect
							)
							if not inside(x, y, depth) then
								table.insert(problems, {
									t = t,
									what = string.format(
										"floor under the %s off screen (%.2f, %.2f) (%s)",
										who,
										x,
										y,
										tag
									),
								})
							end
						end
					end
					-- big enough to read on a phone
					local _, top = project(
						targetAt + Vector3.new(0, ROOT_TO_HEAD + 0.5, 0),
						cam,
						look,
						fov,
						roll,
						aspect
					)
					local _, bottom = project(
						targetAt - Vector3.new(0, ROOT_TO_FEET, 0),
						cam,
						look,
						fov,
						roll,
						aspect
					)
					local tall = math.abs(top - bottom) / 2
					-- the worm's-eye hang (4.2-4.5) shows them small against the sky on purpose (Azure 5.58-5.92),
					-- but still readable
					local needed = if t >= 4.6 and t < 4.95
						then HANG_TARGET_HEIGHT
						else MIN_TARGET_HEIGHT
					if tall < needed then
						table.insert(problems, {
							t = t,
							what = string.format(
								"target only %.2f of the screen tall (%s)",
								tall,
								tag
							),
						})
					end
					-- the attacker in front of the target's head
					local hx, hy, hd = project(
						targetAt + Vector3.new(0, ROOT_TO_HEAD, 0),
						cam,
						look,
						fov,
						roll,
						aspect
					)
					local ax, ay, ad = project(attackerAt, cam, look, fov, roll, aspect)
					local halfWidth = 1.1
						/ (math.max(ad, 1e-3) * math.tan(math.rad(fov) / 2) * aspect)
					local _, atop = project(
						attackerAt + Vector3.new(0, ROOT_TO_HEAD + 0.6, 0),
						cam,
						look,
						fov,
						roll,
						aspect
					)
					local _, afoot = project(
						attackerAt - Vector3.new(0, ROOT_TO_FEET, 0),
						cam,
						look,
						fov,
						roll,
						aspect
					)
					local hidden = ad < hd
						and math.abs(hx - ax) < halfWidth
						and hy <= math.max(atop, afoot)
						and hy >= math.min(atop, afoot)
					hiddenFor = if hidden then hiddenFor + 1 / 30 else 0
					if hiddenFor > MAX_HIDDEN then
						table.insert(
							problems,
							{ t = t, what = `target hidden behind the attacker ({tag})` }
						)
						hiddenFor = 0
					end
					local key = string.format("%.2f", t - t % 0.5)
					report[key] = string.format(
						"worst edge %.2f (limit %.2f)",
						math.max(
							worst,
							tonumber(string.match(report[key] or "", "%d+%.%d+") or "0") or 0
						),
						1 - 2 * MARGIN
					)
				end
				t += 1 / 30
			end
		end
	end
	return problems, report
end

return {
	["Haymaker Rush keeps both fighters in frame, big enough, unblocked, the camera never inside them"] = function()
		local problems, report = check()
		if process.env.ULT_REPORT then
			local keys = {}
			for key in report do
				table.insert(keys, key)
			end
			table.sort(keys, function(a, b)
				local x: number = tonumber(a) or 0
				local y: number = tonumber(b) or 0
				return x < y
			end)
			for _, key in keys do
				print(`  {key} s: {report[key]}`)
			end
		end
		if #problems > 0 then
			local lines = {}
			for index = 1, math.min(#problems, 12) do
				table.insert(
					lines,
					string.format("%.2f s: %s", problems[index].t, problems[index].what)
				)
			end
			error(`{#problems} problems, first ones:\n` .. table.concat(lines, "\n"))
		end
	end,

	["every Haymaker Rush camera stays on the attacker's right, in every frame it uses"] = function()
		local line = Ultimates.TIMELINES.Base
		for _, shot in line.shots do
			-- anchor, pair and attacker shots all keep +X as the attacker's right
			assert(shot.cam.X > 0, `shot at {shot.t} crosses the line`)
		end
	end,
}
