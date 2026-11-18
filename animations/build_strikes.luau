--!nocheck
-- Rebuilds the hook punches and the heavy kick in src/shared/Config/AnimClips.luau, with Lune
-- (there's no Python on every machine). Run from the project folder:
--   lune run animations/build_strikes
-- It ports the parts of animations/build_clips.py the swings need (the R6 joint maths, ArmPlacer,
-- lock_feet, the swing beats and the frame simplifier), so the two give the same kind of clip.
-- Only the clips named in CLIPS below are replaced; every other clip in AnimClips is left as it is.
-- WARNING: build_clips.py still has the old jab-like hooks (strike 0.08) and no HeavyKick. Running it
-- rewrites the whole of AnimClips, so run this script straight after it, or port these into it.

local fs = require("@lune/fs")

local FPS = 60
local GROUND = -3.0

-- ---- Matrices: a transform is { rotation rows, position }.
local function matMul(a, b)
	local out = {}
	for r = 1, 3 do
		out[r] = {}
		for c = 1, 3 do
			local sum = 0
			for k = 1, 3 do
				sum += a[r][k] * b[k][c]
			end
			out[r][c] = sum
		end
	end
	return out
end

local function matVec(a, v)
	local out = {}
	for r = 1, 3 do
		out[r] = a[r][1] * v[1] + a[r][2] * v[2] + a[r][3] * v[3]
	end
	return out
end

local function transpose(a)
	local out = {}
	for r = 1, 3 do
		out[r] = { a[1][r], a[2][r], a[3][r] }
	end
	return out
end

local function combine(a, b)
	local moved = matVec(a[1], b[2])
	return { matMul(a[1], b[1]), { a[2][1] + moved[1], a[2][2] + moved[2], a[2][3] + moved[3] } }
end

local function inverse(a)
	local back = transpose(a[1])
	local moved = matVec(back, a[2])
	return { back, { -moved[1], -moved[2], -moved[3] } }
end

local function angles(rx, ry, rz)
	local x, y, z = math.rad(rx), math.rad(ry), math.rad(rz)
	local cx, sx, cy, sy, cz, sz =
		math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	local mx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local my = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local mz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	return matMul(matMul(mx, my), mz)
end

local RIGHT = { { 0, 0, 1 }, { 0, 1, 0 }, { -1, 0, 0 } }
local LEFT = { { 0, 0, -1 }, { 0, 1, 0 }, { 1, 0, 0 } }
local UP = { { -1, 0, 0 }, { 0, 0, 1 }, { 0, 1, 0 } }
local JOINTS = {
	Torso = { UP, { 0, 0, 0 }, UP, { 0, 0, 0 } },
	Head = { UP, { 0, 1, 0 }, UP, { 0, -0.5, 0 } },
	["Right Arm"] = { RIGHT, { 1, 0.5, 0 }, RIGHT, { -0.5, 0.5, 0 } },
	["Left Arm"] = { LEFT, { -1, 0.5, 0 }, LEFT, { 0.5, 0.5, 0 } },
	["Right Leg"] = { RIGHT, { 1, -1, 0 }, RIGHT, { 0.5, 1, 0 } },
	["Left Leg"] = { LEFT, { -1, -1, 0 }, LEFT, { -0.5, 1, 0 } },
}
local LIMBS = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function partTransforms(pose)
	local function joint(name, parent)
		local j = JOINTS[name]
		local v = pose[name] or { 0, 0, 0, 0, 0, 0 }
		local transform = { angles(v[1], v[2], v[3]), { v[4], v[5], v[6] } }
		return combine(combine(combine(parent, { j[1], j[2] }), transform), inverse({ j[3], j[4] }))
	end
	local root = { { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, { 0, 0, 0 } }
	local torso = joint("Torso", root)
	local parts = { Torso = torso }
	for _, name in LIMBS do
		parts[name] = joint(name, torso)
	end
	return parts
end

local function lowestFoot(pose)
	local parts = partTransforms(pose)
	local lowest = 99
	for _, name in { "Right Leg", "Left Leg" } do
		local rot, pos = parts[name][1], parts[name][2]
		for _, dx in { -0.5, 0.5 } do
			for _, dz in { -0.5, 0.5 } do
				local corner = matVec(rot, { dx, -1, dz })
				lowest = math.min(lowest, pos[2] + corner[2])
			end
		end
	end
	return lowest
end

-- ---- Vectors.
local function norm(v)
	local size = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / size, v[2] / size, v[3] / size }
end

local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function add(a, b, scale)
	scale = scale or 1
	return { a[1] + b[1] * scale, a[2] + b[2] * scale, a[3] + b[3] * scale }
end

local function lerp(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function toEuler(rot)
	local ry = math.asin(math.clamp(rot[1][3], -1, 1))
	local rx = math.atan2(-rot[2][3], rot[3][3])
	local rz = math.atan2(-rot[1][2], rot[1][1])
	return math.deg(rx), math.deg(ry), math.deg(rz)
end

-- "Limb centre here, end pointing that way", in torso space, to a joint Transform.
local function newPlacer(jointName)
	local placer = { side = { 1, 0, 0 } }
	function placer.pose(centre, endDir)
		local j = JOINTS[jointName]
		local c0r, c0p, c1r, c1p = j[1], j[2], j[3], j[4]
		local down = norm(endDir)
		local up = { -down[1], -down[2], -down[3] }
		local side = norm(add(placer.side, up, -dot(placer.side, up)))
		placer.side = side
		local back = cross(side, up)
		local part = {
			{ side[1], up[1], back[1] },
			{ side[2], up[2], back[2] },
			{ side[3], up[3], back[3] },
		}
		local transform = matMul(matMul(transpose(c0r), part), c1r)
		local c1Inv = inverse({ c1r, c1p })
		local wanted =
			matVec(transpose(c0r), { centre[1] - c0p[1], centre[2] - c0p[2], centre[3] - c0p[3] })
		local moved = matVec(transform, c1Inv[2])
		local rx, ry, rz = toEuler(transform)
		return { rx, ry, rz, wanted[1] - moved[1], wanted[2] - moved[2], wanted[3] - moved[3] }
	end
	return placer
end

local SHOULDER = { ["Right Arm"] = { 1, 0.5, 0 }, ["Left Arm"] = { -1, 0.5, 0 } }
local HIP = { ["Right Leg"] = { 0.5, -1, 0 }, ["Left Leg"] = { -0.5, -1, 0 } }
local LEG_LENGTH = 2

local function easeInHard(t)
	return t * t * t
end
local function easeOut(t)
	return 1 - (1 - t) * (1 - t)
end
local function easeOutHard(t)
	local left = 1 - t
	return 1 - left * left * left
end
local function smooth(t)
	return t * t * (3 - 2 * t)
end

local function partFoot(pose, name)
	local p = partTransforms(pose)[name]
	return add(p[2], matVec(p[1], { 0, -1, 0 }))
end

local function clonePose(pose)
	local out = {}
	for k, v in pose do
		out[k] = table.clone(v)
	end
	return out
end

local function lockFeet(pose, feet, placers)
	local torso = table.clone(pose.Torso)
	for _ = 1, 3 do
		pose.Torso = table.clone(torso)
		local t = partTransforms({ Torso = pose.Torso }).Torso
		local back = transpose(t[1])
		for name, foot in feet do
			local localPos =
				matVec(back, { foot[1] - t[2][1], foot[2] - t[2][2], foot[3] - t[2][3] })
			local hip = HIP[name]
			local direction =
				norm({ localPos[1] - hip[1], localPos[2] - hip[2], localPos[3] - hip[3] })
			local centre = add(hip, direction, LEG_LENGTH / 2)
			pose[name] = placers[name].pose(centre, direction)
		end
		torso[6] += GROUND - lowestFoot(pose)
	end
	pose.Torso = table.clone(torso)
	return pose
end

-- ---- The stance and guard, as build_clips.py has them.
local GUARD = {
	["Right Arm"] = { { 0.8, 0.28, -0.8 }, { -0.14, 0.93, -0.34 } },
	["Left Arm"] = { { -0.72, 0.42, -1.12 }, { 0.14, 0.93, -0.34 } },
}
local STANCE_TURN = -12
local STANCE_DIP = 7
local SPRINT_LEAN = 38

local function baseStance()
	local pose = {
		Torso = { STANCE_DIP, 0, STANCE_TURN, 0, 0, 0 },
		["Right Leg"] = { 2, 0, -10 + STANCE_DIP, 0, 0, 0 },
		["Left Leg"] = { 2, 0, -(16 + STANCE_DIP), 0, 0, 0 },
	}
	pose.Torso[6] = GROUND - lowestFoot(pose)
	return pose
end
local STANCE_BASE = baseStance()
local STANCE_FEET = {
	["Right Leg"] = partFoot(STANCE_BASE, "Right Leg"),
	["Left Leg"] = partFoot(STANCE_BASE, "Left Leg"),
}
local STANCE_HEIGHT = STANCE_BASE.Torso[6]

-- ---- THE HOOKS. Each lands at Punch.Windup (0.16 s), when the server decides the hit, so the clip's
-- own lead-in IS the windup: the arm swings out wide to its own side and back (0 to HOLD_UNTIL, which is
-- also where a held punch waits), then whips round flat across the front, elbow high, into the target.
-- A hook is the fist coming in from the side on a level arc, not driven straight out like a jab.
local STRIKE = 0.16 -- Punch.Windup
local HOLD_UNTIL = 0.09 -- Punch.Windup - Punch.ReleaseWindup: where a held punch waits
local THROUGH_AT = 0.27
local HANG_FOR = 0.06
local SWING_SECONDS = 0.63
local BODY_LEADS = 1 / FPS
local HEAD_LAGS = 2 / FPS
local OFF_HAND_LAGS = 1 / FPS
local RUN_TURN_SHARE = 0.42
local RUN_TURN_MAX = 24
local RETURN_DROP = 0.3

local HOOK = {
	cocked = {
		sweep = 112,
		lift = 4,
		reach = 1.05,
		turn = -50,
		dip = 5,
		rise = -0.1,
		bank = 8,
		look = -4,
	},
	contact = {
		sweep = -18,
		lift = 6,
		reach = 1.3,
		turn = 34,
		dip = 9,
		rise = -0.04,
		bank = -4,
		pull = 0.6,
		look = 2,
	},
	through = {
		sweep = -84,
		lift = 4,
		reach = 1.1,
		turn = 62,
		dip = 12,
		rise = -0.12,
		bank = -10,
		pull = 1,
		look = 6,
	},
}

local function aim(sideSign, sweep, lift)
	local s, l = math.rad(sweep), math.rad(lift)
	return { sideSign * math.sin(s) * math.cos(l), math.sin(l), -math.cos(s) * math.cos(l) }
end

local function swingBeats(shape)
	local cocked = shape.cocked
	local pulled = table.clone(cocked)
	for key, share in { sweep = 1.08, turn = 1.1, dip = 1.08, lift = 1.05 } do
		if pulled[key] then
			pulled[key] = cocked[key] * share
		end
	end
	local through = shape.through
	local hangTo = THROUGH_AT + HANG_FOR
	local drifted = {}
	for key, value in through do
		drifted[key] = value
	end
	return {
		{
			0,
			HOLD_UNTIL,
			cocked,
			pulled,
			function(t)
				return easeOut(t)
			end,
		},
		{ HOLD_UNTIL, STRIKE, pulled, shape.contact, easeInHard },
		{ STRIKE, THROUGH_AT, shape.contact, through, easeOutHard },
		{
			THROUGH_AT,
			hangTo,
			through,
			drifted,
			function(t)
				return t
			end,
		},
		{ hangTo, SWING_SECONDS, drifted, nil, smooth },
	}
end

local function swingValues(beats, t)
	t = math.max(t, 0)
	for index, beat in beats do
		local start, finish, first, second, easing = beat[1], beat[2], beat[3], beat[4], beat[5]
		if t <= finish or index == #beats then
			local amount = easing(math.min((t - start) / (finish - start), 1))
			local values = {}
			local keys = {}
			for key in first do
				keys[key] = true
			end
			for key in second or {} do
				keys[key] = true
			end
			for key in keys do
				local a = first[key] or 0
				local b = if second then (second[key] or 0) else 0
				values[key] = a + (b - a) * amount
			end
			return values, first, second, amount
		end
	end
	error("no beat")
end

local function getOr(t, key)
	return t[key] or 0
end

local function bakeSwing(arm, shape, running)
	local other = if arm == "Right Arm" then "Left Arm" else "Right Arm"
	local sideSign = if arm == "Right Arm" then 1 else -1
	local placer, off = newPlacer(arm), newPlacer(other)
	local legs = { ["Right Leg"] = newPlacer("Right Leg"), ["Left Leg"] = newPlacer("Left Leg") }
	local guardCentre, guardDir = GUARD[arm][1], GUARD[arm][2]
	local offCentre, offDir = GUARD[other][1], GUARD[other][2]
	local beats = swingBeats(shape)
	local frames, turns = {}, {}
	local total = math.round(SWING_SECONDS * FPS)
	local timeSet = {}
	for index = 0, total do
		timeSet[math.round(index / FPS * 1e6) / 1e6] = true
	end
	timeSet[STRIKE] = true
	timeSet[HOLD_UNTIL] = true
	local times = {}
	for t in timeSet do
		table.insert(times, t)
	end
	table.sort(times)
	for _, t in times do
		local values, first, second, amount = swingValues(beats, t)
		local centre, direction
		if second then
			direction = aim(sideSign, values.sweep, values.lift)
			centre = add(SHOULDER[arm], direction, values.reach)
		else
			local startDir = aim(sideSign, first.sweep, first.lift)
			local startCentre = add(SHOULDER[arm], startDir, first.reach)
			centre = lerp(startCentre, guardCentre, amount)
			centre = add(centre, { 0, -RETURN_DROP * math.sin(math.pi * amount), 0 })
			direction = norm(lerp(startDir, guardDir, amount))
		end
		local body = swingValues(beats, math.min(t + BODY_LEADS, SWING_SECONDS))
		local late = swingValues(beats, math.max(t - HEAD_LAGS, 0))
		local hand = swingValues(beats, math.max(t - OFF_HAND_LAGS, 0))
		local twist = getOr(body, "turn") * sideSign
			+ STANCE_TURN * (1 - math.min(math.abs(getOr(body, "turn")) / 20, 1))
		local pull = getOr(hand, "pull")
		local pose = {
			[arm] = placer.pose(centre, direction),
			[other] = off.pose(add(offCentre, { 0, -0.4 * pull, 0.55 * pull }), offDir),
		}
		if running then
			local lateTurn = getOr(late, "turn") * sideSign
			pose.Head = {
				-SPRINT_LEAN * 0.74 - getOr(late, "look"),
				0,
				-lateTurn * RUN_TURN_SHARE * 0.6,
				0,
				0,
				0,
			}
			local turn = getOr(values, "turn") * sideSign * RUN_TURN_SHARE
			table.insert(turns, { t, math.clamp(turn, -RUN_TURN_MAX, RUN_TURN_MAX) })
		else
			local lean = STANCE_DIP + getOr(body, "dip")
			local lateLean = STANCE_DIP + getOr(late, "dip")
			local lateTwist = getOr(late, "turn") * sideSign
				+ STANCE_TURN * (1 - math.min(math.abs(getOr(late, "turn")) / 20, 1))
			pose.Torso = { lean, -getOr(body, "bank") * sideSign, twist, 0, 0, STANCE_HEIGHT }
			pose.Head = { -lateLean * 0.6 - getOr(late, "look"), 0, -lateTwist * 0.6, 0, 0, 0 }
			lockFeet(pose, STANCE_FEET, legs)
			pose.Torso[6] += getOr(values, "rise")
		end
		table.insert(frames, { t = t, pose = pose })
	end
	local clip = {
		loop = false,
		priority = "Action2",
		seconds = SWING_SECONDS,
		strike = STRIKE,
		hold = HOLD_UNTIL,
		frames = frames,
	}
	if running then
		clip.turn = turns
	end
	return clip
end

-- ---- THE HEAVY KICK. A short, plain telegraph: the body sinks and leans back, the kicking knee comes
-- up and the arms open, all held a moment so it reads from across the arena. Then the leg snaps up and
-- through, a rising kick that lifts whoever it meets, and the body rocks back into the stance. It
-- strikes at HeavyKick.Windup, when the server decides the hit. Legs are joint angles in "world" terms
-- (degrees forward of straight down, with the torso's lean taken back out), as build_clips.py does.
local KICK_STRIKE = 0.3 -- HeavyKick.Windup
local KICK_SECONDS = 0.8
local KICK_KEYS = {
	-- t, torso lean, torso turn, crouch, kick leg, standing leg, arms open (0 to 1)
	{ 0.0, STANCE_DIP, STANCE_TURN, 0, -10, 16, 0 },
	{ 0.12, -4, -26, -0.35, 55, 22, 0.7 },
	{ 0.24, -8, -30, -0.4, 62, 24, 1 }, -- the telegraph, held
	{ KICK_STRIKE, -22, 8, -0.1, 150, 10, 0.8 }, -- the strike: the leg's straight up in front
	{ 0.4, -26, 12, -0.05, 160, 8, 0.7 },
	{ 0.56, -6, 0, -0.2, 40, 14, 0.4 },
	{ KICK_SECONDS, STANCE_DIP, STANCE_TURN, 0, -10, 16, 0 },
}

local function kickAt(t)
	for index = 1, #KICK_KEYS - 1 do
		local a, b = KICK_KEYS[index], KICK_KEYS[index + 1]
		if t <= b[1] or index == #KICK_KEYS - 1 then
			local share = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
			-- Snap into the strike, ease everywhere else.
			share = if b[1] == KICK_STRIKE then easeInHard(share) else smooth(share)
			local out = {}
			for i = 2, 7 do
				out[i] = a[i] + (b[i] - a[i]) * share
			end
			return out
		end
	end
	error("no key")
end

local function bakeHeavyKick()
	local right, left = newPlacer("Right Arm"), newPlacer("Left Arm")
	local frames = {}
	local total = math.round(KICK_SECONDS * FPS)
	local timeSet = { [KICK_STRIKE] = true }
	for index = 0, total do
		timeSet[math.round(index / FPS * 1e6) / 1e6] = true
	end
	local times = {}
	for t in timeSet do
		table.insert(times, t)
	end
	table.sort(times)
	for _, t in times do
		local v = kickAt(t)
		local lean, turn, crouch, kickLeg, standLeg, open = v[2], v[3], v[4], v[5], v[6], v[7]
		local rightCentre = lerp(GUARD["Right Arm"][1], { 1.45, 0.35, 0.2 }, open)
		local leftCentre = lerp(GUARD["Left Arm"][1], { -1.4, 0.45, -0.6 }, open)
		local pose = {
			Torso = { lean, 0, turn, 0, 0, 0 },
			Head = { -lean * 0.6, 0, -turn * 0.6, 0, 0, 0 },
			["Right Arm"] = right.pose(
				rightCentre,
				norm(lerp(GUARD["Right Arm"][2], { 0.6, 0.6, 0.3 }, open))
			),
			["Left Arm"] = left.pose(
				leftCentre,
				norm(lerp(GUARD["Left Arm"][2], { -0.5, 0.7, -0.4 }, open))
			),
			["Right Leg"] = { 2, 0, kickLeg + lean, 0, 0, 0 },
			["Left Leg"] = { 2, 0, -(-standLeg + lean), 0, 0, 0 },
		}
		-- Stand on the planted (left) foot: the body sits so that foot is on the floor.
		local probe = clonePose(pose)
		probe["Right Leg"] = { 2, 0, -10 + lean, 0, 0, 0 }
		pose.Torso[6] = GROUND - lowestFoot(probe) + crouch
		table.insert(frames, { t = t, pose = pose })
	end
	return {
		loop = false,
		priority = "Action2",
		seconds = KICK_SECONDS,
		strike = KICK_STRIKE,
		frames = frames,
	}
end

-- ---- Fewer frames, same motion (build_clips.py's simplify). Keeps the strike and hold frames.
local SIMPLIFY_DEGREES = 0.6
local SIMPLIFY_STUDS = 0.01

local function simplify(clip)
	local frames = clip.frames
	if #frames < 3 then
		return clip
	end
	local keep = { [clip.strike or -1] = true, [clip.hold or -1] = true }
	local kept = { 1 }
	local index = 2
	while index < #frames do
		local reach = index
		while reach < #frames do
			local startIndex = kept[#kept]
			local start, candidate = frames[startIndex], frames[reach + 1]
			local fine = true
			for m = startIndex + 1, reach do
				local middle = frames[m]
				if keep[middle.t] then
					fine = false
					break
				end
				local share = (middle.t - start.t) / (candidate.t - start.t)
				for joint, values in middle.pose do
					for i = 1, 6 do
						local a, b = start.pose[joint][i], candidate.pose[joint][i]
						local allowed = if i <= 3 then SIMPLIFY_DEGREES else SIMPLIFY_STUDS
						if
							math.abs(a + (b - a) * share - values[i]) > allowed
							or (i <= 3 and math.abs(b - a) > 70)
						then
							fine = false
							break
						end
					end
					if not fine then
						break
					end
				end
				if not fine then
					break
				end
			end
			if not fine then
				break
			end
			reach += 1
		end
		table.insert(kept, math.max(reach, index))
		index = kept[#kept] + 1
	end
	if kept[#kept] ~= #frames then
		table.insert(kept, #frames)
	end
	local out = {}
	for _, i in kept do
		table.insert(out, frames[i])
	end
	clip.frames = out
	return clip
end

-- ---- Writing them into AnimClips.luau.
local ORDER = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local function num(v, places)
	local s = string.format(`%.{places}f`, v)
	if s:match("^%-0%.?0*$") then
		s = s:sub(2)
	end
	return s
end

local function clipSource(name, clip)
	local lines = {
		`\t{name} = \{`,
		`\t\tloop = {if clip.loop then "true" else "false"},`,
		`\t\tpriority = "{clip.priority}",`,
		`\t\tseconds = {clip.seconds},`,
	}
	if clip.strike then
		table.insert(lines, `\t\tstrike = {clip.strike},`)
	end
	if clip.hold then
		table.insert(lines, `\t\thold = {clip.hold},`)
	end
	if clip.turn then
		local parts = {}
		for _, pair in clip.turn do
			table.insert(parts, `\{ {num(pair[1], 3)}, {num(pair[2], 1)} \}`)
		end
		table.insert(lines, `\t\tturn = \{ {table.concat(parts, ", ")} \},`)
	end
	table.insert(lines, "\t\tframes = {")
	for _, frame in clip.frames do
		local parts = {}
		for _, joint in ORDER do
			local values = frame.pose[joint]
			if values then
				local numbers = {}
				for i = 1, 6 do
					numbers[i] = num(values[i], 3)
				end
				table.insert(parts, `["{joint}"] = \{ {table.concat(numbers, ", ")} \}`)
			end
		end
		table.insert(
			lines,
			`\t\t\t\{ t = {num(frame.t, 4)}, pose = \{ {table.concat(parts, ", ")} \} \},`
		)
	end
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t},")
	return table.concat(lines, "\n")
end

-- ---- THE ULTIMATE'S UPWARD PUNCHES (kits-7d, 2026-11-17). The user, on the hook juggle: "they look like youre
-- slapping them rather than an actual punch barrage ... the barrage should be facing upwards right?" and "same
-- with the last punch, should be punching them up and away" (Garou vs Stinger 7.5-9.4 s: the one being juggled is
-- above the striker). Built from keys: each arm is either in its guard or AIMED (sweep, lift, reach, like the
-- hooks' beats), blended centre-and-direction between keys, the feet locked like every swing here. They go to
-- their own module (AnimClips is at Studio's size limit).
local function armAt(arm, spec)
	if spec.guard then
		return GUARD[arm][1], norm(GUARD[arm][2])
	end
	local sideSign = if arm == "Right Arm" then 1 else -1
	local direction = aim(sideSign, spec.sweep, spec.lift)
	return add(SHOULDER[arm], direction, spec.reach), direction
end

local EASINGS = {
	smooth = smooth,
	snap = easeInHard,
	out = easeOut,
	outHard = easeOutHard,
}

-- keys: { t, ease (into this key), right, left, lean, turn, crouch, look }; feet: where they stay planted.
local function bakeKeyed(keys, seconds, meta, feet)
	local right, left = newPlacer("Right Arm"), newPlacer("Left Arm")
	local legs = { ["Right Leg"] = newPlacer("Right Leg"), ["Left Leg"] = newPlacer("Left Leg") }
	local timeSet = {}
	for index = 0, math.round(seconds * FPS) do
		timeSet[math.round(index / FPS * 1e6) / 1e6] = true
	end
	for _, key in keys do
		timeSet[key.t] = true
	end
	local times = {}
	for t in timeSet do
		table.insert(times, t)
	end
	table.sort(times)
	local frames = {}
	for _, t in times do
		local a, b = keys[1], keys[#keys]
		for index = 1, #keys - 1 do
			if t <= keys[index + 1].t then
				a, b = keys[index], keys[index + 1]
				break
			end
		end
		local share = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 1
		share = EASINGS[b.ease or "smooth"](share)
		local function blendArm(arm, placer)
			local ca, da = armAt(arm, a[if arm == "Right Arm" then "right" else "left"])
			local cb, db = armAt(arm, b[if arm == "Right Arm" then "right" else "left"])
			return placer.pose(lerp(ca, cb, share), norm(lerp(da, db, share)))
		end
		local function mix(key)
			return (a[key] or 0) + ((b[key] or 0) - (a[key] or 0)) * share
		end
		local lean, turn = mix("lean"), mix("turn")
		local pose = {
			Torso = { lean, 0, turn, 0, 0, STANCE_HEIGHT },
			Head = { -lean * 0.6 - mix("look"), 0, -turn * 0.6, 0, 0, 0 },
			["Right Arm"] = blendArm("Right Arm", right),
			["Left Arm"] = blendArm("Left Arm", left),
		}
		-- a key may carry its own feet (kits-7j: a stride, a tuck in the air), blended like everything else
		local feetA, feetB = a.feet or feet, b.feet or feet
		local blendedFeet = {}
		for name, at in feetA do
			blendedFeet[name] = lerp(at, feetB[name] or at, share)
		end
		lockFeet(pose, blendedFeet, legs)
		pose.Torso[6] += mix("crouch")
		table.insert(frames, { t = t, pose = pose })
	end
	local clip = { loop = meta.loop, priority = meta.priority, seconds = seconds, frames = frames }
	clip.strike = meta.strike
	clip.hold = meta.hold
	return clip
end

-- A wider stance for both (the striker plants and drives up): each foot half a stud further out.
local WIDE_FEET = {
	["Right Leg"] = add(STANCE_FEET["Right Leg"], { 0.5, 0, 0 }),
	["Left Leg"] = add(STANCE_FEET["Left Leg"], { -0.5, 0, 0 }),
}
-- The flurry's stance (kits-7k, Garou vs Stinger 7.5-9.4 s: the striker plants a WIDE, LOW horse stance and punches
-- up from it): each foot a stud further out than the guard, and the body sat lower (FLURRY_SIT).
local FLURRY_FEET = {
	["Right Leg"] = add(STANCE_FEET["Right Leg"], { 1.0, 0, 0 }),
	["Left Leg"] = add(STANCE_FEET["Left Leg"], { -1.0, 0, 0 }),
}
local FLURRY_SIT = -0.3

-- BarrageUp: a 0.25 s loop, a punch every 0.125 s. Each arm fires from its guard up and forward at 50 degrees
-- (aimed a little inward, at the one above them), snaps back; right lands at 0.0625, left at 0.1875. The body
-- leans back to look up and twists into each punch.
local GUARDED = { guard = true }
-- BarrageUp v2 (kits-7h, stage B of design/haymaker-rush-v4-gaps.md; vault: Anime Fight Animation - What the
-- References Do and Where Haymaker Rush Falls Short). The gap study: the old loop was ONE punch mirrored (2 poses),
-- out 0.0625 s and back 0.0625 s, the body almost still (twist +/-14, lean change 2 deg); the references draw 4-17
-- different pushed poses, the body throwing every blow, the contact HELD and the retract barely shown (Jotaro,
-- Tanktop, Garou vs Stinger). Now a 1.0 s loop of 8 DIFFERENT punches, still one every 0.125 s: for each, a chamber
-- key, the contact 0.03 s later (snapped), held 0.04 s, then 0.055 s back into the next punch's chamber. The body
-- leans, twists and drops into each one; the feet stay planted (Garou vs Stinger: 17 frames, the feet never move).
-- { arm, chamber spec (nil = from the guard), contact spec, lean, turn, crouch at the chamber, crouch at contact }
local FLURRY_PUNCHES = {
	{ "R", nil, { sweep = -8, lift = 52, reach = 1.35 }, -14, 35, -0.3, -0.3 }, -- straight up
	{
		"L",
		{ sweep = 70, lift = 0, reach = 1.0 },
		{ sweep = -20, lift = 35, reach = 1.2 },
		-6,
		-40,
		-0.2,
		-0.2,
	}, -- rising hook
	{
		"R",
		{ sweep = 10, lift = -50, reach = 0.9 },
		{ sweep = -5, lift = 75, reach = 1.25 },
		-22,
		25,
		-0.45,
		-0.1,
	}, -- uppercut
	{ "L", nil, { sweep = -10, lift = 45, reach = 1.35 }, -10, -35, -0.25, -0.25 }, -- straight
	{
		"R",
		{ sweep = 40, lift = 80, reach = 1.0 },
		{ sweep = -25, lift = 40, reach = 1.3 },
		5,
		45,
		-0.35,
		-0.35,
	}, -- overhand
	{ "L", nil, { sweep = -5, lift = 30, reach = 1.1 }, -4, -20, -0.15, -0.15 }, -- short jab
	{
		"R",
		{ sweep = 70, lift = 0, reach = 1.0 },
		{ sweep = -20, lift = 35, reach = 1.2 },
		-8,
		40,
		-0.2,
		-0.2,
	}, -- rising hook
	{
		"L",
		{ sweep = 10, lift = -50, reach = 0.9 },
		{ sweep = -5, lift = 75, reach = 1.25 },
		-22,
		-25,
		-0.45,
		-0.1,
	}, -- uppercut
}
local FLURRY_STEP = 0.125
local FLURRY_CONTACT = 0.03 -- the strike: chamber to contact
local FLURRY_HOLD = 0.04 -- the contact held
local BARRAGE_UP_KEYS = {}
local function flurryChamber(index: number, t: number)
	local punch = FLURRY_PUNCHES[index]
	local right = if punch[1] == "R" then (punch[2] or GUARDED) else GUARDED
	local left = if punch[1] == "L" then (punch[2] or GUARDED) else GUARDED
	-- wound the other way a little before it fires
	return {
		t = t,
		ease = "smooth",
		right = right,
		left = left,
		lean = punch[4] * 0.5,
		turn = -punch[5] * 0.3,
		crouch = punch[6] + FLURRY_SIT,
		look = 10,
	}
end
for index, punch in FLURRY_PUNCHES do
	local s = (index - 1) * FLURRY_STEP
	table.insert(BARRAGE_UP_KEYS, flurryChamber(index, s))
	local right = if punch[1] == "R" then punch[3] else GUARDED
	local left = if punch[1] == "L" then punch[3] else GUARDED
	table.insert(BARRAGE_UP_KEYS, {
		t = s + FLURRY_CONTACT,
		ease = "outHard",
		right = right,
		left = left,
		lean = punch[4],
		turn = punch[5],
		crouch = punch[7] + FLURRY_SIT,
		look = 14,
	})
	-- the held contact: a hair further through
	table.insert(BARRAGE_UP_KEYS, {
		t = s + FLURRY_CONTACT + FLURRY_HOLD,
		ease = "smooth",
		right = right,
		left = left,
		lean = punch[4] - 2,
		turn = punch[5] * 1.1,
		crouch = punch[7] + FLURRY_SIT,
		look = 14,
	})
end
-- back to the first chamber, so the loop joins
table.insert(BARRAGE_UP_KEYS, flurryChamber(1, #FLURRY_PUNCHES * FLURRY_STEP))

-- HaymakerUp: wound up deep (held at 0.25: the right fist low behind the hip, crouched, twisted away, the left
-- hand out in front), then a rising straight right up and away at 55 degrees (strikes at 0.32, 0.07 s after the
-- hold, as the timeline lets it go), the body uncoiling and leaning back into it, then settling.
-- kits-7j (stage B pass 3, the gap study B9-B11): the coil pushed deeper (turn -42 -> -70, leaning in, crouched,
-- looking up at them) and a DRIVEN follow-through, the arm held out up and away with the body leaning back into it
-- for 0.3 s (Tanktop 22.25-22.67) before it settles. It is thrown in the air, so the legs are an air pose (lead knee
-- up, the other trailing), not feet locked as if standing.
local AIR_FEET = {
	["Right Leg"] = { 0.55, -1.9, -1.3 }, -- the lead knee up
	["Left Leg"] = { -0.55, -2.8, 0.9 }, -- trailing
}
local HAYMAKER_UP_KEYS = {
	{ t = 0, right = GUARDED, left = GUARDED, lean = STANCE_DIP, turn = STANCE_TURN },
	{
		t = 0.25,
		ease = "smooth",
		right = { sweep = 150, lift = -40, reach = 1.0 },
		left = { sweep = -10, lift = 30, reach = 1.1 },
		lean = 15,
		turn = -70,
		crouch = -0.5,
		look = 20,
	},
	{
		t = 0.32,
		ease = "snap",
		right = { sweep = -8, lift = 55, reach = 1.35 },
		left = GUARDED,
		lean = -14,
		turn = 30,
		crouch = -0.05,
		look = 14,
	},
	{
		t = 0.45,
		ease = "outHard",
		right = { sweep = -10, lift = 68, reach = 1.35 },
		left = { sweep = 40, lift = -20, reach = 1.0 },
		lean = -24,
		turn = 45,
		crouch = 0,
		look = 16,
	},
	{
		t = 0.75,
		ease = "smooth",
		right = { sweep = -10, lift = 70, reach = 1.35 },
		left = { sweep = 45, lift = -25, reach = 1.0 },
		lean = -30,
		turn = 50,
		crouch = 0,
		look = 18,
	},
	{
		t = 1.0,
		ease = "smooth",
		right = GUARDED,
		left = GUARDED,
		lean = STANCE_DIP,
		turn = STANCE_TURN,
	},
}

-- RushIn (kits-7j, B8 + B13): the lock-in, then the rush. The gap study: no reference shows a run cycle; speed comes
-- from a launch pose and a held, stretched stride (Acheron, Azure, Human Battery), and ours rose upright for 3
-- frames and ran a cycle. 0-0.36 the lock-in: right fist cocked at the shoulder, body turned away; 0.40-0.48 the
-- LAUNCH CROUCH (low, leaning in, rear leg driving back); then one stretched stride, held, the arms pumped; the
-- hook (a swing on top) takes the arms over at 0.98 and the legs plant at 1.14.
local RUSH_STRIDE_FEET = {
	["Right Leg"] = { 0.5, GROUND + 0.6, 2.0 }, -- driving back
	["Left Leg"] = { -0.5, GROUND + 0.5, -1.7 }, -- reaching forward
}
local RUSH_LAUNCH_FEET = {
	["Right Leg"] = { 0.55, GROUND, 1.9 },
	["Left Leg"] = { -0.55, GROUND, -0.5 },
}
local COCKED = { sweep = 120, lift = 15, reach = 0.85 }
local RUSH_IN_KEYS = {
	{ t = 0, right = COCKED, left = GUARDED, lean = 6, turn = -30, crouch = -0.15, look = 4 },
	{
		t = 0.36,
		ease = "smooth",
		right = COCKED,
		left = GUARDED,
		lean = 8,
		turn = -36,
		crouch = -0.2,
		look = 6,
	},
	{
		t = 0.48,
		ease = "out",
		right = { sweep = 40, lift = -35, reach = 1.0 },
		left = { sweep = -15, lift = -15, reach = 1.0 },
		lean = 50,
		turn = -10,
		crouch = -0.55,
		look = -20,
		feet = RUSH_LAUNCH_FEET,
	},
	{
		t = 0.58,
		ease = "outHard",
		right = { sweep = 30, lift = -45, reach = 1.0 },
		left = { sweep = -10, lift = 15, reach = 1.0 },
		lean = 38,
		turn = 8,
		crouch = -0.3,
		look = -15,
		feet = RUSH_STRIDE_FEET,
	},
	{
		t = 0.98,
		ease = "smooth",
		right = { sweep = 30, lift = -40, reach = 1.0 },
		left = { sweep = -10, lift = 20, reach = 1.0 },
		lean = 34,
		turn = 10,
		crouch = -0.3,
		look = -12,
		feet = RUSH_STRIDE_FEET,
	},
	{
		t = 1.14,
		ease = "out",
		right = GUARDED,
		left = GUARDED,
		lean = 15,
		turn = 0,
		crouch = -0.3,
		look = 0,
	},
}

-- UpperSet (kits-7j, B11): the deep crouch in the set before the uppercut: low, leaning in over the front knee, the
-- right fist dropped to knee height; the Uppercut swing rises out of it.
local UPPER_SET_KEYS = {
	{ t = 0, right = GUARDED, left = GUARDED, lean = 10, turn = 0, crouch = -0.2 },
	{
		t = 0.12,
		ease = "out",
		right = { sweep = 15, lift = -70, reach = 0.95 },
		left = { sweep = -10, lift = 20, reach = 1.0 },
		lean = 45,
		turn = -25,
		crouch = -0.6,
		look = 25,
	},
	{
		t = 0.3,
		ease = "smooth",
		right = { sweep = 15, lift = -72, reach = 0.95 },
		left = { sweep = -10, lift = 22, reach = 1.0 },
		lean = 47,
		turn = -28,
		crouch = -0.62,
		look = 26,
	},
}

-- Dangle (kits-7m, the owner: "the torso should be facing the players fists, and the arms and legs and head should be
-- dangling just like in the garou clip"): the TARGET's limp pose through the juggle. The timeline pitches the body
-- forward ~32 deg over the fists (targetTilt), so "hanging straight down" is down-and-forward in the body's own
-- frame: arms and legs aimed 55 deg below level, toward the front, the head dropped; a slow sway, never posed.
local DANGLE_ARM = { sweep = 12, lift = -55, reach = 1.0 }
local DANGLE_FEET = {
	["Right Leg"] = { 0.55, -2.64, -1.15 },
	["Left Leg"] = { -0.45, -2.6, -1.25 },
}
local DANGLE_SWAY_FEET = {
	["Right Leg"] = { 0.45, -2.6, -1.25 },
	["Left Leg"] = { -0.55, -2.64, -1.1 },
}
local DANGLE_KEYS = {
	{
		t = 0,
		right = DANGLE_ARM,
		left = DANGLE_ARM,
		lean = 0,
		turn = 0,
		crouch = 0,
		look = -25,
		feet = DANGLE_FEET,
	},
	{
		t = 0.3,
		ease = "smooth",
		right = { sweep = 18, lift = -62, reach = 1.0 },
		left = { sweep = 6, lift = -50, reach = 1.0 },
		lean = 0,
		turn = 4,
		crouch = 0,
		look = -30,
		feet = DANGLE_SWAY_FEET,
	},
	{
		t = 0.6,
		ease = "smooth",
		right = DANGLE_ARM,
		left = DANGLE_ARM,
		lean = 0,
		turn = 0,
		crouch = 0,
		look = -25,
		feet = DANGLE_FEET,
	},
}

-- LeapUp (kits-7j, B10): the leap after them: a crouch, a 2-frame extension, then a tuck (knees up) in the air.
local LEAP_UP_KEYS = {
	{ t = 0, right = GUARDED, left = GUARDED, lean = 25, turn = 0, crouch = -0.6, look = 30 },
	{
		t = 0.08,
		ease = "snap",
		right = { sweep = -10, lift = 70, reach = 1.2 },
		left = { sweep = -10, lift = 60, reach = 1.1 },
		lean = -8,
		turn = 10,
		crouch = 0.1,
		look = 35,
		feet = {
			["Right Leg"] = { 0.5, GROUND - 0.1, 0.4 },
			["Left Leg"] = { -0.5, GROUND - 0.1, 0.6 },
		},
	},
	{
		t = 0.22,
		ease = "out",
		right = GUARDED,
		left = { sweep = -10, lift = 30, reach = 1.1 },
		lean = 10,
		turn = -20,
		crouch = 0,
		look = 30,
		feet = { ["Right Leg"] = { 0.55, -1.7, -1.5 }, ["Left Leg"] = { -0.55, -2.0, -1.0 } },
	},
	{
		t = 0.3,
		ease = "smooth",
		right = GUARDED,
		left = { sweep = -10, lift = 30, reach = 1.1 },
		lean = 10,
		turn = -22,
		crouch = 0,
		look = 30,
		feet = { ["Right Leg"] = { 0.55, -1.7, -1.5 }, ["Left Leg"] = { -0.55, -2.0, -1.0 } },
	},
}

local ULTIMATE_CLIPS = {
	BarrageUp = simplify(
		bakeKeyed(
			BARRAGE_UP_KEYS,
			#FLURRY_PUNCHES * FLURRY_STEP,
			{ loop = true, priority = "Action2", strike = FLURRY_CONTACT },
			FLURRY_FEET
		)
	),
	HaymakerUp = simplify(
		bakeKeyed(
			HAYMAKER_UP_KEYS,
			1.0,
			{ loop = false, priority = "Action2", strike = 0.32, hold = 0.25 },
			AIR_FEET
		)
	),
	-- the attacker's whole-body poses on the ultimate's timeline (Ultimates `clips`, AnimController.PlayClip): each
	-- plays once and holds its last frame until the next one
	RushIn = simplify(
		bakeKeyed(RUSH_IN_KEYS, 1.14, { loop = false, priority = "Action" }, STANCE_FEET)
	),
	UpperSet = simplify(
		bakeKeyed(UPPER_SET_KEYS, 0.3, { loop = false, priority = "Action" }, WIDE_FEET)
	),
	LeapUp = simplify(
		bakeKeyed(LEAP_UP_KEYS, 0.3, { loop = false, priority = "Action" }, STANCE_FEET)
	),
	Dangle = simplify(
		bakeKeyed(DANGLE_KEYS, 0.6, { loop = true, priority = "Action" }, DANGLE_FEET)
	),
}

local CLIPS = {
	HookLeft = simplify(bakeSwing("Left Arm", HOOK, false)),
	HookRight = simplify(bakeSwing("Right Arm", HOOK, false)),
	HookLeftRun = simplify(bakeSwing("Left Arm", HOOK, true)),
	HookRightRun = simplify(bakeSwing("Right Arm", HOOK, true)),
	HeavyKick = simplify(bakeHeavyKick()),
}

local PATH = "src/shared/Config/AnimClips.luau"
local source = fs.readFile(PATH)
for name, clip in CLIPS do
	local block = clipSource(name, clip)
	local startAt = source:find(`\n\t{name} = \{\n`, 1, true)
	if startAt then
		local endAt = source:find("\n\t},\n", startAt + 1, true)
		source = source:sub(1, startAt) .. block .. source:sub(endAt + 4)
	else
		-- A new clip goes just before the closing brace.
		local closeAt = source:find("\n}\n?$")
		source = source:sub(1, closeAt) .. block .. source:sub(closeAt)
	end
	print(name, "frames", #clip.frames, "seconds", clip.seconds)
end
assert(#source < 185000, `AnimClips is {#source} characters, over Studio's safe limit`)
fs.writeFile(PATH, source)
print("AnimClips characters", #source)

-- The ultimate's clips, in their own module (merged with AnimClips by AnimController).
local ultimate = {
	"--!strict",
	"-- GENERATED FILE - DO NOT EDIT BY HAND. Source: animations/build_strikes.luau (lune run animations/build_strikes).",
	"-- The ultimate's own clips (kits-7d): the upward barrage loop and the rising haymaker. Same format as",
	"-- Config/AnimClips, kept apart because AnimClips is at Studio's size limit; AnimController merges the two.",
	"return {",
}
local names = {}
for name in ULTIMATE_CLIPS do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	table.insert(ultimate, clipSource(name, ULTIMATE_CLIPS[name]))
	print(name, "frames", #ULTIMATE_CLIPS[name].frames, "seconds", ULTIMATE_CLIPS[name].seconds)
end
table.insert(ultimate, "}")
fs.writeFile("src/shared/Config/AnimClipsUltimate.luau", table.concat(ultimate, "\n") .. "\n")
