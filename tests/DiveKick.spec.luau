--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local DiveKick = require("../src/shared/Core/DiveKick")

local CFG: DiveKick.Settings = {
	LaunchSteerStaggerLoss = 0.5,
}

return {
	["the launched can steer, and less so the more staggered they are"] = function()
		assert(DiveKick.launchSteerShare(CFG, 0, 100) == 1, "full control unhurt")
		assert(DiveKick.launchSteerShare(CFG, 100, 100) == 0.5, "half at most stagger")
	end,

	["steering pushes toward the keys, never past its limit, and no keys change nothing"] = function()
		local vx, vz = DiveKick.airSteer(3, 4, 0, 0, 26, 90, 1 / 60)
		assert(vx == 3 and vz == 4, "no keys keeps what it has")
		vx, vz = 0, 0
		for _ = 1, 120 do
			vx, vz = DiveKick.airSteer(vx, vz, 1, 0, 26, 90, 1 / 60)
		end
		assert(math.abs(vx - 26) < 1e-6 and vz == 0, `should settle at the limit, got {vx}`)
	end,
}
