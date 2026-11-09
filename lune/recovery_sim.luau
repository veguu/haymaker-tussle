--!strict
-- Tuning tool, not a test. Launches a body off the platform thousands of times on the real movement,
-- steering and recovery rules, with a simulated player who reacts late, aims imperfectly and clicks
-- unevenly, and prints how often they get back. Nothing here rolls for success: each attempt either
-- reaches the platform or it doesn't. It's a model of a player, so the percentages are a target to play
-- against, not a measurement of real people.
--
-- Run from the project folder: lune run lune/recovery_sim
-- Options: lune run lune/recovery_sim -- trace   prints one attempt per scenario, for comparing with Studio
local process = require("@lune/process")

local AirRecovery = require("../src/shared/Core/AirRecovery")
local Combat = require("../src/shared/Core/Combat")
local DiveKick = require("../src/shared/Core/DiveKick")
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local MOVE: any = GameConfig.Movement
local KNOCK: any = GameConfig.Knockback
local PUNCH: any = GameConfig.Punch
local STAGGER: any = GameConfig.Stagger
local KICK: any = GameConfig.Kick
local AIR: any = GameConfig.AirRecovery
local ARENA: any = GameConfig.Arena

-- Tries other values without touching the design file: RECOVERY_SET="BoostSpeed=30,MaxSpeed=70"
for pair in string.gmatch(process.env.RECOVERY_SET or "", "[^,]+") do
	local key, value = string.match(pair, "(%w+)=(.+)")
	if key and value then
		AIR[key] = tonumber(value)
	end
end

local GRAVITY = 196.2
local TRIALS = 600
-- How far below the platform's top the feet can be and still get on. Measured in Studio on the R6 rig:
-- see "Recovery Scenarios" in the vault note.
local LEDGE_DROP = 2
local LEDGE_REACH = 0.5 -- the body's own width past the rim still catches it

export type Launch = {
	kind: "uppercut" | "hook" | "fallen",
	edgeGap: { number }, -- studs past the current edge when launched; negative is still on the platform
	height: { number }, -- feet above the platform's top
	stagger: { number },
	attackerSpeed: { number },
	spread: number, -- degrees either side of straight out
	vy: { number }?, -- vertical speed, when it isn't the launch's own
	outward: { number }?, -- flat outward speed, when it isn't from a punch
}

export type Skill = {
	reaction: { number }, -- seconds before they start doing anything
	aimError: number, -- degrees of wobble in where they steer
	clickGap: { number }, -- seconds between presses
	propelChance: number,
	steers: boolean,
	punches: boolean,
}

-- What a representative player is like. The two ends are for the quick-versus-delayed comparison.
local TYPICAL: Skill = {
	reaction = { 0.22, 0.6 },
	aimError = 14,
	clickGap = { 0.14, 0.42 },
	propelChance = 0.35,
	steers = true,
	punches = true,
}
local SHARP: Skill = {
	reaction = { 0.15, 0.2 },
	aimError = 3,
	clickGap = { 0.1, 0.12 },
	propelChance = 1,
	steers = true,
	punches = true,
}
local LATE: Skill = {
	reaction = { 0.7, 1 },
	aimError = 14,
	clickGap = { 0.14, 0.42 },
	propelChance = 0.35,
	steers = true,
	punches = true,
}
local STEER_ONLY: Skill = {
	reaction = { 0.22, 0.6 },
	aimError = 14,
	clickGap = { 1, 1 },
	propelChance = 0,
	steers = true,
	punches = false,
}

-- The same seed gives the same attempts, so a change in the numbers comes from a change in the rules.
local function newRng(seed: number): any
	local value = (seed * 2654435761 + 12345) % 4294967296
	local rng = {}
	function rng:NextNumber(low: number?, high: number?): number
		value = (value * 1664525 + 1013904223) % 4294967296
		local share = value / 4294967296
		if low and high then
			return low + (high - low) * share
		end
		return share
	end
	return rng
end

local function between(rng: any, range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

export type Result = {
	back: boolean,
	seconds: number,
	furthest: number, -- most studs past the edge
	topSpeed: number,
	punches: number,
}

-- One attempt. Mirrors the order of MovementController's air step.
local function attempt(launch: Launch, skill: Skill, radius: number, rng: any, step: number): Result
	local angle = math.rad(rng:NextNumber(-launch.spread, launch.spread))
	local x = radius + between(rng, launch.edgeGap)
	local z = 0
	local y = between(rng, launch.height)
	local stagger = between(rng, launch.stagger)
	local state = Momentum.new(-1, 0) -- they were facing their attacker
	local outX, outZ = math.cos(angle), math.sin(angle)

	local speed = if launch.outward
		then between(rng, launch.outward)
		else Combat.punchStrength(KNOCK, STAGGER, between(rng, launch.attackerSpeed), stagger)
	local up = 0
	local floating = launch.kind == "uppercut"
	if launch.kind == "uppercut" then
		up = KNOCK.UppercutLift
	elseif launch.kind == "hook" then
		up = math.min(speed * KNOCK.UpwardFraction, KNOCK.UpwardMax)
	end
	if launch.vy then
		up = between(rng, launch.vy)
	end
	state = Momentum.applyKnock(state, MOVE, outX * speed, outZ * speed)
	local vy = up
	local rising = if floating then KICK.AirGravityScale else 1

	local steerX, steerZ = 0, 0
	local pushX, pushZ = 0, 0
	local t = 0
	local reaction = between(rng, skill.reaction)
	local nextPress = reaction
	local lastPress = -math.huge
	local owed = 0
	local wobble = math.rad(rng:NextNumber(-skill.aimError, skill.aimError))
	local nextWobble = 0
	local usesPropel = rng:NextNumber() < skill.propelChance
	local propelAt = reaction + rng:NextNumber(0.05, 0.4)
	local furthest = 0
	local topSpeed = 0
	local punches = 0
	local buffered: number? = nil
	-- The combo (left, right, uppercut) and the falling lift, the same as MovementController.
	local nextSide = "Left"
	local lifts = AirRecovery.newLifts()
	local liftUntil = -1

	while t < 12 do
		local active = t >= reaction and skill.steers
		local inputX, inputZ = 0, 0
		if active then
			if t >= nextWobble then
				wobble = math.rad(rng:NextNumber(-skill.aimError, skill.aimError))
				nextWobble = t + 0.3
			end
			-- Toward the platform's centre, which is where a person looks when they're off it.
			local size = math.sqrt(x * x + z * z)
			local toX, toZ = -x / size, -z / size
			local c, s = math.cos(wobble), math.sin(wobble)
			inputX, inputZ = toX * c - toZ * s, toX * s + toZ * c
		end

		-- Presses are remembered once if they're a moment early, the same as CombatController.
		local boosted = false
		if skill.punches and t >= nextPress then
			nextPress = t + between(rng, skill.clickGap)
			local readyAt = lastPress + PUNCH.Cooldown + owed
			if t >= readyAt then
				boosted = true
			elseif Combat.pressBuffers(PUNCH, t, readyAt) then
				buffered = t
			end
		end
		if
			not boosted
			and buffered
			and Combat.bufferLive(PUNCH, t, buffered)
			and t >= lastPress + PUNCH.Cooldown + owed
		then
			boosted = true
		end
		if boosted then
			buffered = nil
			local side = Combat.comboSwing(PUNCH, nextSide, t, lastPress)
			nextSide = Combat.nextSwing(side)
			lastPress = t
			owed = PUNCH.MissRecovery -- nobody to hit out here, so every one is a whiff
			punches += 1
			local faceX, faceZ = Momentum.facing(state)
			local dirX, dirZ =
				AirRecovery.direction(inputX, inputZ, faceX, faceZ, MOVE.InputDeadzone)
			local wantX, wantZ = Momentum.velocity(state)
			-- Floor within reach only over the platform, and only when close above it.
			local over = math.sqrt(x * x + z * z) - radius <= LEDGE_REACH
			local floorBelow = if over and y <= AIR.LiftFloorCheck then math.max(y, 0) else nil
			local lifted = side == "Uppercut"
				and AirRecovery.canLift(AIR, lifts, vy, floorBelow, false, t)
			local addX, addZ = AirRecovery.push(
				AIR,
				wantX + steerX + pushX,
				wantZ + steerZ + pushZ,
				dirX,
				dirZ,
				if lifted then AIR.LiftForwardSpeed else nil
			)
			pushX += addX
			pushZ += addZ
			if lifted then
				lifts = AirRecovery.usedLift(lifts, t)
				liftUntil = t + AIR.LiftSeconds
				vy = AIR.LiftSpeed
			else
				vy += AirRecovery.lift(AIR, vy)
			end
		end

		if usesPropel and t >= propelAt then
			usesPropel = false
			local propelled = Momentum.tryPropel(state, MOVE, inputX, inputZ, "forward")
			if propelled then
				state = propelled
			end
		end

		-- One physics-and-control step.
		local share = DiveKick.launchSteerShare(KICK, stagger, STAGGER.Max)
		if floating then
			local propelling = (state.propelLeft or 0) > 0
			state = Momentum.step(
				state,
				MOVE,
				if propelling then inputX else 0,
				if propelling then inputZ else 0,
				true,
				step,
				"forward",
				0
			)
		else
			state = Momentum.step(state, MOVE, inputX, inputZ, false, step, "forward", 0)
		end
		steerX, steerZ = DiveKick.airSteer(
			steerX,
			steerZ,
			inputX,
			inputZ,
			KICK.LaunchSteerSpeed * share,
			KICK.LaunchSteerAcceleration * share,
			step
		)
		local wantX, wantZ = Momentum.velocity(state, Combat.staggerSpeedShare(STAGGER, stagger))
		pushX, pushZ = AirRecovery.fade(AIR, pushX, pushZ, step)
		pushX, pushZ = AirRecovery.limit(AIR, pushX, pushZ, wantX + steerX, wantZ + steerZ)
		local velX, velZ = wantX + steerX + pushX, wantZ + steerZ + pushZ
		topSpeed = math.max(topSpeed, math.sqrt(velX * velX + velZ * velZ))

		vy = if t < liftUntil
			then AirRecovery.liftVelocity(AIR, GRAVITY, vy - GRAVITY * step, step)
			else AirRecovery.fallVelocity(AIR, GRAVITY, rising, vy - GRAVITY * step, step)
		x += velX * step
		z += velZ * step
		y += vy * step
		t += step

		local out = math.sqrt(x * x + z * z) - radius
		furthest = math.max(furthest, out)
		if y <= 0 and out <= LEDGE_REACH and y >= -LEDGE_DROP then
			return {
				back = true,
				seconds = t,
				furthest = furthest,
				topSpeed = topSpeed,
				punches = punches,
			}
		end
		if y < -LEDGE_DROP then
			return {
				back = false,
				seconds = t,
				furthest = furthest,
				topSpeed = topSpeed,
				punches = punches,
			}
		end
	end
	return { back = false, seconds = t, furthest = furthest, topSpeed = topSpeed, punches = punches }
end

local function run(
	launch: Launch,
	skill: Skill,
	radius: number,
	seed: number,
	step: number
): (number, Result)
	local rng = newRng(seed)
	local back = 0
	local sum: Result = { back = false, seconds = 0, furthest = 0, topSpeed = 0, punches = 0 }
	for _ = 1, TRIALS do
		local result = attempt(launch, skill, radius, rng, step)
		if result.back then
			back += 1
		end
		sum.seconds += result.seconds / TRIALS
		sum.furthest += result.furthest / TRIALS
		sum.topSpeed = math.max(sum.topSpeed, result.topSpeed)
		sum.punches += result.punches / TRIALS
	end
	return back / TRIALS, sum
end

-- THE SCENARIOS. Categories are by how far the launch carries past the current edge with no input,
-- which comes from where they were, the height and the outward speed together.
local SCENARIOS: { { name: string, target: string, launch: Launch } } = {
	{
		name = "CLOSE uppercut, stagger 20-45",
		target = "~80",
		launch = {
			kind = "uppercut",
			edgeGap = { 0, 10 },
			height = { 0, 0 },
			stagger = { 20, 45 },
			attackerSpeed = { 0, 36 },
			spread = 20,
		},
	},
	{
		name = "CLOSE drifting out at 30 up, 15-32 studs/s",
		target = "~80",
		launch = {
			kind = "hook",
			edgeGap = { 0, 12 },
			height = { 25, 35 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 0 },
			spread = 20,
			vy = { -6, 0 },
			outward = { 15, 32 },
		},
	},
	{
		name = "FAR uppercut, stagger 50-70",
		target = "~40",
		launch = {
			kind = "uppercut",
			edgeGap = { 0, 12 },
			height = { 0, 0 },
			stagger = { 50, 70 },
			attackerSpeed = { 0, 36 },
			spread = 20,
		},
	},
	{
		name = "FAR drifting out at 30 up, 35-50 studs/s",
		target = "~40",
		launch = {
			kind = "hook",
			edgeGap = { 0, 12 },
			height = { 25, 35 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 0 },
			spread = 20,
			vy = { -6, 0 },
			outward = { 35, 50 },
		},
	},
	{
		name = "VERY FAR uppercut, stagger 92+, running attacker",
		target = "0",
		launch = {
			kind = "uppercut",
			edgeGap = { 0, 15 },
			height = { 0, 0 },
			stagger = { 92, 100 },
			attackerSpeed = { 28, 36 },
			spread = 20,
		},
	},
	{
		name = "VERY FAR punched at 30 up, stagger 40+",
		target = "0",
		launch = {
			kind = "hook",
			edgeGap = { 15, 30 },
			height = { 25, 35 },
			stagger = { 40, 100 },
			attackerSpeed = { 0, 36 },
			spread = 20,
			vy = { -6, 0 },
		},
	},
	{
		name = "(info) uppercut, stagger 92+, standing attacker",
		target = "-",
		launch = {
			kind = "uppercut",
			edgeGap = { 0, 15 },
			height = { 0, 0 },
			stagger = { 92, 100 },
			attackerSpeed = { 0, 0 },
			spread = 20,
		},
	},
	{
		name = "(info) punched at 30 up, no stagger",
		target = "-",
		launch = {
			kind = "hook",
			edgeGap = { 0, 12 },
			height = { 25, 35 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 36 },
			spread = 20,
			vy = { -6, 0 },
		},
	},
	{
		name = "(info) hook off the edge at floor level, no stagger",
		target = "-",
		launch = {
			kind = "hook",
			edgeGap = { 0, 0 },
			height = { 0, 0 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 36 },
			spread = 20,
		},
	},
	{
		name = "(info) slid off the edge at 4-12 studs/s, no lift",
		target = "-",
		launch = {
			kind = "fallen",
			edgeGap = { 0, 1 },
			height = { 0, 0 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 0 },
			spread = 20,
			outward = { 4, 12 },
		},
	},
}

local RADII = { ARENA.StartRadius, 40, ARENA.FinalStageRadius }

local function pct(share: number): string
	return string.format("%3d%%", math.floor(share * 100 + 0.5))
end

-- How recovery falls off with launch strength: lune run lune/recovery_sim curve
if process.args[1] == "curve" then
	print(
		"uppercut from the edge: outward speed, drift past the edge with no input, typical, sharp"
	)
	for speed = 50, 200, 10 do
		local launch: Launch = {
			kind = "uppercut",
			edgeGap = { 0, 8 },
			height = { 0, 0 },
			stagger = { 0, 0 },
			attackerSpeed = { 0, 0 },
			spread = 15,
			outward = { speed - 3, speed + 3 },
		}
		local typical = run(launch, TYPICAL, ARENA.StartRadius, speed, 1 / 60)
		local sharp = run(launch, SHARP, ARENA.StartRadius, speed + 1, 1 / 60)
		print(
			string.format(
				"%4d  %5.0f  %s  %s",
				speed,
				4 + speed * speed / (2 * MOVE.KnockbackDecay),
				pct(typical),
				pct(sharp)
			)
		)
	end
	for _, height in { 15, 30, 45 } do
		print(`knocked while falling from rest, {height} up: outward speed, typical, sharp`)
		for speed = 10, 90, 10 do
			local launch: Launch = {
				kind = "hook",
				edgeGap = { 0, 8 },
				height = { height, height },
				stagger = { 0, 0 },
				attackerSpeed = { 0, 0 },
				spread = 15,
				vy = { -4, 0 },
				outward = { speed - 3, speed + 3 },
			}
			local typical = run(launch, TYPICAL, ARENA.StartRadius, speed, 1 / 60)
			local sharp = run(launch, SHARP, ARENA.StartRadius, speed + 1, 1 / 60)
			print(string.format("%4d  %s  %s", speed, pct(typical), pct(sharp)))
		end
	end
	process.exit(0)
end

-- How late can someone react and still get back? A careful player (no aim wobble, steady clicks, a
-- propel) starts at each reaction time; prints the share back per scenario.
-- lune run lune/recovery_sim window
if process.args[1] == "window" then
	local times = { 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5 }
	local header = string.format("%-54s", "scenario / reaction s")
	for _, r in times do
		header ..= string.format("%6.1f", r)
	end
	print(header)
	for index, scenario in SCENARIOS do
		if scenario.target ~= "-" then
			local line = string.format("%-54s", scenario.name)
			for _, r in times do
				local skill: Skill = {
					reaction = { r, r },
					aimError = 0,
					clickGap = { 0.15, 0.15 },
					propelChance = 1,
					steers = true,
					punches = true,
				}
				local share = run(scenario.launch, skill, ARENA.StartRadius, index, 1 / 60)
				line ..= string.format("%5d%%", math.floor(share * 100 + 0.5))
			end
			print(line)
		end
	end
	process.exit(0)
end

-- Flies one launch exactly as a Studio flight did, to compare the two: lune run lune/recovery_sim compare
-- <gap> <height> <outward> <up> <float 0|1> <seconds W went down> <punch times...>
if process.args[1] == "compare" then
	local a = process.args
	local gap, height, outward, up = tonumber(a[2]), tonumber(a[3]), tonumber(a[4]), tonumber(a[5])
	local floating, wAt = tonumber(a[6]) ~= 0, tonumber(a[7]) :: number
	local times = {}
	for i = 8, #a do
		table.insert(times, tonumber(a[i]))
	end
	local step = 1 / 60
	local x, y, vy = ARENA.StartRadius + (gap :: number), height :: number, up :: number
	local state = Momentum.applyKnock(Momentum.new(-1, 0), MOVE, outward :: number, 0)
	local steerX, steerZ, pushX, pushZ = 0, 0, 0, 0
	local rising = if floating then KICK.AirGravityScale else 1
	local t, nextPunch, furthest, topIn = 0, 1, x - ARENA.StartRadius, 0
	local nextSide, lastPunch, lifts, liftUntil = "Left", nil :: number?, AirRecovery.newLifts(), -1
	while t < 8 do
		local inputX = if t >= wAt then -1 else 0
		if times[nextPunch] and t >= times[nextPunch] then
			nextPunch += 1
			local wantX, wantZ = Momentum.velocity(state)
			local faceX, faceZ = Momentum.facing(state)
			local dirX, dirZ = AirRecovery.direction(inputX, 0, faceX, faceZ, MOVE.InputDeadzone)
			local side = Combat.comboSwing(PUNCH, nextSide, t, lastPunch)
			nextSide, lastPunch = Combat.nextSwing(side), t
			local over = x - ARENA.StartRadius <= LEDGE_REACH
			local floorBelow = if over and y <= AIR.LiftFloorCheck then math.max(y, 0) else nil
			local lifted = side == "Uppercut"
				and AirRecovery.canLift(AIR, lifts, vy, floorBelow, false, t)
			local addX, addZ = AirRecovery.push(
				AIR,
				wantX + steerX + pushX,
				wantZ + steerZ + pushZ,
				dirX,
				dirZ,
				if lifted then AIR.LiftForwardSpeed else nil
			)
			pushX += addX
			pushZ += addZ
			if lifted then
				lifts = AirRecovery.usedLift(lifts, t)
				liftUntil = t + AIR.LiftSeconds
				vy = AIR.LiftSpeed
			else
				vy += AirRecovery.lift(AIR, vy)
			end
		end
		if floating then
			state = Momentum.step(state, MOVE, 0, 0, true, step, "forward", 0)
		else
			state = Momentum.step(state, MOVE, inputX, 0, false, step, "forward", 0)
		end
		steerX, steerZ = DiveKick.airSteer(
			steerX,
			steerZ,
			inputX,
			0,
			KICK.LaunchSteerSpeed,
			KICK.LaunchSteerAcceleration,
			step
		)
		local wantX, wantZ = Momentum.velocity(state)
		pushX, pushZ = AirRecovery.fade(AIR, pushX, pushZ, step)
		pushX, pushZ = AirRecovery.limit(AIR, pushX, pushZ, wantX + steerX, wantZ + steerZ)
		local velX = wantX + steerX + pushX
		vy = if t < liftUntil
			then AirRecovery.liftVelocity(AIR, GRAVITY, vy - GRAVITY * step, step)
			else AirRecovery.fallVelocity(AIR, GRAVITY, rising, vy - GRAVITY * step, step)
		x += velX * step
		y += vy * step
		t += step
		local out = x - ARENA.StartRadius
		furthest = math.max(furthest, out)
		topIn = math.max(topIn, -velX)
		if y <= 0 and out <= LEDGE_REACH and y >= -LEDGE_DROP then
			print(
				string.format(
					"SIM back at %.2f s, furthest %.1f, top inward %d",
					t,
					furthest,
					topIn
				)
			)
			break
		elseif y < -LEDGE_DROP then
			print(
				string.format(
					"SIM lost at %.2f s, %.1f past the edge, furthest %.1f, top inward %d",
					t,
					out,
					furthest,
					topIn
				)
			)
			break
		end
	end
	process.exit(0)
end

print(
	`Fall scale {AIR.FallGravityScale}, max fall {AIR.MaxFallSpeed}, boost {AIR.BoostSpeed}, fade {AIR.BoostFade}, cap {AIR.MaxSpeed}, lift {AIR.UpAssist}`
)
print(
	`{TRIALS} attempts per cell. Typical player unless named. Radius {ARENA.StartRadius} unless named.\n`
)
print(
	"scenario                                              target typical sharp  late  no-punch  r40  r18"
)
for index, scenario in SCENARIOS do
	local typical = run(scenario.launch, TYPICAL, ARENA.StartRadius, index, 1 / 60)
	local sharp = run(scenario.launch, SHARP, ARENA.StartRadius, index + 100, 1 / 60)
	local late = run(scenario.launch, LATE, ARENA.StartRadius, index + 200, 1 / 60)
	local steer = run(scenario.launch, STEER_ONLY, ARENA.StartRadius, index + 300, 1 / 60)
	local r40 = run(scenario.launch, TYPICAL, RADII[2], index + 400, 1 / 60)
	local r18 = run(scenario.launch, TYPICAL, RADII[3], index + 500, 1 / 60)
	print(
		string.format(
			"%-54s %-6s %s    %s  %s  %s      %s %s",
			scenario.name,
			scenario.target,
			pct(typical),
			pct(sharp),
			pct(late),
			pct(steer),
			pct(r40),
			pct(r18)
		)
	)
end

print(
	"\nDetail, typical player: average seconds in the air, furthest past the edge, punches, top speed"
)
for index, scenario in SCENARIOS do
	local _, sum = run(scenario.launch, TYPICAL, ARENA.StartRadius, index, 1 / 60)
	print(
		string.format(
			"%-54s %.2fs  %5.1f studs  %4.1f punches  %3d studs/s",
			scenario.name,
			sum.seconds,
			sum.furthest,
			sum.punches,
			math.floor(sum.topSpeed)
		)
	)
end

print("\nFrame rate, typical player: the same scenario at 30, 60, 144 and 240 fps")
for index, scenario in SCENARIOS do
	if scenario.target ~= "-" then
		local line = string.format("%-54s", scenario.name)
		for _, fps in { 30, 60, 144, 240 } do
			local share = run(scenario.launch, TYPICAL, ARENA.StartRadius, index, 1 / fps)
			line ..= " " .. pct(share)
		end
		print(line)
	end
end

if process.args[1] == "trace" then
	print("\nOne attempt per scenario, sharp player")
	for index, scenario in SCENARIOS do
		local rng = newRng(index)
		local result = attempt(scenario.launch, SHARP, ARENA.StartRadius, rng, 1 / 60)
		print(
			`{scenario.name}: back {result.back}, {string.format("%.2f", result.seconds)} s, furthest {string.format(
				"%.1f",
				result.furthest
			)}`
		)
	end
end
