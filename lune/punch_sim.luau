--!strict
-- Tuning tool, not a test. Plays an attacker running at a target thousands of times on the
-- real movement, punch and bump rules, and prints how often punches land, so a hitbox or
-- miss-penalty change can be judged before anyone plays it.
-- Run from the project folder: lune run lune/punch_sim
local Combat = require("../src/shared/Core/Combat")
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local MOVE: any = GameConfig.Movement
local KNOCK: any = GameConfig.Knockback
local PUNCH: any = GameConfig.Punch
local STAGGER: any = GameConfig.Stagger
local STEP = 1 / 60
local MAX_PRESSES = 3

type Scenario = { name: string, startX: number, startZ: number, inputX: number, inputZ: number }

local SCENARIOS: { Scenario } = {
	{ name = "standing", startX = 30, startZ = 0, inputX = 0, inputZ = 0 },
	{ name = "strafing", startX = 34, startZ = -20, inputX = 0, inputZ = 1 },
	{ name = "head-on", startX = 50, startZ = 0, inputX = -1, inputZ = 0 },
	{ name = "fleeing", startX = 14, startZ = 0, inputX = 0.8, inputZ = 0.6 },
}

local function aimed(x: number, z: number, angle: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length < 0.001 then
		return 1, 0
	end
	local c, s = math.cos(angle), math.sin(angle)
	return (x * c - z * s) / length, (x * s + z * c) / length
end

-- Returns which press landed, or 0 if none did.
local function trial(scenario: Scenario, punch: any, missKeep: number, rng: any): number
	local attacker = Momentum.new(1, 0)
	attacker.speed = MOVE.MaxSpeed
	attacker.forwardCoast = true
	local target = Momentum.new(1, 0)
	if scenario.inputX ~= 0 or scenario.inputZ ~= 0 then
		target = Momentum.new(scenario.inputX, scenario.inputZ)
		target.speed = MOVE.MaxSpeed * 0.8
	end

	local ax, az = 0, 0
	local tx, tz = scenario.startX, scenario.startZ
	local aim = math.rad(rng:NextNumber(-15, 15)) -- how far off the player's steering is
	local startDistance = rng:NextNumber(8, 14) -- when they start clicking
	local bumped = false
	local presses = 0
	local nextPress: number? = nil
	local impactAt: number? = nil
	local pressAX, pressAZ, pressTX, pressTZ, pressFX, pressFZ = 0, 0, 0, 0, 1, 0
	local now = 0

	for _ = 1, 6 * 60 do
		now += STEP
		local ix, iz = aimed(tx - ax, tz - az, aim)
		attacker = Momentum.step(attacker, MOVE, ix, iz, true, STEP, "forward", 0)
		target =
			Momentum.step(target, MOVE, scenario.inputX, scenario.inputZ, true, STEP, "forward", 0)
		local avx, avz = Momentum.velocity(attacker)
		local tvx, tvz = Momentum.velocity(target)
		ax += avx * STEP
		az += avz * STEP
		tx += tvx * STEP
		tz += tvz * STEP

		local gap = math.sqrt((tx - ax) ^ 2 + (tz - az) ^ 2)
		if not bumped and gap <= KNOCK.BumpDistance then
			local closing = Combat.closingSpeed(ax, az, avx, avz, tx, tz, tvx, tvz)
			if closing >= KNOCK.BumpMinClosingSpeed then
				bumped = true
				local lineX, lineZ = Combat.bumpDirection(ax, az, avx, avz, tx, tz, tvx, tvz)
				local out = Combat.bumpOutcome(
					KNOCK,
					STAGGER,
					MOVE.PropelSpeed,
					closing,
					avx,
					avz,
					tvx,
					tvz
				)
				attacker =
					Momentum.applyKnock(attacker, MOVE, -lineX * out.knockA, -lineZ * out.knockA)
				target = Momentum.applyKnock(target, MOVE, lineX * out.knockB, lineZ * out.knockB)
			end
		end

		if nextPress == nil and gap <= startDistance then
			nextPress = now + rng:NextNumber(0, 0.1)
		end
		if nextPress and now >= nextPress and impactAt == nil and presses < MAX_PRESSES then
			presses += 1
			impactAt = now + punch.Windup
			pressAX, pressAZ, pressTX, pressTZ = ax, az, tx, tz
			pressFX, pressFZ = Momentum.facing(attacker)
			nextPress = now + punch.Cooldown
		end
		if impactAt and now >= impactAt then
			impactAt = nil
			local fx, fz = Momentum.facing(attacker)
			if
				Combat.inHitbox(punch, ax, 0, az, fx, fz, tx, 0, tz)
				or (
					punch.CheckPress
					and Combat.inHitbox(
						punch,
						pressAX,
						0,
						pressAZ,
						pressFX,
						pressFZ,
						pressTX,
						0,
						pressTZ
					)
				)
			then
				return presses
			end
			attacker = Momentum.applyKnock(attacker, MOVE, 0, 0, missKeep)
			if presses >= MAX_PRESSES then
				return 0
			end
		end
	end
	return 0
end

local function report(
	label: string,
	range: number,
	missKeep: number,
	overlap: number,
	checkPress: boolean
)
	local punch = table.clone(PUNCH)
	punch.Range = range
	punch.OverlapRadius = overlap
	punch.CheckPress = checkPress
	local parts = {}
	for _, scenario in SCENARIOS do
		math.randomseed(1234)
		local rng = {
			NextNumber = function(_, low: number, high: number): number
				return low + (high - low) * math.random()
			end,
		}
		local first, within = 0, 0
		local runs = 3000
		for _ = 1, runs do
			local landed = trial(scenario, punch, missKeep, rng)
			if landed == 1 then
				first += 1
			end
			if landed >= 1 then
				within += 1
			end
		end
		table.insert(
			parts,
			string.format("%s %2.0f/%2.0f", scenario.name, first / runs * 100, within / runs * 100)
		)
	end
	local outline = Combat.hitboxOutline(punch, 180)
	local area = 0
	for index, point in outline do
		local following = outline[index % #outline + 1]
		area += (point.x * following.z - following.x * point.z) / 2
	end
	print(string.format("%-34s area %3.0f  %s", label, math.abs(area), table.concat(parts, "  ")))
end

print("% landing on the first press / within 3 presses")
report("current settings", PUNCH.Range, PUNCH.MissSpeedKeep, PUNCH.OverlapRadius, false)
