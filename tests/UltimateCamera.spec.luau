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

-- A point's place on screen: -1..1 across and up, and its depth (+ in front). As the game builds the camera
-- (UltimateController: CFrame.lookAt(cam, look) * CFrame.Angles(0, 0, roll), vertical FOV): the roll turns the
-- camera's right toward its up (right cos + up sin), so a point lands at x cos + y sin, y cos - x sin, turned in the
-- picture's own square units and only then narrowed by the aspect. cam-1: before 2026-11-21 this turned the other way
-- and after the aspect; checked against Lune's CFrame.fromMatrix * CFrame.Angles (Lune 0.8.9's CFrame.lookAt is wrong
-- for most directions: its LookVector misses the target, so don't check cameras with it).
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
	local half = math.max(depth, 1e-3) * math.tan(math.rad(fov) / 2)
	local x = rel:Dot(right) / half
	local y = rel:Dot(up) / half
	local r = math.rad(roll)
	return (x * math.cos(r) + y * math.sin(r)) / aspect, y * math.cos(r) - x * math.sin(r), depth
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

	-- cam-1: the leap-and-dash camera is a track baked from Blender (Config/CameraTracks, animations/camera).
	["the baked dash camera fits its window, keeps both fighters whole on every screen, and lands on the drawn eye"] = function()
		local line = Ultimates.TIMELINES.Base
		local track = line.track
		assert(track, "Haymaker Rush plays a baked dash track")
		local haymaker = 0
		for _, cue in line.cues do
			if cue.name == "haymaker" then
				haymaker = cue.t
			end
		end
		-- it runs from the cut to the dash shot up to the contact: if the timeline is retimed, export it again
		local dashCut = false
		for _, shot in line.shots do
			dashCut = dashCut or (shot.cut == true and math.abs(shot.t - track.from) < 1e-4)
		end
		assert(dashCut, `the track starts at {track.from}, where no shot cuts: export it again`)
		assert(
			math.abs(track.to - haymaker) < 1e-4,
			`the track ends at {track.to}, the haymaker lands at {haymaker}`
		)
		local rows = track.frames
		assert(
			math.abs(rows[1][1] - track.from) < 1e-4 and math.abs(rows[#rows][1] - track.to) < 1e-4,
			"first and last rows"
		)
		for index = 2, #rows do
			local step = rows[index][1] - rows[index - 1][1]
			assert(
				step > 0 and step <= 1 / 60 + 1e-4,
				`rows {index - 1} and {index} are {step} s apart`
			)
			-- one cut only, onto the last row; before it the camera stays put and its aim never jumps
			assert((rows[index][10] == 1) == (index == #rows), `a cut at row {index}`)
			if index < #rows then
				local a, b = rows[index - 1], rows[index]
				local moved = (Vector3.new(b[2], b[3], b[4]) - Vector3.new(a[2], a[3], a[4])).Magnitude
				local aimA = (Vector3.new(a[5], a[6], a[7]) - Vector3.new(a[2], a[3], a[4])).Unit
				local aimB = (Vector3.new(b[5], b[6], b[7]) - Vector3.new(b[2], b[3], b[4])).Unit
				local turned = math.deg(math.acos(math.clamp(aimA:Dot(aimB), -1, 1)))
				assert(moved < 0.01, `the camera moves {moved} studs at row {index}`)
				assert(turned < 1, `the aim turns {turned} degrees in one frame at row {index}`)
			end
		end
		-- the game plays it: inside the window Ultimates.shot returns the track, whatever the attacker's start
		for _, start in STARTS do
			local t = track.from
			while t < track.to do
				local attackerAt, targetAt = Ultimates.pose(line, t, start)
				local cam, look, fov, roll = Ultimates.shot(line, t, attackerAt, targetAt, start)
				for who, root in { attacker = attackerAt, target = targetAt } do
					assert(
						toBody(cam, root) >= 1.5,
						string.format("%.3f s: the camera is inside the %s", t, who)
					)
				end
				for aspectName, aspect in ASPECTS do
					local ax = project(attackerAt, cam, look, fov, roll, aspect)
					local tx = project(targetAt, cam, look, fov, roll, aspect)
					assert(
						ax < tx,
						string.format(
							"%.3f s: the attacker is not left of the target (%s)",
							t,
							aspectName
						)
					)
					for who, root in { attacker = attackerAt, target = targetAt } do
						for part, point in
							{
								root = root,
								head = root + Vector3.new(0, ROOT_TO_HEAD, 0),
								feet = root - Vector3.new(0, ROOT_TO_FEET, 0),
							}
						do
							local x, y, depth = project(point, cam, look, fov, roll, aspect)
							assert(
								inside(x, y, depth),
								string.format(
									"%.3f s: %s %s off screen (%.2f, %.2f) on %s",
									t,
									who,
									part,
									x,
									y,
									aspectName
								)
							)
						end
					end
				end
				t += 1 / 60
			end
		end
		-- the last row IS the drawn plunge's eye, the shot the game cuts to on the contact
		local start = STARTS[1]
		local attackerAt, targetAt = Ultimates.pose(line, track.to, start)
		local cam, look, fov, roll = Ultimates.shot(line, track.to, attackerAt, targetAt, start)
		local last = rows[#rows]
		local lastCam = Vector3.new(last[2], last[3], last[4])
		local lastAim = (Vector3.new(last[5], last[6], last[7]) - lastCam).Unit
		assert(
			(lastCam - cam).Magnitude < 0.01,
			`the last row is {(lastCam - cam).Magnitude} studs from the drawn eye`
		)
		assert(
			math.deg(math.acos(math.clamp(lastAim:Dot((look - cam).Unit), -1, 1))) < 0.1,
			"the last row's aim"
		)
		assert(
			math.abs(last[8] - fov) < 0.1 and math.abs(last[9] - roll) < 0.1,
			"the last row's lens and roll"
		)
	end,

	["every Haymaker Rush camera stays on the attacker's right, in every frame it uses"] = function()
		local line = Ultimates.TIMELINES.Base
		for _, shot in line.shots do
			-- anchor, pair and attacker shots all keep +X as the attacker's right
			assert(shot.cam.X > 0, `shot at {shot.t} crosses the line`)
		end
	end,
}
