--!strict
-- HudLogic - the HUD's rules as plain functions, so they can be tested without Studio: what state an
-- action tile is in, how full a cooldown is, how the speed gauge reads past normal running speed,
-- when a number changes enough to redraw, what the round strip says, and what a ring-out feed line
-- says. HudController only draws what these return.

local HudLogic = {}

export type ActionState = "ready" | "recovering" | "unavailable"

--- What a tile shows. Recovering wins over unavailable, so a cooldown is always visible while it runs.
function HudLogic.actionState(now: number, readyAt: number, usable: boolean): ActionState
	if now < readyAt then
		return "recovering"
	end
	return if usable then "ready" else "unavailable"
end

--- Share of a cooldown still left, 1 just after use and 0 when ready. `total` is the whole cooldown
--- that started it, including any miss recovery.
function HudLogic.cooldownLeft(now: number, readyAt: number, total: number): number
	if total <= 0 then
		return 0
	end
	return math.clamp((readyAt - now) / total, 0, 1)
end

--- The momentum gauge: `base` fills to normal running speed, and `over` is how far past it, up to
--- `overMax`, for a propel or a launch. Both are 0 to 1.
function HudLogic.speedGauge(speed: number, maxSpeed: number, overMax: number): (number, number)
	local base = math.clamp(speed / math.max(maxSpeed, 0.001), 0, 1)
	local over = 0
	if speed > maxSpeed and overMax > maxSpeed then
		over = math.clamp((speed - maxSpeed) / (overMax - maxSpeed), 0, 1)
	end
	return base, over
end

--- The speed digits only move when the real speed is more than `hysteresis` away from what's shown,
--- so they hold still while running steadily instead of flickering between two numbers.
function HudLogic.steadyDigits(shown: number, speed: number, hysteresis: number): number
	if math.abs(speed - shown) > hysteresis or (speed < 0.5 and shown ~= 0) then
		return math.floor(speed + 0.5)
	end
	return shown
end

--- Whether a stagger change earns the one short accent: only a real gain, of at least `threshold`.
function HudLogic.staggerAccent(before: number, after: number, threshold: number): boolean
	return after - before >= threshold
end

export type RoundState = {
	phase: string?, -- "Intermission", "Starting", "Fighting", "RoundOver", or nil with no round running
	alive: number?,
	total: number?,
	countdownEnd: number?, -- server time
	round: number?,
}

export type Strip = {
	visible: boolean,
	title: string,
	count: string?, -- the big number
	total: string?,
	finalTwo: boolean,
}

local function countdown(now: number, finish: number?): string
	local left = math.max(math.ceil((finish or now) - now), 0)
	return tostring(left)
end

--- What the top strip says. There's no round time limit, so a fight shows survivors, not a clock.
function HudLogic.strip(state: RoundState, now: number): Strip
	local phase = state.phase
	if phase == nil then
		return { visible = false, title = "", finalTwo = false }
	end
	if phase == "Intermission" then
		return {
			visible = true,
			title = "NEXT ROUND",
			count = countdown(now, state.countdownEnd),
			finalTwo = false,
		}
	elseif phase == "Starting" then
		return {
			visible = true,
			title = "GET READY",
			count = countdown(now, state.countdownEnd),
			finalTwo = false,
		}
	elseif phase == "RoundOver" then
		return { visible = true, title = "ROUND OVER", finalTwo = false }
	end
	local alive = state.alive or 0
	local finalTwo = alive == 2
	return {
		visible = true,
		title = if finalTwo then "FINAL TWO" elseif alive <= 1 then "LAST ONE" else "STANDING",
		count = tostring(alive),
		total = if state.total then tostring(state.total) else nil,
		finalTwo = finalTwo,
	}
end

--- One ring-out feed line. `cause` is "knocked", "fell" or "left".
function HudLogic.feedLine(victim: string, attacker: string?, cause: string): string
	if cause == "left" then
		return `{victim} left`
	elseif attacker and attacker ~= "" and cause == "knocked" then
		return `{attacker} knocked out {victim}`
	end
	return `{victim} fell`
end

--- A big entrance for a change (final two, the arena closing) only when nothing timed is on screen.
--- During a kick's timing or a clash, the change still shows, just without the emphasis.
function HudLogic.emphasize(promptActive: boolean, reducedMotion: boolean): boolean
	return not promptActive and not reducedMotion
end

--- Seconds into a stagger meter catch-up, retargeted: a new value mid-animation starts a fresh, short
--- move from wherever the bar is now, never a replay of the old ones.
function HudLogic.catchUp(from: number, to: number, elapsed: number, seconds: number): number
	if seconds <= 0 or elapsed >= seconds then
		return to
	end
	local t = elapsed / seconds
	local eased = 1 - (1 - t) * (1 - t)
	return from + (to - from) * eased
end

return HudLogic
