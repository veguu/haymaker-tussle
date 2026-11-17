--!strict
-- Text roles, resolved (UI Phase 0c, 2026-11-15). Pure, no Roblox globals, so tests/TypeRoles.spec.luau can
-- check it in Lune; Shared/Typography turns the answers into Font objects.
--
-- Source of truth: Tokens.type (the Voltline scale since 2026-11-16, vault UI Research/Design System/Typography), passed in
-- by the caller because Core modules require nothing. The old role names every screen still uses (Headline, Stat, Button, ...) are ALIASES: they take the new role's face and
-- weight but KEEP THEIR OLD SIZE, so no existing box overflows while screens are rebuilt one by one (Phase 1+).
-- Aliases go in Phase 7.

local TypeRoles = {}

-- Enum.FontWeight names and their numbers.
TypeRoles.WEIGHT = {
	Thin = 100,
	ExtraLight = 200,
	Light = 300,
	Regular = 400,
	Medium = 500,
	SemiBold = 600,
	Bold = 700,
	ExtraBold = 800,
	Heavy = 900,
}

local NAME_OF: { [number]: string } = {}
for name, n in TypeRoles.WEIGHT do
	NAME_OF[n] = name
end

-- The weights each face really has, measured in Studio 2026-11-14 (TextService:GetFamilyInfoAsync,
-- research_notes/roblox_fonts_measured.md). Only Montserrat goes to 900.
TypeRoles.AVAILABLE = {
	text = { 200, 300, 400, 600, 700, 900 }, -- Titillium Web (measured 2026-11-16: no 500, no 800)
	display = { 200, 300, 400, 600, 700, 900 }, -- Titillium Web again: Black is its 900
	mono = { 300, 400, 700 }, -- Builder Mono
}

-- old role -> new role, and the old size it keeps (Technical Architecture 3.3).
TypeRoles.ALIASES = {
	Headline = { role = "display.l", size = 40 },
	Winner = { role = "display.l", size = 34 },
	Announce = { role = "headline", size = 20 },
	Stat = { role = "numeral.l", size = 32 },
	StatSmall = { role = "numeral.m", size = 18 },
	Action = { role = "title", size = 17 },
	Button = { role = "button", size = 17 },
	Name = { role = "body.strong", size = 16 },
	Key = { role = "label", size = 15 },
	Value = { role = "mono.small", size = 15 },
	Label = { role = "label", size = 15 },
	Body = { role = "body", size = 16 },
	World = { role = "body.strong", size = 16 },
}

-- Roblox's PreferredTextSize setting -> multiplier for reading text (design judgment, fit to be measured).
TypeRoles.TEXT_SCALE = { Medium = 1, Large = 1.15, Larger = 1.3, Largest = 1.5 }

export type Resolved = {
	role: string, -- the new role it resolves to
	face: string, -- "text" | "display" | "mono"
	weight: string, -- an Enum.FontWeight name the face really has
	size: number,
	lineHeight: number,
	italic: boolean, -- slanted (display headings and numerals)
	scalable: boolean, -- follows PreferredTextSize (not numerals or display calls)
}

--- The nearest weight the face really has (ties go heavier, so a 500 on Extended reads 600, not 400).
function TypeRoles.snap(face: string, weight: string): string
	local want = TypeRoles.WEIGHT[weight]
	assert(want, `unknown weight {weight}`)
	local list = TypeRoles.AVAILABLE[face]
	assert(list, `unknown face {face}`)
	local best = list[1]
	for _, n in list do
		if math.abs(n - want) <= math.abs(best - want) then
			best = n
		end
	end
	return NAME_OF[best]
end

type TokenRole = {
	face: string,
	weight: string,
	size: number,
	lineHeight: number,
	italic: boolean?,
}
type TokenSet = { type: { [string]: TokenRole }, textFloor: number }

--- A role name (new or old) resolved to face, weight, size and line height, from the given Tokens.
--- Errors on an unknown name.
function TypeRoles.resolve(Tokens: TokenSet, name: string): Resolved
	local alias = TypeRoles.ALIASES[name]
	local roleName = if alias then alias.role else name
	local role = Tokens.type[roleName]
	assert(role, `no text role {name}`)
	local prefix = string.match(roleName, "^(%a+)")
	return {
		role = roleName,
		face = role.face,
		weight = TypeRoles.snap(role.face, role.weight),
		size = math.max(if alias then alias.size else role.size, Tokens.textFloor),
		lineHeight = math.max(role.lineHeight, 1),
		italic = role.italic == true,
		scalable = prefix ~= "numeral" and prefix ~= "display",
	}
end

--- The multiplier for a PreferredTextSize name; anything unknown reads as 1.
function TypeRoles.textScale(preferred: string?): number
	return (preferred and TypeRoles.TEXT_SCALE[preferred]) or 1
end

return TypeRoles
