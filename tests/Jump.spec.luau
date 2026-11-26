--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The running jump (user, 2026-11-11), on the game's real settings.
local GameConfig = require("../src/shared/Config/GameConfig")
local Jump = require("../src/shared/Core/Jump")

local JUMP: any = GameConfig.Jump

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
}
