--!strict
-- Nitro - the boost's stamina and ramp, as plain maths with no Roblox instances.
--
-- STAMINA. Holding the boost while allowed to drains it at DrainPerSecond. Anything else, after
-- RechargeDelay without spending, refills it at RechargePerSecond. Starting needs ActivateMin. Running it
-- dry stops the boost and marks it exhausted: it can't start again until ExhaustedRecharge is back, so an
-- empty bar can't be tapped for flickers of speed.
--
-- RAMP. `ramp` goes 0 to 1 over RampSeconds while boosting, and back over RampDownSeconds after. The
-- boost `level` is that ramp on an S-curve (RampCurve above 1): gentle at first, strongest in the middle,
-- settling into the top. Top speed and the loss of turning both follow the level, so neither ever jumps.
--
-- The client runs this for its own body. The server runs the same rules on its own clock, only to decide
-- whether the trail everyone sees may show and whether a boosted dash is allowed.

local Nitro = {}

export type Settings = {
	SpeedMultiplier: number,
	RampSeconds: number,
	RampCurve: number,
	RampAcceleration: number,
	RampDownSeconds: number,
	StaminaMax: number,
	DrainPerSecond: number,
	RechargeDelay: number,
	RechargePerSecond: number,
	ActivateMin: number,
	ExhaustedRecharge: number,
	TurnScale: number,
	ReleaseDeceleration: number,
	DashStaminaCost: number,
}

export type State = {
	stamina: number,
	active: boolean,
	exhausted: boolean,
	ramp: number,
	-- Seconds since stamina was last spent, for the recharge delay.
	sinceUse: number,
}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Nitro.new(cfg: Settings): State
	return {
		stamina = cfg.StaminaMax,
		active = false,
		exhausted = false,
		ramp = 0,
		sinceUse = math.huge,
	}
end

--- Could the boost start right now?
function Nitro.canStart(cfg: Settings, state: State): boolean
	if state.exhausted then
		return state.stamina >= cfg.ExhaustedRecharge
	end
	return state.stamina >= cfg.ActivateMin
end

--- One step. `wants` is whether the boost is held and allowed this step. Returns a new state.
function Nitro.step(cfg: Settings, state: State, wants: boolean, dt: number): State
	local nextState = table.clone(state)
	if not isFinite(dt) or dt <= 0 then
		return nextState
	end
	if nextState.exhausted and nextState.stamina >= cfg.ExhaustedRecharge then
		nextState.exhausted = false
	end
	local active = wants and (state.active or Nitro.canStart(cfg, nextState))
	if active then
		nextState.stamina = math.max(nextState.stamina - cfg.DrainPerSecond * dt, 0)
		nextState.sinceUse = 0
		nextState.ramp = math.min(nextState.ramp + dt / math.max(cfg.RampSeconds, 0.001), 1)
		if nextState.stamina <= 0 then
			active = false
			nextState.exhausted = true
		end
	else
		nextState.sinceUse += dt
		nextState.ramp = math.max(nextState.ramp - dt / math.max(cfg.RampDownSeconds, 0.001), 0)
		if nextState.sinceUse >= cfg.RechargeDelay then
			nextState.stamina =
				math.min(nextState.stamina + cfg.RechargePerSecond * dt, cfg.StaminaMax)
		end
	end
	nextState.active = active
	return nextState
end

--- Stops the boost at once, keeping whatever stamina is left. For being moved, held or respawned.
function Nitro.stop(state: State): State
	local nextState = table.clone(state)
	nextState.active = false
	nextState.ramp = 0
	return nextState
end

--- Takes `amount` of stamina if there's that much. Returns the new state and whether it was taken.
function Nitro.spend(state: State, amount: number): (State, boolean)
	if state.stamina < amount then
		return state, false
	end
	local nextState = table.clone(state)
	nextState.stamina -= amount
	nextState.sinceUse = 0
	return nextState, true
end

--- How boosted, 0 to 1: the ramp on an S-curve.
function Nitro.level(cfg: Settings, state: State): number
	local x = math.clamp(state.ramp, 0, 1)
	local curve = math.max(cfg.RampCurve, 0.01)
	local up, down = x ^ curve, (1 - x) ^ curve
	if up + down <= 0 then
		return 0
	end
	return up / (up + down)
end

--- Top speed at this boost level.
function Nitro.topSpeed(cfg: Settings, maxSpeed: number, level: number): number
	return maxSpeed * (1 + (cfg.SpeedMultiplier - 1) * math.clamp(level, 0, 1))
end

--- The share of the normal turn rate at this boost level.
function Nitro.turnScale(cfg: Settings, level: number): number
	return 1 - (1 - cfg.TurnScale) * math.clamp(level, 0, 1)
end

--- The share of the bar that's full.
function Nitro.share(cfg: Settings, state: State): number
	return math.clamp(state.stamina / math.max(cfg.StaminaMax, 0.001), 0, 1)
end

return Nitro
