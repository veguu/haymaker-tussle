--!strict
-- The "Fight Poster" design tokens (the owner's fourth direction, 2026-11-16: everything reworked from reference
-- videos; the look is in the vault's UI Research/fight-poster-prototype.html and its colour-system card). They
-- replace Ringside, Voltline and Golden Hour. Every colour, space, radius, surface, motion and type number the
-- interface uses: screens never use a literal; they read these. Pure data at the top level (no Roblox globals)
-- so Lune can load it for tests/Tokens.spec.luau.
--
-- ONE COLOUR SYSTEM (the owner: colours must complement each other, never a mix of unrelated hues):
--   two neutrals: a deep VIOLET ink and a cream paper; three print inks with jobs; one light violet for quiet
--   things; eight class colours as one warm-to-cool sweep at even brightness.
-- THE TOKEN NAMES ARE JOBS, not paints (kept since Golden Hour so old screens follow every palette change):
--   ink.*    surfaces: 950 the INK of every outline and lip, 900 panel, 800 sheet, 700 card, 600 well / header /
--            empty track, 500 raised or picked card
--   ivory.*  cream text and neutral marks        stone.*  quiet and disabled text (violet greys)
--   coral.*  YELLOW = the primary action (buy, do it), YOU, the tab or card you are on. Same hue as gold on
--            purpose: yellow is the opposite of the violet ink, so it is the loudest accent.
--   teal.*   CYAN   = READY, equip, owned, on    gold.*   YELLOW = coins, the ultimate, rising stagger, wins
--   danger   MAGENTA = critical, warnings, close line.*  500 = outline ink, 300 = the faint inner edge
--   violet   LIGHT VIOLET = the gamepad focus ring and quiet controls

-- SOFT PALETTE (the owner, 2026-11-19: "less vibrant and easier on the eyes ... lighter", from two reference
-- clips: a butter-yellow flower and a pastel toy room). Every name keeps its job; only the paint changed: the
-- ink is a dusty plum instead of near-black violet, the cream is the same paper, and yellow, cyan, magenta and
-- the class sweep are pastels at even lightness. Ink text on every accent stays above 4.5:1 (Tokens.spec).

local Tokens = {}

Tokens.hex = {
	["ink.950"] = "#3A2E4D",
	["ink.900"] = "#43365A",
	["ink.800"] = "#4A3D62",
	["ink.700"] = "#52456B",
	["ink.600"] = "#3D3151",
	["ink.500"] = "#6B5D86",
	["stone.500"] = "#A9A1C4",
	["stone.300"] = "#CFC9E2",
	["ivory.200"] = "#F2EADB",
	["ivory.50"] = "#FFF9EC",
	["coral.700"] = "#C9A84C",
	["coral.500"] = "#FADF7F",
	["coral.300"] = "#FDEDB4",
	["teal.700"] = "#62AABB",
	["teal.400"] = "#A5DFEC",
	["teal.200"] = "#D6F2F8",
	-- the Equip button alone (the owner, 2026-11-17: a vibrant, cool green, easier to notice than the cyan)
	["go.400"] = "#A3E2BB",
	-- its opposite: the Equipped button under the pointer, where it offers to take the class off
	["stop.400"] = "#F29A9A",
	["gold.600"] = "#C9A84C",
	["gold.400"] = "#FADF7F",
	["gold.200"] = "#FDF1C4",
	["danger.600"] = "#F5A6C0",
	["line.500"] = "#3A2E4D",
	["line.300"] = "#8A7EA8",
	["violet.400"] = "#DAD3F7",
	-- the fight-poster mockup's own darks, used as drawn there: a skill tile that is cooling or can't be used,
	-- its stripes, and an unlit stagger segment
	["poster.dark"] = "#6E667D",
	["poster.stripe"] = "#8A8299",
	["poster.unlit"] = "#7D758C",
	-- one colour per class, as ONE sweep from warm to cool at even brightness (Base yellow, Bruiser orange,
	-- Inferno red-orange, Beast red-pink, Trickster pink, Dragon violet, Frost blue, Tempest teal), so any two
	-- sit well together. Marks and card art only, never state.
	["class.Base"] = "#FADF7F",
	["class.Tempest"] = "#97E0D3",
	["class.Inferno"] = "#F7AC92",
	["class.Frost"] = "#A3CEF5",
	["class.Beast"] = "#F4A0AE",
	["class.Dragon"] = "#C8B0F5",
	["class.Bruiser"] = "#F9C488",
	["class.Trickster"] = "#F5ABDB",
	-- the timing meter's own scale
	["meter.red"] = "#EC8A8C",
	["meter.orange"] = "#F3B07A",
	["meter.yellow"] = "#F4DB84",
	["meter.green"] = "#8FD6A6",
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
	-- the fight-poster HUD and menus (2026-11-16): the mockup's two faces at fixed sizes. Oswald Bold for numbers,
	-- key caps and big words; Titillium Web Bold for labels. The size here is only a default: each use sets the
	-- mockup's own pixel size through Ui/Poster, which knows how Roblox's text sizes map to a browser's.
	["poster.display"] = {
		face = "poster",
		weight = "Bold",
		size = 24,
		lineHeight = 1.0,
		case = "upper",
	},
	-- ONE FACE since 2026-11-19 (the owner: "keep the numbers and words for everything [at] consistent quality
	-- ... the stagger frame looks more bolded than the rest"): labels were Titillium Web Bold, lighter and wider
	-- than the Oswald Bold of the numbers, key caps and big words beside them. Now both roles are Oswald Bold.
	["poster.label"] = {
		face = "poster",
		weight = "Bold",
		size = 23,
		lineHeight = 1.0,
		case = "upper",
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
	-- Oswald since 2026-11-19 (was TitilliumWeb.json): the owner wants ONE weight of lettering everywhere, so the
	-- older pieces (clash bar, kick meter, kick prompt, tutorial, training panel) follow the poster UI. Oswald has
	-- no Heavy face: a role asking for Heavy gets its Bold.
	display = "rbxasset://fonts/families/Oswald.json",
	poster = "rbxasset://fonts/families/Oswald.json", -- the fight-poster look's numbers and big words
	text = "rbxasset://fonts/families/TitilliumWeb.json",
	mono = "rbxasset://fonts/families/BuilderMono.json",
	-- the coach's notes (ui-19d): the small descriptive lines, as if written on the poster with a brush pen. A
	-- stock Roblox family with a Bold face (checked with TextService:GetFamilyInfoAsync, 2026-11-18).
	note = "rbxasset://fonts/families/Kalam.json",
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
