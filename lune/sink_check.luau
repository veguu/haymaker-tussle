--!nocheck
-- The haymaker's sink, sampled (kits-8f): from the contact to the blast, where the fist is against the target's chest
-- (its depth past the chest's front face, + is in) and how fast each body moves, from the timeline and the baked clips.
--   lune run lune/sink_check
local Ultimates = require("../src/shared/Core/Ultimates")
local Rig = require("../tests/support/Rig")
local Clips = require("../src/shared/Config/AnimClips")
local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")

local Vector3 = Rig.Vector3
local line = Ultimates.TIMELINES.Base
local start = Vector3.new(0, 0, 12)

local function clipNamed(name)
	return UltimateClips[name] or Clips[name]
end

local hit, blast = 0, 0
for _, cue in line.cues do
	if cue.name == "haymaker" then
		hit = cue.t
	elseif cue.name == "blast" then
		blast = cue.t
	end
end
local slow = 0
for _, blow in line.blows do
	if math.abs(blow.t - hit) < 0.011 then
		slow = blow.slow or 0
	end
end
local swing
for _, s in line.swings do
	if s.side == "HaymakerUp" then
		swing = s
	end
end
local clip = clipNamed("HaymakerUp")
local fold = clipNamed("Fold")
local foldFrom = 0
for _, c in line.targetClips do
	if c.name == "Fold" and c.t <= hit then
		foldFrom = c.t
	end
end

print(
	string.format(
		"hit %.2f  blast %.2f  slow %.2f  clip strike %.2f",
		hit,
		blast,
		slow,
		clip.strike or 0
	)
)
print("   t    clip   depth  gap   target v  attacker v  tilt")
local step = 0.1
local prevA, prevT
local t = hit
while t <= blast + 1e-6 do
	local a, tg = Ultimates.pose(line, t, start)
	local root = Ultimates.attackerFrame(a, tg)
	local ct = (clip.strike or 0) + (swing.contact or 0) + (t - hit) * slow
	local tip = Rig.strike(root, clip, ct)
	local targetRoot =
		Ultimates.targetCFrame(tg, tg + Vector3.new(0, 0, 1), Ultimates.tilt(line, t))
	local torso = Rig.parts(targetRoot, Rig.sample(fold, t - foldFrom)).Torso
	local l = torso:PointToObjectSpace(tip)
	local depth = l.Z + 0.5 -- the chest's front face is torso-local Z = -0.5
	local va = if prevA then (a - prevA).Magnitude / step else 0
	local vt = if prevT then (tg - prevT).Magnitude / step else 0
	local tilt = Ultimates.tilt(line, t)
	print(
		string.format(
			"%5.2f  %5.3f  %+5.2f  %4.2f  %6.2f    %6.2f    %5.1f",
			t,
			ct,
			depth,
			Rig.torsoGap(torso, tip),
			vt,
			va,
			if typeof(tilt) == "Vector3" then tilt.X else tilt
		)
	)
	prevA, prevT = a, tg
	t += step
end
