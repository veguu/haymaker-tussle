--!strict
-- GroundBreak - the shape of the floor breaking under a jump, as plain maths with no Roblox instances.
--
-- Everything is measured on the floor: x and z along it from the feet, y straight up out of it, and 0
-- is the floor's surface. FxController turns this into parts. Nothing here can touch gameplay.

local GroundBreak = {}

export type Settings = {
	GroundBreakSeconds: number,
	GroundFadeSeconds: number,
	GroundChunks: number,
	GroundChunkSizeMin: number,
	GroundChunkSizeMax: number,
	GroundChunkOutMin: number,
	GroundChunkOutMax: number,
	GroundChunkUpMin: number,
	GroundChunkUpMax: number,
	GroundChunkGravity: number,
	GroundChunkBounce: number,
	GroundSlabs: number,
	GroundSlabRing: number,
	GroundSlabLengthMin: number,
	GroundSlabLengthMax: number,
	GroundSlabWidthMin: number,
	GroundSlabWidthMax: number,
	GroundSlabThickness: number,
	GroundSlabTiltMin: number,
	GroundSlabTiltMax: number,
	GroundSlabRiseSeconds: number,
	GroundSlabSinkSeconds: number,
	GroundCracks: number,
	GroundCrackLengthMin: number,
	GroundCrackLengthMax: number,
	GroundCrackWidth: number,
	GroundCrackBend: number,
	GroundPits: number,
	GroundPitSize: number,
}

export type Chunk = {
	x: number,
	z: number,
	outX: number,
	outZ: number,
	up: number,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	spinX: number,
	spinY: number,
	spinZ: number,
	dark: number,
}

export type Slab = {
	x: number,
	z: number,
	angle: number,
	tilt: number,
	length: number,
	width: number,
	dark: number,
}

-- A flat dark mark on the floor: a stretch of crack, or part of the hole under the feet.
export type Mark = {
	x: number,
	z: number,
	angle: number,
	length: number,
	width: number,
	delay: number,
}

export type Plan = {
	chunks: { Chunk },
	slabs: { Slab },
	cracks: { Mark },
	pits: { Mark },
}

local CRACK_PIECES = 3
local CRACK_SPREAD_SECONDS = 0.07
local MAX_SPIN = 9

local function between(random: () -> number, low: number, high: number): number
	return low + (high - low) * random()
end

--- Lays out one break. `random` returns 0 to 1, so a test can pin it.
function GroundBreak.plan(cfg: Settings, random: () -> number): Plan
	local plan: Plan = { chunks = {}, slabs = {}, cracks = {}, pits = {} }

	for index = 1, cfg.GroundChunks do
		local angle = (index / cfg.GroundChunks) * math.pi * 2 + random() * 0.5
		local dirX, dirZ = math.cos(angle), math.sin(angle)
		local start = cfg.GroundSlabRing * 0.6 * random()
		local out = between(random, cfg.GroundChunkOutMin, cfg.GroundChunkOutMax)
		table.insert(plan.chunks, {
			x = dirX * start,
			z = dirZ * start,
			outX = dirX * out,
			outZ = dirZ * out,
			up = between(random, cfg.GroundChunkUpMin, cfg.GroundChunkUpMax),
			sizeX = between(random, cfg.GroundChunkSizeMin, cfg.GroundChunkSizeMax),
			sizeY = between(random, cfg.GroundChunkSizeMin, cfg.GroundChunkSizeMax),
			sizeZ = between(random, cfg.GroundChunkSizeMin, cfg.GroundChunkSizeMax),
			spinX = between(random, -MAX_SPIN, MAX_SPIN),
			spinY = between(random, -MAX_SPIN, MAX_SPIN),
			spinZ = between(random, -MAX_SPIN, MAX_SPIN),
			dark = random() * 0.3,
		})
	end

	for index = 1, cfg.GroundSlabs do
		-- Uneven on purpose, like the smoke: a neat ring reads as a shape, not broken floor.
		local angle = (index / cfg.GroundSlabs) * math.pi * 2 + random() * 0.45
		local ring = cfg.GroundSlabRing * between(random, 0.85, 1.2)
		table.insert(plan.slabs, {
			x = math.cos(angle) * ring,
			z = math.sin(angle) * ring,
			angle = angle,
			tilt = math.rad(between(random, cfg.GroundSlabTiltMin, cfg.GroundSlabTiltMax)),
			length = between(random, cfg.GroundSlabLengthMin, cfg.GroundSlabLengthMax),
			width = between(random, cfg.GroundSlabWidthMin, cfg.GroundSlabWidthMax),
			dark = random() * 0.2,
		})
	end

	for index = 1, cfg.GroundCracks do
		local angle = (index / cfg.GroundCracks) * math.pi * 2 + random() * 0.6
		local x, z =
			math.cos(angle) * cfg.GroundSlabRing * 0.4, math.sin(angle) * cfg.GroundSlabRing * 0.4
		local piece = between(random, cfg.GroundCrackLengthMin, cfg.GroundCrackLengthMax)
			/ CRACK_PIECES
		for step = 1, CRACK_PIECES do
			local nextX, nextZ = x + math.cos(angle) * piece, z + math.sin(angle) * piece
			table.insert(plan.cracks, {
				x = (x + nextX) / 2,
				z = (z + nextZ) / 2,
				angle = angle,
				length = piece,
				width = cfg.GroundCrackWidth * (1 - (step - 1) / (CRACK_PIECES + 1)),
				delay = (step - 1) / CRACK_PIECES * CRACK_SPREAD_SECONDS,
			})
			x, z = nextX, nextZ
			angle += math.rad(between(random, -cfg.GroundCrackBend, cfg.GroundCrackBend))
		end
	end

	for _ = 1, cfg.GroundPits do
		local angle = random() * math.pi * 2
		local shift = random() * cfg.GroundPitSize * 0.15
		table.insert(plan.pits, {
			x = math.cos(angle) * shift,
			z = math.sin(angle) * shift,
			angle = random() * math.pi,
			length = cfg.GroundPitSize * between(random, 0.6, 1),
			width = cfg.GroundPitSize * between(random, 0.6, 1),
			delay = 0,
		})
	end

	return plan
end

--- Where a thrown chunk is `t` seconds in: flies, bounces once, then lies still until it shrinks away.
--- Returns x, y, z, the seconds of tumbling so far (it stops when the chunk stops), and its scale.
function GroundBreak.chunkAt(
	cfg: Settings,
	chunk: Chunk,
	t: number
): (number, number, number, number, number)
	local gravity = cfg.GroundChunkGravity
	local rest = math.min(chunk.sizeX, chunk.sizeY, chunk.sizeZ) / 2
	local flight = 2 * chunk.up / gravity
	local after = math.max(t - flight, 0)
	local bounceUp = chunk.up * cfg.GroundChunkBounce
	local bounceFlight = 2 * bounceUp / gravity

	local height, travel
	if t < flight then
		height = chunk.up * t - 0.5 * gravity * t * t
		travel = t
	else
		local bounced = math.min(after, bounceFlight)
		height = bounceUp * bounced - 0.5 * gravity * bounced * bounced
		travel = flight + bounced * cfg.GroundChunkBounce
	end

	local fadeFrom = cfg.GroundBreakSeconds - cfg.GroundFadeSeconds
	local scale = 1 - math.clamp((t - fadeFrom) / cfg.GroundFadeSeconds, 0, 1)
	return chunk.x + chunk.outX * travel,
		rest + math.max(height, 0),
		chunk.z + chunk.outZ * travel,
		math.min(t, flight + bounceFlight),
		scale
end

--- How far out of the floor a slab stands: 0 buried, 1 fully up. Bursts out, holds, sinks back.
function GroundBreak.slabShare(cfg: Settings, t: number): number
	local rising = math.clamp(t / cfg.GroundSlabRiseSeconds, 0, 1)
	local left = 1 - rising
	local up = 1 - left * left
	local sinking = math.clamp((cfg.GroundBreakSeconds - t) / cfg.GroundSlabSinkSeconds, 0, 1)
	return up * (sinking * sinking * (3 - 2 * sinking))
end

--- How faded the dark marks on the floor are: 0 solid, 1 gone.
function GroundBreak.markFade(cfg: Settings, t: number): number
	return math.clamp(
		(t - (cfg.GroundBreakSeconds - cfg.GroundFadeSeconds)) / cfg.GroundFadeSeconds,
		0,
		1
	)
end

return GroundBreak
