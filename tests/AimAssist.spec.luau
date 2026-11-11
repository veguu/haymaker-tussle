--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- Lock-on is aim assist, not an aim lock: it leans the camera, the keys and a punch toward the one you
-- picked, a little, and never takes control.
local AimAssist = require("../src/shared/Core/AimAssist")
local GameConfig = require("../src/shared/Config/GameConfig")

local CFG: any = GameConfig.LockOn

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- The same turn the camera makes with CFrame.Angles(0, angle, 0).
local function turned(x: number, z: number, angle: number): (number, number)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c + z * s, -x * s + z * c
end

return {
	["turnBetween is the turn CFrame.Angles makes"] = function()
		for _, pair in
			{ { 1, 0, 0, -1 }, { 0, -1, 1, 0 }, { 0.6, 0.8, -0.8, 0.6 }, { 1, 0, -1, 0.001 } }
		do
			local angle = AimAssist.turnBetween(pair[1], pair[2], pair[3], pair[4])
			local x, z = turned(pair[1], pair[2], angle)
			local size = math.sqrt(pair[3] ^ 2 + pair[4] ^ 2)
			assert(
				near(x, pair[3] / size, 1e-6) and near(z, pair[4] / size, 1e-6),
				`({pair[1]}, {pair[2]}) to ({pair[3]}, {pair[4]}) went to ({x}, {z})`
			)
		end
		assert(AimAssist.turnBetween(0, 0, 1, 0) == 0)
	end,

	["the camera eases toward them, and never all the way in one frame"] = function()
		local dt = 1 / 60
		local gap = math.rad(40)
		local step = AimAssist.cameraYaw(CFG, gap, dt, false)
		assert(step > 0 and step < gap * 0.2, `one frame turned {math.deg(step)} of 40 degrees`)
		-- A second of it closes most of the gap, but you can always turn away faster than it pulls.
		local left = gap
		for _ = 1, 60 do
			left -= AimAssist.cameraYaw(CFG, left, dt, false)
		end
		assert(left < gap * 0.5, `after a second still {math.deg(left)} degrees off`)
		assert(left > 0, "it locked on exactly: that's an aim lock")
		-- The other way round turns the other way.
		assert(AimAssist.cameraYaw(CFG, -gap, dt, false) < 0)
	end,

	["turning the camera yourself weakens the pull, and someone well to the side isn't pulled toward"] = function()
		local dt = 1 / 60
		local free = AimAssist.cameraYaw(CFG, math.rad(30), dt, false)
		local steering = AimAssist.cameraYaw(CFG, math.rad(30), dt, true)
		assert(steering > 0 and steering < free * 0.5, "your own turning should win")
		local behind = AimAssist.cameraYaw(CFG, math.rad(CFG.AssistCameraDegrees + 5), dt, false)
		assert(behind == 0, "it dragged the camera round to someone off to the side")
		assert(AimAssist.cameraYaw(CFG, 0 / 0, dt, false) == 0, "NaN turned the camera")
	end,

	["the keys bend partway toward them, only when already roughly their way"] = function()
		-- Keys straight ahead (-Z), target 30 degrees to one side.
		local tx, tz = turned(0, -1, math.rad(30))
		local x, z = AimAssist.bendInput(CFG, 0, -1, tx, tz)
		local bent = AimAssist.turnBetween(0, -1, x, z)
		assert(near(bent, math.rad(30) * CFG.AssistInputShare, 1e-6), `bent {math.deg(bent)}`)
		assert(near(math.sqrt(x * x + z * z), 1, 1e-6), "the push changed length")
		-- A half-pushed stick stays half pushed.
		local hx, hz = AimAssist.bendInput(CFG, 0, -0.5, tx, tz)
		assert(near(math.sqrt(hx * hx + hz * hz), 0.5, 1e-6))
		-- Keys pointing well away from them are left alone.
		local ax, az = turned(0, -1, math.rad(CFG.AssistInputDegrees + 10))
		local kx, kz = AimAssist.bendInput(CFG, 0, -1, ax, az)
		assert(kx == 0 and kz == -1, "it steered keys that weren't heading their way")
		-- No keys, no movement.
		local nx, nz = AimAssist.bendInput(CFG, 0, 0, tx, tz)
		assert(nx == 0 and nz == 0)
	end,

	["a punch turns you to face them only when they're close and roughly in front"] = function()
		local fx, fz = AimAssist.punchFacing(CFG, 0, -1, 2, -5)
		assert(fx and fz, "close and in front: should face them")
		local size = math.sqrt(4 + 25)
		assert(near(fx, 2 / size, 1e-6) and near(fz, -5 / size, 1e-6))
		local farX = AimAssist.punchFacing(CFG, 0, -1, 0, -(CFG.AssistPunchReach + 1))
		assert(farX == nil, "it turned you toward someone out of reach")
		local sx, sz = turned(0, -1, math.rad(CFG.AssistPunchDegrees + 10))
		local sideX = AimAssist.punchFacing(CFG, 0, -1, sx * 5, sz * 5)
		assert(sideX == nil, "it turned you toward someone well to the side")
	end,

	["the assisted punch never reaches further than a punch does"] = function()
		local punch: any = GameConfig.Punch
		local reach = punch.Range * (1 + punch.ChargeReach) + punch.TargetRadius
		assert(
			CFG.AssistPunchReach <= reach + 2,
			"turning to face someone that far away is a free dash, not a punch"
		)
	end,
}
