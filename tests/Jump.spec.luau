--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The running jump and its dive kick (user, 2026-11-11), on the game's real settings.
local GameConfig = require("../src/shared/Config/GameConfig")
local Jump = require("../src/shared/Core/Jump")

local JUMP: any = GameConfig.Jump
local DIVE: any = GameConfig.Dive

return {
	["standing, a jump is a hop straight up"] = function()
		local up, forward = Jump.launch(JUMP, 0)
		assert(up == JUMP.UpBase and forward == nil)
		local _, nan = Jump.launch(JUMP, 0 / 0)
		assert(nan == nil, "NaN counts as standing")
	end,

	["moving, a jump is higher and longer the faster you go"] = function()
		local slowUp, slowForward = Jump.launch(JUMP, 15)
		local fastUp, fastForward = Jump.launch(JUMP, 50)
		assert(slowForward and fastForward, "both carry forward")
		assert(fastUp > slowUp and fastForward > slowForward)
		assert(fastForward >= 50, "never slower than the run it came from")
		local top, topForward = Jump.launch(JUMP, 10000)
		assert(top == JUMP.UpMax, "the lift is capped")
		assert(topForward == 10000, "past the cap there's no boost, but nothing is lost")
		local _, dash = Jump.launch(JUMP, JUMP.ForwardMax - 1)
		assert(dash == JUMP.ForwardMax, "the boost stops at the cap")
	end,

	["a jump has a real cooldown"] = function()
		assert(JUMP.Cooldown >= 1)
		assert(Jump.ready(JUMP, 10, nil), "the first is free")
		assert(not Jump.ready(JUMP, 10, 10 - JUMP.Cooldown + 0.1))
		assert(Jump.ready(JUMP, 10, 10 - JUMP.Cooldown))
	end,

	["a dive always goes down, and no further than its range"] = function()
		local x, y, z = Jump.diveWay(DIVE, 10, -10, 0)
		assert(math.abs(x * x + y * y + z * z - 1) < 1e-6, "a unit vector")
		assert(x > 0 and y < 0 and z == 0)
		-- Aimed level or upward: still downward.
		local _, up = Jump.diveWay(DIVE, 10, 5, 0)
		assert(up < 0)
		-- Aimed far away: the same line as the spot at full range.
		local fx, fy = Jump.diveWay(DIVE, DIVE.Range * 10, -8, 0)
		local nx, ny = Jump.diveWay(DIVE, DIVE.Range, -8, 0)
		assert(math.abs(fx - nx) < 1e-6 and math.abs(fy - ny) < 1e-6)
		-- Nothing to aim at: straight down.
		local sx, sy, sz = Jump.diveWay(DIVE, 0, 0, 0)
		assert(sx == 0 and sy == -1 and sz == 0)
		local bx, by, bz = Jump.diveWay(DIVE, 0 / 0, 0, 0)
		assert(bx == 0 and by == -1 and bz == 0)
	end,
}
