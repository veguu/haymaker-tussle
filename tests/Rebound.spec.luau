--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local DiveKick = require("../src/shared/Core/DiveKick")

local CFG: DiveKick.Settings = {
	ReboundRiseRed = 14,
	ReboundRiseOrange = 30,
	ReboundRiseGreen = 46,
	ReboundLandNear = 15,
	ReboundLandFar = 55,
	ReboundSpeedMax = 300,
} :: any

local RADIUS = 75
local GRAVITY = 196.2 * 0.85
local UPPERCUT_RISE = 57

-- A kick this far from the platform's centre along +X, kicking outward, so backward is home.
local function from(
	x: number,
	height: number?,
	backX: number?,
	backZ: number?
): DiveKick.ReboundFrom
	return {
		x = x,
		z = 0,
		height = height or 40,
		backX = backX or -1,
		backZ = backZ or 0,
		centerX = 0,
		centerZ = 0,
		radius = RADIUS,
		speed = 84,
		gravity = GRAVITY,
	}
end

local function landing(at: DiveKick.ReboundFrom, plan: DiveKick.ReboundPlan): (number, number)
	return at.x + plan.dirX * plan.speed * plan.air, at.z + plan.dirZ * plan.speed * plan.air
end

local function landsOn(grade: DiveKick.Grade, at: DiveKick.ReboundFrom): boolean
	local x, z = landing(at, DiveKick.planRebound(CFG, grade, at))
	return math.sqrt(x * x + z * z) <= RADIUS
end

return {
	["a better kick rises higher, and every grade stays under an uppercut"] = function()
		local function rise(grade: DiveKick.Grade): number
			local up = DiveKick.planRebound(CFG, grade, from(100)).up
			return up * up / (2 * GRAVITY)
		end
		assert(rise("red") < rise("orange") and rise("orange") < rise("green"), "order")
		assert(math.abs(rise("green") - CFG.ReboundRiseGreen) < 0.001, "green's rise")
		assert(rise("green") < UPPERCUT_RISE, "under an uppercut")
		assert(rise("red") > 10, "red is still well up, not a hop")
	end,

	["only the height changes with the grade: the speed is the propel's"] = function()
		local grades: { DiveKick.Grade } = { "red", "orange", "green" }
		for _, grade in grades do
			assert(DiveKick.planRebound(CFG, grade, from(RADIUS + 90)).speed == 84, grade)
		end
	end,

	["red gets back from a short way out, but not from all the way out"] = function()
		assert(landsOn("red", from(RADIUS + 50)), "50 out")
		assert(not landsOn("red", from(RADIUS + 115)), "115 out")
	end,

	["close gets back from further than red can, but not from any distance"] = function()
		assert(landsOn("orange", from(RADIUS + 115)), "115 out")
		assert(not landsOn("orange", from(RADIUS + 140)), "140 out")
	end,

	["perfect always gets back, from any distance and any height"] = function()
		for out = 0, 400, 10 do
			for _, height in { 5, 20, 40, 70 } do
				assert(landsOn("green", from(RADIUS + out, height)), `{out} out, {height} up`)
			end
		end
	end,

	["perfect gets back even when backward leads away from the platform"] = function()
		assert(landsOn("green", from(RADIUS + 60, 40, 1, 0)), "straight away")
		assert(landsOn("green", from(RADIUS + 60, 40, 0, 1)), "sideways, missing it")
		local plan = DiveKick.planRebound(CFG, "green", from(RADIUS + 60, 40, 1, 0))
		assert(plan.dirX == -1, "goes home instead")
	end,

	["perfect keeps backward when backward does lead to the platform"] = function()
		local at = from(RADIUS + 20, 40, -0.8, 0.6)
		local plan = DiveKick.planRebound(CFG, "green", at)
		assert(
			math.abs(plan.dirX + 0.8) < 0.0001 and math.abs(plan.dirZ - 0.6) < 0.0001,
			"still backward"
		)
		assert(landsOn("green", at), "and lands")
	end,

	["red and close keep going backward even when that leads away"] = function()
		local plan = DiveKick.planRebound(CFG, "orange", from(RADIUS + 60, 40, 1, 0))
		assert(plan.dirX == 1 and plan.speed == 84, "as thrown")
	end,

	["no grade throws you past the far side of the platform"] = function()
		local grades: { DiveKick.Grade } = { "red", "orange", "green" }
		for _, grade in grades do
			for x = -70, 100, 10 do
				local at = from(x)
				local landX = landing(at, DiveKick.planRebound(CFG, grade, at))
				assert(landX >= -RADIUS, `{grade} from {x} landed at {landX}`)
			end
		end
	end,

	["a landing with room stays at the propel's speed"] = function()
		local plan = DiveKick.planRebound(CFG, "red", from(RADIUS + 100))
		assert(plan.speed == 84, `speed {plan.speed}`)
	end,

	["being below the platform's top can't break the sums"] = function()
		local plan = DiveKick.planRebound(CFG, "red", from(100, -20))
		assert(plan.air > 0 and plan.air == plan.air, "air time")
	end,

	["exactly over the middle with no direction stays put safely"] = function()
		local plan = DiveKick.planRebound(CFG, "green", from(0, 40, 0, 0))
		assert(plan.dirX == 0 and plan.dirZ == 0, "no direction")
		assert(plan.up > 0, "still rises")
	end,

	["a slower fall is planned for: the air time comes from fallTime and the landing still holds"] = function()
		local AirRecovery = require("../src/shared/Core/AirRecovery")
		local air: AirRecovery.Settings = {
			FallGravityScale = 0.24,
			FallEaseSpeed = 16,
			MaxFallSpeed = 30,
			FallDrag = 120,
		} :: any
		for _, grade: DiveKick.Grade in { "red", "orange", "green" } do
			local at = from(RADIUS + 40)
			local plain = DiveKick.planRebound(CFG, grade, at)
			at.fallTime = function(up: number, height: number): number
				return AirRecovery.timeToDrop(air, 196.2, 0.85, up, height)
			end
			local slow = DiveKick.planRebound(CFG, grade, at)
			assert(slow.air > plain.air + 0.5, grade .. ": a slower fall stays up longer")
			assert(slow.up == plain.up, grade .. ": the rise is unchanged")
			local x = at.x + slow.dirX * slow.speed * slow.air
			assert(math.abs(x) <= RADIUS, grade .. ": lands on the platform")
			assert(
				x >= -(RADIUS - CFG.ReboundLandFar) - 0.001,
				grade .. ": never past the far limit"
			)
		end
	end,
}
