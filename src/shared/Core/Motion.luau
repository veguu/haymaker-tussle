--!strict
-- Motion rules (UI Phase 0e, 2026-11-15). Pure, no Roblox globals, so tests/Motion.spec.luau checks them in Lune;
-- Ui/HudMotion turns the answers into tweens. Source: Tokens.motion (vault UI Research/Design System/Animation
-- and Motion), passed in by the caller because Core modules require nothing.
--
-- Reduced motion (Roblox's setting or the game's own toggle): nothing moves or scales; fades still fade but
-- take at most REDUCED_FADE; colour changes are untouched. State always changes, only the motion goes.

local Motion = {}

Motion.REDUCED_FADE = 0.1
Motion.STAGGER_STEP = 0.03 -- per item in a list that builds in
Motion.STAGGER_CAP = 0.4 -- the whole list's delay never exceeds this

export type Kind = "fade" | "move" | "scale" | "colour"

type Easing = { style: string, direction: string }
type MotionTokens = { duration: { [string]: number }, easing: { [string]: Easing } }

--- Seconds, easing style name and direction name for a tween, from the duration and easing tokens, the kind
--- of change and whether motion is reduced. Zero seconds means "set it at once". Errors on an unknown token.
function Motion.resolve(
	motion: MotionTokens,
	durationToken: string,
	easingToken: string,
	kind: Kind,
	reduced: boolean
): (number, string, string)
	local seconds = motion.duration[durationToken]
	assert(seconds, `unknown duration token {durationToken}`)
	local easing = motion.easing[easingToken]
	assert(easing, `unknown easing token {easingToken}`)
	if reduced then
		if kind == "move" or kind == "scale" then
			seconds = 0
		elseif kind == "fade" then
			seconds = math.min(seconds, Motion.REDUCED_FADE)
		end
	end
	return seconds, easing.style, easing.direction
end

--- The delay before item `index` (1-based) of a list that builds in.
function Motion.stagger(index: number): number
	return math.min(Motion.STAGGER_STEP * math.max(index - 1, 0), Motion.STAGGER_CAP)
end

return Motion
