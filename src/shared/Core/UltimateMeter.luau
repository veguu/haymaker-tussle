--!strict
-- UltimateMeter - the ultimate meter's rules, as plain maths with no Roblox instances (2026-11-15).
--
-- Landing hits fills it (GameConfig.Ultimate: a stunning punch, a string's last punch and an attack skill
-- each give their own amount; four full strings fill it). After DrainDelaySeconds without landing one it
-- drains at DrainPerSecond. FULL, it is READY and holds for ReadyHoldSeconds; every hit landed while full
-- starts that hold again. After the hold it drains like any other time, and is no longer ready. Using the
-- ultimate empties it.

local UltimateMeter = {}

export type Settings = {
	Max: number,
	DrainDelaySeconds: number,
	DrainPerSecond: number,
	ReadyHoldSeconds: number,
}

export type State = {
	value: number,
	lastHitAt: number, -- when a hit last landed
	fullAt: number?, -- when it last became (or was kept) full
}

function UltimateMeter.new(): State
	return { value = 0, lastHitAt = -math.huge, fullAt = nil }
end

--- Is it full, so the ultimate can be used?
function UltimateMeter.ready(cfg: Settings, state: State): boolean
	return state.value >= cfg.Max
end

--- A hit landed at `now` worth `amount`. Returns the new state.
function UltimateMeter.gain(cfg: Settings, state: State, amount: number, now: number): State
	if amount ~= amount or amount <= 0 then
		return state
	end
	local value = math.min(state.value + amount, cfg.Max)
	return {
		value = value,
		lastHitAt = now,
		fullAt = if value >= cfg.Max then now else nil,
	}
end

--- `dt` seconds pass, ending at `now`. Returns the new state.
function UltimateMeter.step(cfg: Settings, state: State, now: number, dt: number): State
	if state.value <= 0 or dt <= 0 then
		return state
	end
	local draining
	if state.value >= cfg.Max then
		draining = state.fullAt == nil or now - state.fullAt >= cfg.ReadyHoldSeconds
	else
		draining = now - state.lastHitAt >= cfg.DrainDelaySeconds
	end
	if not draining then
		return state
	end
	-- Draining from full drops below full at once, so it is not ready a moment longer.
	local value = math.max(state.value - cfg.DrainPerSecond * dt, 0)
	if state.value >= cfg.Max then
		value = math.min(value, cfg.Max - 0.001)
	end
	return { value = value, lastHitAt = state.lastHitAt, fullAt = nil }
end

--- Used: empty.
function UltimateMeter.spend(state: State): State
	return { value = 0, lastHitAt = state.lastHitAt, fullAt = nil }
end

return UltimateMeter
