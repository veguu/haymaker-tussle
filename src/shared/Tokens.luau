--!strict
-- The "Ringside" design tokens (palette A "Ringside Night", picked by the owner 2026-11-16 from six; the look and
-- the navigation are in the vault's UI Research/ringside-prototype.html). They replace Voltline's Electric blue
-- (rejected: "the placeholder UI with different colours") and Golden Hour before it. Every colour, space, radius,
-- surface, motion and type number the interface uses: screens never use a literal; they read these. Pure data
-- at the top level (no Roblox globals) so Lune can load it for tests/Tokens.spec.luau.
--
-- THE TOKEN NAMES ARE JOBS, not paints (kept since Golden Hour so old screens follow every palette change):
--   ink.*    surfaces: 950 the INK of every outline and lip, 900 panel, 800 sheet, 700 card, 600 well / header /
--            empty track, 500 raised or picked card
--   ivory.*  text and neutral marks              stone.*  quiet and disabled text
--   coral.*  RED-ORANGE = the primary action (buy, do it), YOU, the tab or card you are on
--   teal.*   GREEN  = READY, equip, owned, on    gold.*   YELLOW = coins, the ultimate, rising stagger, wins
--   danger   PINK-RED = critical, warnings, close  line.*  500 = outline ink, 300 = the faint inner edge
--   violet   the gamepad focus ring (light blue)

local Tokens = {}

Tokens.hex = {
	["ink.950"] = "#05070A",
	["ink.900"] = "#171C24",
	["ink.800"] = "#1B212B",
	["ink.700"] = "#222A36",
	["ink.600"] = "#0E1116",
	["ink.500"] = "#2C3645",
	["stone.500"] = "#7C889B",
	["stone.300"] = "#9AA6B8",
	["ivory.200"] = "#DDE3EC",
	["ivory.50"] = "#F4F6FA",
	["coral.700"] = "#A82410",
	["coral.500"] = "#FF4B2B",
	["coral.300"] = "#FF8A73",
	["teal.700"] = "#1C8F54",
	["teal.400"] = "#35E08A",
	["teal.200"] = "#9DF2C6",
	["gold.600"] = "#B37F0C",
	["gold.400"] = "#FFC83D",
	["gold.200"] = "#FFE49A",
	["danger.600"] = "#FF3B5C",
	["line.500"] = "#05070A",
	["line.300"] = "#3A4656",
	["violet.400"] = "#7FD4FF",
	-- one colour per class (from the kits-4 design: Base gold, Tempest cyan, Inferno orange, Frost ice blue,
	-- Beast red, Dragon violet, Bruiser brown-gold, Trickster pink). Marks and card art only, never state.
	["class.Base"] = "#F2C94C",
	["class.Tempest"] = "#3FE0E0",
	["class.Inferno"] = "#FF6A2B",
	["class.Frost"] = "#6FB8FF",
	["class.Beast"] = "#E0344B",
	["class.Dragon"] = "#9B5CFF",
	["class.Bruiser"] = "#C98A3C",
	["class.Trickster"] = "#FF5FB8",
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

-- Restrained rounding. The look is the STICKER: a rounded tile with a 3-unit ink outline that sits on a darker
-- lip and drops onto it when pressed (Components.sticker). Tokens.cut is the older image-built panel the HUD
-- still uses until its restyle.
Tokens.radius = { s = 6, m = 9, l = 12, full = 999 }

-- The cut-corner shape: 9-slice images (white, tinted in use) with the top-right and bottom-left corners cut.
-- Sources in assets/ui (cut_fill, cut_line, cut_flag .png: 96 px, a 24 px cut, a 4 px line), uploaded
-- 2026-11-16. `scale` 0.5 gives a 12-unit cut and a 2-unit line.
Tokens.cut = {
	-- rounded since Ringside (assets/ui/round_fill, round_line, round_badge .png; the cut-corner cut_*.png of
	-- Voltline are kept on disk): a 12-unit radius and a 3-unit ink line at `scale` 0.5
	fill = "rbxassetid://76833744141686",
	line = "rbxassetid://97311833623704",
	flag = "rbxassetid://110797461255609", -- the ready badge: a dot in an ink ring, tinted green
	slice = { 32, 32, 64, 64 },
	scale = 0.5,
}

-- Surface levels: 0 = on the scene, 1 = HUD panel, 2 = menu sheet/card, 3 = dialog/toast.
Tokens.surface = {
	[0] = { colour = nil, transparency = 1 },
	[1] = { colour = "ink.900", transparency = 0.04 }, -- 0.12 is the most: past it text loses contrast on a bright arena
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
	italic: boolean?,
	face: string,
	weight: string,
	size: number,
	lineHeight: number,
	case: string,
}

-- Type scale per role. One family, Titillium Web, upright: "display" in Black for headings and numerals and
-- Bold for short caps labels, "text" for everything people read. "mono" = Builder Mono (ticking figures).
-- weight names are Enum.FontWeight names, resolved by Typography.
Tokens.type = {
	["display.xl"] = {
		face = "display",
		weight = "Heavy",
		size = 120,
		lineHeight = 1.0,
		case = "upper",
	},
	["display.l"] = {
		face = "display",
		weight = "Heavy",
		size = 64,
		lineHeight = 1.0,
		case = "upper",
	},
	["numeral.l"] = {
		face = "display",
		weight = "Heavy",
		size = 44,
		lineHeight = 1.0,
		case = "figures",
	},
	["numeral.m"] = {
		face = "display",
		weight = "Heavy",
		size = 28,
		lineHeight = 1.0,
		case = "figures",
	},
	headline = {
		face = "display",
		weight = "Heavy",
		size = 28,
		lineHeight = 1.05,
		case = "upper",
	},
	title = {
		face = "display",
		weight = "Heavy",
		size = 20,
		lineHeight = 1.1,
		case = "upper",
	},
	label = { face = "display", weight = "Bold", size = 15, lineHeight = 1.0, case = "upper" },
	["body.l"] = {
		face = "text",
		weight = "Medium",
		size = 19,
		lineHeight = 1.25,
		case = "sentence",
	},
	body = { face = "text", weight = "Regular", size = 17, lineHeight = 1.2, case = "sentence" },
	["body.strong"] = {
		face = "text",
		weight = "Bold",
		size = 17,
		lineHeight = 1.2,
		case = "sentence",
	},
	caption = {
		face = "text",
		weight = "SemiBold",
		size = 15,
		lineHeight = 1.15,
		case = "sentence",
	},
	button = {
		face = "display",
		weight = "Heavy",
		size = 17,
		lineHeight = 1.0,
		case = "upper",
	},
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
	display = "rbxasset://fonts/families/TitilliumWeb.json",
	text = "rbxasset://fonts/families/TitilliumWeb.json",
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
