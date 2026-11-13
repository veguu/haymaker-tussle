--!strict
-- HexBarrier - the hexagon barrier's maths, with no Roblox instances: the hexagon grid, how far the pattern
-- has drifted, where the upward sweep is, and how bright each hexagon near a player is.
--
-- Everything is measured on a wall's face in PIXELS, x to the right and y DOWN, as someone inside the lobby
-- sees it. The pattern is a grid of pointy-top hexagons that repeats every `periodX` across and `periodY`
-- down (two rows). The drawn pattern is one image tiled at exactly that period, so sliding it by any amount
-- and wrapping at a period can't show a seam, a reset or a gap.

local HexBarrier = {}

export type Grid = {
	periodX: number, -- pixels between hexagons in a row; also a hexagon's width
	periodY: number, -- pixels for two rows
	rowY: number, -- pixels between rows
	cellHeight: number, -- a hexagon's height
	pixelsPerStud: number,
}

export type Offset = {
	x: number, -- whole pixels the pattern sits right of its start, 0 to periodX - 1
	y: number, -- whole pixels down, 0 to periodY - 1
	fracX: number, -- what's left over, 0 to 1 of a pixel (the wall itself is nudged by this)
	fracY: number,
	wrapsX: number, -- whole periods drifted so far, so a hexagon keeps its identity
	wrapsY: number,
}

local ROOT3 = math.sqrt(3)
local KEY_SPAN = 8192
local KEY_HALF = 4096

--- The grid for hexagons `hexSize` studs from centre to corner, drawn at `pixelsPerStud`. Periods are
--- whole, even pixels, so rows and half-steps land on whole pixels too.
function HexBarrier.grid(hexSize: number, pixelsPerStud: number): Grid
	local periodX = math.max(2, 2 * math.round(ROOT3 * hexSize * pixelsPerStud / 2))
	local rowY = math.max(2, math.round(1.5 * hexSize * pixelsPerStud))
	return {
		periodX = periodX,
		periodY = rowY * 2,
		rowY = rowY,
		cellHeight = math.round(rowY * 4 / 3),
		pixelsPerStud = pixelsPerStud,
	}
end

--- Which way the pattern drifts, in studs a second (x right, y down): D1 up-right, D2 up-left,
--- D3 down-right, D4 down-left. Anything else is D1.
function HexBarrier.driftVelocity(direction: string, speed: number): (number, number)
	local diagonal = speed * math.sqrt(0.5)
	if direction == "D2" then
		return -diagonal, -diagonal
	elseif direction == "D3" then
		return diagonal, diagonal
	elseif direction == "D4" then
		return -diagonal, diagonal
	end
	return diagonal, -diagonal
end

--- Where the pattern is `seconds` in, drifting at (vx, vy) studs a second.
function HexBarrier.offset(grid: Grid, vx: number, vy: number, seconds: number): Offset
	local dx = vx * grid.pixelsPerStud * seconds
	local dy = vy * grid.pixelsPerStud * seconds
	local wrapsX = math.floor(dx / grid.periodX)
	local wrapsY = math.floor(dy / grid.periodY)
	local restX = dx - wrapsX * grid.periodX
	local restY = dy - wrapsY * grid.periodY
	local wholeX = math.min(math.floor(restX), grid.periodX - 1)
	local wholeY = math.min(math.floor(restY), grid.periodY - 1)
	return {
		x = wholeX,
		y = wholeY,
		fracX = math.clamp(restX - wholeX, 0, 1),
		fracY = math.clamp(restY - wholeY, 0, 1),
		wrapsX = wrapsX,
		wrapsY = wrapsY,
	}
end

--- The centre of hexagon (i, j), in pixels from the pattern's own corner.
function HexBarrier.cellCentre(grid: Grid, i: number, j: number): (number, number)
	return grid.periodX * (i + 0.5 * (j % 2)), grid.rowY * j
end

function HexBarrier.key(i: number, j: number): number
	return (i + KEY_HALF) * KEY_SPAN + (j + KEY_HALF)
end

function HexBarrier.unkey(key: number): (number, number)
	return key // KEY_SPAN - KEY_HALF, key % KEY_SPAN - KEY_HALF
end

--- 1 at the player, easing to 0 at `radius`.
function HexBarrier.falloff(distance: number, radius: number): number
	if radius <= 0 or distance >= radius then
		return 0
	end
	local x = 1 - distance / radius
	return x * x * (3 - 2 * x)
end

--- A soft ring travelling outward: 0 to 1, a crest every `length` studs, moving at `speed`.
function HexBarrier.ripple(distance: number, seconds: number, speed: number, length: number): number
	if length <= 0 then
		return 0.5
	end
	return 0.5 + 0.5 * math.cos((distance - speed * seconds) * 2 * math.pi / length)
end

--- A sparse spark: most hexagons give 0; about `chance` of them flash once per `every` seconds.
function HexBarrier.spark(
	i: number,
	j: number,
	seconds: number,
	every: number,
	chance: number
): number
	if every <= 0 or chance <= 0 then
		return 0
	end
	local slot = math.floor(seconds / every)
	local roll = math.sin(i * 127.1 + j * 311.7 + slot * 74.7) * 43758.5453
	roll -= math.floor(roll)
	if roll >= chance then
		return 0
	end
	return math.sin((seconds / every - slot) * math.pi)
end

--- How bright one hexagon is, 0 to 1: `distance` studs from the player (through the air, so stepping back
--- from the wall dims it), in the given style. R1 glow + ripple, R2 glow only, R3 glow + sparse sparks.
function HexBarrier.brightness(
	cfg: any,
	distance: number,
	seconds: number,
	i: number,
	j: number
): number
	local wide = HexBarrier.falloff(distance, cfg.ProximityRadius)
	if wide <= 0 then
		return 0
	end
	-- Two tiers, as in the reference: lines showing over the whole radius, and a bright core by the player.
	local mid: number = cfg.ProximityMidBrightness
	local glow = mid * wide + (1 - mid) * HexBarrier.falloff(distance, cfg.ProximityCoreRadius)
	local style = cfg.ProximityStyle
	if style == "R2" then
		return glow
	elseif style == "R3" then
		local spark = HexBarrier.spark(i, j, seconds, cfg.SparkSeconds, cfg.SparkChance)
		-- sparks reach a little further out than the steady glow: the square root is wider
		return math.clamp(glow * 0.8 + spark * math.sqrt(glow), 0, 1)
	end
	local wave = HexBarrier.ripple(distance, seconds, cfg.RippleSpeed, cfg.RippleLength)
	return math.clamp(glow * (1 + cfg.RippleStrength * (2 * wave - 1)), 0, 1)
end

--- Adds one player's glow to `into` (hexagon key -> brightness, the brightest player winning).
--- The player is at pattern pixel (x, y), `depth` studs off the wall, glowing at `strength` (0 to 1).
--- `wrapsX`/`wrapsY` come from the offset, so a spark stays on its hexagon as the pattern wraps.
--- `minY`/`maxY` are the pattern rows worth lighting (the wall's top and bottom).
function HexBarrier.accumulate(
	cfg: any,
	grid: Grid,
	into: { [number]: number },
	x: number,
	y: number,
	depth: number,
	strength: number,
	seconds: number,
	wrapsX: number,
	wrapsY: number,
	minY: number,
	maxY: number
)
	local radius = cfg.ProximityRadius
	if strength <= 0 or depth >= radius then
		return
	end
	local pps = grid.pixelsPerStud
	local reach = math.sqrt(radius * radius - depth * depth) * pps
	local periodX, rowY = grid.periodX, grid.rowY
	local j0 = math.ceil(math.max(y - reach, minY) / rowY)
	local j1 = math.floor(math.min(y + reach, maxY) / rowY)
	for j = j0, j1 do
		local shift = 0.5 * (j % 2) * periodX
		local cy = rowY * j
		for i = math.ceil((x - reach - shift) / periodX), math.floor((x + reach - shift) / periodX) do
			local cx = periodX * i + shift
			local flatX, flatY = (cx - x) / pps, (cy - y) / pps
			local distance = math.sqrt(flatX * flatX + flatY * flatY + depth * depth)
			local value = strength
				* HexBarrier.brightness(cfg, distance, seconds, i - wrapsX, j - 2 * wrapsY)
			if value > 0.004 then
				local key = (i + KEY_HALF) * KEY_SPAN + (j + KEY_HALF)
				local had = into[key]
				if not had or value > had then
					into[key] = value
				end
			end
		end
	end
end

--- Where the sweep's middle is, in studs below the wall's top, or nil while it rests between passes.
--- It starts just under the bottom, leaves just over the top, then waits `SweepGapSeconds`.
function HexBarrier.sweep(cfg: any, seconds: number): number?
	if cfg.SweepSpeed <= 0 or cfg.SweepStrength <= 0 then
		return nil
	end
	local travel = cfg.Height + 2 * cfg.SweepWidth
	local pass = travel / cfg.SweepSpeed
	local phase = seconds % (pass + cfg.SweepGapSeconds)
	if phase >= pass then
		return nil
	end
	return cfg.Height + cfg.SweepWidth - phase * cfg.SweepSpeed
end

--- How much of the wall shows `below` studs under its top edge: 0 at the top, 1 from `TopFade` down.
function HexBarrier.topFade(cfg: any, below: number): number
	if cfg.TopFade <= 0 then
		return if below >= 0 then 1 else 0
	end
	return math.clamp(below / cfg.TopFade, 0, 1)
end

--- A player's glow strength a moment later: rising while they're in reach, falling once they aren't.
function HexBarrier.ease(cfg: any, strength: number, near: boolean, dt: number): number
	if near then
		return if cfg.FadeInSeconds <= 0 then 1 else math.min(1, strength + dt / cfg.FadeInSeconds)
	end
	return if cfg.FadeOutSeconds <= 0 then 0 else math.max(0, strength - dt / cfg.FadeOutSeconds)
end

return HexBarrier
