--!strict
-- AnimSequence - turns one clip from Config/AnimClips into a KeyframeSequence. Studio uses this to preview a clip
-- that hasn't been uploaded yet, and animations/export_clips.py uses it to make the files that get uploaded, so the
-- two can't disagree.

local AnimSequence = {}

--- The name of the marker on the frame a swing strikes.
AnimSequence.STRIKE_EVENT = "Hit"

function AnimSequence.build(name: string, clip: any): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = clip.loop
	sequence.Priority = (Enum.AnimationPriority :: any)[clip.priority]
	for _, frame in clip.frames do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.t
		-- The Hit event sits exactly on the frame the swing strikes.
		if clip.strike and math.abs(frame.t - clip.strike) < 0.0001 then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = AnimSequence.STRIKE_EVENT
			keyframe:AddMarker(marker)
		end

		local function poseFor(part: string): Pose
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			local values = frame.pose[part]
			if values then
				pose.Weight = 1
				pose.CFrame = CFrame.new(values[4], values[5], values[6])
					* CFrame.Angles(math.rad(values[1]), math.rad(values[2]), math.rad(values[3]))
			else
				pose.Weight = 0
			end
			return pose
		end

		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		local torso = poseFor("Torso")
		root:AddSubPose(torso)
		for _, limb in { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
			if frame.pose[limb] then
				torso:AddSubPose(poseFor(limb))
			end
		end
		keyframe:AddPose(root)
		sequence:AddKeyframe(keyframe)
	end
	return sequence
end

return AnimSequence
