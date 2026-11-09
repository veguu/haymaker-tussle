--!strict
-- Tuning tool, not a test. Prints how the movement settings answer the player: how long and
-- how far each control takes, on the real rules. Add a line to compare other values.
-- Run from the project folder: lune run lune/control_sim
local GameConfig = require("../src/shared/Config/GameConfig")
local Momentum = require("../src/shared/Core/Momentum")

local STEP = 1 / 60

local function running(cfg: any): any
	local state = Momentum.new(0, -1)
	state.speed = cfg.MaxSpeed
	state.forwardCoast = true
	return state
end

-- Holds one input until `done` says stop. Returns seconds and studs travelled.
local function measure(
	cfg: any,
	state: any,
	x: number,
	z: number,
	drive: any,
	done: (any) -> boolean
): (number, number)
	local seconds, studs = 0, 0
	while seconds < 15 and not done(state) do
		state = Momentum.step(state, cfg, x, z, true, STEP, drive, 0)
		local vx, vz = Momentum.velocity(state)
		studs += math.sqrt(vx * vx + vz * vz) * STEP
		seconds += STEP
	end
	return seconds, studs
end

local function stopped(state: any): boolean
	return state.speed <= 1
end

local function report(label: string, changes: { [string]: number })
	local cfg: any = table.clone(GameConfig.Movement)
	for key, value in changes do
		cfg[key] = value
	end
	local top = function(state: any): boolean
		return state.speed >= cfg.MaxSpeed - 0.01
	end
	local reversed = function(state: any): boolean
		return state.headingZ >= 0.99 and state.speed >= cfg.MaxSpeed * 0.8
	end
	local startS = measure(cfg, Momentum.new(0, -1), 0, -1, "forward", top)
	local coastS, coastD = measure(cfg, running(cfg), 0, 0, nil, stopped)
	local brakeS, brakeD = measure(cfg, running(cfg), 0, 1, "back", stopped)
	local sideStart = Momentum.new(1, 0)
	sideStart.speed = cfg.MaxSpeed
	local sideS, sideD = measure(cfg, sideStart, 0, 0, nil, stopped)
	-- Turning all the way round at full speed by pointing the camera behind you and holding W.
	local turnS = measure(cfg, running(cfg), 0, 1, "forward", reversed)
	print(
		string.format(
			"%-8s top speed %.2fs | let go of W %.1fs %.0f studs | S stop %.2fs %.0f studs | A/D stop %.2fs %.0f studs | turn round %.2fs",
			label,
			startS,
			coastS,
			coastD,
			brakeS,
			brakeD,
			sideS,
			sideD,
			turnS
		)
	)
end

report("was", {
	Acceleration = 28,
	CoastFallSeconds = 2.9,
	BrakeDeceleration = 30,
	SideStopDeceleration = 28,
	ReverseDeceleration = 18,
})
report("current", {})
