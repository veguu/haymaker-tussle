--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- UI Phase 0e: tweens come from the motion tokens, exits are quicker than entrances, and reduced motion keeps
-- every state change but drops movement.
local Motion = require("../src/shared/Core/Motion")
local Tokens = require("../src/shared/Tokens")

local M = Tokens.motion

return {
	["a tween takes its seconds and easing from the tokens"] = function()
		local s, style, dir = Motion.resolve(M, "base", "enter", "fade", false)
		assert(s == 0.22 and style == "Quint" and dir == "Out")
		s, style, dir = Motion.resolve(M, "quick", "exit", "move", false)
		assert(s == 0.14 and style == "Quad" and dir == "In")
	end,

	["exits are quicker than entrances, and a release slower than a press"] = function()
		assert(M.duration.quick < M.duration.base)
		assert(M.duration.press < M.duration.release)
		assert(M.easing.exit.direction == "In" and M.easing.enter.direction == "Out")
	end,

	["reduced motion: nothing moves or scales, fades are short, colour is untouched"] = function()
		assert(Motion.resolve(M, "panel", "enter", "move", true) == 0)
		assert(Motion.resolve(M, "press", "enter", "scale", true) == 0)
		assert(Motion.resolve(M, "ceremony", "enter", "fade", true) == Motion.REDUCED_FADE)
		assert(Motion.resolve(M, "micro", "enter", "fade", true) == M.duration.micro) -- already short
		assert(Motion.resolve(M, "base", "linear", "colour", true) == M.duration.base)
	end,

	["without reduced motion every kind keeps its full time"] = function()
		for _, kind in { "fade", "move", "scale", "colour" } do
			assert(
				Motion.resolve(M, "panel", "enter", kind :: any, false) == M.duration.panel,
				kind
			)
		end
	end,

	["a list builds in 0.03 s apart and never takes longer than 0.4 s"] = function()
		assert(Motion.stagger(1) == 0)
		assert(math.abs(Motion.stagger(3) - 0.06) < 1e-9)
		assert(Motion.stagger(100) == Motion.STAGGER_CAP)
	end,

	["an unknown token fails loudly"] = function()
		assert(not pcall(Motion.resolve, M, "slowish", "enter", "fade", false))
		assert(not pcall(Motion.resolve, M, "base", "wobble", "fade", false))
	end,
}
