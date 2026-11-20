--!nocheck
-- Where each flurry punch lands on the juggled target (kits-8l, the owner: "it looks like the barrage is hitting the head
-- instead of the torso"): the BarrageUp fist at each landing (the 1 s loop from `barrage.from`: punch k lands at clip
-- time strike + (k - 1) / 8, right first) on the attacker posed by the timeline, in the target's torso (x right, y up: -1 bottom, +1 top, the head from +1 to +2;
-- z back: -0.5 is the chest front). Also printed: the head's gap from the fist.
--   lune run lune/flurry_check [dy dz]   (try the target moved by dy up and dz toward the attacker, anchor space)
-- "bodies" counts sample points of the target's parts inside the attacker's head, torso or legs (0: no clipping).
local Ultimates = require("../src/shared/Core/Ultimates")
local Rig = require("../tests/support/Rig")
local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")

local process = require("@lune/process")
local Vector3 = Rig.Vector3
local shift = Vector3.new(0, tonumber(process.args[1]) or 0, tonumber(process.args[2]) or 0)
local SIZES = {
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(1.2, 1, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
}
local function clipping(mine, theirs)
	local inside = 0
	for name, part in theirs do
		local size = SIZES[name]
		for ix = -1, 1 do
			for iy = -2, 2 do
				for iz = -1, 1 do
					local p = part:PointToWorldSpace(
						Vector3.new(ix * size.X / 2, iy * size.Y / 4, iz * size.Z / 2)
					)
					for _, other in { "Head", "Torso", "Right Leg", "Left Leg" } do
						local l = mine[other]:PointToObjectSpace(p)
						local s = SIZES[other]
						if
							math.abs(l.X) < s.X / 2
							and math.abs(l.Y) < s.Y / 2
							and math.abs(l.Z) < s.Z / 2
						then
							inside += 1
						end
					end
				end
			end
		end
	end
	return inside
end
local line = Ultimates.TIMELINES.Base
local clip = UltimateClips[(line.barrage and line.barrage.clip) or "BarrageUp"]
local dangle = UltimateClips.Dangle

local function targetClipStart(t)
	local from = 0
	for _, c in line.targetClips or {} do
		if c.t <= t then
			from = c.t
		end
	end
	return from
end

local index = 0
local sum, count, worst = Vector3.new(0, 0, 0), 0, 0
for _, cue in line.cues do
	if cue.name == "flurryHit" then
		index += 1
		local t = cue.t
		local right = index % 2 == 1
		local a, tg = Ultimates.pose(line, t, Vector3.new(0, 0, 12))
		tg += shift
		local root = Ultimates.attackerFrame(a, tg)
		local ct = (t - line.barrage.from) % (clip.seconds or 1)
		local mine = Rig.parts(root, Rig.sample(clip, ct))
		local arm = mine[if right then "Right Arm" else "Left Arm"]
		local tip = Rig.fist(arm)
		local tRoot = Ultimates.targetCFrame(tg, tg + Vector3.new(0, 0, 1), Ultimates.tilt(line, t))
		local parts =
			Rig.parts(tRoot, if dangle then Rig.sample(dangle, t - targetClipStart(t)) else nil)
		local l = parts.Torso:PointToObjectSpace(tip)
		local head = (parts.Head.Position - tip).Magnitude
		-- how far the target would move (anchor space) to put the chest front's centre on this fist
		local want = tip - parts.Torso:PointToWorldSpace(Vector3.new(0, 0, -0.5))
		sum += want
		local bodies = clipping(mine, parts)
		worst = math.max(worst, bodies)
		count += 1
		print(
			string.format(
				"%2d %s t=%.3f  fist in torso (%.2f, %.2f, %.2f)  torso gap %.2f  head %.2f  move (%.2f, %.2f, %.2f)  bodies %d",
				index,
				if right then "R" else "L",
				t,
				l.X,
				l.Y,
				l.Z,
				Rig.torsoGap(parts.Torso, tip),
				head,
				want.X,
				want.Y,
				want.Z,
				bodies
			)
		)
	end
end
local mean = sum / math.max(count, 1)
print(
	string.format(
		"mean move to centre the chest on the fists: (%.2f, %.2f, %.2f)",
		mean.X,
		mean.Y,
		mean.Z
	)
)
print("most target points inside the attacker in one punch: " .. worst)
