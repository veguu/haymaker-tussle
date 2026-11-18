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

-- HaymakerUp: the leap AND the haymaker in one clip, so nothing else fights it for the body (kits-8a).
-- kits-8c, measured against the references (design/cutscene-study/12a, 12b; the owner: "the leap + dash have really
-- weak impact, doesnt feel strong at all and feels like you just glide over"): the WAITING comes before the dash, in a
-- coil that is deepest on its last frame (Azure 4.83-5.07, 0.23 s); the dash itself is short (Azure and Strongest
-- Battlegrounds: 0.23 s) and hits on arrival; the strike is visibly LOADED and released in 1-3 frames (Mumen Rider's
-- hand raised by the head, then the arm to horizontal in 2-3 frames; Serious Punch's fist cocked through the hold).
-- kits-8a's load kept the arm aimed at the target, drawn back along itself, and on screen it read as already thrown.
-- The clip runs on the timeline's clock 1:1 (Ultimates: LOAD is clip 0, TAKEOFF clip 0.30, the hit clip 0.45):
--   0.00-0.30  the coil: crouching, turning away, the right fist cocked up and back by the ear, deepest at 0.30
--   0.30-0.34  the take-off: the legs drive out (2 frames)
--   0.34-0.38  the dive pose (the hold point), the fist still cocked; held through the dash
--   0.38-0.45  the strike: the arm snaps from cocked to aimed at them while the torso turns 65 deg into it (0.07 s)
--   0.45-0.88  the driven follow-through (Tanktop 22.25-22.67), then it settles
local AIR_FEET = {
	["Right Leg"] = { 0.55, -1.9, -1.3 }, -- the lead knee up
	["Left Leg"] = { -0.55, -2.8, 0.9 }, -- trailing
}
local LOAD_FEET = {
	["Right Leg"] = { 0.6, GROUND, 0.9 }, -- the rear leg, ready to drive
	["Left Leg"] = { -0.6, GROUND, -0.9 },
}
local TAKEOFF_FEET = {
	["Right Leg"] = { 0.5, GROUND - 0.2, 1.5 }, -- extended back, toes last off the floor
	["Left Leg"] = { -0.5, -2.2, -0.6 }, -- the lead knee coming up
}
-- An arm's aim is in the torso's frame: a turn of -45 faces the torso 45 deg to its right (measured with
-- tests/support/Rig), so to keep a world aim the sweep follows the turn and the lift adds the lean.
local HAY_TURN_LOADED = -45
local HAY_TURN_STRUCK = 20
local HAY_UP = 28
local HAY_LEAN_LOADED = 35
local HAY_LEAN_STRUCK = 22
local HAY_INWARD = 18 -- a straight right aims at their middle: the fist crosses to the centreline at full reach
-- cocked: the fist up and back by the ear (solved on the Rig for the loaded torso: world aim about (0.2, 0.87, 0.43))
local COCKED_UP = { sweep = 122, lift = 28, reach = 0.65 }
local STRUCK = { sweep = HAY_TURN_STRUCK - HAY_INWARD, lift = HAY_UP + HAY_LEAN_STRUCK, reach = 1.45 }
local SIGHT = { sweep = -HAY_TURN_LOADED, lift = 25 + HAY_LEAN_LOADED, reach = 1.15 } -- the left hand out at them
local HAYMAKER_UP_KEYS = {
	{ t = 0, right = GUARDED, left = GUARDED, lean = STANCE_DIP, turn = STANCE_TURN, feet = STANCE_FEET },
	{
		t = 0.18,
		ease = "out",
		right = COCKED_UP,
		left = SIGHT,
		lean = HAY_LEAN_LOADED - 5,
		turn = HAY_TURN_LOADED + 10,
		crouch = -0.45,
		look = -10,
		feet = LOAD_FEET,
	},
	{
		-- deepest on the last frame before it goes
		t = 0.3,
		ease = "smooth",
		right = COCKED_UP,
		left = SIGHT,
		lean = HAY_LEAN_LOADED,
		turn = HAY_TURN_LOADED,
		crouch = -0.65,
		look = -12,
		feet = LOAD_FEET,
	},
	{
		t = 0.34,
		ease = "snap",
		right = COCKED_UP,
		left = SIGHT,
		lean = HAY_LEAN_LOADED,
		turn = HAY_TURN_LOADED,
		crouch = 0.1,
		look = -15,
		feet = TAKEOFF_FEET,
	},
	{
		t = 0.38,
		ease = "out",
		right = COCKED_UP,
		left = SIGHT,
		lean = HAY_LEAN_LOADED,
		turn = HAY_TURN_LOADED,
		crouch = 0,
		look = -15,
		feet = AIR_FEET,
	},
	{
		t = 0.45,
		ease = "snap",
		right = STRUCK,
		left = { sweep = 160, lift = -30, reach = 0.9 }, -- yanked back by the side as the right goes
		lean = HAY_LEAN_STRUCK,
		turn = HAY_TURN_STRUCK,
		crouch = 0,
		look = -8,
		feet = AIR_FEET,
	},
	{
		t = 0.58,
		ease = "outHard",
		right = { sweep = 30 - HAY_INWARD, lift = HAY_UP + 4 + 18, reach = 1.5 },
		left = { sweep = 160, lift = -32, reach = 0.9 },
		lean = 18,
		turn = 30,
		crouch = 0,
		look = -6,
		feet = AIR_FEET,
	},
	{
		t = 0.88,
		ease = "smooth",
		right = { sweep = 32 - HAY_INWARD, lift = HAY_UP + 6 + 15, reach = 1.5 },
		left = { sweep = 160, lift = -32, reach = 0.9 },
		lean = 15,
		turn = 32,
		crouch = 0,
		look = -4,
		feet = AIR_FEET,
	},
	{
		t = 1.1,
		ease = "smooth",
		right = GUARDED,
		left = GUARDED,
		lean = STANCE_DIP,
		turn = STANCE_TURN,
		feet = AIR_FEET,
	},
}

-- RushIn (kits-7j, B8 + B13): the lock-in, then the launch. 0-0.36 the lock-in: right fist cocked at the shoulder,
-- body turned away; 0.40-0.48 the LAUNCH CROUCH (low, leaning in, rear leg driving back). kits-7j's held stride
-- (the gap study's "no reference shows a run cycle") read as a statue sliding at 0.58 s of travel; the 10-reference
-- study found the held pose works only for 4-6 frame dashes (Azure, Garou vs Stinger, Acheron), and Human Battery F3's
-- 40-frame dash strides. So the travel is RushRun over the Sprint cycle (below).
local RUSH_LAUNCH_FEET = {
	["Right Leg"] = { 0.55, GROUND, 1.9 },
	["Left Leg"] = { -0.55, GROUND, -0.5 },
}
local COCKED = { sweep = 120, lift = 15, reach = 0.85 }
-- kits-8a (the owner: "the opening rush animation looks strange and does not read clearly as a rush"; measured: one
-- held stride slid ~10 studs with the feet still, a statue skating, filmed from straight behind so the lean was lost):
-- RushIn is now only the lock-in and the launch crouch (the fist stays cocked, no arm swing), and RushRun takes the
-- travel: ARMS AND HEAD ONLY (the way the hooks' Run variants are), so the real Sprint cycle shows under it, legs
-- striding and the torso pitched 40 deg, the right fist loaded at the shoulder for the hook (Human Battery F3
-- 17.43-18.10: "torso pitched forward, legs striding, fist cocked at the chest") and the left hand reaching ahead.
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
		right = { sweep = 158, lift = -65, reach = 0.8 }, -- drawn back, as RushRun carries it
		left = { sweep = -15, lift = 10, reach = 1.05 },
		lean = 45,
		turn = -20,
		crouch = -0.55,
		look = 8, -- the head comes up: eyes on the target over the low lean
		feet = RUSH_LAUNCH_FEET,
	},
}
-- the right fist drawn back by the hip, the arm along the leaning body (kits-8a recording: sweep 120, lift 25 stuck the
-- arm out sideways and up over the Sprint torso, which read as waving; solved with tests/support/Rig: this points back
-- and a little down in the world)
local RUN_COCKED = { sweep = 158, lift = -67, reach = 0.8 }
local RUSH_RUN_KEYS = {
	{ t = 0, right = RUN_COCKED, left = { sweep = -15, lift = 35, reach = 1.05 }, lean = 40, look = 6 },
	{
		t = 0.16,
		ease = "smooth",
		right = { sweep = 155, lift = -62, reach = 0.8 },
		left = { sweep = -12, lift = 45, reach = 1.1 },
		lean = 40,
		look = 6,
	},
	{
		t = 0.32,
		ease = "smooth",
		right = RUN_COCKED,
		left = { sweep = -18, lift = 32, reach = 1.05 },
		lean = 40,
		look = 6,
	},
	{
		t = 0.5,
		ease = "smooth",
		-- into the hook's cocked shape (HOOK.cocked), so the swing taking the arm over at 0.5 doesn't pop
		right = { sweep = 112, lift = 6, reach = 1.0 },
		left = { sweep = -12, lift = 42, reach = 1.1 },
		lean = 40,
		look = 6,
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

-- Fold (kits-8a): the TARGET's pose on the uppercut and the haymaker, from the contact on. The owner: "the target's
-- torso still does not face the player's fist at the moment of impact" (measured: the heavy flinch turned the chest
-- ~30 deg away and up on the contact frame). Every reference folds the one hit ONTO the fist, belly to it, limbs
-- thrown forward past it: Garou vs Stinger 7.27-8.95 ("folded around them"), Mumen Rider hit 1 ("doubles forward over
-- the fist"), Tanktop at the wall ("folded forward over the attacker's arm"). The torso pitched forward over the hips,
-- the legs and arms flung forward, the head dropped; the timeline's tilt then aims the whole C at the fist. A pose
-- clip on the target also keeps AnimController's flinch off it (kits-7m rule), so nothing turns it on the hit.
local FOLD_FEET = {
	["Right Leg"] = { 0.5, -2.3, -1.5 },
	["Left Leg"] = { -0.5, -2.4, -1.3 },
}
local FOLD_KEYS = {
	{
		t = 0,
		right = { sweep = 22, lift = -25, reach = 1.0 },
		left = { sweep = 18, lift = -30, reach = 1.0 },
		lean = 28,
		turn = 0,
		crouch = 0,
		look = -30,
		feet = FOLD_FEET,
	},
	{
		-- the C closes round the fist a little more as it drives in
		t = 0.25,
		ease = "out",
		right = { sweep = 26, lift = -35, reach = 1.0 },
		left = { sweep = 22, lift = -38, reach = 1.0 },
		lean = 34,
		turn = 2,
		crouch = 0,
		look = -34,
		feet = {
			["Right Leg"] = { 0.5, -2.2, -1.7 },
			["Left Leg"] = { -0.5, -2.3, -1.5 },
		},
	},
}

-- arms and head only (the hooks' Run variants do the same): the Sprint cycle under it keeps the legs and torso
local function armsAndHead(clip)
	for _, frame in clip.frames do
		frame.pose.Torso = nil
		frame.pose["Right Leg"] = nil
		frame.pose["Left Leg"] = nil
	end
	return clip
end

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
			1.1,
			{ loop = false, priority = "Action2", strike = 0.45, hold = 0.38 },
			AIR_FEET
		)
	),
	-- the attacker's whole-body poses on the ultimate's timeline (Ultimates `clips`, AnimController.PlayClip): each
	-- plays once and holds its last frame until the next one
	RushIn = simplify(
		bakeKeyed(RUSH_IN_KEYS, 0.5, { loop = false, priority = "Action" }, STANCE_FEET)
	),
	RushRun = simplify(
		armsAndHead(
			bakeKeyed(RUSH_RUN_KEYS, 0.66, { loop = false, priority = "Action" }, STANCE_FEET)
		)
	),
	UpperSet = simplify(
		bakeKeyed(UPPER_SET_KEYS, 0.3, { loop = false, priority = "Action" }, WIDE_FEET)
	),
	Dangle = simplify(
		bakeKeyed(DANGLE_KEYS, 0.6, { loop = true, priority = "Action" }, DANGLE_FEET)
	),
	Fold = simplify(bakeKeyed(FOLD_KEYS, 0.4, { loop = false, priority = "Action" }, FOLD_FEET)),
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
