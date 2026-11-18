--!nocheck
-- Where the fist really is at each big contact of Haymaker Rush, from the timeline and the baked clips (kits-8a):
-- the fist's gap to the target's torso box, and how square it drives into the chest (0 = straight into its front).
--   lune run lune/contact_check
-- The same numbers are asserted by tests/Ultimates.spec ("the fist lands square on the chest front").
local Ultimates = require("../src/shared/Core/Ultimates")
local Rig = require("../tests/support/Rig")
local Clips = require("../src/shared/Config/AnimClips")
local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")

local Vector3, CFrame = Rig.Vector3, Rig.CFrame
local line = Ultimates.TIMELINES.Base

local function clipNamed(name)
	return UltimateClips[name] or Clips[name]
end

local function targetClipAt(t)
	local current
	for _, clip in line.targetClips or {} do
		if clip.t <= t then
			current = clip
		end
	end
	if current and current.name ~= "" then
		return clipNamed(current.name), t - current.t
	end
	return nil, 0
end

for _, blow in line.blows do
	if blow.freeze then
		for _, swing in line.swings do
			if math.abs(swing.t + swing.windup - blow.t) < 0.011 then
				local name = swing.side
				if name == "Right" or name == "Left" then
					continue -- the running hooks pose the arms only (the Sprint has the torso)
				end
				local clip = clipNamed(name)
				local attackerAt, targetAt = Ultimates.pose(line, blow.t, Vector3.new(0, 0, 12))
				local root = Ultimates.attackerFrame(attackerAt, targetAt)
				local ct = (clip.strike or 0) + (swing.contact or 0)
				local tip, motion = Rig.strike(root, clip, ct)
				local _, arm = Rig.fist(Rig.parts(root, Rig.sample(clip, ct))["Right Arm"])
				local drive = if swing.side == "Uppercut" then motion else arm
				local targetRoot = Ultimates.targetCFrame(
					targetAt,
					targetAt + Vector3.new(0, 0, 1),
					Ultimates.tilt(line, blow.t)
				)
				local tClip, tAt = targetClipAt(blow.t)
				local torso =
					Rig.parts(targetRoot, if tClip then Rig.sample(tClip, tAt) else nil).Torso
				local l = torso:PointToObjectSpace(tip)
				print(
					string.format(
						"%-11s t=%.2f gap %.2f  square %3.0f deg  tip in torso (%.2f, %.2f, %.2f)  drive (%.2f, %.2f, %.2f)",
						swing.side,
						blow.t,
						Rig.torsoGap(torso, tip),
						Rig.squareness(torso, drive),
						l.X,
						l.Y,
						l.Z,
						drive.X,
						drive.Y,
						drive.Z
					)
				)
			end
		end
	end
end
