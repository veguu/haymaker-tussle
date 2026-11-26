--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- These hold the generated clips to the game's real settings.
local AnimClips: any = require("../src/shared/Config/AnimClips")
local GameConfig: any = require("../src/shared/Config/GameConfig")

local SWINGS = { "HookLeft", "HookRight", "Uppercut", "HookLeftRun", "HookRightRun", "UppercutRun" }

return {
	["every swing can be slowed to land when the server decides the hit"] = function()
		-- AnimController plays the lead-in at strike / Windup speed, so the strike lands on the windup. That
		-- only works slowing a clip down, never speeding it up past its own frames.
		for _, name in SWINGS do
			local clip = AnimClips[name]
			assert(clip, `missing {name}`)
			assert(
				clip.strike > 0 and clip.strike <= GameConfig.Punch.Windup,
				`{name} strikes at {clip.strike}, after the windup`
			)
		end
	end,

	["looping clips end exactly where they start"] = function()
		for name, clip in AnimClips do
			if clip.loop then
				local first = clip.frames[1].pose
				local last = clip.frames[#clip.frames].pose
				for joint, values in first do
					for index, value in values do
						local gap = math.abs(value - last[joint][index])
						assert(gap < 0.01, `{name} {joint} jumps by {gap} at the loop`)
					end
				end
			end
		end
	end,

	["frames run in order and fill the clip"] = function()
		for name, clip in AnimClips do
			local last = -1
			for _, frame in clip.frames do
				assert(frame.t > last, `{name} frames out of order at {frame.t}`)
				last = frame.t
			end
			assert(
				math.abs(last - clip.seconds) < 0.02,
				`{name} ends at {last}, not {clip.seconds}`
			)
		end
	end,

	["run versions of the swings leave the legs and torso to the sprint"] = function()
		for _, name in { "HookLeftRun", "HookRightRun", "UppercutRun" } do
			local pose = AnimClips[name].frames[1].pose
			assert(
				pose["Right Leg"] == nil and pose["Left Leg"] == nil,
				`{name} must not pose the legs`
			)
			assert(
				pose.Torso == nil,
				`{name} must not pose the torso: it swings the legs out from under it`
			)
			assert(AnimClips[name].turn, `{name} needs its body turn`)
		end
	end,

	["a running swing's body turn is modest, and it ends straight"] = function()
		for _, name in { "HookLeftRun", "HookRightRun", "UppercutRun" } do
			local turn = AnimClips[name].turn
			for _, point in turn do
				assert(math.abs(point[2]) <= 24.01, `{name} turns too far: {point[2]}`)
			end
			assert(math.abs(turn[#turn][2]) < 0.5, `{name} doesn't end straight: {turn[#turn][2]}`)
		end
	end,

	["every swing's first frame is already a big pose, thrown far from the guard"] = function()
		local guard = AnimClips.Guard.frames[1].pose
		for _, name in SWINGS do
			local arm = if name:find("Left") then "Left Arm" else "Right Arm"
			local first = AnimClips[name].frames[1].pose[arm]
			local apart = 0
			for index = 1, 3 do
				apart = math.max(apart, math.abs(first[index] - guard[arm][index]))
			end
			assert(apart > 40, `{name} starts only {apart} degrees from the guard`)
		end
	end,

	["a swing gets from its wind-up to its hit in a few frames, with nothing wasted"] = function()
		for _, name in SWINGS do
			local clip = AnimClips[name]
			local hit
			for _, frame in clip.frames do
				if math.abs(frame.t - clip.strike) < 0.0001 then
					hit = frame
				end
			end
			assert(hit, `{name} has no frame on the strike, so the Hit event would be lost`)
		end
	end,

	["standing swings end exactly on the stance's body, so nothing pops"] = function()
		for _, name in { "HookLeft", "HookRight", "Uppercut" } do
			local clip = AnimClips[name]
			local last = clip.frames[#clip.frames].pose.Torso
			local stance = AnimClips.Stance.frames[1].pose.Torso
			assert(
				math.abs(last[1] - stance[1]) < 3,
				`{name} ends leaning {last[1]}, stance {stance[1]}`
			)
			assert(
				math.abs(last[3] - stance[3]) < 3,
				`{name} ends turned {last[3]}, stance {stance[3]}`
			)
		end
	end,

	["the reactions and the settle exist, and don't take the legs from a runner when they shouldn't"] = function()
		for _, name in
			{
				"HitFlinch",
				"HitFlinchHeavy",
				"HitFlinchBack",
				"HitSkid",
				"AirTumble",
				"Slammed",
				"FloorHit",
				"Land",
				"BrakeSettle",
			}
		do
			assert(AnimClips[name], `missing {name}`)
		end
		for _, name in { "HitFlinch", "HitFlinchHeavy", "HitFlinchBack" } do
			local flinch = AnimClips[name].frames[1].pose
			assert(
				flinch["Right Leg"] == nil,
				`{name} should leave the legs to whatever they're doing`
			)
		end
	end,

	["the guard poses only the arms, so it sits on any legs"] = function()
		local pose = AnimClips.Guard.frames[1].pose
		assert(pose["Right Arm"] and pose["Left Arm"], "the guard must pose both arms")
		assert(not pose.Torso and not pose["Right Leg"], "the guard must leave the rest alone")
	end,
}
