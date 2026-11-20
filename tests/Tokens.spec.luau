--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
-- The Ringside tokens (palette A, Ringside Night, 2026-11-16) keep the rules the design system promises: readable
-- contrast, the 4-unit grid, the 15-unit text floor.
local Tokens = require("../src/shared/Tokens")

local function channel(v: number): number
	v /= 255
	return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex: string): number
	local r = tonumber(hex:sub(2, 3), 16) :: number
	local g = tonumber(hex:sub(4, 5), 16) :: number
	local b = tonumber(hex:sub(6, 7), 16) :: number
	return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

local function contrast(a: string, b: string): number
	local la, lb = luminance(Tokens.hex[a]), luminance(Tokens.hex[b])
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

local TEXT = {
	"ivory.50",
	"ivory.200",
	"stone.300",
	"stone.500",
	"coral.300", -- the red-orange for text; coral.500 is for fills and marks (and text on ink.900 only)
	"teal.400",
	"gold.400",
}
local SURFACES = { "ink.900", "ink.800", "ink.700" }

return {
	["every colour is a 6-digit HEX"] = function()
		for name, hex in Tokens.hex do
			assert(hex:match("^#%x%x%x%x%x%x$"), `{name} = {hex} is not #RRGGBB`)
		end
	end,

	["the palette's measured contrasts hold (to 0.1)"] = function()
		local expect = {
			{ "ivory.50", "ink.900", 14.39 },
			{ "coral.300", "ink.900", 12.55 },
			{ "coral.500", "ink.900", 10.92 },
			{ "teal.400", "ink.900", 6.18 },
			{ "gold.400", "ink.900", 10.92 },
			{ "stone.500", "ink.900", 6.20 },
			{ "danger.600", "ink.900", 4.55 },
		}
		for _, e in expect do
			local got = contrast(e[1], e[2])
			assert(math.abs(got - e[3]) < 0.1, `{e[1]} on {e[2]}: {got}, the palette says {e[3]}`)
		end
	end,

	["every essential text token reads at 4.5:1 or better on every solid surface"] = function()
		for _, t in TEXT do
			if not Tokens.nonEssentialText[t] then
				for _, s in SURFACES do
					local c = contrast(t, s)
					assert(c >= 4.5, `{t} on {s} is {c}:1`)
				end
			end
		end
	end,

	["accent buttons take ink text at 4.5:1 or better"] = function()
		for _, fill in { "ivory.50", "gold.400", "teal.400", "coral.500", "danger.600" } do
			local c = contrast("ink.950", fill)
			assert(c >= 4.5, `ink.950 on {fill} is {c}:1`)
		end
	end,

	["the words on the HUD panel that carry state read at 4.5:1 or better"] = function()
		-- stagger's CRITICAL and the pink of your own name are text on ink.900 only
		for _, tone in { "danger.600", "coral.500" } do
			local c = contrast(tone, "ink.900")
			assert(c >= 4.5, `{tone} on ink.900 is {c}:1`)
		end
	end,

	["the cut-corner images are named and sliced inside their 96 px"] = function()
		for _, key in { "fill", "line", "flag" } do
			assert(string.match(Tokens.cut[key], "^rbxassetid://%d+$"), key)
		end
		local c = Tokens.cut.slice
		assert(c[1] < c[3] and c[2] < c[4] and c[3] <= 96 and c[4] <= 96)
		assert(Tokens.cut.scale > 0 and Tokens.cut.scale <= 1)
	end,

	["spacing sits on the 4-unit grid and grows"] = function()
		local prev = 0
		for i, v in Tokens.space do
			assert(v % 4 == 0, `space.{i} = {v} is off the 4-unit grid`)
			assert(v > prev, `space.{i} does not grow`)
			prev = v
		end
		assert(#Tokens.space == 8, "eight spacing steps")
	end,

	["no type role is under the 15-unit floor"] = function()
		for role, t in Tokens.type do
			assert(t.size >= Tokens.textFloor, `{role} is {t.size}`)
			assert(Tokens.family[t.face], `{role} has an unknown face {t.face}`)
		end
	end,

	["HUD panels stay at 12 % transparency or less"] = function()
		assert(Tokens.surface[1].transparency <= 0.12)
		for level = 1, 3 do
			assert(
				Tokens.hex[Tokens.surface[level].colour :: string],
				`surface {level} colour is not a token`
			)
		end
	end,

	["every easing names a style and a direction; durations are short"] = function()
		for name, e in Tokens.motion.easing do
			assert(type(e.style) == "string" and type(e.direction) == "string", name)
		end
		for name, d in Tokens.motion.duration do
			assert(d >= 0 and d <= 1, `{name} = {d}`)
		end
	end,
}
