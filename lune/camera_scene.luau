--!nocheck
-- Samples Haymaker Rush from the game's own maths for the Blender camera scene (animations/camera):
-- every 0.01 s from FROM to TO, in ANCHOR space: both roots, every joint's Transform (the clips synced the way
-- UltimateController and AnimController sync them), today's camera (Ultimates.shot), the shake, where both roots
-- fall on a 16:9 screen with the CONTROLLER's camera maths, and the fist's gap to the target's torso.
--   lune run lune/camera_scene            -> animations/camera/out/scene.json
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Ultimates = require("../src/shared/Core/Ultimates")
local Rig = require("../tests/support/Rig")
local Clips = require("../src/shared/Config/AnimClips")
local UltimateClips = require("../src/shared/Config/AnimClipsUltimate")

local Vector3, CFrame = Rig.Vector3, Rig.CFrame
local line = Ultimates.TIMELINES.Base
local START = Vector3.new(0, 0, 12) -- where the attacker began (the tests' and lune tools' usual start)
local FROM, TO, STEP = 4.20, 5.00, 0.01
local ASPECT = 16 / 9

local function clipNamed(name)
	return UltimateClips[name] or Clips[name]
end

local function current(list, t)
	local found
	for _, item in list or {} do
		if item.t <= t then
			found = item
		end
	end
	return found
end

local function heldAt(clip, seconds)
	return math.clamp(seconds, 0, math.max(clip.seconds - 0.02, 0))
end

-- The attacker's clip and clip time at t: the whole-body pose clip (SyncClip), or the big swing on the shared clock
-- (UltimateController's three-part lead, then AnimController.SyncSwing).
local function attackerClip(t)
	for _, swing in line.swings do
		if not swing.hold and not swing.fromHold and clipNamed(swing.side) then
			local hitAt = swing.t + swing.windup
			local freeze, slow = 0, 0
			for _, blow in line.blows do
				if math.abs(blow.t - hitAt) < 0.011 then
					freeze, slow = blow.freeze or 0, blow.slow or 0
				end
			end
			if t >= swing.t and t < hitAt + freeze then
				local clip = clipNamed(swing.side)
				local lead = math.clamp((t - swing.t) / math.max(swing.windup, 1e-3), 0, 1)
				if swing.loaded and swing.release and swing.holdShare then
					if t < swing.loaded then
						lead = swing.holdShare * math.clamp((t - swing.t) / math.max(swing.loaded - swing.t, 1e-3), 0, 1)
					elseif t < swing.release then
						lead = swing.holdShare
					else
						lead = swing.holdShare
							+ (1 - swing.holdShare) * math.clamp((t - swing.release) / math.max(hitAt - swing.release, 1e-3), 0, 1)
					end
				end
				local hold = (clip.strike or 0) + (swing.contact or 0)
				return swing.side, clip, heldAt(clip, lead * hold + math.max(t - hitAt, 0) * slow)
			end
		end
	end
	local pose = current(line.clips, t)
	if pose and pose.name ~= "" then
		local clip = clipNamed(pose.name)
		return pose.name, clip, heldAt(clip, t - pose.t)
	end
	return "", nil, 0
end

local function targetClip(t)
	local pose = current(line.targetClips, t)
	if pose and pose.name ~= "" then
		local clip = clipNamed(pose.name)
		return pose.name, clip, heldAt(clip, t - pose.t)
	end
	return "", nil, 0
end

local function numbers(cf)
	return { cf:GetComponents() }
end

local JOINT_NAMES = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local function joints(clip, seconds)
	local out = {}
	local pose = if clip then Rig.sample(clip, seconds) else {}
	for _, name in JOINT_NAMES do
		out[name] = numbers(pose[name] or CFrame.new())
	end
	return out, if clip then pose else nil
end

-- The camera as UltimateController builds it: CFrame.lookAt(from, toward) * CFrame.Angles(0, 0, roll). Built from its
-- axes (Lune's lookAt is backwards for exactly +-Z). Returns right, up, forward.
local function cameraAxes(cam, look, roll)
	local forward = (look - cam).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(forward)
	local r = math.rad(roll)
	-- a turn of +roll about the camera's own back axis: right goes toward up
	return right * math.cos(r) + up * math.sin(r), up * math.cos(r) - right * math.sin(r), forward
end

local function onScreen(point, cam, look, fov, roll)
	local right, up, forward = cameraAxes(cam, look, roll)
	local rel = point - cam
	local depth = rel:Dot(forward)
	local half = math.tan(math.rad(fov) / 2)
	return { rel:Dot(right) / (depth * half * ASPECT), rel:Dot(up) / (depth * half), depth }
end

local frames = {}
local count = math.floor((TO - FROM) / STEP + 0.5)
for index = 0, count do
	local t = FROM + index * STEP
	local attackerAt, targetAt = Ultimates.pose(line, t, START)
	local attackerRoot = Ultimates.attackerFrame(attackerAt, targetAt)
	local targetRoot = Ultimates.targetCFrame(targetAt, targetAt + Vector3.new(0, 0, 1), Ultimates.tilt(line, t))
	local aName, aClip, aTime = attackerClip(t)
	local tName, tClip, tTime = targetClip(t)
	local aJoints, aPose = joints(aClip, aTime)
	local tJoints, tPose = joints(tClip, tTime)
	local cam, look, fov, roll = Ultimates.shot(line, t, attackerAt, targetAt, START)
	local sx, sy = Ultimates.shake(line, t)
	local tip = Rig.fist(Rig.parts(attackerRoot, aPose)["Right Arm"])
	local torso = Rig.parts(targetRoot, tPose).Torso
	local solo = line.soloArm
	table.insert(frames, {
		t = math.floor(t * 100 + 0.5) / 100,
		attackerRoot = numbers(attackerRoot),
		targetRoot = numbers(targetRoot),
		attackerClip = aName,
		attackerClipTime = aTime,
		targetClip = tName,
		targetClipTime = tTime,
		attacker = aJoints,
		target = tJoints,
		cam = { cam.X, cam.Y, cam.Z },
		look = { look.X, look.Y, look.Z },
		fov = fov,
		roll = roll,
		shake = { sx, sy },
		cut = Ultimates.currentShot(line, t).t,
		attackerOnScreen = onScreen(attackerRoot.Position, cam, look, fov, roll),
		targetOnScreen = onScreen(targetRoot.Position, cam, look, fov, roll),
		fist = { tip.X, tip.Y, tip.Z },
		fistGap = Rig.torsoGap(torso, tip),
		fistInTorso = { torso:PointToObjectSpace(tip).X, torso:PointToObjectSpace(tip).Y, torso:PointToObjectSpace(tip).Z },
		soloArm = solo ~= nil and t >= solo.from and t < solo.to,
	})
end

local cues = {}
for _, cue in line.cues do
	if cue.t >= FROM and cue.t <= TO then
		table.insert(cues, { t = cue.t, name = cue.name })
	end
end
local jolts = {}
for _, jolt in line.jolts or {} do
	table.insert(jolts, jolt)
end
fs.writeDir("animations/camera/out")
fs.writeFile(
	"animations/camera/out/scene.json",
	serde.encode("json", { from = FROM, to = TO, step = STEP, aspect = ASPECT, frames = frames, cues = cues, jolts = jolts })
)
for _, frame in frames do
	local t = frame.t
	if math.abs(t * 100 % 5) < 0.01 or math.abs(t - 4.32) < 0.001 or math.abs(t - 4.93) < 0.001 or math.abs(t - 4.82) < 0.001 then
		print(string.format(
			"t=%.2f  %-10s %.3f | %-6s | attacker (%.2f, %.2f, %.2f) target (%.2f, %.2f, %.2f) | cam (%.2f, %.2f, %.2f) fov %.1f roll %.1f | fist gap %.2f%s",
			t, frame.attackerClip, frame.attackerClipTime, frame.targetClip,
			frame.attackerRoot[1], frame.attackerRoot[2], frame.attackerRoot[3],
			frame.targetRoot[1], frame.targetRoot[2], frame.targetRoot[3],
			frame.cam[1], frame.cam[2], frame.cam[3], frame.fov, frame.roll, frame.fistGap,
			if frame.soloArm then "  (arm only)" else ""
		))
	end
end
print("wrote animations/camera/out/scene.json,", #frames, "frames")
