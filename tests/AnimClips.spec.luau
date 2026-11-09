--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- These hold the generated clips to the game's real settings.
local AnimClips: any = require("../src/shared/Config/AnimClips")
local GameConfig: any = require("../src/shared/Config/GameConfig")

local SWINGS = { "HookLeft", "HookRight", "Uppercut", "HookLeftRun", "HookRightRun", "UppercutRun" }

return {
	["every swing lands exactly when the server decides the hit"] = function()
		for _, name in SWINGS do
			local clip = AnimClips[name]
			assert(clip, `missing {name}`)
			assert(
				clip.strike == GameConfig.Punch.Windup,
				`{name} strikes at {clip.strike}, not the windup`
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

	["the flip stays small enough between frames to blend the right way round"] = function()
		local frames = AnimClips.KickSpin.frames
		for index = 2, #frames do
			local gap = math.abs(frames[index].pose.Torso[1] - frames[index - 1].pose.Torso[1])
			assert(gap < 120, `KickSpin jumps {gap} degrees, which would spin the wrong way`)
		end
		local total = frames[#frames].pose.Torso[1] - frames[1].pose.Torso[1]
		assert(total > 270 and total < 340, `expected most of a whole turn, got {total}`)
	end,

	["the spin starts in a ball, with the arms and knees tucked"] = function()
		local pose = AnimClips.KickSpin.frames[1].pose
		assert(
			pose["Right Leg"][3] > 110,
			`knee should be at the chest, got {pose["Right Leg"][3]}`
		)
		assert(-pose["Left Leg"][3] > 110, `other knee too, got {pose["Left Leg"][3]}`)
		assert(pose["Right Arm"][3] > 90, `arm should be tucked in, got {pose["Right Arm"][3]}`)
	end,

	["the kicking leg passes overhead, then the rotation brings the heel down"] = function()
		-- A leg's direction in the world: its swing forward, less the body's turn forward.
		local overhead = false
		local frames = AnimClips.KickSpin.frames
		for _, frame in frames do
			local world = (frame.pose["Right Leg"][3] - frame.pose.Torso[1]) % 360
			if world > 150 and world < 210 and frame.pose["Right Leg"][3] < 80 then
				overhead = true
			end
		end
		assert(overhead, "the leg should be uncurling and pointing up as the body turns over")
		local strike = AnimClips.KickDown.frames[1].pose
		local down = (strike["Right Leg"][3] - strike.Torso[1]) % 360
		assert(down > 5 and down < 40, `the heel should strike down and slightly ahead, got {down}`)
	end,

	["the spin runs straight into the strike, with no jump"] = function()
		local spin = AnimClips.KickSpin.frames
		local last = spin[#spin].pose
		local strike = AnimClips.KickDown.frames[1].pose
		local spinWorld = (last["Right Leg"][3] - last.Torso[1]) % 360
		local strikeWorld = (strike["Right Leg"][3] - strike.Torso[1]) % 360
		assert(
			math.abs(spinWorld - strikeWorld) < 15,
			`the leg jumps from {spinWorld} to {strikeWorld}`
		)
	end,

	["after the strike the kicking leg comes back, and the body goes up with the recoil"] = function()
		local frames = AnimClips.KickDown.frames
		local first = frames[1].pose
		local highestLeg, highestBody = first["Right Leg"][3], first.Torso[6]
		for _, frame in frames do
			highestLeg = math.max(highestLeg, frame.pose["Right Leg"][3])
			highestBody = math.max(highestBody, frame.pose.Torso[6])
		end
		assert(highestLeg > first["Right Leg"][3] + 50, `the leg should retract, got {highestLeg}`)
		assert(highestBody > first.Torso[6] + 0.3, `the body should rise, got {highestBody}`)
	end,

	["the jump's clip and physics leave the floor together, and the arms stay down"] = function()
		local clip = AnimClips.KickLeap
		assert(clip.spring == GameConfig.Kick.JumpSquatSeconds, `clip springs at {clip.spring}`)
		for _, frame in clip.frames do
			local arm = frame.pose["Right Arm"][3]
			assert(math.abs(arm) < 30, `arms should stay beside the body, got {arm} at {frame.t}`)
			assert(frame.pose["Right Arm"][1] < 0, `arms should stay slightly out, at {frame.t}`)
		end
	end,

	["the spin takes exactly as long as the server's flip"] = function()
		assert(
			AnimClips.KickSpin.seconds == GameConfig.Kick.FlipSeconds,
			"the heel has to land on the hit"
		)
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
