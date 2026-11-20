--!strict
-- ColourMath - a fighter's comic palette worked out from ONE colour, and the colour wheel's maths (pure: plain
-- numbers 0 to 1, no Roblox types, so the specs run in Lune).
--
-- The owner, 2026-11-20 (ui-24a; seen and approved on work/burst-options.html and work/cosmetics-options.html):
-- * the word pop-ups take the palette of YOUR colour (your class colour unless you picked another in More >
--   Cosmetics): a light TINT (the colour mixed toward the newsprint cream), the colour itself and a DEEP shade
--   (the same hue, darker), with cream and ink as the neutrals; the yellow and red that were mixed in are gone.
--   Letters go ink or cream, whichever reads better on their card (`inkReads`).
-- * the countdown in RANDOM colours (the owner: "i mean like RANDOM COLORS, not random SETS of colors, so it
--   shouldnt be all purple, all blue"): each number and each TUSSLE! card its own colour, no two neighbours alike,
--   new every round. `sequence` draws them from the round's own CountdownEnd, so every player sees the same ones
--   without a message being sent.
-- * the colour wheel: hue round it (0 at the TOP, clockwise, like his picture), strength from white at the middle
--   to the full hue at the rim, brightness on a slider (design/ui/make_colour_wheel.py draws the same wheel).

export type RGB = { r: number, g: number, b: number }
export type Palette = { tone: RGB, light: RGB, deep: RGB }

local ColourMath = {}

ColourMath.PAPER = { r = 0xFF / 255, g = 0xF4 / 255, b = 0xD6 / 255 } :: RGB -- ivory.50
ColourMath.INK = { r = 0x1E / 255, g = 0x22 / 255, b = 0x33 / 255 } :: RGB -- ink.900
ColourMath.TINT = 0.55 -- how far the tint is mixed toward the cream
ColourMath.DEEPER = 0.22 -- how much lower the deep shade's lightness is
ColourMath.DEEP_FLOOR = 0.3 -- the deep shade's lightness never goes under this (it would read as ink)
ColourMath.DEEP_SATURATION = 0.9 -- the deep shade a little less saturated, so it is not harsh

local function clamp01(v: number): number
	return math.clamp(v, 0, 1)
end

function ColourMath.fromHex(hex: string): RGB
	local text = string.gsub(hex, "#", "")
	assert(#text == 6, "a colour is six hex digits")
	local r = tonumber(string.sub(text, 1, 2), 16)
	local g = tonumber(string.sub(text, 3, 4), 16)
	local b = tonumber(string.sub(text, 5, 6), 16)
	assert(r and g and b, "a colour is six hex digits")
	return { r = r / 255, g = g / 255, b = b / 255 }
end

--- Six upper-case hex digits, no "#".
function ColourMath.toHex(c: RGB): string
	return string.format(
		"%02X%02X%02X",
		math.round(clamp01(c.r) * 255),
		math.round(clamp01(c.g) * 255),
		math.round(clamp01(c.b) * 255)
	)
end

--- Six hex digits (with or without "#", any case), or nil if it is not one.
function ColourMath.parseHex(text: string): RGB?
	local clean = string.upper((string.gsub(text, "^%s*#?", "")))
	clean = string.gsub(clean, "%s+$", "")
	if not string.match(clean, "^%x%x%x%x%x%x$") then
		return nil
	end
	return ColourMath.fromHex(clean)
end

function ColourMath.mix(a: RGB, b: RGB, t: number): RGB
	return { r = a.r + (b.r - a.r) * t, g = a.g + (b.g - a.g) * t, b = a.b + (b.b - a.b) * t }
end

--- Hue 0 to 1, saturation, lightness.
function ColourMath.toHsl(c: RGB): (number, number, number)
	local high, low = math.max(c.r, c.g, c.b), math.min(c.r, c.g, c.b)
	local l = (high + low) / 2
	if high == low then
		return 0, 0, l
	end
	local d = high - low
	local s = if l > 0.5 then d / (2 - high - low) else d / (high + low)
	local h
	if high == c.r then
		h = (c.g - c.b) / d + (if c.g < c.b then 6 else 0)
	elseif high == c.g then
		h = (c.b - c.r) / d + 2
	else
		h = (c.r - c.g) / d + 4
	end
	return h / 6, s, l
end

function ColourMath.fromHsl(h: number, s: number, l: number): RGB
	if s == 0 then
		return { r = l, g = l, b = l }
	end
	local q = if l < 0.5 then l * (1 + s) else l + s - l * s
	local p = 2 * l - q
	local function part(t: number): number
		t = t % 1
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		elseif t < 1 / 2 then
			return q
		elseif t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end
	return { r = part(h + 1 / 3), g = part(h), b = part(h - 1 / 3) }
end

--- Hue 0 to 1, saturation, value (brightness).
function ColourMath.toHsv(c: RGB): (number, number, number)
	local high, low = math.max(c.r, c.g, c.b), math.min(c.r, c.g, c.b)
	local d = high - low
	local s = if high > 0 then d / high else 0
	if d == 0 then
		return 0, s, high
	end
	local h
	if high == c.r then
		h = (c.g - c.b) / d + (if c.g < c.b then 6 else 0)
	elseif high == c.g then
		h = (c.b - c.r) / d + 2
	else
		h = (c.r - c.g) / d + 4
	end
	return h / 6, s, high
end

function ColourMath.fromHsv(h: number, s: number, v: number): RGB
	local i = math.floor((h % 1) * 6)
	local f = (h % 1) * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	if i == 0 then
		return { r = v, g = t, b = p }
	elseif i == 1 then
		return { r = q, g = v, b = p }
	elseif i == 2 then
		return { r = p, g = v, b = t }
	elseif i == 3 then
		return { r = p, g = q, b = v }
	elseif i == 4 then
		return { r = t, g = p, b = v }
	end
	return { r = v, g = p, b = q }
end

local function channel(v: number): number
	return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
end

function ColourMath.luminance(c: RGB): number
	return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
end

function ColourMath.contrast(a: RGB, b: RGB): number
	local la, lb = ColourMath.luminance(a), ColourMath.luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

--- True when ink letters read better than cream ones on `face`.
function ColourMath.inkReads(face: RGB): boolean
	return ColourMath.contrast(face, ColourMath.INK) >= ColourMath.contrast(face, ColourMath.PAPER)
end

--- The colour's tint, itself and its deep shade.
function ColourMath.palette(tone: RGB): Palette
	local h, s, l = ColourMath.toHsl(tone)
	return {
		tone = tone,
		light = ColourMath.mix(tone, ColourMath.PAPER, ColourMath.TINT),
		deep = ColourMath.fromHsl(
			h,
			s * ColourMath.DEEP_SATURATION,
			math.max(ColourMath.DEEP_FLOOR, l - ColourMath.DEEPER)
		),
	}
end

--- One of `count` choices (1 to count) from a number every client sees the same (the round's CountdownEnd, in
--- seconds): the same pick everywhere, a different one round to round.
function ColourMath.pick(seed: number, count: number): number
	if count <= 1 then
		return 1
	end
	local whole = math.floor(math.abs(seed) * 1000) % 1000003
	return (whole * 7919 + 17) % count + 1
end

--- `length` picks of 1 to `count` drawn from a number every client sees the same (the round's CountdownEnd), no
--- two neighbours alike: the same list everywhere, a new one each round.
function ColourMath.sequence(seed: number, length: number, count: number): { number }
	local modulus = 2147483647
	local state = math.floor(math.abs(seed) * 1000) % modulus
	if state == 0 then
		state = 1
	end
	local picks = table.create(length)
	for index = 1, length do
		state = (state * 48271) % modulus -- (under 2^47: exact in a double)
		local pick = state % count + 1
		if count > 1 and index > 1 and pick == picks[index - 1] then
			pick = pick % count + 1
		end
		picks[index] = pick
	end
	return picks
end

--- The wheel: a point (dx, dy) from its middle, in units of its radius (y DOWN), to hue and strength. Hue 0 is at
--- the top and grows clockwise; strength is the distance out, at most 1.
function ColourMath.wheelAt(dx: number, dy: number): (number, number)
	local hue = (math.deg(math.atan2(dx, -dy)) % 360) / 360
	return hue, math.min(1, math.sqrt(dx * dx + dy * dy))
end

--- The other way: where on the wheel (dx, dy, y down, in units of its radius) a hue and strength stand.
function ColourMath.wheelPoint(hue: number, strength: number): (number, number)
	local turn = hue * 2 * math.pi
	return math.sin(turn) * strength, -math.cos(turn) * strength
end

return ColourMath
