--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local Combat = require("../src/shared/Core/Combat")
local Tutorial = require("../src/shared/Core/Tutorial")

local CFG: Tutorial.Settings = { HitsToLearn = 3, FastHitSpeed = 25, BumpPunishSeconds = 1.5 }
local PUNCH: Combat.PunchSettings = {
	Cooldown = 0.32,
	CooldownTolerance = 0.06,
	Range = 6,
	TargetRadius = 2,
	OverlapRadius = 3,
	HitCancelsPunch = true,
	ComboResetSeconds = 2,
	HookOuterDegrees = 55,
	HookInnerDegrees = 20,
	UppercutDegrees = 55,
	CloseRange = 2.7,
	CloseDegrees = 100,
	VerticalLimit = 4.5,
}
local WINDUP = 0.12

-- Attacker at the origin facing -Z, target straight ahead at `distance`.
local function atImpact(distance: number, attackerSpeed: number, targetSpeed: number): boolean
	local inside = Combat.inHitboxAtImpact(
		PUNCH,
		WINDUP,
		0,
		0,
		0,
		0,
		-1,
		0,
		-attackerSpeed,
		0,
		0,
		-distance,
		0,
		-targetSpeed
	)
	return inside
end

local function reach(step: number): Tutorial.State
	return { step = step, hits = 0 }
end

return {
	["the run step ends only when the dummy is in reach"] = function()
		local state = Tutorial.new()
		state = Tutorial.handle(state, CFG, { kind = "hit" })
		assert(Tutorial.stepName(state) == "run", "a hit shouldn't finish the run step")
		state = Tutorial.handle(state, CFG, { kind = "inReach" })
		assert(Tutorial.stepName(state) == "punch", "being in reach should move on")
	end,

	["the punch step needs its number of confirmed hits"] = function()
		local state = reach(2)
		state = Tutorial.handle(state, CFG, { kind = "hit" })
		state = Tutorial.handle(state, CFG, { kind = "hit" })
		assert(Tutorial.stepName(state) == "punch" and state.hits == 2, "two hits isn't enough")
		state = Tutorial.handle(state, CFG, { kind = "hit" })
		assert(Tutorial.stepName(state) == "fast", "three hits should move on")
	end,

	["only a fast hit finishes the speed step"] = function()
		local state = reach(3)
		state = Tutorial.handle(state, CFG, { kind = "hit", speed = 10 })
		assert(Tutorial.stepName(state) == "fast", "a slow hit shouldn't count")
		state = Tutorial.handle(state, CFG, { kind = "hit", speed = 30 })
		assert(Tutorial.stepName(state) == "bump", "a fast hit should move on")
	end,

	["the bump step needs a bump, then a hit soon after"] = function()
		local state = reach(4)
		state = Tutorial.handle(state, CFG, { kind = "hit", now = 10 })
		assert(Tutorial.stepName(state) == "bump", "a hit with no bump shouldn't count")
		state = Tutorial.handle(state, CFG, { kind = "bump", now = 11 })
		state = Tutorial.handle(state, CFG, { kind = "hit", now = 20 })
		assert(Tutorial.stepName(state) == "bump", "a hit long after the bump shouldn't count")
		state = Tutorial.handle(state, CFG, { kind = "bump", now = 30 })
		state = Tutorial.handle(state, CFG, { kind = "hit", now = 31 })
		assert(Tutorial.stepName(state) == "propel", "bump then quick hit should move on")
	end,

	["the propel ends the tutorial"] = function()
		local state = Tutorial.handle(reach(5), CFG, { kind = "propel" })
		assert(Tutorial.isDone(state), "expected the tutorial to be done")
		assert(Tutorial.handle(state, CFG, { kind = "propel" }).step == state.step, "stays done")
	end,

	["every objective is 8 words or fewer, on every device"] = function()
		for step = 1, #Tutorial.STEPS + 1 do
			for _, device: Tutorial.Device in { "mouse", "touch", "gamepad" } :: { Tutorial.Device } do
				local objective = Tutorial.text(reach(step), CFG, device)
				local _, words = objective:gsub("%S+", "")
				assert(words <= 8, `"{objective}" is {words} words`)
			end
		end
	end,

	["phones and gamepads are never told to click or press Q"] = function()
		for step = 1, #Tutorial.STEPS + 1 do
			for _, device: Tutorial.Device in { "touch", "gamepad" } :: { Tutorial.Device } do
				local objective, hint = Tutorial.text(reach(step), CFG, device)
				local all = (objective .. " " .. hint):lower()
				assert(not all:find("click"), `{device} told to click: {all}`)
				assert(not all:find("press q"), `{device} told to press Q: {all}`)
				assert(not all:find("hold w"), `{device} told to hold W: {all}`)
			end
		end
	end,

	["the prompt says click only when a punch would really land"] = function()
		assert(Tutorial.advice(true, nil, true) == "click", "in the hitbox and ready")
		assert(Tutorial.advice(true, nil, false) == "wait", "still cooling down")
		assert(Tutorial.advice(false, "range", true) == "closer", "too far")
		assert(Tutorial.advice(false, "height", true) == "closer", "too high")
		assert(Tutorial.advice(false, "facing", true) == "turn", "not in front")
	end,

	["a punch is judged where everyone will be when it lands"] = function()
		assert(not atImpact(11, 0, 0), "11 studs away standing still is out of reach")
		assert(atImpact(11, 36, 0), "running in at full speed, the same spot is in reach")
		assert(atImpact(7.5, 0, 0), "standing in reach")
		assert(not atImpact(7.5, 0, 36), "a target running away will be gone")
	end,
}
