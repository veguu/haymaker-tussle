--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local LockCamera = require("../src/shared/Core/LockCamera")

local CFG: LockCamera.Settings = {
	BaseDistance = 13,
	DistancePerStud = 0.12,
	MinDistance = 11,
	MaxDistance = 24,
	YawMaxDegrees = 420,
	PitchUpMax = 55,
	PitchDownMax = 45,
	HoldFlat = 3,
	FullFlat = 10,
	OrbitYawMax = 30,
	OrbitPitchMax = 18,
	OrbitReturnDelay = 1.5,
	OrbitReturnRate = 1.2,
	PullOutRate = 6,
	MinPull = 3,
}

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 0.0001)
end

local RATE = 13
local MAX_SPEED = math.rad(420)

-- Runs a second of following at this frame rate.
local function follow(fps: number, from: number, to: number): number
	local value = from
	for _ = 1, fps do
		value = LockCamera.smooth(value, to, RATE, 1 / fps)
	end
	return value
end

return {
	["smoothing lands in the same place at any frame rate"] = function()
		local at60 = LockCamera.smooth(0, 100, RATE, 0.25)
		for _, fps in { 32, 60, 144, 240 } do
			local value = 0
			for _ = 1, fps / 4 do
				value = LockCamera.smooth(value, 100, RATE, 1 / fps)
			end
			assert(near(value, at60, 0.01), `{fps} fps gave {value} against {at60}`)
		end
	end,

	["smoothing is quick and never passes its target"] = function()
		local value = 0
		for _ = 1, 600 do
			value = LockCamera.smooth(value, 10, RATE, 1 / 60)
			assert(value <= 10, `overshot to {value}`)
		end
		assert(LockCamera.smooth(0, 10, RATE, 0.2) > 9, "90% of the way within 0.2 s")
		assert(follow(30, 0, 10) > 9.99, "settled within a second")
	end,

	["angles turn the short way across the wraparound"] = function()
		assert(
			near(LockCamera.angleBetween(math.rad(170), math.rad(-170)), math.rad(20)),
			"forward"
		)
		assert(near(LockCamera.angleBetween(math.rad(-170), math.rad(170)), math.rad(-20)), "back")
		local after = LockCamera.smoothAngle(math.rad(170), math.rad(-170), RATE, MAX_SPEED, 1 / 60)
		assert(after > math.rad(170), "goes up through 180, not back through 0")
	end,

	["someone crossing behind you can't whip the camera round"] = function()
		for _, fps in { 30, 60, 144 } do
			local dt = 1 / fps
			local after = LockCamera.smoothAngle(0, math.rad(179), RATE, MAX_SPEED, dt)
			assert(after <= MAX_SPEED * dt + 0.00001, `{fps} fps moved {math.deg(after)} degrees`)
			assert(after > 0, "but it does move")
		end
		-- Half a turn takes a visible moment, and it's the same moment at any frame rate.
		local function secondsToTurn(fps: number): number
			local yaw, t = 0, 0
			while math.abs(LockCamera.angleBetween(yaw, math.rad(179))) > math.rad(5) do
				yaw = LockCamera.smoothAngle(yaw, math.rad(179), RATE, MAX_SPEED, 1 / fps)
				t += 1 / fps
			end
			return t
		end
		assert(secondsToTurn(60) > 0.35 and secondsToTurn(60) < 0.6, `took {secondsToTurn(60)} s`)
		assert(near(secondsToTurn(30), secondsToTurn(144), 0.05), "same at 30 and 144 fps")
	end,

	["the yaw and look direction agree, with no roll involved"] = function()
		for _, target in { { 0, 0, -10 }, { 10, 0, 0 }, { -6, 4, 8 }, { 3, -7, -2 } } do
			local yaw, pitch = LockCamera.angleTo(0, 0, 0, target[1], target[2], target[3])
			local x, y, z = LockCamera.look(yaw, pitch)
			local size = math.sqrt(target[1] ^ 2 + target[2] ^ 2 + target[3] ^ 2)
			assert(near(x, target[1] / size, 0.001), "x")
			assert(near(y, target[2] / size, 0.001), "y")
			assert(near(z, target[3] / size, 0.001), "z")
		end
	end,

	["zoom grows with distance apart, inside its limits"] = function()
		assert(LockCamera.zoom(CFG, 0) == 13, "close")
		assert(LockCamera.zoom(CFG, 40) > 17 and LockCamera.zoom(CFG, 40) < 19, "medium")
		assert(LockCamera.zoom(CFG, 500) == 24, "never further than the limit")
	end,

	["straight above or below you, the yaw holds still"] = function()
		assert(LockCamera.yawShare(CFG, 0) == 0, "overhead")
		assert(LockCamera.yawShare(CFG, 3) == 0, "at the hold distance")
		assert(LockCamera.yawShare(CFG, 6.5) == 0.5, "easing back in")
		assert(LockCamera.yawShare(CFG, 40) == 1, "normal")
		local before = 1
		assert(
			LockCamera.smoothAngle(
				before,
				-2,
				RATE * LockCamera.yawShare(CFG, 1),
				MAX_SPEED,
				1 / 60
			) == before,
			"it doesn't move at all"
		)
	end,

	["the mouse moves the view within its limits, the expected way"] = function()
		local yaw, pitch = LockCamera.orbit(CFG, 0, 0, 10, 5)
		assert(near(yaw, math.rad(-10)) and near(pitch, math.rad(-5)), "right and down")
		yaw, pitch = LockCamera.orbit(CFG, 0, 0, 500, -500)
		assert(near(yaw, math.rad(-30)) and near(pitch, math.rad(18)), "stops at the limits")
	end,

	["the view only drifts back once the mouse has been left alone"] = function()
		assert(LockCamera.orbitSettle(CFG, 0.3, 0.2, 1 / 60) == 0.3, "hands off while moving")
		assert(LockCamera.orbitSettle(CFG, 0.3, 2, 1 / 60) < 0.3, "eases back after")
		assert(LockCamera.orbitSettle(CFG, 0.3, 2, 1 / 60) > 0.29, "and gently")
	end,

	["pitch stays comfortable, however high they are"] = function()
		assert(near(LockCamera.finalPitch(CFG, math.rad(89), 0), math.rad(55)), "up")
		assert(near(LockCamera.finalPitch(CFG, math.rad(-89), 0), math.rad(-45)), "down")
		assert(
			near(LockCamera.finalPitch(CFG, math.rad(50), math.rad(18)), math.rad(55)),
			"with the mouse"
		)
		assert(near(LockCamera.finalPitch(CFG, math.rad(10), math.rad(5)), math.rad(15)), "normal")
	end,

	["the camera comes in at once for a wall and goes back out slowly"] = function()
		assert(LockCamera.pull(CFG, 15, 6, 1 / 60) == 6, "in at once, never through it")
		local out = LockCamera.pull(CFG, 6, 15, 1 / 60)
		assert(out > 6 and out < 7, `back out slowly, got {out}`)
		assert(LockCamera.pull(CFG, 15, 0.5, 1 / 60) == 3, "never right inside your head")
	end,

	["entering and leaving ease at both ends"] = function()
		assert(LockCamera.blendShare(0) == 0 and LockCamera.blendShare(1) == 1, "ends")
		assert(LockCamera.blendShare(0.5) == 0.5, "middle")
		assert(LockCamera.blendShare(0.1) < 0.1, "soft start")
		assert(LockCamera.blendShare(5) == 1 and LockCamera.blendShare(-5) == 0, "kept in range")
	end,
}
