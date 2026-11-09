--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local BotBrain = require("../src/shared/Core/BotBrain")
local GameConfig = require("../src/shared/Config/GameConfig")

local CFG: any = GameConfig.TestBot
local PUNCH: any = GameConfig.Punch
local RADIUS = GameConfig.Arena.StartRadius

return {
	["runs straight at a target that's far away"] = function()
		local x, z = BotBrain.steer(CFG, RADIUS, 0, 0, 30, 0)
		assert(x == 1 and z == 0)
	end,

	["eases off when close, still facing the target"] = function()
		local x, z = BotBrain.steer(CFG, RADIUS, 0, 0, CFG.StopDistance - 0.5, 0)
		assert(math.abs(x - CFG.CloseInput) < 1e-9 and z == 0)
	end,

	["turns back at the edge instead of following you off it"] = function()
		local at = RADIUS - CFG.EdgeMargin + 2
		local x = BotBrain.steer(CFG, RADIUS, at, 0, at + 10, 0)
		assert(x < 0, "should head back in")
	end,

	["near the edge it still chases you inward"] = function()
		local at = RADIUS - CFG.EdgeMargin + 2
		local x = BotBrain.steer(CFG, RADIUS, at, 0, 0, 0)
		assert(x < 0)
	end,

	["with nobody to fight it stands, or walks back from the edge"] = function()
		local x, z = BotBrain.steer(CFG, RADIUS, 0, 0, nil, nil)
		assert(x == 0 and z == 0)
		x = BotBrain.steer(CFG, RADIUS, RADIUS - 2, 0, nil, nil)
		assert(x < 0)
	end,

	["waits for its reaction time, then its cooldown"] = function()
		assert(not BotBrain.shouldPunch(CFG, 10, nil, nil))
		assert(not BotBrain.shouldPunch(CFG, 10, 10 - CFG.ReactionSeconds / 2, nil))
		assert(BotBrain.shouldPunch(CFG, 10, 10 - CFG.ReactionSeconds - 0.001, nil))
		assert(not BotBrain.shouldPunch(CFG, 10, 0, 10 - CFG.PunchCooldown / 2))
		assert(BotBrain.shouldPunch(CFG, 10, 0, 10 - CFG.PunchCooldown - 0.001))
	end,

	["it only ever overestimates its reach, by up to the setting"] = function()
		assert(BotBrain.judgedPunch(PUNCH, CFG.MisjudgeStuds, 0).Range == PUNCH.Range)
		assert(
			BotBrain.judgedPunch(PUNCH, CFG.MisjudgeStuds, 1).Range
				== PUNCH.Range + CFG.MisjudgeStuds
		)
		assert(PUNCH.Range == GameConfig.Punch.Range, "the real settings are left alone")
	end,

	["some swings go wide"] = function()
		assert(BotBrain.isWildSwing(CFG, 0))
		assert(not BotBrain.isWildSwing(CFG, 0.999))
	end,
}
