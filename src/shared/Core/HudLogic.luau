--!strict
-- HudLogic - the HUD's rules as plain functions, so they can be tested without Studio: what state an
-- action tile is in, how full a cooldown is, which colour step and word your stagger shows and how many
-- segments of its bar are lit, what the round strip says, and what a ring-out feed line says.
-- HudController only draws what these return.

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

-- Golden Hour combat HUD (UI Phase 1, 2026-11-15; vault UI Specifications/Combat HUD) ---------------------

export type StaggerBand = "calm" | "rising" | "critical"

--- Your stagger's band: calm under 40 % of the max, rising to 70 %, critical from 70 %.
function HudLogic.staggerBand(value: number, max: number): StaggerBand
	local share = value / math.max(max, 1)
	if share >= 0.7 then
		return "critical"
	elseif share >= 0.4 then
		return "rising"
	end
	return "calm"
end

--- The knockback multiplier as the caption shows it: one decimal, no trailing zero dance ("1.0", "3.4", "6.0").
function HudLogic.multiplierText(multiplier: number): string
	return string.format("%.1f", math.floor(multiplier * 10 + 0.5) / 10)
end

--- Recovering: the value went down and nothing raised it for `delay` seconds (the server's recovery delay).
--- A drop sooner than that is hit relief (you landed a hit), not recovery.
function HudLogic.recovering(
	value: number,
	previous: number,
	now: number,
	lastRise: number,
	delay: number
): boolean
	return value < previous and now - lastRise >= delay
end

-- Fight-poster stagger readout (2026-11-16): a number, a 12-segment bar and one word ------------------------

export type StaggerTier = "white" | "yellow" | "pink"

--- The colour step of YOUR stagger number: white, then yellow from `yellowShare` of the max, then pink from
--- `pinkShare`. The segmented bar uses the same shares, so the number and the bar never disagree.
function HudLogic.staggerTier(
	value: number,
	max: number,
	yellowShare: number,
	pinkShare: number
): StaggerTier
	local share = value / math.max(max, 1)
	if share >= pinkShare - 1e-9 then
		return "pink"
	elseif share >= yellowShare - 1e-9 then
		return "yellow"
	end
	return "white"
end

--- How many of `count` segments are lit. Any stagger at all lights one, so the bar is never empty while the
--- number is above zero.
function HudLogic.segmentsLit(value: number, max: number, count: number): number
	if value <= 0 then
		return 0
	end
	local lit = math.floor(value / math.max(max, 1) * count + 0.5)
	return math.clamp(lit, 1, count)
end

--- The colour step of segment `index` (1 = first) of `count`, by where the segment starts.
function HudLogic.segmentTier(
	index: number,
	count: number,
	yellowShare: number,
	pinkShare: number
): StaggerTier
	local start = (index - 1) / math.max(count, 1)
	if start >= pinkShare - 1e-9 then
		return "pink"
	elseif start >= yellowShare - 1e-9 then
		return "yellow"
	end
	return "white"
end

--- The one word under the number: RISING for `risingFor` seconds after a gain, RECOVERING while it drains,
--- STEADY otherwise. A fresh gain wins over recovering.
function HudLogic.staggerWord(
	now: number,
	lastRise: number,
	risingFor: number,
	recovering: boolean
): string
	if now - lastRise < risingFor then
		return "RISING"
	elseif recovering then
		return "RECOVERING"
	end
	return "STEADY"
end

return HudLogic
