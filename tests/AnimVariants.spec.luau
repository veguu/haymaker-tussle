--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The kits' own punches (2026-11-15), derived from the baked clips: mirrored, reversed, doubled.
local AnimClips = require("../src/shared/Config/AnimClips")
local AnimVariants = require("../src/shared/AnimVariants")

local CLIPS: any = AnimClips
local ALL: any = AnimVariants.all(CLIPS)

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local function strikeOnAFrame(clip: any): boolean
	for _, frame in clip.frames do
		if math.abs(frame.t - clip.strike) < 0.0001 then
			return true
		end
	end
	return false
end

return {
	["every kit punch is a real clip with its strike on a frame"] = function()
		for kit, sides in AnimVariants.Swings do
			for _, side in { "Left", "Right" } do
				local name = sides[side]
				assert(name, `{kit} has a {side} punch`)
				local clip = ALL[name]
				assert(clip, `{name} exists`)
				assert(clip.strike and clip.strike > 0, `{name} has a strike`)
				assert(strikeOnAFrame(clip), `{name}'s Hit marker lands on a frame`)
				assert(clip.frames[1].t == 0, `{name} starts at 0`)
				for index = 2, #clip.frames do
					assert(clip.frames[index].t > clip.frames[index - 1].t, `{name} runs forward`)
				end
			end
		end
	end,

	["the baked clips are untouched, and still all there"] = function()
		for name, clip in CLIPS do
			assert(ALL[name] == clip, `{name} is the same table`)
		end
		assert(CLIPS.ChopRight == nil, "the source is not written to")
	end,

	["a kit with no punches of its own throws the boxer's"] = function()
		assert(AnimVariants.swing("Base", "Left") == nil)
		assert(AnimVariants.swing(nil, "Right") == nil)
		assert(AnimVariants.swing("Frost", "Uppercut") == nil, "only the ordinary punches change")
		assert(AnimVariants.swing("Frost", "Right") == "ChopRight")
	end,

	["mirroring swaps the sides, and twice is the same pose again"] = function()
		local pose = CLIPS.Guard.frames[1].pose
		local mirrored = AnimVariants.mirrorPose(pose)
		for slot = 1, 6 do
			-- The guard is symmetric: each arm is the other's mirror image.
			assert(
				near(mirrored["Left Arm"][slot], AnimVariants.mirrorPose(pose)["Left Arm"][slot])
			)
		end
		local right = pose["Right Arm"]
		assert(near(mirrored["Left Arm"][1], right[1]) and near(mirrored["Left Arm"][3], -right[3]))
		local back = AnimVariants.mirrorPose(mirrored)
		for joint, values in pose do
			for slot = 1, 6 do
				assert(near(back[joint][slot], values[slot]), joint)
			end
		end
	end,

	["sampling between two frames is part way between them, and holds at the ends"] = function()
		local clip = CLIPS.HookRight
		local first, second = clip.frames[1], clip.frames[2]
		local middle = AnimVariants.sample(clip, (first.t + second.t) / 2)
		local a, b = first.pose["Right Arm"][3], second.pose["Right Arm"][3]
		assert(near(middle["Right Arm"][3], (a + b) / 2))
		assert(AnimVariants.sample(clip, -1) == first.pose)
		assert(AnimVariants.sample(clip, 99) == clip.frames[#clip.frames].pose)
	end,

	["a reversed clip ends where the original began, with the same strike pose"] = function()
		local base = CLIPS.Uppercut
		local chop = ALL.ChopRight
		assert(#chop.frames == #base.frames)
		assert(chop.frames[1].pose == base.frames[#base.frames].pose)
		assert(chop.frames[#chop.frames].pose == base.frames[1].pose)
		local struck
		for _, frame in base.frames do
			if math.abs(frame.t - base.strike) < 0.0001 then
				struck = frame.pose
			end
		end
		for _, frame in chop.frames do
			if math.abs(frame.t - chop.strike) < 0.0001 then
				assert(frame.pose == struck, "the strike frame is the uppercut's strike frame")
			end
		end
		assert(chop.hold < chop.strike)
	end,

	["a doubled clip moves the other arm as the mirror of the first, a moment later"] = function()
		local base = CLIPS.HookRight
		local rake = ALL.RakeRight
		assert(#rake.frames == #base.frames)
		local frame = rake.frames[12]
		local earlier = AnimVariants.sample(base, frame.t - 0.03)["Right Arm"]
		assert(near(frame.pose["Left Arm"][1], earlier[1]))
		assert(near(frame.pose["Left Arm"][3], -earlier[3]))
		assert(
			frame.pose["Right Arm"] == base.frames[12].pose["Right Arm"],
			"the first arm is unchanged"
		)
		assert(
			base.frames[12].pose["Left Arm"] ~= frame.pose["Left Arm"],
			"the source is not written to"
		)
	end,
}
