--!strict
local UltimateMeter = require("../src/shared/Core/UltimateMeter")
local GameConfig = require("../src/shared/Config/GameConfig")

local CFG: any = GameConfig.Ultimate

local function string(state: UltimateMeter.State, at: number): (UltimateMeter.State, number)
	for _ = 1, 3 do
		state = UltimateMeter.gain(CFG, state, CFG.StunHitGain, at)
		at += 0.45
	end
	state = UltimateMeter.gain(CFG, state, CFG.FinisherGain, at)
	return state, at + 1
end

return {
	["four full strings fill it, three don't"] = function()
		local state, at = UltimateMeter.new(), 0
		for _ = 1, 3 do
			state, at = string(state, at)
		end
		assert(not UltimateMeter.ready(CFG, state), `three strings: {state.value}`)
		state, at = string(state, at)
		assert(UltimateMeter.ready(CFG, state), `four strings: {state.value}`)
		assert(state.value == CFG.Max, "never past full")
	end,

	["it waits DrainDelaySeconds after a hit, then drains"] = function()
		local state = UltimateMeter.gain(CFG, UltimateMeter.new(), 40, 10)
		state = UltimateMeter.step(CFG, state, 10 + CFG.DrainDelaySeconds - 0.1, 1)
		assert(state.value == 40, "no drain before the delay")
		state = UltimateMeter.step(CFG, state, 10 + CFG.DrainDelaySeconds + 1, 1)
		assert(math.abs(state.value - (40 - CFG.DrainPerSecond)) < 0.001, `drained {state.value}`)
		for i = 1, 60 do
			state = UltimateMeter.step(CFG, state, 20 + i, 1)
		end
		assert(state.value == 0, "never below empty")
	end,

	["full, it holds for ReadyHoldSeconds, hits keep it, then it drains and isn't ready"] = function()
		local state = UltimateMeter.gain(CFG, UltimateMeter.new(), CFG.Max, 0)
		state = UltimateMeter.step(CFG, state, CFG.ReadyHoldSeconds - 0.5, 0.5)
		assert(UltimateMeter.ready(CFG, state), "still ready inside the hold")
		state = UltimateMeter.gain(CFG, state, CFG.StunHitGain, CFG.ReadyHoldSeconds - 0.5)
		state = UltimateMeter.step(CFG, state, CFG.ReadyHoldSeconds + 1, 0.1)
		assert(UltimateMeter.ready(CFG, state), "a hit while full starts the hold again")
		state = UltimateMeter.step(CFG, state, CFG.ReadyHoldSeconds * 2 + 1, 0.01)
		assert(not UltimateMeter.ready(CFG, state), "after the hold: not ready")
	end,

	["using it empties it; nonsense gains do nothing"] = function()
		local state = UltimateMeter.gain(CFG, UltimateMeter.new(), CFG.Max, 0)
		state = UltimateMeter.spend(state)
		assert(state.value == 0 and not UltimateMeter.ready(CFG, state))
		assert(UltimateMeter.gain(CFG, state, 0 / 0, 1).value == 0, "NaN")
		assert(UltimateMeter.gain(CFG, state, -5, 1).value == 0, "negative")
	end,
}
