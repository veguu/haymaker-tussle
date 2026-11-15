--!strict
-- The "Golden Hour" design tokens (approved 2026-11-15): every colour, space, radius, surface, motion and type
-- number the interface uses. Screens never use a literal; they read these. Source of truth for the values:
-- the vault's UI Research/Design System pages (Color Palette, Spacing and Layout, Shapes and Components,
-- Animation and Motion, Typography). Pure data at the top level (no Roblox globals) so Lune can load it for
-- tests/Tokens.spec.luau; Color3 values are built lazily by Tokens.colour at runtime.

local Tokens = {}

-- Colours as HEX strings. One colour, one job: coral = YOU, teal = READY/RECOVERING, gold = EARNED,
-- ivory/stone = everything neutral. The meter.* scale belongs to the air-kick meter alone.
Tokens.hex = {
	-- neutrals (warm inks, hue ~25 deg)
	["ink.950"] = "#0F0C0A", -- full-screen scrims, fade cover
	["ink.900"] = "#15110E", -- base surface: HUD panels, menu background
	["ink.800"] = "#1F1A16", -- raised surface: cards, menu panels
	["ink.700"] = "#2B241F", -- highest surface: dialogs, hovered cards
	["ink.600"] = "#3D342D", -- empty tracks, dividers on solid surfaces
	["stone.500"] = "#7E7366", -- disabled text and icons (non-essential only)
	["stone.300"] = "#B9AD9C", -- secondary text, labels, captions
	["ivory.200"] = "#EDE3D2", -- body text in long passages
	["ivory.50"] = "#FBF5EA", -- primary text, numerals, neutral marks, primary button fill
	-- accents
	["coral.700"] = "#C84634",
	["coral.500"] = "#FF6A55",
	["coral.300"] = "#FF9C8C",
	["teal.700"] = "#1E7F71",
	["teal.400"] = "#36C2AE",
	["teal.200"] = "#9FE5DA",
	["gold.600"] = "#C9952A",
	["gold.400"] = "#F4C24D",
	["gold.200"] = "#FBE3A6",
	["danger.600"] = "#E23B2E", -- fills only
	-- the timing meter's own scale
	["meter.red"] = "#E5484D",
	["meter.orange"] = "#F0883A",
	["meter.yellow"] = "#EFC94C",
	["meter.green"] = "#4CC273",
}

-- Text tokens that may sit under 4.5:1 because what they carry is never essential (Color Palette section 5).
Tokens.nonEssentialText = { ["stone.500"] = true }

-- Spacing on a 4-unit grid, in design units at the 1280x720 reference (before the HUD scale).
Tokens.space = { 4, 8, 12, 16, 24, 32, 48, 64 }

Tokens.radius = { s = 6, m = 10, l = 14, full = 999 }

-- Surface levels: 0 = on the scene, 1 = HUD panel, 2 = menu sheet/card, 3 = dialog/toast.
Tokens.surface = {
	[0] = { colour = nil, transparency = 1 },
	[1] = { colour = "ink.900", transparency = 0.12 }, -- the HUD maximum: more and coral loses contrast on paving
	[2] = { colour = "ink.800", transparency = 0 },
	[3] = { colour = "ink.700", transparency = 0 },
}

Tokens.shadow = {
	[2] = { size = 24, transparency = 0.6, offsetX = 0, offsetY = 4 },
	[3] = { size = 40, transparency = 0.5, offsetX = 0, offsetY = 8 },
}

-- Motion: durations in seconds; easings as style/direction names, resolved to Enum in HudMotion.
Tokens.motion = {
	duration = {
		instant = 0,
		press = 0.06,
		micro = 0.08,
		quick = 0.14,
		release = 0.16,
		base = 0.22,
		panel = 0.32,
		ceremony = 0.6,
		hold = 0.9,
	},
	easing = {
		enter = { style = "Quint", direction = "Out" },
		exit = { style = "Quad", direction = "In" },
		move = { style = "Quart", direction = "InOut" },
		pop = { style = "Back", direction = "Out" },
		linear = { style = "Linear", direction = "InOut" },
	},
}

-- The text floor: no text under this many design units, on any device.
Tokens.textFloor = 15

export type TypeRole = {
	face: string,
	weight: string,
	size: number,
	lineHeight: number,
	case: string,
}

-- Type scale per role. face: "display" = Builder Extended, "text" = Builder Sans, "mono" = Builder Mono.
-- weight names are Enum.FontWeight names, resolved by Typography.
Tokens.type = {
	["display.xl"] = {
		face = "display",
		weight = "ExtraBold",
		size = 120,
		lineHeight = 1.0,
		case = "upper",
	},
	["display.l"] = {
		face = "display",
		weight = "ExtraBold",
		size = 64,
		lineHeight = 1.0,
		case = "upper",
	},
	["numeral.l"] = {
		face = "display",
		weight = "ExtraBold",
		size = 44,
		lineHeight = 1.0,
		case = "figures",
	},
	["numeral.m"] = {
		face = "display",
		weight = "SemiBold",
		size = 28,
		lineHeight = 1.0,
		case = "figures",
	},
	headline = {
		face = "display",
		weight = "ExtraBold",
		size = 28,
		lineHeight = 1.05,
		case = "upper",
	},
	title = { face = "display", weight = "SemiBold", size = 20, lineHeight = 1.1, case = "upper" },
	label = { face = "display", weight = "SemiBold", size = 15, lineHeight = 1.0, case = "upper" },
	["body.l"] = {
		face = "text",
		weight = "Medium",
		size = 19,
		lineHeight = 1.25,
		case = "sentence",
	},
	body = { face = "text", weight = "Regular", size = 17, lineHeight = 1.25, case = "sentence" },
	["body.strong"] = {
		face = "text",
		weight = "Bold",
		size = 17,
		lineHeight = 1.2,
		case = "sentence",
	},
	caption = { face = "text", weight = "Medium", size = 15, lineHeight = 1.2, case = "sentence" },
	button = { face = "display", weight = "SemiBold", size = 17, lineHeight = 1.0, case = "upper" },
	["mono.timer"] = {
		face = "mono",
		weight = "Bold",
		size = 22,
		lineHeight = 1.0,
		case = "figures",
	},
	["mono.small"] = {
		face = "mono",
		weight = "Bold",
		size = 15,
		lineHeight = 1.0,
		case = "figures",
	},
} :: { [string]: TypeRole }

-- Font families for the faces above.
Tokens.family = {
	display = "rbxasset://fonts/families/BuilderExtended.json",
	text = "rbxasset://fonts/families/BuilderSans.json",
	mono = "rbxasset://fonts/families/BuilderMono.json",
}

local cache: { [string]: any } = {}

-- The Color3 for a colour token (runtime only: Lune has no Color3). Errors on an unknown name, so a typo
-- fails loudly in Studio instead of drawing black.
function Tokens.colour(name: string): Color3
	local c = cache[name]
	if c then
		return c
	end
	local hex = Tokens.hex[name]
	assert(hex, `unknown colour token "{name}"`)
	c = Color3.fromHex(hex)
	cache[name] = c
	return c
end

return Tokens
