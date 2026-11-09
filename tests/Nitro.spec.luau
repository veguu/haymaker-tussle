--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local GameConfig = require("../src/shared/Config/GameConfig")
local Nitro = require("../src/shared/Core/Nitro")

local CFG: Nitro.Settings = GameConfig.Nitro :: any
local MAX_SPEED = GameConfig.Movement.MaxSpeed
local DT = 1 / 60

local function near(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- Holds (or doesn't) for `seconds`, and says how long it was active.
local function hold(state: Nitro.State, wants: boolean, seconds: number): (Nitro.State, number)
	local active = 0
	for _ = 1, math.floor(seconds / DT + 0.5) do
		state = Nitro.step(CFG, state, wants, DT)
		if state.active then
			active += DT
		end
	end
	return state, active
end

return {
	["a full bar lasts about three seconds of boost, then stops by itself"] = function()
		local state, active = hold(Nitro.new(CFG), true, 6)
		local expected = CFG.StaminaMax / CFG.DrainPerSecond
		assert(near(active, expected, 0.05), `expected about {expected} s, got {active}`)
		assert(near(active, 3, 0.25), `the design asks for roughly 3 s, got {active}`)
		assert(not state.active and state.exhausted, "it must stop and be marked run dry")
	end,

	["run dry, it stays off until enough is back, even while held"] = function()
		-- Held until the moment it runs dry.
		local state = Nitro.step(CFG, Nitro.new(CFG), true, DT)
		while state.active do
			state = Nitro.step(CFG, state, true, DT)
		end
		assert(not Nitro.canStart(CFG, state), "no restart straight away")
		local seconds = 0
		while not state.active and seconds < 30 do
			state = Nitro.step(CFG, state, true, DT)
			seconds += DT
		end
		assert(state.active, "it should come back eventually")
		local expected = CFG.RechargeDelay + CFG.ExhaustedRecharge / CFG.RechargePerSecond
		-- Held the whole time, so it waits out the delay, refills to the lockout, then runs again.
		assert(near(seconds, expected, 0.1), `expected about {expected} s, got {seconds}`)
	end,

	["it only refills after a short delay, and slowly"] = function()
		local state = hold(Nitro.new(CFG), true, 1)
		local spent = state.stamina
		state = hold(state, false, CFG.RechargeDelay * 0.9)
		assert(state.stamina == spent, "nothing comes back during the delay")
		state = hold(state, false, 1)
		assert(state.stamina > spent, "it refills after the delay")
		assert(state.stamina - spent <= CFG.RechargePerSecond * 1 + 0.01, "no faster than its rate")
	end,

	["starting needs a minimum, but a running boost carries on below it"] = function()
		local low: Nitro.State = {
			stamina = CFG.ActivateMin - 1,
			active = false,
			exhausted = false,
			ramp = 0,
			sinceUse = 0,
		}
		assert(not Nitro.step(CFG, low, true, DT).active, "can't start below the minimum")
		local running = table.clone(low)
		running.active = true
		assert(Nitro.step(CFG, running, true, DT).active, "an already running boost keeps going")
	end,

	["the boost level rises on a smooth S-curve and never jumps"] = function()
		local state = Nitro.new(CFG)
		local last = Nitro.level(CFG, state)
		assert(last == 0, "no boost at rest")
		local biggest = 0
		for _ = 1, math.floor(CFG.RampSeconds / DT) + 1 do
			state = Nitro.step(CFG, state, true, DT)
			local level = Nitro.level(CFG, state)
			assert(level >= last, "the level never falls while boosting")
			biggest = math.max(biggest, level - last)
			last = level
		end
		assert(near(last, 1, 0.001), `full boost by the end of the ramp, got {last}`)
		assert(biggest < 0.1, `no frame should jump, the largest step was {biggest}`)
	end,

	["full boost doubles top speed and makes turning harder"] = function()
		assert(near(Nitro.topSpeed(CFG, MAX_SPEED, 1), MAX_SPEED * 2, 0.001), "double at full")
		assert(Nitro.topSpeed(CFG, MAX_SPEED, 0) == MAX_SPEED, "normal with none")
		assert(Nitro.turnScale(CFG, 0) == 1, "full turning with none")
		assert(near(Nitro.turnScale(CFG, 1), CFG.TurnScale, 0.001), "reduced at full")
		assert(CFG.TurnScale > 0, "still steerable")
	end,

	["letting go ends it at once, and stopping keeps what's left"] = function()
		local state = hold(Nitro.new(CFG), true, 1)
		local left = state.stamina
		state = Nitro.step(CFG, state, false, DT)
		assert(not state.active, "released means off")
		local stopped = Nitro.stop(hold(Nitro.new(CFG), true, 1))
		assert(not stopped.active and stopped.ramp == 0, "a stop is off and back to no boost")
		assert(near(stopped.stamina, left, 0.01), "stopping keeps the stamina")
	end,

	["a boosted dash costs stamina only if there's enough"] = function()
		local full = Nitro.new(CFG)
		local spent, ok = Nitro.spend(full, CFG.DashStaminaCost)
		assert(ok and spent.stamina == CFG.StaminaMax - CFG.DashStaminaCost, "it takes the cost")
		local poor = table.clone(full)
		poor.stamina = CFG.DashStaminaCost - 1
		local same, paid = Nitro.spend(poor, CFG.DashStaminaCost)
		assert(not paid and same.stamina == poor.stamina, "not enough means nothing taken")
	end,
}
