--!strict
-- Spec files are required BY the runner, so this path is relative to tests/.
local GroundBreak = require("../src/shared/Core/GroundBreak")

local CFG: GroundBreak.Settings = {
	GroundBreakSeconds = 2.6,
	GroundFadeSeconds = 0.5,
	GroundChunks = 16,
	GroundChunkSizeMin = 0.7,
	GroundChunkSizeMax = 2.4,
	GroundChunkOutMin = 8,
	GroundChunkOutMax = 26,
	GroundChunkUpMin = 26,
	GroundChunkUpMax = 80,
	GroundChunkGravity = 120,
	GroundChunkBounce = 0.28,
	GroundSlabs = 9,
	GroundSlabRing = 3.4,
	GroundSlabLengthMin = 3,
	GroundSlabLengthMax = 5,
	GroundSlabWidthMin = 2.2,
	GroundSlabWidthMax = 3.8,
	GroundSlabThickness = 0.9,
	GroundSlabTiltMin = 20,
	GroundSlabTiltMax = 50,
	GroundSlabRiseSeconds = 0.07,
	GroundSlabSinkSeconds = 0.35,
	GroundCracks = 7,
	GroundCrackLengthMin = 5,
	GroundCrackLengthMax = 11,
	GroundCrackWidth = 0.45,
	GroundCrackBend = 28,
	GroundPits = 4,
	GroundPitSize = 6,
}

local function roll(seed: number): () -> number
	-- A small repeatable generator: the test runner has no Roblox Random.
	local value = seed
	return function()
		value = (value * 16807) % 2147483647
		return value / 2147483647
	end
end

-- A chunk thrown as hard as the settings allow, the slowest to come down.
local HIGHEST: GroundBreak.Chunk = {
	x = 0,
	z = 0,
	outX = 10,
	outZ = 0,
	up = CFG.GroundChunkUpMax,
	sizeX = 2,
	sizeY = 2,
	sizeZ = 1,
	spinX = 1,
	spinY = 1,
	spinZ = 1,
	dark = 0,
}

return {
	["a plan has what the settings ask for, with three pieces per crack"] = function()
		local plan = GroundBreak.plan(CFG, roll(1))
		assert(#plan.chunks == CFG.GroundChunks, "chunks")
		assert(#plan.slabs == CFG.GroundSlabs, "slabs")
		assert(#plan.cracks == CFG.GroundCracks * 3, "cracks")
		assert(#plan.pits == CFG.GroundPits, "pits")
	end,

	["the same dice give the same break"] = function()
		local a, b = GroundBreak.plan(CFG, roll(7)), GroundBreak.plan(CFG, roll(7))
		assert(a.chunks[3].up == b.chunks[3].up, "chunk")
		assert(a.cracks[5].x == b.cracks[5].x, "crack")
	end,

	["each stretch of a crack starts where the last one ended"] = function()
		local plan = GroundBreak.plan(CFG, roll(2))
		local one, two = plan.cracks[1], plan.cracks[2]
		local endX = one.x + math.cos(one.angle) * one.length / 2
		local startX = two.x - math.cos(two.angle) * two.length / 2
		assert(math.abs(endX - startX) < 0.001, `gap of {endX - startX}`)
	end,

	["cracks get thinner and spread outward over time"] = function()
		local plan = GroundBreak.plan(CFG, roll(3))
		assert(plan.cracks[2].width < plan.cracks[1].width, "thinner")
		assert(plan.cracks[2].delay > plan.cracks[1].delay, "later")
	end,

	["a chunk never goes under the floor, at any moment"] = function()
		local plan = GroundBreak.plan(CFG, roll(4))
		for _, chunk in plan.chunks do
			local rest = math.min(chunk.sizeX, chunk.sizeY, chunk.sizeZ) / 2
			for step = 0, 260 do
				local _, y = GroundBreak.chunkAt(CFG, chunk, step / 100)
				assert(y >= rest - 0.0001, `y {y} under {rest} at {step / 100}`)
			end
		end
	end,

	["a chunk has stopped before it starts to shrink, even the highest thrown"] = function()
		local fadeFrom = CFG.GroundBreakSeconds - CFG.GroundFadeSeconds
		local x1, y1, _, turn1, scale1 = GroundBreak.chunkAt(CFG, HIGHEST, fadeFrom)
		local x2, y2, _, turn2 = GroundBreak.chunkAt(CFG, HIGHEST, fadeFrom + 0.2)
		assert(x1 == x2 and y1 == y2, "still moving")
		assert(turn1 == turn2, "still tumbling")
		assert(scale1 == 1, "already shrinking")
	end,

	["a chunk is gone by the end"] = function()
		local _, _, _, _, scale = GroundBreak.chunkAt(CFG, HIGHEST, CFG.GroundBreakSeconds)
		assert(scale == 0, `scale {scale}`)
	end,

	["the fastest chunks really rise past the character's height"] = function()
		local _, y = GroundBreak.chunkAt(CFG, HIGHEST, HIGHEST.up / CFG.GroundChunkGravity)
		assert(y > 20, `only {y} studs`)
	end,

	["a bounce is lower and slower than the throw"] = function()
		local flight = 2 * HIGHEST.up / CFG.GroundChunkGravity
		local x1 = GroundBreak.chunkAt(CFG, HIGHEST, flight)
		local x2 = GroundBreak.chunkAt(CFG, HIGHEST, flight + 0.1)
		assert(x2 - x1 < HIGHEST.outX * 0.1, "should have lost flat speed")
		local _, y = GroundBreak.chunkAt(
			CFG,
			HIGHEST,
			flight + HIGHEST.up * CFG.GroundChunkBounce / CFG.GroundChunkGravity
		)
		local _, top = GroundBreak.chunkAt(CFG, HIGHEST, HIGHEST.up / CFG.GroundChunkGravity)
		assert(y < top * 0.2, `bounce reached {y} of {top}`)
	end,

	["slabs burst up, hold, and are fully buried again at the end"] = function()
		assert(GroundBreak.slabShare(CFG, 0) == 0, "starts buried")
		assert(GroundBreak.slabShare(CFG, CFG.GroundSlabRiseSeconds) == 1, "up after the rise")
		assert(GroundBreak.slabShare(CFG, 1.5) == 1, "holds")
		assert(GroundBreak.slabShare(CFG, CFG.GroundBreakSeconds) == 0, "buried at the end")
	end,

	["marks stay solid, then fade out exactly by the end"] = function()
		assert(GroundBreak.markFade(CFG, 1) == 0, "solid")
		assert(GroundBreak.markFade(CFG, CFG.GroundBreakSeconds) == 1, "gone")
	end,
}
